"""
Builds Sources/WordPop/Resources/words.txt, the type-ahead word list for
Quick Search: every single-word Open English WordNet lemma, one per line,
ordered by general-English frequency (wordfreq) so that "app" suggests
"apple, application, approach" before "appanage".

Setup (one-time):
    pip3 install wn wordfreq
    python3 -c "import wn; wn.download('oewn:2021')"

Usage:
    cd scripts && python3 build_words.py
    cp words.txt ../Sources/WordPop/Resources/
"""
import wn
from wordfreq import zipf_frequency

lemmas = {
    w.lemma() for w in wn.Wordnet("oewn:2021").words()
    if w.lemma().islower() and w.lemma().replace("-", "").isalpha()
}
ordered = sorted(lemmas, key=lambda w: (-zipf_frequency(w, "en"), len(w), w))
print(f"{len(ordered)} words")

with open("words.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(ordered))
    f.write("\n")
