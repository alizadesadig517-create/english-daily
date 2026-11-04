"""Pre-recorded audio for the interactive page (Piper text-to-speech).

The page cannot rely on the phone's speech engine (the Claude app's viewer has
none), so every text the page can say is synthesized here and embedded in the
page as MP3 data URIs, keyed by `audio_key(text)` (the page computes the same
key). Clips are cached in play/build/audio-cache by voice and text.

Needs: `pip install piper-tts`, ffmpeg, and the voice models in
play/build/voices (downloaded by `ensure_voices()`).
"""
import base64
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
import wave

PLAY = os.path.dirname(os.path.abspath(__file__))
VOICE_DIR = os.path.join(PLAY, "build", "voices")
CACHE_DIR = os.path.join(PLAY, "build", "audio-cache")
VOICES = {
    "female": ("en_US-lessac-medium", "en/en_US/lessac/medium"),
    "male": ("en_US-ryan-medium", "en/en_US/ryan/medium"),
}
BASE_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main"


def audio_key(text):
    """Must match audioKey() in play/template.html."""
    t = text.lower().replace("’", "'")
    t = re.sub(r"[“”\"]", "", t)
    t = re.sub(r"[^\w' ]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def ensure_voices():
    os.makedirs(VOICE_DIR, exist_ok=True)
    for name, path in VOICES.values():
        for ext in (".onnx", ".onnx.json"):
            dest = os.path.join(VOICE_DIR, name + ext)
            if not os.path.exists(dest) or os.path.getsize(dest) == 0:
                print(f"downloading {name}{ext} ...")
                urllib.request.urlretrieve(f"{BASE_URL}/{path}/{name}{ext}", dest)


def available():
    try:
        import piper  # noqa: F401
    except ImportError:
        return "piper-tts is not installed (pip install piper-tts)"
    if not shutil.which("ffmpeg"):
        return "ffmpeg is not installed"
    return None


class Synth:
    def __init__(self):
        from piper import PiperVoice
        ensure_voices()
        self.voices = {g: PiperVoice.load(os.path.join(VOICE_DIR, name + ".onnx")) for g, (name, _) in VOICES.items()}
        os.makedirs(CACHE_DIR, exist_ok=True)
        self.made = self.cached = 0

    def mp3(self, text, gender="female"):
        clean = re.sub(r"[“”\"]", "", text).strip()
        h = hashlib.sha1(f"{gender}|{clean}".encode()).hexdigest()[:20]
        path = os.path.join(CACHE_DIR, h + ".mp3")
        if os.path.exists(path):
            self.cached += 1
        else:
            with tempfile.TemporaryDirectory() as tmp:
                wav_path = os.path.join(tmp, "a.wav")
                with wave.open(wav_path, "wb") as w:
                    self.voices[gender].synthesize_wav(clean, w)
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-ac", "1", "-ar", "22050",
                                "-b:a", "32k", path], check=True)
            self.made += 1
        with open(path, "rb") as f:
            return "data:audio/mpeg;base64," + base64.b64encode(f.read()).decode()


def texts_for(data):
    """(text, gender) for everything the page can speak."""
    out = []
    lesson = data["lesson"]
    for w in lesson["words"]:
        out.append(w["word"])
        for s in w["senses"]:
            out += [e["text"] for e in s["examples"]]
    out += [g["term"] for g in lesson["story"]["glossary"]]
    out += [e["text"] for e in lesson["grammar"]["examples"]]
    for r in data["review"]:
        out.append(r["word"])
        if r.get("example"):
            out.append(r["example"]["text"])
    pairs = [(t, "female") for t in out]
    gender = {c["name"]: c.get("voice", "female") for c in data.get("characters", [])}
    speakers = data["extras"].get("speakers", {})
    for pi, p in enumerate(lesson["story"]["paragraphs"]):
        for si, s in enumerate(p["sentences"]):
            who = speakers.get(f"{pi}-{si}")
            pairs.append((s["text"], gender.get(who, "female") if who else "female"))
    return pairs


def build_audio(data):
    """Return {audio_key: data_uri}. Story lines win over other uses of the same text."""
    problem = available()
    if problem:
        print(f"WARNING: no audio ({problem}); the page falls back to the phone's speech engine")
        return {}
    synth = Synth()
    audio = {}
    for text, gender in texts_for(data):
        k = audio_key(text)
        if k and (k not in audio or gender == "male"):
            audio[k] = synth.mp3(text, gender)
    size = sum(len(v) for v in audio.values())
    print(f"audio: {len(audio)} clips ({synth.made} new, {synth.cached} cached), {size // 1024} KB embedded")
    return audio
