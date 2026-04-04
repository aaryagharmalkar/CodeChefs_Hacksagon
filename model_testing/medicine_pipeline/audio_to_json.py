import os
import sys
import time
import json
import subprocess
import shutil
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from dotenv import load_dotenv
from groq import Groq
import requests

# ===============================
# LOAD ENV
# ===============================
load_dotenv()

ASSEMBLYAI_API_KEY = os.getenv("ASSEMBLYAI_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not ASSEMBLYAI_API_KEY:
    raise RuntimeError("ASSEMBLYAI_API_KEY missing from .env")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY missing from .env")

try:
    groq_client = Groq(api_key=GROQ_API_KEY)
except Exception as e:
    print("ERROR: Groq initialisation failed.", file=sys.stderr)
    raise e

UPLOAD_HEADERS = {"authorization": ASSEMBLYAI_API_KEY}
TRANSCRIPT_HEADERS = {
    "authorization": ASSEMBLYAI_API_KEY,
    "content-type": "application/json",
}

# ===============================
# FASTAPI APP
# ===============================
app = FastAPI(title="MediBuddy Voice Processing Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Lock down to your IP in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
os.makedirs("input",   exist_ok=True)
os.makedirs("output",  exist_ok=True)

# ===============================
# VALID INTAKE TIMES  (single source of truth)
# ===============================
VALID_INTAKE_TIMES = [
    "Before Breakfast",
    "After Breakfast",
    "Before Lunch",
    "After Lunch",
    "Before Dinner",
    "After Dinner",
]

# ===============================
# HELPER FUNCTIONS
# ===============================

def convert_to_wav(input_file: str) -> str:
    """Convert any audio file to 16 kHz mono WAV via ffmpeg."""
    base    = os.path.splitext(os.path.basename(input_file))[0]
    wav_path = os.path.join("input", f"{base}.wav")

    cmd = [
        "ffmpeg", "-y",
        "-i", input_file,
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "pcm_s16le",
        "-vn",
        "-hide_banner",
        "-loglevel", "error",
        wav_path,
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {result.stderr.decode()}")
    return wav_path


def upload_audio(path: str) -> str:
    with open(path, "rb") as f:
        r = requests.post(
            "https://api.assemblyai.com/v2/upload",
            headers=UPLOAD_HEADERS,
            data=f,
        )
    print(f"Upload response: {r.status_code} — {r.json()}")  # ADD THIS
    r.raise_for_status()
    return r.json()["upload_url"]


def start_transcription(audio_url: str) -> str:
    payload = {
        "audio_url": audio_url,
        "speech_models": ["universal-2"]
    }
    r = requests.post(
        "https://api.assemblyai.com/v2/transcript",
        headers={"authorization": ASSEMBLYAI_API_KEY},
        json=payload,
    )
    print(f"Transcription status: {r.status_code}", flush=True)
    print(f"Transcription body: {r.text}", flush=True)
    sys.stdout.flush()
    if not r.ok:
        raise RuntimeError(f"AssemblyAI error {r.status_code}: {r.text}")
    return r.json()["id"]


def wait_for_result(tid: str) -> dict:
    """Poll until transcription is complete or errored."""
    while True:
        r = requests.get(
            f"https://api.assemblyai.com/v2/transcript/{tid}",
            headers=TRANSCRIPT_HEADERS,
        )
        r.raise_for_status()
        res = r.json()

        if res["status"] == "completed":
            return res
        if res["status"] == "error":
            raise RuntimeError(res["error"])
        time.sleep(3)


def normalize_intake_times(raw_times: list) -> list:
    """
    Ensure every entry is one of the six valid intake-time strings.
    Handles common LLM variations and converts them to canonical form.
    Preserves insertion order and removes duplicates.
    """
    cleaned = []
    for t in raw_times:
        t_str = str(t)

        # Already valid — keep as-is
        if t_str in VALID_INTAKE_TIMES:
            cleaned.append(t_str)
            continue

        # Fuzzy fix for common LLM variations
        t_lower = t_str.lower()
        if "before breakfast" in t_lower or "before bf" in t_lower:
            cleaned.append("Before Breakfast")
        elif "after breakfast" in t_lower or "after bf" in t_lower or "morning" in t_lower:
            cleaned.append("After Breakfast")
        elif "before lunch" in t_lower:
            cleaned.append("Before Lunch")
        elif "after lunch" in t_lower or "afternoon" in t_lower or "noon" in t_lower:
            cleaned.append("After Lunch")
        elif "before dinner" in t_lower:
            cleaned.append("Before Dinner")
        elif "after dinner" in t_lower or "evening" in t_lower or "night" in t_lower:
            cleaned.append("After Dinner")
        # Unknown strings are silently dropped

    # Remove duplicates, preserve order
    return list(dict.fromkeys(cleaned))


def normalize_dose_count(dose_count, med_type: str) -> int:
    """
    Enforce rounding rules that match the Flutter UI constraints:
      tablet / other  → nearest whole number  (min 1)
      syrup           → nearest multiple of 5  (min 5)
    """
    try:
        dose_count = float(dose_count)
    except (TypeError, ValueError):
        dose_count = 1.0

    if med_type == "syrup":
        rounded = max(5, round(dose_count / 5) * 5)
    else:
        rounded = max(1, round(dose_count))

    return int(rounded)


def parse_medication_info(transcript_json: dict) -> dict:
    """
    Send the transcript text to Groq/LLaMA, extract structured medication
    data, then sanitise and normalise every field before returning.
    """
    text = transcript_json.get("text", "").strip()
    if not text:
        return _default_medication()

    prompt = f"""
You are a medication information extraction system.

Extract medication details from the user's voice input and return ONLY valid JSON.
No markdown. No explanations. No code blocks.

The JSON MUST strictly follow this structure:

{{
  "name": string (medicine name),
  "type": string (one of: "tablet", "syrup", "other"),
  "intakeTimes": [string] (array of: "Before Breakfast", "After Breakfast", "Before Lunch", "After Lunch", "Before Dinner", "After Dinner"),
  "customTimes": [string] (array of time strings in HH:MM 24-hour format, e.g. "08:30", "14:00"),
  "frequency": string (one of: "Daily", "Alternate Days"),
  "days": [string] (array of days if specific days mentioned: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
  "doseCount": number (tablets count or ml for syrup — whole number for tablet, multiple of 5 for syrup),
  "durationDays": number (duration in days, positive integer)
}}

Rules:
- Extract medicine name carefully.
- type must be exactly one of: "tablet", "syrup", "other".
- intakeTimes must use ONLY the six exact strings listed above.
- customTimes must be HH:MM in 24-hour format.
- frequency must be exactly "Daily" or "Alternate Days" — nothing else.
- doseCount: whole number for tablets (min 1), multiple of 5 for syrups (min 5).
- durationDays: positive integer.
- Do NOT include isCritical, startDay, or any fields not listed above.
- Do NOT hallucinate — only extract what is clearly stated.
- If information is missing, use these defaults:
    type → "tablet", frequency → "Daily", doseCount → 1, durationDays → 7

User's voice input:
{text}
"""

    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.1,
    )

    content = response.choices[0].message.content.strip()

    # Strip markdown fences if the LLM added them anyway
    if content.startswith("```"):
        parts = content.split("```")
        content = parts[1] if len(parts) > 1 else content
        if content.startswith("json"):
            content = content[4:]
    content = content.strip()

    try:
        data = json.loads(content)
    except Exception as e:
        print(f"⚠️  JSON parse error: {e}", file=sys.stderr)
        data = {}

    # ── Sanitise every field ──────────────────────────────────────────────────

    med_type = data.get("type", "tablet")
    if med_type not in ("tablet", "syrup", "other"):
        med_type = "tablet"

    frequency = data.get("frequency", "Daily")
    if frequency not in ("Daily", "Alternate Days"):
        frequency = "Daily"

    intake_times = normalize_intake_times(data.get("intakeTimes", []))

    # customTimes: keep only strings that look like HH:MM
    raw_custom = data.get("customTimes", [])
    custom_times = [
        str(t) for t in raw_custom
        if isinstance(t, str) and len(t) == 5 and t[2] == ":"
    ]

    dose_count = normalize_dose_count(
        data.get("doseCount", 1 if med_type == "tablet" else 5),
        med_type,
    )

    duration = data.get("durationDays", 7)
    try:
        duration = max(1, int(duration))
    except (TypeError, ValueError):
        duration = 7

    days = data.get("days", [])
    valid_days = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
    days = [d for d in days if d in valid_days]

    return {
        "name":         data.get("name", ""),
        "type":         med_type,
        "intakeTimes":  intake_times,
        "customTimes":  custom_times,
        "frequency":    frequency,
        "days":         days,
        "doseCount":    dose_count,
        "durationDays": duration,
    }


def _default_medication() -> dict:
    """Return a safe default when transcript is empty."""
    return {
        "name":         "",
        "type":         "tablet",
        "intakeTimes":  [],
        "customTimes":  [],
        "frequency":    "Daily",
        "days":         [],
        "doseCount":    1,
        "durationDays": 7,
    }


# ===============================
# API ENDPOINTS
# ===============================

@app.get("/")
async def root():
    return {
        "service":   "MediBuddy Voice Processing Server",
        "status":    "running",
        "endpoints": {
            "health":        "/health",
            "process_voice": "POST /api/medicine/process-voice",
        },
    }


@app.get("/health")
async def health_check():
    return {
        "status":    "running",
        "timestamp": time.time(),
        "service":   "medication-voice-processor",
    }


@app.post("/api/medicine/process-voice")
async def process_voice(audio: UploadFile = File(...)):
    """
    Accept any audio file, transcribe it via AssemblyAI, extract structured
    medication data via Groq/LLaMA, and return clean JSON.
    """
    temp_audio_path = None
    wav_path        = None

    try:
        temp_audio_path = f"uploads/{audio.filename}"
        with open(temp_audio_path, "wb") as buf:
            shutil.copyfileobj(audio.file, buf)
        print(f"📥 Received: {audio.filename}")

        print("🔄 Converting to WAV...")
        wav_path = convert_to_wav(temp_audio_path)

        print("☁️  Uploading to AssemblyAI...")
        audio_url = upload_audio(wav_path)

        print("🎤 Starting transcription...")
        transcript_id = start_transcription(audio_url)

        print("⏳ Waiting for transcription...")
        transcript = wait_for_result(transcript_id)

        print("🧠 Extracting medication details...")
        medication_data = parse_medication_info(transcript)

        print(f"✅ Done — extracted: {medication_data.get('name', '(empty)')}")
        return JSONResponse(content=medication_data)

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        if temp_audio_path and os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)
        if wav_path and os.path.exists(wav_path):
            os.remove(wav_path)


# ===============================
# ENTRY POINT
# ===============================
if __name__ == "__main__":
    print("=" * 50)
    print("🎤  MediBuddy Voice Processing Server")
    print("📍  http://0.0.0.0:5001")
    print("🎯  POST /api/medicine/process-voice")
    print("=" * 50)
    uvicorn.run(app, host="0.0.0.0", port=5001, log_level="info")