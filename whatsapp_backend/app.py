import os

from flask import Flask, request
import requests
from twilio.twiml.messaging_response import MessagingResponse
from twilio.rest import Client
import time
import threading

app = Flask(__name__)

UPLOAD_URL = os.getenv("UPLOAD_URL")
SUMMARY_URL = os.getenv("SUMMARY_URL")

ACCOUNT_SID = os.getenv("ACCOUNT_SID")
AUTH_TOKEN = os.getenv("AUTH_TOKEN")

twilio_client = Client(ACCOUNT_SID, AUTH_TOKEN)


def fetch_summary_with_polling(audio_name, max_retries=20, initial_delay=3):
    for attempt in range(1, max_retries + 1):
        print(f"  🔄 Attempt {attempt}/{max_retries} for audio: {audio_name}")
        try:
            summary_res = requests.get(f"{SUMMARY_URL}/{audio_name}", timeout=15)
            print(f"  Status: {summary_res.status_code} | Body: {summary_res.text}")

            if summary_res.status_code == 200:
                return summary_res.json()
            elif summary_res.status_code in (202, 404):
                print("  ⏳ Not ready yet, retrying...")
            else:
                raise Exception(f"Unexpected status {summary_res.status_code}: {summary_res.text}")

        except requests.RequestException as e:
            print(f"  ⚠️ Request error on attempt {attempt}: {e}")
            if attempt == max_retries:
                raise

        wait = min(initial_delay * (1 + attempt * 0.3), 8)
        print(f"  ⏱️ Waiting {wait:.1f}s before next attempt...")
        time.sleep(wait)

    raise Exception(f"Summary not ready after {max_retries} attempts.")


def process_and_reply(media_url, from_number):
    """Runs in background thread — does the heavy work and sends reply via Twilio API."""
    try:
        # 1. Download audio
        print("⬇️ Downloading audio...")
        audio_response = requests.get(media_url, auth=(ACCOUNT_SID, AUTH_TOKEN))
        print("Download status:", audio_response.status_code)

        # 2. Upload to backend
        print("🚀 Uploading to backend...")
        upload_res = requests.post(UPLOAD_URL, files={
            "file": ("audio.ogg", audio_response.content)
        })
        print("Upload response:", upload_res.text)

        upload_data = upload_res.json()
        audio_name = upload_data.get("audio_name")

        if not audio_name:
            raise Exception("No audio_name returned from upload")

        # 3. Poll for summary
        print(f"📡 Polling for summary (audio_name={audio_name})...")
        data = fetch_summary_with_polling(audio_name)
        print(f"✅ Got summary data: {data}")

        # 4. Format message
        symptoms     = ", ".join(data.get("symptoms", [])) or "None reported"
        history      = ", ".join(data.get("patient_history", [])) or "None"
        risk_factors = ", ".join(data.get("risk_factors", [])) or "None"
        prescription = "\n• ".join(data.get("prescription", [])) or "None"
        advice       = "\n• ".join(data.get("advice", [])) or "None"
        action       = data.get("recommended_action", "") or "Follow prescribed medication."
        doctor_sum   = data.get("doctor_summary", "N/A")

        message_text = f"""🧠 *Neuro Screening Report*

📋 *Summary:* {doctor_sum}

🤒 *Symptoms:* {symptoms}
📜 *History:* {history}
⚠️ *Risk Factors:* {risk_factors}

💊 *Prescription:*
- {prescription}

💡 *Advice:*
- {advice}

✅ *Recommended Action:*
{action}

_This is an AI-based screening, not a medical diagnosis._"""

    except Exception as e:
        print("❌ ERROR in background thread:", str(e))
        message_text = "⚠️ Error processing your audio. Please try again."

    # 5. Send reply via Twilio REST API (not TwiML)
    print("📤 Sending reply via Twilio API...")
    twilio_client.messages.create(
        from_="whatsapp:+14155238886",
        to=from_number,
        body=message_text
    )
    print("✅ Reply sent!")


@app.route("/whatsapp", methods=["POST"])
def whatsapp():
    print("\n🔥 ===== NEW REQUEST RECEIVED =====")

    media_url = request.form.get("MediaUrl0")
    from_number = request.form.get("From")  # e.g. whatsapp:+918169366578

    print("Media URL:", media_url)
    print("From:", from_number)

    if not media_url:
        print("❌ No media found")
        resp = MessagingResponse()
        resp.message("❌ No audio received. Please send a voice message.")
        return str(resp)

    # 🔑 KEY FIX: Spin off background thread, respond to Twilio immediately
    thread = threading.Thread(target=process_and_reply, args=(media_url, from_number))
    thread.daemon = True
    thread.start()

    # Acknowledge Twilio instantly (within 15s limit)
    resp = MessagingResponse()
    resp.message("⏳ Processing your audio... You'll receive your report in a moment!")
    return str(resp)


if __name__ == "__main__":
    app.run(port=5000)