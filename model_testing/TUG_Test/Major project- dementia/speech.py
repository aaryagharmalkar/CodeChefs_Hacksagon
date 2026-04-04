import pyttsx3
import threading

engine = pyttsx3.init()
engine.setProperty('rate', 150)

lock = threading.Lock()

def speak(text):
    def run():
        with lock:
            engine.say(text)
            engine.runAndWait()

    threading.Thread(target=run, daemon=True).start()