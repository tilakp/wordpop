"""
Packs synonyms.json, antonyms.json, rhymes.json, syllables.json and words.txt (the outputs
of the other build scripts) and the hand-written confusables.txt,
stronger.txt and inclusive.txt into Sources/WordPop/Resources/wordpop.sqlite.

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

db.commit()
db.execute("VACUUM")
db.close()
print(f"wrote {OUT} ({os.path.getsize(OUT) / 1_048_576:.1f} MB)")
