#!/usr/bin/env python3
"""
Audio to Cognitive Pipeline (EXACT LOGIC)
Uses the exact risk calculation from Colab notebook
"""

import sys
import json
import os
import re
import pickle
from pathlib import Path
import numpy as np
from deep_translator import GoogleTranslator
import assemblyai as aai
from dotenv import load_dotenv

load_dotenv()

# Setup paths
SCRIPT_DIR = Path(__file__).parent
MODEL_DIR = SCRIPT_DIR.parent.parent / "model_testing" / "cookie_theft"

# Load models
try:
    with open(MODEL_DIR / "dementia_model_cookie.pkl", "rb") as f:
        cookie_model = pickle.load(f)
    with open(MODEL_DIR / "tfidf_vectorizer (1).pkl", "rb") as f:
        tfidf = pickle.load(f)
except Exception as e:
    print(json.dumps({"error": f"Failed to load models: {str(e)}"}), file=sys.stderr)
    sys.exit(1)

# Setup AssemblyAI
try:
    assemblyai_key = os.getenv('ASSEMBLYAI_API_KEY')
    if not assemblyai_key:
        print(json.dumps({"error": "ASSEMBLYAI_API_KEY environment variable not set"}), file=sys.stderr)
        sys.exit(1)
    aai.settings.api_key = assemblyai_key
except Exception as e:
    print(json.dumps({"error": f"Failed to setup AssemblyAI: {str(e)}"}), file=sys.stderr)
    sys.exit(1)




# --- Add after imports, before any functions ---
FEATURE_NORMS = {
    "filler_rate":         (0.015, 0.012, +1),
    "hesitation_ratio":    (0.025, 0.018, +1),
    "long_pause_rate":     (0.010, 0.010, +1),
    "lexical_diversity":   (0.72,  0.12,  -1),
    "avg_sentence_length": (12.0,  4.0,   -1),
}

def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))

def cognitive_to_probability(cog: dict, audio_avg_pause: float = 0.0, audio_pause_count: int = 0) -> float:
    z_scores = []
    weights = [1.2, 1.2, 1.0, 1.5, 1.0]  # filler, hesitation, long_pause, lex_div, sent_len

    for (feat, (mu, sigma, direction)), w in zip(FEATURE_NORMS.items(), weights):
        val = cog.get(feat, mu)
        z = direction * (val - mu) / max(sigma, 1e-6)
        z_scores.append(z * w)

    if audio_pause_count > 0:
        pause_z = (audio_avg_pause - 0.8) / 0.4
        z_scores.append(pause_z * 1.3)

    return float(_sigmoid(np.mean(z_scores)))

# ==================== EXACT LOGIC FROM COLAB ====================

def translate_to_english(text):
    """Translate text to English"""
    try:
        return GoogleTranslator(source="auto", target="en").translate(text)
    except:
        return text


def clean_scene_words(text):
    """Clean and normalize text - EXACT from Colab"""
    text = text.lower()
    text = re.sub(r"[^a-z\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def pause_features(text):
    """Extract pause features from text - EXACT from Colab"""
    text = text.lower()
    long_pauses = len(re.findall(r"\.\.\.|--", text))
    fillers = len(re.findall(r"\b(uh|um|erm|ah|अं|उह)\b", text))
    repeats = len(re.findall(r"\b(\w+)\s+\1\b", text))

    words = text.split()
    total = max(len(words), 1)

    return long_pauses/total, fillers/total, repeats/total


def cognitive_text_features(text):
    """Extract cognitive features - EXACT from Colab"""
    words = text.split()
    unique = set(words)
    lexical_div = len(unique) / max(len(words), 1)

    sentences = re.split(r"[.!?]", text)
    sent_lens = [len(s.split()) for s in sentences if s.strip()]
    avg_len = np.mean(sent_lens) if sent_lens else 0

    long_pause_rate, filler_rate, repeat_rate = pause_features(text)

    hesitation_ratio = filler_rate + repeat_rate

    return {
        "filler_rate": filler_rate,
        "lexical_diversity": lexical_div,
        "avg_sentence_length": avg_len,
        "hesitation_ratio": hesitation_ratio,
        "long_pause_rate": long_pause_rate
    }


# REPLACE the existing predict_cognitive_risk entirely
def predict_cognitive_risk(text, audio_avg_pause: float = 0.0, audio_pause_count: int = 0):
    text_en = translate_to_english(text)
    clean = clean_scene_words(text_en)

    vec = tfidf.transform([clean])
    p_model = float(cookie_model.predict_proba(vec)[0][1])

    cog = cognitive_text_features(clean)
    p_cog = cognitive_to_probability(cog, audio_avg_pause, audio_pause_count)

    # Weighted fusion — cognitive features weighted slightly higher
    # because cookie model is domain-mismatched to conversational speech
    p_final = 0.45 * p_model + 0.55 * p_cog

    signal_gap = abs(p_model - p_cog)
    confidence = "high" if signal_gap < 0.25 else ("medium" if signal_gap < 0.45 else "low")

    is_healthy = (
        cog["filler_rate"] < 0.02 and
        cog["hesitation_ratio"] < 0.03 and
        cog["lexical_diversity"] > 0.6 and
        cog["avg_sentence_length"] > 10
    )

    return {
        "dementia_probability": round(p_final, 3),
        "component_scores": {
            "lexical_model": round(p_model, 3),
            "cognitive_features": round(p_cog, 3),
        },
        "cognitive_markers": {
            "filler_rate": round(cog["filler_rate"], 3),
            "lexical_diversity": round(cog["lexical_diversity"], 3),
            "avg_sentence_length": round(cog["avg_sentence_length"], 2),
            "hesitation_ratio": round(cog["hesitation_ratio"], 3),
            "long_pause_rate": round(cog["long_pause_rate"], 3),
        },
        "confidence": confidence,
        "is_healthy": is_healthy,
    }


def speech_to_text_assemblyai(audio_path):
    """Transcribe using AssemblyAI - EXACT config from Colab"""
    if not aai.settings.api_key:
        raise Exception("AssemblyAI API key is not set")

    transcriber = aai.Transcriber()

    # EXACT config from Colab
    config = aai.TranscriptionConfig(
        language_detection=True, # English (matches Colab)
        speech_models=["universal-3-pro", "universal-2"],
        punctuate=True,
        format_text=True
    )

    transcript = transcriber.transcribe(audio_path, config=config)

    if transcript.error:
        raise Exception(f"AssemblyAI error: {transcript.error}")

    return transcript.text, transcript.words


def extract_assemblyai_audio_pauses(words):
    """Extract pauses - EXACT from Colab"""
    if not words or len(words) < 2:
        return 0.0, 0

    pauses = []
    for i in range(1, len(words)):
        current_word = words[i]
        previous_word = words[i - 1]

        # Timestamps in milliseconds, convert to seconds
        gap = (current_word.start - previous_word.end) / 1000.0

        if gap > 0.7:  # Exact threshold from Colab
            pauses.append(gap)

    avg_pause = sum(pauses) / len(pauses) if pauses else 0.0
    return round(avg_pause, 2), len(pauses)


def process_audio(audio_file):
    try:
        if not os.path.exists(audio_file):
            raise FileNotFoundError(f"Audio file not found: {audio_file}")

        transcript_text, words = speech_to_text_assemblyai(audio_file)
        avg_pause, pause_count = extract_assemblyai_audio_pauses(words)

        # ✅ CHANGE 1: pass audio pause info through
        risk_result = predict_cognitive_risk(transcript_text, avg_pause, pause_count)

        output = {
            "status": "success",
            "transcript": transcript_text,
            "audio_metrics": {
                "avg_pause_duration_seconds": float(avg_pause),
                "pause_count": int(pause_count)
            },
            "dementia_probability": float(risk_result["dementia_probability"]),
            # ✅ CHANGE 2: expose both component scores + confidence
            "component_scores": {
                "lexical_model": float(risk_result["component_scores"]["lexical_model"]),
                "cognitive_features": float(risk_result["component_scores"]["cognitive_features"]),
            },
            "confidence": risk_result["confidence"],
            "cognitive_markers": {
                "filler_rate": float(risk_result["cognitive_markers"]["filler_rate"]),
                "lexical_diversity": float(risk_result["cognitive_markers"]["lexical_diversity"]),
                "avg_sentence_length": float(risk_result["cognitive_markers"]["avg_sentence_length"]),
                "hesitation_ratio": float(risk_result["cognitive_markers"]["hesitation_ratio"]),
                "long_pause_rate": float(risk_result["cognitive_markers"]["long_pause_rate"])
            },
            "is_healthy_speech": bool(risk_result["is_healthy"])
        }

        return output

    except Exception as e:
        return {"status": "error", "error": str(e)}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: python audio_to_cognitive_pipeline.py <audio_file>"
        }), file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]
    result = process_audio(audio_file)
    print(json.dumps(result))