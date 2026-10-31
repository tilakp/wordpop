"""
Builds Sources/WordPop/Resources/examples.sqlite: English example sentences
from Tatoeba (https://tatoeba.org, CC BY 2.0 FR) with a full-text index, for
Quick Search's usage check ("different than" or "different from"?).

It is a database of its own, apart from wordpop.sqlite, so a change to the
word lists does not add another copy of these sentences to the repository.

Kept: sentences of MIN_WORDS to MAX_WORDS words, without "Tom" or "Mary"
(Tatoeba's stock names, in about 400,000 near-identical sentences), once
each, ignoring case and punctuation. From those, TARGET are taken, spread
evenly by a hash of the text so the choice is the same on every run.

Usage (downloads about 25 MB):
    cd scripts && python3 build_examples.py
"""
import bz2
import hashlib
import os
import re
import sqlite3
import subprocess
import tempfile

URL = "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2"
OUT = "../Sources/WordPop/Resources/examples.sqlite"
MIN_WORDS, MAX_WORDS = 7, 25
TARGET = 400_000

with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "eng.tsv.bz2")
    subprocess.run(["curl", "-sL", "-o", path, URL], check=True)
    with bz2.open(path, "rt", encoding="utf-8") as f:
        lines = f.readlines()

seen, sentences = set(), []
for line in lines:
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 3:
        continue
    text = parts[2].strip()
    if not MIN_WORDS <= len(text.split()) <= MAX_WORDS or re.search(r"\b(Tom|Mary)\b", text):
        continue
    key = re.sub(r"\W+", " ", text.lower()).strip()
    if key not in seen:
        seen.add(key)
        sentences.append(text)
print(f"{len(sentences)} candidate sentences")

# The TARGET sentences with the lowest hash: an even, repeatable sample.
sentences.sort(key=lambda s: hashlib.md5(s.encode()).hexdigest())
sentences = sentences[:TARGET]

if os.path.exists(OUT):
    os.remove(OUT)
db = sqlite3.connect(OUT)
db.execute("CREATE VIRTUAL TABLE sentences USING fts5(text, tokenize = 'unicode61')")
db.executemany("INSERT INTO sentences (text) VALUES (?)", ((s,) for s in sentences))
db.execute("INSERT INTO sentences (sentences) VALUES ('optimize')")
db.commit()
db.execute("VACUUM")
db.close()
print(f"wrote {OUT}: {len(sentences)} sentences, {os.path.getsize(OUT) / 1_048_576:.1f} MB")
