"""
Builds Sources/WordPop/Resources/rhymes.json from the CMU Pronouncing
Dictionary: groups words by their "rhyme key" (the phoneme sequence from the
last stressed vowel to the end of the word) and, within each group, ranks
words by general-English frequency so common rhymes surface first.

Usage:
    cd scripts && python3 build_rhymes.py
    cp rhymes.json ../Sources/WordPop/Resources/
"""
import json
import subprocess
from collections import defaultdict

CMUDICT_URL = "https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict"
FREQ_URL = "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-no-swears.txt"

MAX_RHYMES = 15


def fetch(url):
    # curl instead of urllib: avoids this Python install's incomplete
    # certifi/SSL trust store on a fresh macOS setup.
    return subprocess.run(
        ["curl", "-sL", url], check=True, capture_output=True, text=True
    ).stdout


print("downloading frequency list...")
freq_rank = {w.strip().lower(): i for i, w in enumerate(fetch(FREQ_URL).splitlines()) if w.strip()}

# cmudict is speech-recognition oriented and full of proper nouns/surnames
# (e.g. "haim", "mapi") that happen to rhyme but aren't real dictionary
# words. Filter candidates through macOS's system word list (only its
# all-lowercase entries, since it capitalizes proper nouns) to drop those.
with open("/usr/share/dict/words", encoding="utf-8", errors="ignore") as f:
    real_words = {w.strip() for w in f if w.strip() and w.strip().islower()}
print(f"{len(real_words)} real dictionary words for filtering")

print("downloading cmudict...")
lines = fetch(CMUDICT_URL).splitlines()
print(f"{len(lines)} lines")


def rhyme_key(phonemes):
    # Find the last phoneme carrying primary/secondary stress (a trailing
    # digit 1 or 2), and use everything from there to the end as the key.
    last_stress = -1
    for i, ph in enumerate(phonemes):
        if ph[-1] in "12":
            last_stress = i
    if last_stress == -1:
        return None
    return tuple(phonemes[last_stress:])


buckets = defaultdict(list)
word_keys = defaultdict(set)

for line in lines:
    line = line.strip()
    if not line or line.startswith(";;;"):
        continue
    parts = line.split()
    raw_word = parts[0].lower()
    phonemes = parts[1:]
    # Skip alternate pronunciations like "the(2)" — keep only the primary one
    # per word for a clean rhyme set.
    if "(" in raw_word:
        continue
    if not raw_word.isalpha():
        continue

    key = rhyme_key(phonemes)
    if key is None:
        continue
    buckets[key].append(raw_word)
    word_keys[raw_word].add(key)

print(f"{len(buckets)} rhyme buckets, {len(word_keys)} words")

result = {}
for word, keys in word_keys.items():
    candidates = []
    seen = {word}
    for key in keys:
        for other in buckets[key]:
            if other in seen or other not in real_words:
                continue
            seen.add(other)
            candidates.append(other)
    if not candidates:
        continue
    candidates.sort(key=lambda w: (freq_rank.get(w, 100_000), len(w), w))
    result[word] = candidates[:MAX_RHYMES]

print(f"words with rhymes: {len(result)}")

with open("rhymes.json", "w", encoding="utf-8") as f:
    json.dump(result, f, separators=(",", ":"), ensure_ascii=False)
