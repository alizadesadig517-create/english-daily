#!/usr/bin/env python3
"""Validate English Daily content files.

Usage:
    python3 scripts/validate.py            # validate everything in content/ and config/
    python3 scripts/validate.py FILE...    # validate the given lesson files (plus index/history)

Checks:
  * every lesson against schema/lesson.schema.json (uses the `jsonschema`
    package when installed, otherwise a built-in validator for the subset of
    JSON Schema that the lesson schema uses - so only the standard library is
    required)
  * extra rules the schema cannot express (file name = date, story contains
    the new words, exercise answers are valid, ...)
  * content/index.json, content/history.json and config/settings.json

Exit code 0 = valid, 1 = errors found. Warnings never fail the run.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")
SCHEMA_PATH = os.path.join(ROOT, "schema", "lesson.schema.json")
SETTINGS_PATH = os.path.join(ROOT, "config", "settings.json")
INDEX_PATH = os.path.join(CONTENT, "index.json")
HISTORY_PATH = os.path.join(CONTENT, "history.json")

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
LESSON_FILE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.json$")
LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]

errors = []
warnings = []


def err(where, msg):
    errors.append(f"{where}: {msg}")


def warn(where, msg):
    warnings.append(f"{where}: {msg}")


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        err(rel(path), "file not found")
    except json.JSONDecodeError as e:
        err(rel(path), f"invalid JSON: {e}")
    return None


def rel(path):
    return os.path.relpath(path, ROOT)


# --------------------------------------------------------------------------
# Minimal JSON Schema validator (subset used by lesson.schema.json)
# --------------------------------------------------------------------------

def _type_ok(value, t):
    if t == "object":
        return isinstance(value, dict)
    if t == "array":
        return isinstance(value, list)
    if t == "string":
        return isinstance(value, str)
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if t == "boolean":
        return isinstance(value, bool)
    if t == "null":
        return value is None
    raise ValueError(f"unsupported type {t}")


def _resolve(root, ref):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref {ref}")
    node = root
    for part in ref[2:].split("/"):
        node = node[part]
    return node


def builtin_validate(value, schema, root, path, out):
    if "$ref" in schema:
        builtin_validate(value, _resolve(root, schema["$ref"]), root, path, out)
        return
    if "const" in schema and value != schema["const"]:
        out.append(f"{path}: must be {schema['const']!r}")
        return
    if "enum" in schema and value not in schema["enum"]:
        out.append(f"{path}: {value!r} is not one of {schema['enum']}")
        return
    t = schema.get("type")
    if t and not _type_ok(value, t):
        out.append(f"{path}: expected {t}, got {type(value).__name__}")
        return
    if isinstance(value, str):
        if "minLength" in schema and len(value.strip()) < schema["minLength"]:
            out.append(f"{path}: must not be empty")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            out.append(f"{path}: {value!r} does not match {schema['pattern']}")
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            out.append(f"{path}: needs at least {schema['minItems']} items, has {len(value)}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            out.append(f"{path}: allows at most {schema['maxItems']} items, has {len(value)}")
        if "items" in schema:
            for i, item in enumerate(value):
                builtin_validate(item, schema["items"], root, f"{path}[{i}]", out)
    if isinstance(value, dict):
        props = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                out.append(f"{path}: missing required property '{key}'")
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in props:
                    out.append(f"{path}: unexpected property '{key}'")
        for key, sub in props.items():
            if key in value:
                builtin_validate(value[key], sub, root, f"{path}.{key}", out)


def schema_errors(data, schema):
    try:
        import jsonschema  # type: ignore
    except ImportError:
        out = []
        builtin_validate(data, schema, schema, "$", out)
        return out
    validator_cls = jsonschema.validators.validator_for(schema)
    validator = validator_cls(schema)
    out = []
    for e in sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path)):
        loc = "$" + "".join(f"[{p}]" if isinstance(p, int) else f".{p}" for p in e.absolute_path)
        out.append(f"{loc}: {e.message}")
    # jsonschema treats "   " as a valid minLength-1 string; reject blank text too.
    builtin = []
    builtin_validate(data, schema, schema, "$", builtin)
    out.extend(m for m in builtin if m.endswith("must not be empty"))
    return out


# --------------------------------------------------------------------------
# Semantic checks
# --------------------------------------------------------------------------

def norm(s):
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s'-]", " ", s.lower().replace("’", "'"))).strip()


def word_forms(word):
    """Common inflected forms of an English word or phrase (good enough for checks)."""
    w = word.lower()
    parts = w.split()
    if len(parts) > 1:
        # phrasal verbs / phrases: inflect the first word only
        return {" ".join([f] + parts[1:]) for f in word_forms(parts[0])}
    forms = {w, w + "s", w + "es", w + "ed", w + "d", w + "ing", w + "er", w + "est", w + "ly"}
    if w.endswith("e"):
        forms |= {w[:-1] + "ing", w[:-1] + "ed"}
    if w.endswith("y") and len(w) > 2:
        forms |= {w[:-1] + "ies", w[:-1] + "ied", w[:-1] + "ier", w[:-1] + "iest", w[:-1] + "ily"}
    if len(w) >= 3 and w[-1] not in "aeiouwxy" and w[-2] in "aeiou" and w[-3] not in "aeiou":
        forms |= {w + w[-1] + "ed", w + w[-1] + "ing", w + w[-1] + "er"}
    return forms


def text_contains_word(text, word):
    t = " " + norm(text) + " "
    return any(f" {f} " in t for f in word_forms(word))


def check_lesson(path, data, settings):
    where = rel(path)
    name = os.path.basename(path)
    if not LESSON_FILE_RE.match(name):
        err(where, "file name must be YYYY-MM-DD.json")
    elif data.get("date") != name[:-5]:
        err(where, f"date {data.get('date')!r} does not match file name")

    if settings:
        if data.get("level") != settings.get("level"):
            warn(where, f"level {data.get('level')} differs from settings ({settings.get('level')})")
        if data.get("translationLanguage") != settings.get("translationLanguage"):
            warn(where, "translationLanguage differs from settings")

    words = data.get("words", [])
    seen = set()
    for i, w in enumerate(words):
        key = w["word"].lower()
        if key in seen:
            err(where, f"word '{w['word']}' appears twice")
        seen.add(key)
        pos = [s["partOfSpeech"] for s in w["senses"]]
        if len(pos) != len(set(pos)):
            err(where, f"words[{i}] '{w['word']}': one sense per part of speech (duplicates: {pos})")
        for j, s in enumerate(w["senses"]):
            for k, ex in enumerate(s["examples"]):
                if not text_contains_word(ex["text"], w["word"]):
                    warn(where, f"words[{i}].senses[{j}].examples[{k}] may not contain '{w['word']}'")
            for lst in ("synonyms", "antonyms"):
                if any(x.lower() == key for x in s[lst]):
                    err(where, f"words[{i}].senses[{j}].{lst} contains the word itself")

    story = data.get("story")
    if story:
        full = " ".join(s["text"] for p in story["paragraphs"] for s in p["sentences"])
        for w in words:
            if not text_contains_word(full, w["word"]):
                err(where, f"new word '{w['word']}' does not appear in the story")
        lemmas = {g["lemma"].lower() for g in story["glossary"]}
        for w in words:
            if w["word"].lower() not in lemmas:
                err(where, f"story.glossary needs an entry with lemma '{w['word']}'")
        terms = set()
        for i, g in enumerate(story["glossary"]):
            t = norm(g["term"])
            if t in terms:
                err(where, f"story.glossary[{i}] duplicate term '{g['term']}'")
            terms.add(t)
            if f" {t} " not in f" {norm(full)} ":
                err(where, f"story.glossary[{i}] term '{g['term']}' is not in the story text (use the exact form from the story)")
    elif settings and settings.get("storyEnabled"):
        warn(where, "no story, but storyEnabled is true in settings")

    for i, q in enumerate(data["grammar"]["exercise"]["questions"]):
        qw = f"grammar.exercise.questions[{i}]"
        if q["type"] == "choice":
            opts = q.get("options")
            if not opts:
                err(where, f"{qw}: choice question needs options")
            elif q["answer"] not in opts:
                err(where, f"{qw}: answer {q['answer']!r} is not one of the options")
            elif len(set(opts)) != len(opts):
                err(where, f"{qw}: duplicate options")
        elif "options" in q:
            err(where, f"{qw}: text question must not have options")


def check_settings(settings):
    where = rel(SETTINGS_PATH)
    expected = {"level": str, "translationLanguage": str, "wordsPerDay": int,
                "storyEnabled": bool, "minutesPerDay": int}
    for key, t in expected.items():
        if key not in settings:
            err(where, f"missing '{key}'")
        elif not isinstance(settings[key], t) or (t is int and isinstance(settings[key], bool)):
            err(where, f"'{key}' must be {t.__name__}")
    for key in settings:
        if key not in expected:
            warn(where, f"unknown key '{key}'")
    if settings.get("level") not in LEVELS:
        err(where, f"level must be one of {LEVELS}")
    if not re.match(r"^[a-z]{2,3}$", str(settings.get("translationLanguage", ""))):
        err(where, "translationLanguage must be a language code like 'az'")
    if isinstance(settings.get("wordsPerDay"), int) and not 1 <= settings["wordsPerDay"] <= 20:
        err(where, "wordsPerDay must be 1..20")
    if isinstance(settings.get("minutesPerDay"), int) and not 1 <= settings["minutesPerDay"] <= 240:
        err(where, "minutesPerDay must be 1..240")


def check_index(lesson_dates):
    where = rel(INDEX_PATH)
    index = load_json(INDEX_PATH)
    if index is None:
        return
    if not isinstance(index, dict) or not isinstance(index.get("dates"), list):
        err(where, 'must be {"dates": ["YYYY-MM-DD", ...]}')
        return
    dates = index["dates"]
    for d in dates:
        if not isinstance(d, str) or not DATE_RE.match(d):
            err(where, f"bad date {d!r}")
    if dates != sorted(dates, reverse=True):
        err(where, "dates must be sorted newest first")
    if len(dates) != len(set(dates)):
        err(where, "dates must be unique")
    for d in set(dates) - lesson_dates:
        err(where, f"lists {d} but content/{d}.json does not exist")
    for d in lesson_dates - set(dates):
        err(where, f"content/{d}.json exists but {d} is not listed")


def check_history(lessons):
    where = rel(HISTORY_PATH)
    hist = load_json(HISTORY_PATH)
    if hist is None:
        return
    if not isinstance(hist, dict) or not isinstance(hist.get("words"), list) \
            or not isinstance(hist.get("grammarTopics"), list):
        err(where, 'must be {"words": [{"word","date"}], "grammarTopics": [{"topic","date"}]}')
        return
    word_dates = {}
    for i, e in enumerate(hist["words"]):
        if not isinstance(e, dict) or not isinstance(e.get("word"), str) or not DATE_RE.match(str(e.get("date"))):
            err(where, f"words[{i}] must be {{\"word\": str, \"date\": \"YYYY-MM-DD\"}}")
            continue
        k = e["word"].lower()
        if k in word_dates:
            err(where, f"word '{e['word']}' is listed twice (repeats are not allowed)")
        word_dates[k] = e["date"]
    topic_dates = {}
    for i, e in enumerate(hist["grammarTopics"]):
        if not isinstance(e, dict) or not isinstance(e.get("topic"), str) or not DATE_RE.match(str(e.get("date"))):
            err(where, f"grammarTopics[{i}] must be {{\"topic\": str, \"date\": \"YYYY-MM-DD\"}}")
            continue
        k = norm(e["topic"])
        if k in topic_dates:
            err(where, f"grammar topic '{e['topic']}' is listed twice")
        topic_dates[k] = e["date"]

    for date, data in lessons.items():
        for w in data.get("words", []):
            d = word_dates.get(w["word"].lower())
            if d is None:
                err(where, f"missing word '{w['word']}' from {date}")
            elif d != date:
                err(f"content/{date}.json", f"word '{w['word']}' was already used on {d}")
        t = data.get("grammar", {}).get("topic")
        if t:
            d = topic_dates.get(norm(t))
            if d is None:
                err(where, f"missing grammar topic '{t}' from {date}")
            elif d != date:
                err(f"content/{date}.json", f"grammar topic '{t}' was already used on {d}")


def main(argv):
    schema = load_json(SCHEMA_PATH)
    settings = load_json(SETTINGS_PATH)
    if settings is not None:
        check_settings(settings)
    if schema is None:
        return report()

    all_files = sorted(f for f in os.listdir(CONTENT) if LESSON_FILE_RE.match(f))
    targets = [os.path.abspath(a) for a in argv] if argv else [os.path.join(CONTENT, f) for f in all_files]

    lessons = {}
    for path in [os.path.join(CONTENT, f) for f in all_files] + targets:
        date = os.path.basename(path)[:-5]
        if date in lessons:
            continue
        data = load_json(path)
        if data is None:
            continue
        problems = schema_errors(data, schema)
        if problems:
            for p in problems:
                err(rel(path), p)
            continue
        lessons[date] = data
        if path in targets:
            check_lesson(path, data, settings)

    check_index({f[:-5] for f in all_files})
    check_history(lessons)
    return report()


def report():
    for w in warnings:
        print(f"WARNING {w}")
    for e in errors:
        print(f"ERROR   {e}")
    if errors:
        print(f"\nINVALID: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"OK: content is valid ({len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
