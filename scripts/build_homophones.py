"""
Writes homophones.json: for each word, the words that sound the same
("pair" -> pare, pear; "council" -> counsel), from the CMU Pronouncing
Dictionary. build_db.py packs it into the homophones table.

Two words sound the same when they share a pronunciation, stress included.
Only words in words.txt and more common than MAX_RANK, and common function
words and contractions, are kept, single letters are not, and British
and American spellings of one word ("colour", "color"; "realise",
"realize") are not homophones, so they are left out.

Setup (one-time): none beyond words.txt (build_words.py).

Usage:
    cd scripts && python3 build_homophones.py && python3 build_db.py
"""
import json
import re
import subprocess
from collections import defaultdict

CMUDICT_URL = "https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict"
MAX_RANK = 45_000
MAX_WORDS = 6

# Function words and contractions, which WordNet (and so words.txt) does
# not list but which hold the most often confused homophones: their, there,
# they're; to, too, two; its, it's.
FUNCTION_WORDS = """a about all an and any are as at be been but by can could did do does for from had has have he her
here him his how i if in into is it its it's me my no not now of off on one only or our out so some than that the their
them then there these they they're this those to too two up us was we we're were what when where which while who who's
whose why will with won't would you you're your yours hour our week weak whole hole knew new knows nose""".split()

with open("words.txt", encoding="utf-8") as f:
    rank = {line.strip(): i for i, line in enumerate(f) if line.strip()}
for word in FUNCTION_WORDS:
    rank.setdefault(word, -1)

lines = subprocess.run(["curl", "-sL", CMUDICT_URL], check=True, capture_output=True, text=True).stdout.splitlines()
by_sound = defaultdict(set)
for line in lines:
    line = line.split("#")[0].strip()
    if not line:
        continue
    word, *phones = line.split()
    word = re.sub(r"\(\d+\)$", "", word)
    if len(word) > 1 and (word.isalpha() or word in FUNCTION_WORDS) and rank.get(word, MAX_RANK) < MAX_RANK:
        by_sound[" ".join(phones)].add(word)


def spelling_variant(a, b):
    """Whether a and b are one word in British and American spelling."""
    for british, american in (("our", "or"), ("ise", "ize"), ("isa", "iza"), ("yse", "yze"), ("re", "er"), ("ll", "l"),
                              ("ogue", "og"), ("ae", "e"), ("oe", "e"), ("ce", "se"), ("mme", "m"), ("ss", "s")):
        if a.replace(british, american) == b or b.replace(british, american) == a:
            return True
    return False


result = defaultdict(set)
for words in by_sound.values():
    for word in words:
        for other in words:
            if other != word and not spelling_variant(word, other):
                result[word].add(other)

out = {word: sorted(others, key=rank.get)[:MAX_WORDS] for word, others in result.items() if others}
with open("homophones.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print(f"homophones: {len(out)} words")
