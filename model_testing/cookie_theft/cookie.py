"""
cookie_theft_scoring.py

Automated scoring for Cookie Theft picture descriptions.

Dependencies:
 - Python 3.8+
 - spaCy (tested with spacy==3.6.0) and the en_core_web_sm model

Notes:
 - This is a heuristic/linguistic scoring tool. It is NOT a clinical diagnostic tool.
 - The Content Unit list is editable; adapt it to local scoring norms or add synonyms.
 - For rigorous research/clinical use, compare automatic scores to human raters and refine heuristics.
"""

import argparse
import json
import os
import re
from collections import Counter, defaultdict
from typing import List, Dict, Tuple

import spacy

# ---- Configurable lists (edit as needed) ----
# Content units (CU) typical for Cookie Theft; include synonyms where useful.
# These are surface patterns; expand to include more synonyms or multiword patterns.
CONTENT_UNITS = [
    "boy", "girl", "mother", "cookie", "cookie jar", "stool", "ladder", "sink",
    "water", "overflow", "tap", "running water", "cup", "cups", "plate", "dishes",
    "drying dishes", "stool tipping", "stool falling", "boy on stool",
    "girl reaching", "girl arm up", "mother not looking", "mother distracted",
    "giving cookie", "taking cookie", "curtain", "garden", "outside", "floor wet"
]

# Map of normalized pattern -> canonical CU label (for output clarity)
CU_CANONICAL = {cu: cu for cu in CONTENT_UNITS}

# Mental state verbs/phrases to detect (expandable)
MENTAL_STATE_TERMS = [
    "want", "wants", "wanted", "wanting",
    "think", "thinks", "thought",
    "believe", "believes",
    "forget", "forgot", "forgotten",
    "remember", "remembers", "remembered",
    "attention", "preoccupied", "preoccupied with",
    "trying to", "trying", "intend", "intent",
    "feel", "feels", "feeling",
    "wish", "wishes"
]

# Filled pauses (fluency markers)
FILLERS = ["um", "uh", "erm", "hmm", "mm", "ah"]

# Pronouns to check for referential cohesion
PRONOUNS = {"he", "she", "they", "it", "his", "her", "their", "them", "its"}

# Simple antecedent keywords (specific referents)
ANTECEDENT_KEYWORDS = {"mother", "mom", "mother's", "boy", "girl", "son", "daughter", "stool", "sink", "jar", "cookie", "girl's"}

# ---- End configurable lists ----

nlp = spacy.load("en_core_web_sm")


# ---------- Utility text functions ----------
def normalize_text(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[-—]", " ", s)
    s = re.sub(r"[^\w\s']", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def find_content_units(text: str, cu_patterns: List[str]) -> Tuple[set, Dict[str, int]]:
    """
    Simple pattern matching for content units.
    Returns set of matched canonical CU labels and frequency dict.
    """
    text_norm = normalize_text(text)
    counts = Counter()
    for pat in cu_patterns:
        pat_norm = normalize_text(pat)
        # match multiword patterns as substring; single tokens as word boundary
        if " " in pat_norm:
            if pat_norm in text_norm:
                counts[CU_CANONICAL.get(pat, pat_norm)] += text_norm.count(pat_norm)
        else:
            # word boundary match
            matches = re.findall(r"\b{}\b".format(re.escape(pat_norm)), text_norm)
            if matches:
                counts[CU_CANONICAL.get(pat, pat_norm)] += len(matches)
    return set(counts.keys()), dict(counts)


def count_mental_state_terms(text: str, terms: List[str]) -> Dict[str, int]:
    text_norm = normalize_text(text)
    c = Counter()
    for t in terms:
        t_norm = normalize_text(t)
        if t_norm in text_norm:
            c[t_norm] = text_norm.count(t_norm)
    return dict(c)


def count_fillers(text: str, fillers: List[str]) -> Dict[str, int]:
    text_norm = normalize_text(text)
    c = Counter()
    for f in fillers:
        matches = re.findall(r"\b{}\b".format(re.escape(f)), text_norm)
        if matches:
            c[f] = len(matches)
    return dict(c)


def lexical_diversity(tokens: List[str]) -> float:
    if not tokens:
        return 0.0
    types = set(tokens)
    return len(types) / len(tokens)


def detect_repetitions(text: str, min_ngram=2, max_ngram=6) -> Dict[str, int]:
    """
    Detect repeated n-grams (simple approach).
    Returns n-grams that repeat with counts.
    """
    text_norm = normalize_text(text)
    words = text_norm.split()
    found = Counter()
    for n in range(min_ngram, min(max_ngram + 1, len(words) + 1)):
        for i in range(len(words) - n + 1):
            ngram = " ".join(words[i:i + n])
            found[ngram] += 1
    # keep only ngrams that appear more than once
    rep = {k: v for k, v in found.items() if v > 1}
    # sort by length and frequency (longer ngrams first, then frequency)
    sorted_items = sorted(rep.items(), key=lambda x: (-len(x[0].split()), -x[1]))
    # take top 20 and return as dict
    return dict(sorted_items[:20])


def pronoun_antecedent_heuristic(doc) -> Tuple[int, int, Dict[str, int]]:
    """
    Heuristic: for each pronoun occurrence, check whether a specific antecedent
    keyword was mentioned earlier in the text (prior sentences).
    Returns (pronoun_count, pronouns_with_antecedent, breakdown)
    """
    pronoun_count = 0
    pronouns_with_antecedent = 0
    breakdown = Counter()

    # gather sentence-level sets of tokens (normalized)
    sent_keywords = []
    for sent in doc.sents:
        tokens = set([tok.lemma_.lower() for tok in sent if not tok.is_punct])
        sent_keywords.append(tokens)

    # for each sentence, look for pronouns and try to find antecedent in any prior sentence
    for i, sent in enumerate(doc.sents):
        sent_text = normalize_text(sent.text)
        toks = [tok for tok in sent if not tok.is_punct]
        for tok in toks:
            if tok.text.lower() in PRONOUNS:
                pronoun_count += 1
                # search prior sentences for antecedent keywords
                found = False
                for j in range(0, i):
                    if sent_keywords[j] & ANTECEDENT_KEYWORDS:
                        found = True
                        break
                if found:
                    pronouns_with_antecedent += 1
                    breakdown[tok.text.lower()] += 1
    return pronoun_count, pronouns_with_antecedent, dict(breakdown)


# ---------- Main scoring pipeline ----------
def score_transcript(text: str, cu_list: List[str] = CONTENT_UNITS) -> Dict:
    """
    Score a single transcript string and return a dictionary of metrics + details.
    """
    text = text.strip()
    doc = nlp(text)

    # tokens and sentences
    tokens = [tok.text for tok in doc if not tok.is_punct]
    sents = list(doc.sents)

    # content units
    matched_cus, cu_counts = find_content_units(text, cu_list)
    cu_total = len(cu_list)
    cu_present = len(matched_cus)
    cu_proportion = cu_present / cu_total if cu_total else 0.0

    # mental state language
    mental_counts = count_mental_state_terms(text, MENTAL_STATE_TERMS)
    mental_total = sum(mental_counts.values())

    # fillers / fluency
    filler_counts = count_fillers(text, FILLERS)
    filler_total = sum(filler_counts.values())

    # lexical diversity
    lex_div = lexical_diversity([tok.lower() for tok in tokens if tok.isalpha()])

    # pronoun antecedent heuristic
    pron_count, pron_with_ante, pron_breakdown = pronoun_antecedent_heuristic(doc)
    pron_cohesion_ratio = (pron_with_ante / pron_count) if pron_count else 1.0

    # repetitions (top n-grams repeated)
    repetitions = detect_repetitions(text)

    # mean sentence length
    mean_sent_len = (len(tokens) / len(sents)) if sents else 0

    # assemble output
    out = {
        "raw_text": text,
        "n_tokens": len(tokens),
        "n_sentences": len(sents),
        "mean_sentence_length_tokens": mean_sent_len,
        "content_units": {
            "expected_total": cu_total,
            "present_count": cu_present,
            "present_proportion": round(cu_proportion, 3),
            "matched_items": list(matched_cus),
            "counts": cu_counts
        },
        "mental_state": {
            "counts_by_term": mental_counts,
            "total_mental_terms": mental_total
        },
        "fluency_fillers": {
            "counts_by_filler": filler_counts,
            "total_fillers": filler_total
        },
        "lexical_diversity": round(lex_div, 3),
        "pronoun_cohesion": {
            "pronoun_count": pron_count,
            "pronouns_with_prior_antecedent": pron_with_ante,
            "cohesion_ratio": round(pron_cohesion_ratio, 3),
            "breakdown": pron_breakdown
        },
        "repetitions": repetitions
    }
    return out


# ---------- CLI / batch processing ----------
def process_input_path(input_path: str, outpath: str = None):
    results = {}
    if os.path.isdir(input_path):
        for fname in os.listdir(input_path):
            if fname.lower().endswith(".txt"):
                p = os.path.join(input_path, fname)
                with open(p, "r", encoding="utf-8") as f:
                    txt = f.read()
                res = score_transcript(txt)
                results[fname] = res
    else:
        with open(input_path, "r", encoding="utf-8") as f:
            txt = f.read()
        res = score_transcript(txt)
        results[os.path.basename(input_path)] = res

    # write to outpath or print
    if outpath:
        with open(outpath, "w", encoding="utf-8") as outf:
            json.dump(results, outf, indent=2)
        print(f"Results written to {outpath}")
    else:
        print(json.dumps(results, indent=2))
    return results


# Optional: a pretty textual report generator
def pretty_report(score_dict: Dict) -> str:
    lines = []
    lines.append("Cookie Theft Automated Scoring Report")
    lines.append("-" * 40)
    lines.append(f"Tokens: {score_dict['n_tokens']}, Sentences: {score_dict['n_sentences']}")
    lines.append(f"Mean sentence length (tokens): {score_dict['mean_sentence_length_tokens']:.2f}")
    cu = score_dict["content_units"]
    lines.append(f"Content units present: {cu['present_count']} / {cu['expected_total']} "
                 f"({cu['present_proportion']*100:.1f}%)")
    lines.append(f"Matched CUs: {', '.join(cu['matched_items']) if cu['matched_items'] else 'None'}")
    lines.append(f"Mental-state terms (total): {score_dict['mental_state']['total_mental_terms']}")
    lines.append(f"Filled pauses: {score_dict['fluency_fillers']['total_fillers']}")
    lines.append(f"Lexical diversity (TTR): {score_dict['lexical_diversity']:.3f}")
    pron = score_dict["pronoun_cohesion"]
    lines.append(f"Pronouns: {pron['pronoun_count']}, with antecedent heuristic: {pron['pronouns_with_prior_antecedent']} "
                 f"(ratio {pron['cohesion_ratio']:.3f})")
    lines.append("Top repeated n-grams (if any):")
    for k, v in score_dict["repetitions"].items():
        lines.append(f"  '{k}' x{v}")
    lines.append("-" * 40)
    return "\n".join(lines)


# ----- CLI entrypoint -----
# ----------------- Heuristic dementia-risk evaluator -----------------
def evaluate_dementia_risk(score: Dict) -> Dict:
    """
    Heuristic rule-based assessment that flags language patterns associated
    with cognitive impairment / dementia. THIS IS NOT A DIAGNOSIS.

    Inputs:
      score: the dictionary output from score_transcript(...)

    Returns:
      dict with:
        - 'risk_label': one of 'Low', 'Moderate', 'High'
        - 'risk_score': numeric 0..1 (higher = more concern)
        - 'reasons': list of human-readable reasons/metrics that contributed
    """
    reasons = []
    # thresholds (tunable)
    TH_CU_PROPORTION_LOW = 0.50     # fewer content units than expected
    TH_LEX_DIV_LOW = 0.25           # low type-token ratio
    TH_FILLERS_PER_100 = 5.0        # >5 fillers per 100 tokens
    TH_MEAN_SENT_LEN_LOW = 8.0      # short sentences (tokens)
    TH_PRON_COHESION_LOW = 0.60     # many pronouns without antecedents
    TH_REPETITIONS_COUNT = 2        # more than 2 repeated n-grams

    # extract metrics defensively
    cu_prop = float(score.get("content_units", {}).get("present_proportion", 0.0))
    lex_div = float(score.get("lexical_diversity", 0.0))
    n_tokens = int(score.get("n_tokens", 0)) or 1
    filler_total = int(score.get("fluency_fillers", {}).get("total_fillers", 0))
    mean_sent_len = float(score.get("mean_sentence_length_tokens", 0.0))
    pron_cohesion = float(score.get("pronoun_cohesion", {}).get("cohesion_ratio", 1.0))
    repetitions = score.get("repetitions", {})
    rep_count = len(repetitions)

    # normalized signals (0..1)
    score_cu = max(0.0, (TH_CU_PROPORTION_LOW - cu_prop) / TH_CU_PROPORTION_LOW)  # higher when cu low
    score_lex = max(0.0, (TH_LEX_DIV_LOW - lex_div) / TH_LEX_DIV_LOW)              # higher when lex div low
    fillers_per_100 = filler_total * 100.0 / n_tokens
    score_fillers = max(0.0, (fillers_per_100 - TH_FILLERS_PER_100) / max(1.0, TH_FILLERS_PER_100))
    score_sentlen = max(0.0, (TH_MEAN_SENT_LEN_LOW - mean_sent_len) / TH_MEAN_SENT_LEN_LOW)
    score_pron = max(0.0, (TH_PRON_COHESION_LOW - pron_cohesion) / TH_PRON_COHESION_LOW)
    score_reps = max(0.0, (rep_count - TH_REPETITIONS_COUNT) / max(1.0, TH_REPETITIONS_COUNT))

    # weighted aggregate (weights chosen to reflect typical importance; tune as needed)
    w = {
        "cu": 0.30,
        "lex": 0.15,
        "fillers": 0.15,
        "sentlen": 0.10,
        "pron": 0.20,
        "reps": 0.10
    }
    # normalize factor (sum of weights)
    total_weight = sum(w.values())
    risk_score = (
        score_cu * w["cu"] +
        score_lex * w["lex"] +
        score_fillers * w["fillers"] +
        score_sentlen * w["sentlen"] +
        score_pron * w["pron"] +
        score_reps * w["reps"]
    ) / total_weight
    risk_score = min(max(risk_score, 0.0), 1.0)

    # collect human-readable reasons
    if cu_prop < TH_CU_PROPORTION_LOW:
        reasons.append(f"Low content completeness (CU proportion {cu_prop:.2f} < {TH_CU_PROPORTION_LOW})")
    if lex_div < TH_LEX_DIV_LOW:
        reasons.append(f"Low lexical diversity (TTR {lex_div:.2f} < {TH_LEX_DIV_LOW})")
    if fillers_per_100 > TH_FILLERS_PER_100:
        reasons.append(f"High filled pauses ({filler_total} fillers; {fillers_per_100:.1f}/100 tokens)")
    if mean_sent_len < TH_MEAN_SENT_LEN_LOW:
        reasons.append(f"Short sentences (mean length {mean_sent_len:.1f} tokens < {TH_MEAN_SENT_LEN_LOW})")
    if pron_cohesion < TH_PRON_COHESION_LOW:
        reasons.append(f"Low pronoun cohesion (ratio {pron_cohesion:.2f} < {TH_PRON_COHESION_LOW})")
    if rep_count > TH_REPETITIONS_COUNT:
        reasons.append(f"Repeated phrases detected (count {rep_count} > {TH_REPETITIONS_COUNT})")

    # label mapping
    if risk_score >= 0.6:
        label = "High concern"
    elif risk_score >= 0.3:
        label = "Moderate concern"
    else:
        label = "Low concern"

    return {
        "risk_label": label,
        "risk_score": round(risk_score, 3),
        "reasons": reasons,
        "metrics": {
            "cu_proportion": cu_prop,
            "lexical_diversity": lex_div,
            "fillers_per_100_tokens": round(fillers_per_100, 2),
            "mean_sentence_length": mean_sent_len,
            "pronoun_cohesion": pron_cohesion,
            "repetitions_count": rep_count
        }
    }


# ----------------- CLI printing helper -----------------
def print_dementia_eval(eval_dict: Dict):
    print("\nAutomated dementia-risk heuristic assessment (not a diagnosis):")
    print(f"  Risk label : {eval_dict['risk_label']}")
    print(f"  Risk score : {eval_dict['risk_score']}  (0 = low concern, 1 = higher concern)")
    if eval_dict["reasons"]:
        print("  Reasons:")
        for r in eval_dict["reasons"]:
            print("   -", r)
    else:
        print("  Reasons: None of the heuristic thresholds were exceeded.")
    print("\n  Suggested next steps:")
    print("   - If concern is 'Moderate' or 'High', recommend formal neuropsychological assessment and clinician evaluation.")
    print("   - Consider repeat testing, full cognitive battery (e.g., MMSE/MOCA), or referral to neurology/geriatric psychiatry.")
    print("   - Use this result only as a screening flag; do not communicate a diagnosis to the patient based solely on this tool.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cookie Theft automated scoring")
    parser.add_argument("--input", "-i", required=True,
                        help="Path to transcript .txt file or folder containing .txt transcripts")
    parser.add_argument("--out", "-o", required=False,
                        help="Optional output JSON file (for batch results)")
    args = parser.parse_args()
    results = process_input_path(args.input, args.out)

    # If single file, print pretty report
    if isinstance(results, dict) and len(results) == 1:
        report = pretty_report(next(iter(results.values())))
        print(report)

    # If single file, print pretty report + heuristic dementia eval
    if isinstance(results, dict) and len(results) == 1:
        score = next(iter(results.values()))
        report = pretty_report(score)
        print(report)

        # evaluate heuristically
        eval_result = evaluate_dementia_risk(score)
        print_dementia_eval(eval_result)
