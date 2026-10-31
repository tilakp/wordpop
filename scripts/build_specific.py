"""
Writes specific.json: for each noun and verb, the more specific words for
its main senses, from Open English WordNet hyponyms ("walk" -> stroll,
amble, trudge; "car" -> taxi, jeep, limousine). build_db.py packs it into
the specific table.

For each part of speech, up to MAX_SENSES senses in WordNet's order (most
common first) that have at least two such words; each sense keeps a short
gloss as its caption and up to MAX_WORDS words, most common first. Words
outside words.txt or rarer than MAX_RANK are left out ("lollop"), and so
are words for which this is not their first sense ("mouse" is a way to
walk, but not what a reader takes it to mean) or whose part of speech is
mostly another ("have" is a kind of person).

Setup (one-time):
    pip3 install wn
    python3 -c "import wn; wn.download('oewn:2021')"

Usage:
    cd scripts && python3 build_specific.py && python3 build_db.py
"""
import json
import wn

MAX_SENSES = 3
MAX_WORDS = 10
MAX_RANK = 45_000
# A word counts when the hyponym is among its first MAIN_SENSES senses
# in that part of speech.
MAIN_SENSES = 1
POS = {"n": "noun", "v": "verb"}

with open("words.txt", encoding="utf-8") as f:
    rank = {line.strip(): i for i, line in enumerate(f) if line.strip()}

net = wn.Wordnet("oewn:2021")


def gloss(synset):
    """The definition up to its first semicolon or comma, in a few words."""
    text = synset.definition().split(";")[0].strip()
    words = text.split()
    return " ".join(words[:8]) + ("…" if len(words) > 8 else "")


def mostly(lemma, pos):
    """Whether `lemma` has at least as many senses as `pos` as in any other
    part of speech: "have" and "modern" are kinds of person in WordNet,
    but a reader takes them as a verb and an adjective."""
    counts = {}
    for synset in net.synsets(lemma):
        kind = "a" if synset.pos == "s" else synset.pos
        counts[kind] = counts.get(kind, 0) + 1
    return counts.get(pos, 0) >= max(counts.values())


result = {}
for word in rank:
    if " " in word or not word.isalpha():
        continue
    for short, pos in POS.items():
        senses = []
        for synset in net.synsets(word, pos=short):
            found = []
            for hyponym in synset.hyponyms():
                for lemma in hyponym.lemmas():
                    lemma = lemma.replace("_", " ")
                    if lemma != word and "-" not in lemma and lemma not in found and rank.get(lemma, MAX_RANK) < MAX_RANK \
                            and hyponym in net.synsets(lemma, pos=short)[:MAIN_SENSES] and mostly(lemma, short):
                        found.append(lemma)
            if len(found) >= 2:
                senses.append([gloss(synset), sorted(found, key=rank.get)[:MAX_WORDS]])
            if len(senses) == MAX_SENSES:
                break
        if senses:
            result.setdefault(word, {})[pos] = senses

with open("specific.json", "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
print(f"specific: {len(result)} words")
