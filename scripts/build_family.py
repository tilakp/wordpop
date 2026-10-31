"""
Writes family.json: for each word, the other words of its family ("decide"
-> decision, decisive, decisively, undecided), from Open English WordNet's
derivation and pertainym links. build_db.py packs it into the family table.

The links are read both ways ("quickly" points to "quick", so "quick" gets
"quickly") and followed for up to MAX_STEPS steps, as "decision" links to
"decide" and "decisive", but "decide" not to "decisively". A word joins a
family only when it shares its first FIRST_LETTERS letters with the word,
which keeps out links such as "create" -> "creature" -> "critter". Words
outside words.txt or rarer than MAX_RANK are left out. Up to MAX_WORDS
words, nouns first, then verbs, adjectives and adverbs, each most common
first.

Setup (one-time):
    pip3 install wn
    python3 -c "import wn; wn.download('oewn:2021')"

Usage:
    cd scripts && python3 build_family.py && python3 build_db.py
"""
import json
import wn

MAX_STEPS = 2
MAX_WORDS = 10
MAX_RANK = 45_000
FIRST_LETTERS = 3
POS_ORDER = {"n": 0, "v": 1, "a": 2, "s": 2, "r": 3}

with open("words.txt", encoding="utf-8") as f:
    rank = {line.strip(): i for i, line in enumerate(f) if line.strip()}

net = wn.Wordnet("oewn:2021")
links = {}
pos_of = {}
for word in rank:
    if " " in word or not word.isalpha():
        continue
    for sense in net.senses(word):
        pos_of.setdefault(word, POS_ORDER.get(sense.word().pos, 4))
        for related in sense.get_related("derivation") + sense.get_related("pertainym"):
            other = related.word().lemma()
            if other != word and other in rank and other.isalpha():
                links.setdefault(word, set()).add(other)
                links.setdefault(other, set()).add(word)
                pos_of.setdefault(other, POS_ORDER.get(related.word().pos, 4))

result = {}
for word in links:
    found, frontier = {word}, {word}
    for _ in range(MAX_STEPS):
        frontier = {other for w in frontier for other in links.get(w, ()) if other not in found}
        found |= frontier
    family = [w for w in found - {word}
              if w[:FIRST_LETTERS] == word[:FIRST_LETTERS] and rank[w] < MAX_RANK]
    if family:
        result[word] = sorted(family, key=lambda w: (pos_of.get(w, 4), rank[w]))[:MAX_WORDS]

with open("family.json", "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
print(f"family: {len(result)} words")
