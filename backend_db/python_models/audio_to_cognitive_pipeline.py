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


def predict_cognitive_risk(text):
    text_en = translate_to_english(text)
    clean = clean_scene_words(text_en)

    vec = tfidf.transform([clean])
    prob = float(cookie_model.predict_proba(vec)[0][1])

    cog = cognitive_text_features(clean)

    is_healthy = (
        cog["filler_rate"] < 0.02 and
        cog["hesitation_ratio"] < 0.03 and
        cog["lexical_diversity"] > 0.6 and
        cog["avg_sentence_length"] > 10
    )

    # ✅ FIX: Actually apply override
    if is_healthy:
        prob = min(prob, 0.30)

    return {
        "dementia_probability": round(prob, 3),
        "cognitive_markers": {
            "filler_rate": round(cog["filler_rate"], 3),
            "lexical_diversity": round(cog["lexical_diversity"], 3),
            "avg_sentence_length": round(cog["avg_sentence_length"], 2),
            "hesitation_ratio": round(cog["hesitation_ratio"], 3),
            "long_pause_rate": round(cog["long_pause_rate"], 3)
        },
        "is_healthy": is_healthy
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
    """Main pipeline - EXACT COLAB FLOW"""
    try:
        # Check file exists
        if not os.path.exists(audio_file):
            raise FileNotFoundError(f"Audio file not found: {audio_file}")

        # Step 1: Transcribe
        transcript_text, words = speech_to_text_assemblyai(audio_file)

        # Step 2: Extract audio pauses
        avg_pause, pause_count = extract_assemblyai_audio_pauses(words)

        # Step 3: Predict cognitive risk (EXACT logic)
        risk_result = predict_cognitive_risk(transcript_text)

        # Compile output - CONVERT ALL NUMPY TYPES TO PYTHON NATIVE
        output = {
            "status": "success",
            "transcript": transcript_text,
            "audio_metrics": {
                "avg_pause_duration_seconds": float(avg_pause),
                "pause_count": int(pause_count)
            },
            "dementia_probability": float(risk_result["dementia_probability"]),
            "cognitive_markers": {
                "filler_rate": float(risk_result["cognitive_markers"]["filler_rate"]),
                "lexical_diversity": float(risk_result["cognitive_markers"]["lexical_diversity"]),
                "avg_sentence_length": float(risk_result["cognitive_markers"]["avg_sentence_length"]),
                "hesitation_ratio": float(risk_result["cognitive_markers"]["hesitation_ratio"]),
                "long_pause_rate": float(risk_result["cognitive_markers"]["long_pause_rate"])
            },
            "is_healthy_speech": bool(risk_result["is_healthy"])  # CONVERT NUMPY BOOL TO PYTHON BOOL
        }

        return output

    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: python audio_to_cognitive_pipeline.py <audio_file>"
        }), file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]
    result = process_audio(audio_file)
    print(json.dumps(result))