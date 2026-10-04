"""
Writes syllables.json: the syllable count, from the CMU Pronouncing
Dictionary, of every word in rhymes.json and near_rhymes.json, so the
popup can group rhymes by syllables for poets and lyricists.

Usage:
    cd scripts && python3 build_syllables.py && python3 build_db.py
"""
import json
import subprocess

CMUDICT_URL = "https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict"

words = set()
for name in ("rhymes.json", "near_rhymes.json"):
    with open(name, encoding="utf-8") as f:
        for head, rhymes in json.load(f).items():
            words.add(head)
            words.update(rhymes)

# curl, as in build_rhymes.py: this Python's SSL trust store can be incomplete.
cmudict = subprocess.run(["curl", "-sL", CMUDICT_URL], check=True, capture_output=True, text=True).stdout
syllables = {}
for line in cmudict.splitlines():
    entry, *phonemes = line.split("#")[0].split()
    word = entry.split("(")[0]  # "read(2)" is a second pronunciation of "read"
    if word in words and word not in syllables:
        # Every vowel phoneme carries a stress digit; one per syllable.
        syllables[word] = sum(phoneme[-1].isdigit() for phoneme in phonemes)

with open("syllables.json", "w", encoding="utf-8") as f:
    json.dump(syllables, f, separators=(",", ":"), ensure_ascii=False, sort_keys=True)
print(f"syllables: {len(syllables)} of {len(words)} words")
