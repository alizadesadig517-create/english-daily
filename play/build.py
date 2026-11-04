#!/usr/bin/env python3
"""Build the interactive (Duolingo-style) page for one day.

Usage: python3 play/build.py <DATE>          -> writes play/build/today.html

Inputs: content/<DATE>.json (the lesson), play/days/<DATE>.json (episode,
comprehension questions, mission, feedback), play/series.json (serial state)
and the previous lessons (review pool). The output is published as an
Artifact by the daily routine; it is not committed.
"""
import json
import os
import random
import sys
from datetime import date, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")
PLAY = os.path.join(ROOT, "play")

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


def review_pool(today, days=7, limit=40):
    """Words from the previous `days` lessons (newest first), with their first sense."""
    index = load(os.path.join(CONTENT, "index.json"))["dates"]
    past = [d for d in index if d < today][:days]
    pool = []
    for d in past:
        lesson = load(os.path.join(CONTENT, f"{d}.json"))
        for w in lesson["words"]:
            s = w["senses"][0]
            pool.append({
                "word": w["word"], "ipa": w["ipa"], "translation": s["translation"],
                "definition": s["definition"], "example": s["examples"][0] if s["examples"] else None,
                "date": d,
            })
    rnd = random.Random(today)
    rnd.shuffle(pool)
    return pool[:limit]


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    today = argv[1]
    lesson = load(os.path.join(CONTENT, f"{today}.json"))
    extras = load(os.path.join(PLAY, "days", f"{today}.json"), default={})
    series = load(os.path.join(PLAY, "series.json"), default={"title": "English Daily"})
    d = date.fromisoformat(today)
    data = {
        "date": today,
        "dateLabel": f"{AZ_DAYS[d.weekday()]}, {d.day} {AZ_MONTHS[d.month - 1]}",
        "level": lesson["level"],
        "lang": lesson["translationLanguage"],
        "lesson": {"words": lesson["words"], "story": lesson.get("story"), "grammar": lesson["grammar"]},
        "extras": extras,
        "series": {"title": series.get("title", "English Daily")},
        "review": review_pool(today),
    }
    if data["lesson"]["story"] is None:
        sys.exit("the interactive page needs a story (storyEnabled)")
    with open(os.path.join(PLAY, "template.html"), encoding="utf-8") as f:
        html = f.read()
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = html.replace("/*__DATA__*/null", payload, 1)
    os.makedirs(os.path.join(PLAY, "build"), exist_ok=True)
    out = os.path.join(PLAY, "build", "today.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"wrote {os.path.relpath(out, ROOT)} ({len(html) // 1024} KB, {len(data['review'])} review words)")


if __name__ == "__main__":
    main(sys.argv)
