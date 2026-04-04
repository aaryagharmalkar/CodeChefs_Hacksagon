import os
import json
import re
import io

from typing import List

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from dotenv import load_dotenv
from PIL import Image

import google.generativeai as genai

# ===============================
# LOAD ENV
# ===============================
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY missing from .env")

import google.generativeai as genai

os.environ["GOOGLE_CLOUD_REGION"] = "us-central1"  # add this line
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel("gemini-2.5-flash")
# ===============================
# FASTAPI APP
# ===============================
app = FastAPI(title="MediBuddy Prescription Image + PDF Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Lock down to your IP in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
# HELPERS
# ===============================

def _clean_json(text: str) -> str:
    text = re.sub(r"```json", "", text)
    text = re.sub(r"```",     "", text)
    return text.strip()


def normalize_intake_times(raw_times: list) -> list:
    """
    Ensure every entry is one of the six valid intake-time strings.
    Handles common LLM variations. Preserves order, removes duplicates.
    """
    cleaned = []
    for t in raw_times:
        t_str = str(t)
        if t_str in VALID_INTAKE_TIMES:
            cleaned.append(t_str)
            continue

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
        return int(max(5, round(dose_count / 5) * 5))
    else:
        return int(max(1, round(dose_count)))


def _extract_from_image(image: Image.Image) -> List[dict]:
    prompt = """
You are a medical prescription extraction system. Analyse this prescription image carefully.

Extract ALL medicines visible in the prescription and return ONLY valid JSON.
No markdown. No explanations. No code blocks.

The JSON MUST strictly follow this structure:

[
  {
    "name": string (medicine name, include strength e.g. "Paracetamol 500mg"),
    "type": string (one of: "tablet", "syrup", "other"),
    "intakeTimes": [string] (array using ONLY these exact strings: "Before Breakfast", "After Breakfast", "Before Lunch", "After Lunch", "Before Dinner", "After Dinner"),
    "customTimes": [string] (HH:MM 24-hour format, e.g. "08:00", "14:00" — leave [] if not applicable),
    "frequency": string (one of: "Daily", "Alternate Days"),
    "doseCount": number (whole number for tablets min 1; multiple of 5 for syrups min 5),
    "durationDays": number (positive integer)
  }
]

EXTRACTION RULES:

1. MEDICINE NAME:
   - Exact name as written, include strength/dosage in name.
   - Do NOT split combination drugs.

2. MEDICINE TYPE:
   - "tablet"  → tablets, capsules, pills
   - "syrup"   → syrups, suspensions, liquids
   - "other"   → injections, drops, ointments, inhalers, patches

3. INTAKE TIMES — use ONLY these six exact strings (case-sensitive):
   "Before Breakfast" | "After Breakfast" | "Before Lunch" |
   "After Lunch"      | "Before Dinner"   | "After Dinner"

   Conversion guide:
   - "morning" / "early morning"      → "After Breakfast"
   - "afternoon" / "noon"             → "After Lunch"
   - "evening" / "night"              → "After Dinner"
   - "empty stomach" / "before food"  → "Before Breakfast"

   Prescription notation:
   - "1-0-1" → ["After Breakfast", "After Dinner"]
   - "1-1-1" → ["After Breakfast", "After Lunch", "After Dinner"]
   - "0-0-1" → ["After Dinner"]
   - "1-0-0" → ["After Breakfast"]
   - "0-1-0" → ["After Lunch"]
   - "1-1-0" → ["After Breakfast", "After Lunch"]

4. CUSTOM TIMES:
   - Only if specific clock times are explicitly written.
   - 24-hour HH:MM format.
   - Leave [] otherwise.

5. DOSE COUNT:
   - Tablet/other: whole number (1, 2, 3…)  — 0.5 → 1, 1.5 → 2
   - Syrup: multiple of 5 ml (5, 10, 15…)  — 7ml → 5ml, 8ml → 10ml
   - "1-0-1" notation → doseCount is 1 per intake (not 2 total)

6. FREQUENCY:
   - "Daily"          → every day
   - "Alternate Days" → every other day or alternate days
   - No other values allowed.

7. DURATION:
   - Exact if stated: "5 days" → 5, "2 weeks" → 14, "1 month" → 30
   - Default: 7

IMPORTANT:
- Return [] if image is not a prescription.
- Skip any medicine whose text is unreadable.
- Do NOT hallucinate or assume.
- Do NOT include isCritical, startDay, days, or any extra fields.

Return ONLY the JSON array, nothing else.
"""
    response = model.generate_content([image, prompt])
    cleaned  = _clean_json(response.text)

    try:
        raw = json.loads(cleaned)
        if not isinstance(raw, list):
            return []
    except Exception:
        return []

    medicines = []
    for med in raw:
        med_type = med.get("type", "tablet")
        if med_type not in ("tablet", "syrup", "other"):
            med_type = "tablet"

        frequency = med.get("frequency", "Daily")
        if frequency not in ("Daily", "Alternate Days"):
            frequency = "Daily"

        intake_times = normalize_intake_times(med.get("intakeTimes", []))
        dose_count   = normalize_dose_count(
            med.get("doseCount", 1 if med_type == "tablet" else 5),
            med_type,
        )

        # customTimes: only well-formed HH:MM strings
        raw_custom   = med.get("customTimes", [])
        custom_times = [
            str(t) for t in raw_custom
            if isinstance(t, str) and len(t) == 5 and t[2] == ":"
        ]

        duration = med.get("durationDays", 7)
        try:
            duration = max(1, int(duration))
        except (TypeError, ValueError):
            duration = 7

        medicines.append({
            "name":         med.get("name", ""),
            "type":         med_type,
            "intakeTimes":  intake_times,
            "customTimes":  custom_times,
            "frequency":    frequency,
            "doseCount":    dose_count,
            "durationDays": duration,
            # NOTE: isCritical intentionally excluded — not in schema or Flutter UI
        })

    return medicines


def extract_medicines(file_bytes: bytes, filename: str) -> List[dict]:
    ext = filename.lower().rsplit(".", 1)[-1]

    # ── IMAGE ──────────────────────────────────────────────────────────────────
    if ext in ("jpg", "jpeg", "png"):
        try:
            image = Image.open(io.BytesIO(file_bytes))
            return _extract_from_image(image)
        except Exception as e:
            print(f"Error processing image: {e}")
            return []

    # ── PDF (via PyMuPDF) ──────────────────────────────────────────────────────
    if ext == "pdf":
        try:
            import fitz  # PyMuPDF

            pdf_document = fitz.open(stream=file_bytes, filetype="pdf")
            if pdf_document.page_count == 0:
                pdf_document.close()
                return []

            all_medicines = []
            for page_num in range(pdf_document.page_count):
                try:
                    page = pdf_document[page_num]
                    mat  = fitz.Matrix(2, 2)          # 200 DPI
                    pix  = page.get_pixmap(matrix=mat)
                    image = Image.open(io.BytesIO(pix.tobytes("png")))
                    all_medicines.extend(_extract_from_image(image))
                except Exception as e:
                    print(f"Error on PDF page {page_num + 1}: {e}")
                    continue

            pdf_document.close()

            # Deduplicate by lowercase name
            unique: dict = {}
            for med in all_medicines:
                key = med.get("name", "").lower()
                if key:
                    unique[key] = med

            return list(unique.values())

        except Exception as e:
            print(f"Error processing PDF: {e}")
            return []

    return []


# ===============================
# API ENDPOINTS
# ===============================

@app.post("/api/medicine/extract-file")
async def extract_prescription(file: UploadFile = File(...)):
    """
    Accept a JPG / PNG / PDF prescription file.
    Returns a list of extracted medicine objects, each compatible with
    the Flutter AddMedicationScreen and the Node.js /api/medicine/add endpoint.
    """
    try:
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")

        ext = file.filename.lower().rsplit(".", 1)[-1]
        if ext not in ("jpg", "jpeg", "png", "pdf"):
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {ext}. Only JPG, PNG, and PDF are supported.",
            )

        MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
        file_bytes = await file.read()

        if len(file_bytes) > MAX_FILE_SIZE:
            raise HTTPException(status_code=400, detail="File too large. Maximum size is 10 MB.")
        if len(file_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded.")

        medicines = extract_medicines(file_bytes, file.filename)

        if not medicines:
            return JSONResponse(
                content={
                    "success":  False,
                    "message":  "No valid medicines detected. Please ensure the image/PDF is a clear prescription.",
                    "medicines": [],
                },
                status_code=200,
            )

        return JSONResponse(
            content={
                "success":  True,
                "message":  f"Successfully extracted {len(medicines)} medicine(s)",
                "medicines": medicines,
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error processing file: {e}")


# ===============================
# ENTRY POINT
# ===============================
if __name__ == "__main__":
    print("=" * 50)
    print("📸  MediBuddy Prescription Server")
    print("🖼️   Image (JPG/PNG) + 📄 PDF Supported")
    print("📍  http://0.0.0.0:5002")
    print("🎯  POST /api/medicine/extract-file")
    print("=" * 50)
    uvicorn.run(app, host="0.0.0.0", port=5002, log_level="info")