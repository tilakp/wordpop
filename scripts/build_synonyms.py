"""
Regenerates Sources/WordPop/Resources/synonyms.json and antonyms.json from
the Open English WordNet. For each word, groups synsets by part of speech
(so "run" the verb and "run" the noun don't get mixed together) and collects
candidate synonyms from every sense — same-synset words, then (for
adjectives, which don't have direct synonyms so much as a "similar to"
satellite network) similar-to neighbors.

Within each group, candidates are ranked by GloVe cosine similarity to the
headword. WordNet's own sense order is a poor proxy for "most useful
synonym first": it put "beardown, beefed-up" ahead of "powerful" for
"strong", and "blessed, blissful" ahead of "glad" for "happy". Candidates
GloVe has no vector for (multi-word phrases, very rare words) fall back to
sense order, after the ranked ones. Antonyms are a direct per-sense WordNet
relation and lists are short, so they keep plain sense order.

Setup (one-time):
    pip3 install wn gensim
    python3 -c "import wn; wn.download('oewn:2021')"
    curl -sL -o glove-wiki-gigaword-100.gz \
      https://github.com/RaRe-Technologies/gensim-data/releases/download/glove-wiki-gigaword-100/glove-wiki-gigaword-100.gz

Usage:
    cd scripts && python3 build_synonyms.py
    cp synonyms.json antonyms.json ../Sources/WordPop/Resources/
"""
import json
import time
import wn
from gensim.models import KeyedVectors

en = wn.Wordnet("oewn:2021")

print("loading GloVe vectors...")
vectors = KeyedVectors.load_word2vec_format("glove-wiki-gigaword-100.gz")

POS_GROUPS = {
    "noun": ["n"],
    "verb": ["v"],
    "adjective": ["a", "s"],
    "adverb": ["r"],
}

MAX_PHRASE_WORDS = 3
MAX_SYNONYMS = 15


def candidates_for_group(word_lower, senses, wn_pos_list):
    group_senses = [s for s in senses if s.synset().pos in wn_pos_list]
    ranked = []
    seen = set()
    for rank, s in enumerate(group_senses):
        ss = s.synset()
        for wd in ss.words():
            lemma = wd.lemma().replace("_", " ")
            key = lemma.lower()
            if key == word_lower or key in seen or len(lemma.split()) > MAX_PHRASE_WORDS:
                continue
            seen.add(key)
            ranked.append((rank, key))
        if ss.pos in ("a", "s"):
            for rel in ss.get_related("similar"):
                for wd in rel.words():
                    lemma = wd.lemma().replace("_", " ")
                    key = lemma.lower()
                    if key == word_lower or key in seen or len(lemma.split()) > MAX_PHRASE_WORDS:
                        continue
                    seen.add(key)
                    ranked.append((rank + 0.5, key))
    # Stable sort: candidates with a vector go first, most similar first;
    # ties and vector-less candidates keep WordNet sense order.
    ranked.sort(key=lambda c: (-similarity(word_lower, c[1]), c[0]))
    return [w for _, w in ranked[:MAX_SYNONYMS]]


def similarity(word_lower, candidate):
    if word_lower in vectors and candidate in vectors:
        return float(vectors.similarity(word_lower, candidate))
    return -1.0


def antonyms_for_group(word_lower, senses, wn_pos_list):
    group_senses = [s for s in senses if s.synset().pos in wn_pos_list]
    ranked = []
    seen = set()
    for rank, s in enumerate(group_senses):
        for rel in s.get_related("antonym"):
            lemma = rel.word().lemma().replace("_", " ")
            key = lemma.lower()
            if key == word_lower or key in seen or len(lemma.split()) > MAX_PHRASE_WORDS:
                continue
            seen.add(key)
            ranked.append((rank, key))
    ranked.sort(key=lambda c: c[0])
    return [w for _, w in ranked[:MAX_SYNONYMS]]


synonyms_result = {}
antonyms_result = {}
all_words = en.words()
print(f"total lemmas: {len(all_words)}")

t0 = time.time()
seen_lemmas = set()
for i, w in enumerate(all_words):
    lemma = w.lemma()
    lower = lemma.lower()
    if lower in seen_lemmas or " " in lemma or "_" in lemma or not lemma.replace("-", "").isalpha():
        continue
    seen_lemmas.add(lower)

    senses = en.senses(lemma)

    syn_entry = {}
    ant_entry = {}
    for group_name, wn_pos_list in POS_GROUPS.items():
        syns = candidates_for_group(lower, senses, wn_pos_list)
        if syns:
            syn_entry[group_name] = syns
        ants = antonyms_for_group(lower, senses, wn_pos_list)
        if ants:
            ant_entry[group_name] = ants
    if syn_entry:
        synonyms_result[lower] = syn_entry
    if ant_entry:
        antonyms_result[lower] = ant_entry

    if i % 20000 == 0:
        print(f"{i}/{len(all_words)} ({time.time()-t0:.1f}s)")

print(f"done in {time.time()-t0:.1f}s, words with synonyms: {len(synonyms_result)}, with antonyms: {len(antonyms_result)}")

with open("synonyms.json", "w", encoding="utf-8") as f:
    json.dump(synonyms_result, f, separators=(",", ":"), ensure_ascii=False)

with open("antonyms.json", "w", encoding="utf-8") as f:
    json.dump(antonyms_result, f, separators=(",", ":"), ensure_ascii=False)
