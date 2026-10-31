"""
Packs synonyms.json, antonyms.json, rhymes.json, syllables.json, specific.json, family.json and words.txt (the outputs
of the other build scripts) and the hand-written confusables.txt,
stronger.txt, inclusive.txt, wordy.txt, plain.txt, cliches.txt and hidden.txt, and the ste.txt style preset, into Sources/WordPop/Resources/wordpop.sqlite.

The app queries this database on demand instead of decoding the JSON at
launch, which took about half a second of CPU and held ~100 MB resident.

Usage:
    cd scripts && python3 build_db.py
"""
import json
import os
import sqlite3

OUT = "../Sources/WordPop/Resources/wordpop.sqlite"
SEPARATOR = "\t"

if os.path.exists(OUT):
    os.remove(OUT)
db = sqlite3.connect(OUT)
db.executescript("""
    CREATE TABLE synonyms (word TEXT NOT NULL, pos TEXT NOT NULL, words TEXT NOT NULL, PRIMARY KEY (word, pos)) WITHOUT ROWID;
    CREATE TABLE antonyms (word TEXT NOT NULL, pos TEXT NOT NULL, words TEXT NOT NULL, PRIMARY KEY (word, pos)) WITHOUT ROWID;
    CREATE TABLE rhymes (word TEXT PRIMARY KEY NOT NULL, words TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE near_rhymes (word TEXT PRIMARY KEY NOT NULL, words TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE words (word TEXT PRIMARY KEY NOT NULL, rank INTEGER NOT NULL) WITHOUT ROWID;
    CREATE TABLE confusables (grp INTEGER NOT NULL, word TEXT NOT NULL, sense TEXT NOT NULL, PRIMARY KEY (word, grp)) WITHOUT ROWID;
    CREATE INDEX confusables_grp ON confusables (grp);
    CREATE TABLE syllables (word TEXT PRIMARY KEY NOT NULL, count INTEGER NOT NULL) WITHOUT ROWID;
    CREATE TABLE hints (word TEXT NOT NULL, kind TEXT NOT NULL, position INTEGER NOT NULL, caption TEXT, words TEXT NOT NULL,
                        PRIMARY KEY (word, kind, position)) WITHOUT ROWID;
    CREATE TABLE flags (phrase TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, fix TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE family (word TEXT PRIMARY KEY NOT NULL, words TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE presets (name TEXT PRIMARY KEY NOT NULL, rules TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE specific (word TEXT NOT NULL, pos TEXT NOT NULL, position INTEGER NOT NULL, caption TEXT NOT NULL,
                           words TEXT NOT NULL, PRIMARY KEY (word, pos, position)) WITHOUT ROWID;
""")

for table in ("synonyms", "antonyms"):
    with open(f"{table}.json", encoding="utf-8") as f:
        data = json.load(f)
    db.executemany(
        f"INSERT INTO {table} VALUES (?, ?, ?)",
        ((word, pos, SEPARATOR.join(words)) for word, groups in data.items() for pos, words in groups.items()),
    )
    print(f"{table}: {len(data)} words")

# CMUdict spells out letters and abbreviations (d, tv, hr, ok), which
# surfaced as rhymes for day, see and me. Only real two-letter words stay.
TWO_LETTER_WORDS = {"be", "he", "me", "we", "so", "no", "go", "do", "to", "on", "by", "hi", "at", "up", "as", "ox",
                    "us", "my", "oh", "ah", "an", "in", "it", "is", "of", "or", "if", "ma", "pa"}


def real_word(word):
    return len(word) > 2 or word in TWO_LETTER_WORDS


for table in ("rhymes", "near_rhymes"):
    with open(f"{table}.json", encoding="utf-8") as f:
        rhymes = {w: kept for w, r in json.load(f).items() if (kept := [x for x in r if real_word(x)])}
    db.executemany(f"INSERT INTO {table} VALUES (?, ?)", ((w, SEPARATOR.join(r)) for w, r in rhymes.items()))
    print(f"{table}: {len(rhymes)} words")

with open("syllables.json", encoding="utf-8") as f:
    syllables = json.load(f)
db.executemany("INSERT INTO syllables VALUES (?, ?)", syllables.items())
print(f"syllables: {len(syllables)} words")

# More specific words by sense, from build_specific.py.
with open("specific.json", encoding="utf-8") as f:
    specific = json.load(f)
db.executemany(
    "INSERT INTO specific VALUES (?, ?, ?, ?, ?)",
    ((word, pos, position, caption, SEPARATOR.join(words))
     for word, groups in specific.items() for pos, senses in groups.items()
     for position, (caption, words) in enumerate(senses)),
)
print(f"specific: {len(specific)} words")

# Word families, from build_family.py.
with open("family.json", encoding="utf-8") as f:
    family = json.load(f)
db.executemany("INSERT INTO family VALUES (?, ?)", ((w, SEPARATOR.join(f)) for w, f in family.items()))
print(f"family: {len(family)} words")

with open("words.txt", encoding="utf-8") as f:
    words = [line.strip() for line in f if line.strip()]
db.executemany("INSERT INTO words VALUES (?, ?)", ((w, i) for i, w in enumerate(words)))
print(f"words: {len(words)}")

with open("confusables.txt", encoding="utf-8") as f:
    groups = [line.strip() for line in f if line.strip() and not line.startswith("#")]
db.executemany(
    "INSERT INTO confusables VALUES (?, ?, ?)",
    ((index, *(part.strip() for part in member.split("=", 1)))
     for index, group in enumerate(groups) for member in group.split(" ; ")),
)
print(f"confusables: {len(groups)} groups")

# "word | caption: alternatives | alternatives": one hint row per group.
for kind in ("stronger", "inclusive"):
    rows = []
    with open(f"{kind}.txt", encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            word, *groups = (part.strip() for part in line.split(" | "))
            for position, group in enumerate(groups):
                caption, _, words = group.rpartition(": ")
                rows.append((word.lower(), kind, position, caption or None,
                             SEPARATOR.join(w.strip() for w in words.split(","))))
    db.executemany("INSERT INTO hints VALUES (?, ?, ?, ?, ?)", rows)
    print(f"hints {kind}: {len(rows)} rows")

# "phrase | fix", where an empty fix means the phrase can go. Plain words
# ("utilize | use") are fixed like wordy phrases.
for kind in ("wordy", "plain", "cliches"):
    with open(f"{kind}.txt", encoding="utf-8") as f:
        rows = [(phrase.strip().lower(), kind, fix.strip())
                for phrase, _, fix in (line.rstrip("\n").partition("|") for line in f if line.strip() and not line.startswith("#"))]
    db.executemany("INSERT INTO flags VALUES (?, ?, ?)", rows)
    print(f"flags {kind}: {len(rows)} phrases")

# Hidden verbs: each base phrase in every form of its first verb, each
# mapped to the same form of the plain verb. Forms: base, third person,
# past, past participle, -ing.
LIGHT_VERBS = {
    "make": ("make", "makes", "made", "made", "making"),
    "give": ("give", "gives", "gave", "given", "giving"),
    "take": ("take", "takes", "took", "taken", "taking"),
    "have": ("have", "has", "had", "had", "having"),
    "reach": ("reach", "reaches", "reached", "reached", "reaching"),
    "come": ("come", "comes", "came", None, "coming"),
    "conduct": ("conduct", "conducts", "conducted", "conducted", "conducting"),
    "perform": ("perform", "performs", "performed", "performed", "performing"),
    "carry": ("carry", "carries", "carried", "carried", "carrying"),
    "undertake": ("undertake", "undertakes", "undertook", "undertaken", "undertaking"),
    "provide": ("provide", "provides", "provided", "provided", "providing"),
    "offer": ("offer", "offers", "offered", "offered", "offering"),
}
IRREGULAR = {"pay": ("pay", "pays", "paid", "paid", "paying")}
DOUBLED = {"refer", "prefer"}


def forms(verb):
    """The five forms of a regular verb ("decide" -> decides, decided,
    decided, deciding)."""
    if verb in IRREGULAR:
        return IRREGULAR[verb]
    if verb in DOUBLED:
        stem = verb + verb[-1]
        return verb, verb + "s", stem + "ed", stem + "ed", stem + "ing"
    if verb.endswith("y") and verb[-2] not in "aeiou":
        return verb, verb[:-1] + "ies", verb[:-1] + "ied", verb[:-1] + "ied", verb + "ing"
    if verb.endswith("ee"):
        return verb, verb + "s", verb + "d", verb + "d", verb + "ing"
    if verb.endswith("e"):
        return verb, verb + "s", verb + "d", verb + "d", verb[:-1] + "ing"
    third = verb + "es" if verb.endswith(("s", "sh", "ch", "x", "z")) else verb + "s"
    return verb, third, verb + "ed", verb + "ed", verb + "ing"


hidden = {}
with open("hidden.txt", encoding="utf-8") as f:
    for line in f:
        if not line.strip() or line.startswith("#"):
            continue
        phrase, _, fix = (part.strip() for part in line.partition("|"))
        light, rest = phrase.split(" ", 1)
        verb, *after = fix.split(" ")
        targets = forms(verb)
        variants = [rest]
        for article in (" a ", " an "):
            if article in f" {rest} ":
                variants.append(f" {rest} ".replace(article, " the ", 1).strip())
        for variant in variants:
            for index, light_form in enumerate(LIGHT_VERBS[light]):
                if light_form:
                    hidden.setdefault(f"{light_form} {variant}", " ".join([targets[index], *after]))
            # "Come" is its own past participle: "have come to the
            # conclusion" -> have concluded, not "have conclude".
            if LIGHT_VERBS[light][3] is None:
                for auxiliary in ("have", "has", "had"):
                    hidden[f"{auxiliary} come {variant}"] = " ".join([auxiliary, targets[3], *after])
db.executemany("INSERT OR IGNORE INTO flags VALUES (?, 'hidden', ?)", hidden.items())
print(f"flags hidden: {len(hidden)} phrases")

# Style rule presets, kept as written; the app parses them like the
# user's own rules file.
with open("ste.txt", encoding="utf-8") as f:
    db.execute("INSERT INTO presets VALUES ('ste', ?)", (f.read(),))
print("presets: ste")

db.commit()
db.execute("VACUUM")
db.close()
print(f"wrote {OUT} ({os.path.getsize(OUT) / 1_048_576:.1f} MB)")
