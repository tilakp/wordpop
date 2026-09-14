"""
Packs synonyms.json, antonyms.json, rhymes.json and words.txt (the outputs
of the other build scripts) into Sources/WordPop/Resources/wordpop.sqlite.

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
""")

for table in ("synonyms", "antonyms"):
    with open(f"{table}.json", encoding="utf-8") as f:
        data = json.load(f)
    db.executemany(
        f"INSERT INTO {table} VALUES (?, ?, ?)",
        ((word, pos, SEPARATOR.join(words)) for word, groups in data.items() for pos, words in groups.items()),
    )
    print(f"{table}: {len(data)} words")

for table in ("rhymes", "near_rhymes"):
    with open(f"{table}.json", encoding="utf-8") as f:
        rhymes = json.load(f)
    db.executemany(f"INSERT INTO {table} VALUES (?, ?)", ((w, SEPARATOR.join(r)) for w, r in rhymes.items()))
    print(f"{table}: {len(rhymes)} words")

with open("words.txt", encoding="utf-8") as f:
    words = [line.strip() for line in f if line.strip()]
db.executemany("INSERT INTO words VALUES (?, ?)", ((w, i) for i, w in enumerate(words)))
print(f"words: {len(words)}")

db.commit()
db.execute("VACUUM")
db.close()
print(f"wrote {OUT} ({os.path.getsize(OUT) / 1_048_576:.1f} MB)")
