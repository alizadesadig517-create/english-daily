#!/usr/bin/env python3
"""Build the interactive (Duolingo-style) site for one day.

Usage:
  python3 play/build.py <DATE>                    today's site
  python3 play/build.py <DATE> --audio-days 30    also record audio for the 30 newest lessons

Writes play/build/site/ (not committed):
  index.html             the page, with today's lesson and the archive list embedded
  data/<date>.json       every lesson up to <DATE> (words, story, grammar, extras, review pool)
  audio/<date>.json      recorded clips for <DATE> (and --audio-days lessons), {key: data URI}

The daily routine publishes index.html plus the new data/ and audio/ files to
the artifact in play/ARTIFACT_URL.
"""
import argparse
import json
import os
import random
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")
PLAY = os.path.join(ROOT, "play")
SITE = os.path.join(PLAY, "build", "site")
AUDIO_KEEP = 30  # lessons whose audio stays published

AZ_MONTHS = ["yanvar", "fevral", "mart", "aprel", "may", "iyun", "iyul", "avqust",
             "sentyabr", "oktyabr", "noyabr", "dekabr"]
AZ_DAYS = ["Bazar ertəsi", "Çərşənbə axşamı", "Çərşənbə", "Cümə axşamı", "Cümə", "Şənbə", "Bazar"]


def load(path, default=None):
    if not os.path.exists(path):
        if default is not None:
            return default
        sys.exit(f"missing {path}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def date_label(d):
    d = date.fromisoformat(d)
    return f"{AZ_DAYS[d.weekday()]}, {d.day} {AZ_MONTHS[d.month - 1]}"


def review_pool(dates, today, days=7, limit=40):
    """Words from the `days` lessons before `today` (newest first), with their first sense."""
    past = [d for d in dates if d < today][:days]
    pool = []
    for d in past:
        for w in load(os.path.join(CONTENT, f"{d}.json"))["words"]:
            s = w["senses"][0]
            pool.append({"word": w["word"], "ipa": w["ipa"], "translation": s["translation"],
                         "definition": s["definition"], "example": s["examples"][0] if s["examples"] else None,
                         "date": d})
    random.Random(today).shuffle(pool)
    return pool[:limit]


def day_data(d, dates, series):
    lesson = load(os.path.join(CONTENT, f"{d}.json"))
    if lesson.get("story") is None:
        return None
    return {
        "date": d,
        "dateLabel": date_label(d),
        "level": lesson["level"],
        "lang": lesson["translationLanguage"],
        "lesson": {"words": lesson["words"], "story": lesson["story"], "grammar": lesson["grammar"]},
        "extras": load(os.path.join(PLAY, "days", f"{d}.json"), default={}),
        "review": review_pool(dates, d),
    }


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("date")
    ap.add_argument("--audio-days", type=int, default=1, help="record audio for this many newest lessons")
    args = ap.parse_args()
    today = args.date

    dates = [d for d in load(os.path.join(CONTENT, "index.json"))["dates"] if d <= today]  # newest first
    if not dates or dates[0] != today:
        sys.exit(f"content/{today}.json is not the newest lesson in content/index.json")
    series = load(os.path.join(PLAY, "series.json"), default={"title": "English Daily"})
    characters = [{"name": c["name"], "look": c.get("look", {}), "voice": c.get("voice", "female")}
                  for c in series.get("characters", [])]

    sys.path.insert(0, PLAY)
    from audio import build_audio

    manifest, days = [], {}
    for d in dates:
        dd = day_data(d, dates, series)
        if dd is None:
            continue
        days[d] = dd
        ep = dd["extras"].get("episode")
        manifest.append({
            "date": d, "label": dd["dateLabel"], "title": dd["lesson"]["story"]["title"],
            "titleAz": dd["lesson"]["story"].get("titleTranslation", ""),
            "episode": ep["number"] if ep else None, "grammar": dd["lesson"]["grammar"]["topic"],
            "words": [w["word"] for w in dd["lesson"]["words"]][:6], "count": len(dd["lesson"]["words"]),
            "audio": False,
        })
        write_json(os.path.join(SITE, "data", f"{d}.json"), dd)

    audio_dates = [m["date"] for m in manifest][:max(1, args.audio_days)]
    for d in audio_dates:
        path = os.path.join(SITE, "audio", f"{d}.json")
        clips = build_audio(dict(days[d], characters=characters))
        if clips:
            write_json(path, clips)
    for m in manifest[:AUDIO_KEEP]:
        m["audio"] = os.path.exists(os.path.join(SITE, "audio", f"{m['date']}.json"))

    page_data = {
        "today": days[today],
        "manifest": manifest,
        "series": {"title": series.get("title", "English Daily"), "titleAz": series.get("titleAz", "")},
        "characters": characters,
    }
    with open(os.path.join(PLAY, "template.html"), encoding="utf-8") as f:
        html = f.read()
    payload = json.dumps(page_data, ensure_ascii=False).replace("</", "<\\/")
    html = html.replace("/*__DATA__*/null", payload, 1)
    with open(os.path.join(SITE, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)

    stale = [m["date"] for m in manifest[AUDIO_KEEP:]]
    print(f"wrote play/build/site: index.html ({len(html) // 1024} KB), {len(manifest)} lessons in data/, "
          f"audio for {sum(m['audio'] for m in manifest)} lessons")
    print("audio to remove from the artifact (older than the newest %d): %s" % (AUDIO_KEEP, ", ".join(stale) or "none"))


if __name__ == "__main__":
    main()
