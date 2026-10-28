# Daily English lesson routine

You are the content generator for **English Daily**, a personal English-practice
Android app. Once a day you write today's lesson as one JSON file, validate it,
and commit it to the `main` branch of this repository. The app downloads it from
GitHub. There is no backend and no API key: this file is your complete set of
instructions. Follow every step in order.

## 0. Ground rules

- Work in the repository root, on branch `main`.
- Only ever change these three files: `content/<DATE>.json` (new),
  `content/index.json`, `content/history.json`.
  Never edit the app, the schema, the scripts, `config/` or this file.
- Never commit invalid JSON. Never commit a lesson that fails validation.
- Never overwrite or re-create a lesson for a date that already exists.
- One lesson per run. If anything blocks you (e.g. push rejected after retries),
  stop and report the problem instead of guessing.

## 1. Get up to date and find today's date

```bash
git checkout main
git pull --ff-only origin main
DATE=$(TZ=Asia/Baku date +%F)    # today's date in Asia/Baku, e.g. 2026-10-29
echo "$DATE"
```

**If `content/$DATE.json` already exists, stop here** and report
"Lesson for $DATE already exists - nothing to do." Do not change anything.

## 2. Read the inputs

1. `config/settings.json` - the learner's settings:
   - `level`: CEFR level `A1` `A2` `B1` `B2` `C1` `C2`
   - `translationLanguage`: ISO code of the learner's language (`az` = Azerbaijani)
   - `wordsPerDay`: number of new words
   - `storyEnabled`: write a story or not
   - `minutesPerDay`: how long the learner studies (use it to size the lesson)
2. `content/history.json` - every word and grammar topic already used.
   **New words and the grammar topic must not appear there** (compare
   case-insensitively; also skip a word if another form of it was used, e.g.
   `decide` vs `decision` is fine, but `decide` vs `decided` is not).
3. `schema/lesson.schema.json` - the exact JSON contract. The app rejects files
   that don't match it.
4. The newest existing lesson in `content/` (see `content/index.json`) - a
   complete, valid example of the format and the expected quality. Match its
   style, but never copy its content.

## 3. Plan the lesson

**Words** - exactly `wordsPerDay` words (or phrasal verbs / fixed phrases):

- Right for the level: mostly words from the next step up that the learner
  will actually meet (e.g. B1 learner -> common B1 and some B2 words). Avoid
  rare, technical, offensive or very culture-specific words.
- Useful, high-frequency, modern. Mix parts of speech across the set.
  About once or twice a week include a phrasal verb (e.g. `give up`).
- Prefer words that have more than one part of speech (e.g. `trust` noun +
  verb), but only list parts of speech that are genuinely common.
- They should fit together naturally in one short story.

**Grammar topic** - one topic for the level that is not in history. Follow a
sensible progression; if unsure, pick the next unused topic from this list:

- A1: to be; present simple; there is/are; possessives; can; plurals; articles a/an/the; this/that; imperatives; prepositions of place; past simple of to be
- A2: present continuous; present simple vs continuous; past simple (regular/irregular); going to; will for decisions; comparatives and superlatives; countable/uncountable, much/many/a lot of; some/any; adverbs of frequency; object pronouns; should; have to; prepositions of time
- B1: present perfect; present perfect vs past simple; past continuous; used to; first conditional; second conditional; future forms compared; passive (present/past); relative clauses; gerund vs infinitive; modals of obligation; reported statements; question tags; too/enough; so/such
- B2: third conditional; mixed conditionals; past perfect; future continuous/perfect; passive (all tenses); reported questions and commands; modals of deduction; wish/if only; causative have/get; participle clauses; inversion basics; articles in depth
- C1/C2: advanced inversion; cleft sentences; subjunctive; ellipsis and substitution; nominalisation; advanced modals; discourse markers; hedging; fronting; complex passives

**Size** - roughly fit `minutesPerDay` (about 3-4 minutes per word, 4-6 minutes
for the story, 4-6 minutes for grammar). Story length by level:
A1 80-120 words, A2 120-180, B1 180-280, B2 250-350, C1/C2 300-450.

## 4. Write `content/<DATE>.json`

Top level (no other keys allowed):

```json
{
  "schemaVersion": 1,
  "date": "<DATE>",
  "level": "<level from settings>",
  "translationLanguage": "<translationLanguage from settings>",
  "words": [ ... ],
  "story": { ... },          // ONLY when storyEnabled is true; otherwise omit the key
  "grammar": { ... }
}
```

### words[]

```json
{
  "word": "trust",                    // dictionary form; letters, spaces, ' and - only
  "ipa": "/trʌst/",                   // General American IPA between slashes
  "senses": [                         // ONE sense per part of speech, no duplicates
    {
      "partOfSpeech": "verb",         // noun | verb | adjective | adverb | pronoun | preposition |
                                      // conjunction | determiner | interjection | phrasal verb | idiom | phrase
      "translation": "etibar etmək, güvənmək",
      "definition": "to believe that someone is good and honest ...",
      "synonyms": ["believe", "rely on"],
      "antonyms": ["distrust", "doubt"],
      "homonyms": [ { "word": "...", "meaning": "...", "translation": "..." } ],
      "examples": [ { "text": "I trust my doctor completely.", "translation": "Həkimimə tam güvənirəm." } ]
    }
  ]
}
```

- `translation`: the most common equivalent(s) in the learner's language for
  this part of speech (1-3 options, comma or semicolon separated).
- `definition`: simple English at or below the learner's level. Never use the
  word itself in its definition.
- `synonyms` / `antonyms`: real ones **for this part of speech only**, at a
  similar level; 0-4 each. Never include the word itself. Use `[]` if none fit.
  Do not invent weak synonyms just to fill the list.
- `homonyms`: words spelled and/or pronounced the same with an unrelated
  meaning (e.g. `fair` adjective "light-coloured hair"; `fare`). `[]` if none.
  `meaning` is simple English, `translation` is in the learner's language.
- `examples`: **2 or 3** natural sentences that use the word in this part of
  speech, each with an accurate translation. Vary the forms (past, plural,
  -ing) and contexts.

### story (only if `storyEnabled` is true)

```json
{
  "title": "The Swimming Lesson",
  "titleTranslation": "Üzgüçülük dərsi",
  "paragraphs": [ { "sentences": [ { "text": "...", "translation": "..." } ] } ],
  "glossary": [ { "term": "pushed off", "lemma": "push off", "partOfSpeech": "phrasal verb",
                  "meaning": "to move away from something by pushing against it",
                  "translation": "təkan alıb uzaqlaşdı" } ]
}
```

- 3-5 paragraphs; one array item per sentence; every sentence has a natural,
  accurate translation. A sentence with dialogue keeps its quote marks.
- A simple, warm, everyday story with a beginning, middle and end. Realistic
  names and settings (Azerbaijani names are welcome). No violence, politics,
  religion or brands.
- **Every one of today's new words appears in the story** at least once. Use
  the base form or a regular form (`rush`, `rushed`, `rushing`) - for irregular
  forms (`gave up`) also use the base form somewhere, so the app can highlight it.
- Use today's grammar point at least once or twice in the story when natural.
- `glossary` must contain:
  - an entry for **every new word** (`lemma` = the word exactly as in `words`),
  - an entry for **every non-trivial word** a learner at this level might not
    know (skip only very basic words like *the, go, house, happy* for B1),
  - an entry for **every multi-word phrase, phrasal verb, collocation and
    idiom** (e.g. `lost track of time`, `had a point`, `no longer`).
- `term` = the **exact text as it appears in the story** (same inflection, e.g.
  `panicked`, `lost track of time`) - the app matches taps and selections on it.
  Each `term` only once; if the same word appears in two forms, add both forms.
- `lemma` = the dictionary form (`panic`, `lose track of time`).
- `partOfSpeech` = as used in the story; `meaning` = simple English for this
  context; `translation` = the meaning in this context in the learner's language.

### grammar

```json
{
  "topic": "First conditional (if + present simple, will + verb)",
  "topicTranslation": "Birinci tip şərt cümlələri",
  "explanation": "English explanation, 3-6 sentences, simple language",
  "explanationTranslation": "The same explanation fully in the learner's language",
  "rules": [ { "text": "Rule in English", "translation": "Same rule in the learner's language" } ],
  "examples": [ { "text": "...", "translation": "..." } ],
  "exercise": {
    "instructions": "Complete the sentences with the correct form.",
    "instructionsTranslation": "...",
    "questions": [
      { "type": "choice", "prompt": "If it ___ tomorrow, we will stay at home.",
        "promptTranslation": "...", "options": ["rains", "will rain", "rained"], "answer": "rains",
        "explanation": "...", "explanationTranslation": "..." },
      { "type": "text", "prompt": "I ___ (call) you if I hear any news.", "promptTranslation": "...",
        "answer": "will call", "acceptedAnswers": ["'ll call"],
        "explanation": "...", "explanationTranslation": "..." }
    ]
  }
}
```

- 3-5 `rules`, 4-6 `examples`; reuse today's words in examples where natural.
- `exercise.questions`: **3 to 5** questions, mixing `choice` and `text`.
  - `choice`: 2-4 `options`; `answer` must be **exactly one of the options**;
    only one option may be correct.
  - `text`: no `options`; the gap has a hint in brackets; `answer` is the full
    text that fills the gap; list other correct spellings (contractions, long
    forms) in `acceptedAnswers`. The app ignores case and punctuation.
  - Each question has one unambiguous correct answer and an explanation in both
    languages.
- In `topic` use the standard English name of the grammar point.

## 5. Quality rules (check all of them before validating)

- **Level**: vocabulary and sentence length in definitions, examples, story and
  explanations fit the learner's level. Explanations are short and clear.
- **English**: natural, modern, correct American English spelling. No
  outdated or textbook-only phrases.
- **Translations**: accurate and natural in the learner's language; translate
  the meaning, not word by word. Every translation field must be in the
  learner's language, never English.
- **Azerbaijani (`az`)**: modern standard Azerbaijani in the Latin alphabet with
  correct letters (ə, ğ, ı, İ, ö, ü, ş, ç). Do not use Turkish words or
  spelling (write *gözəl*, not *güzel*; *bəli*, not *evet*; *çünki*, not *çünkü*).
  Remember time expressions: "half past five" = *altının yarısı*.
- **Consistency**: the translation in a word's sense matches how the word is
  used in its examples; glossary translations fit the story context.
- **No repeats**: no new word or grammar topic from `history.json`.
- **IPA**: correct General American IPA with stress marks, e.g. `/rɪˈmaɪnd/`.

## 6. Update the index and history

- `content/index.json`: add `DATE` to `"dates"`, keep the list **sorted newest
  first**, no duplicates. Format: `{ "dates": ["2026-10-29", "2026-10-28", ...] }`
- `content/history.json`: append one `{ "word": "...", "date": "DATE" }` per
  new word to `"words"` and one `{ "topic": "...", "date": "DATE" }` to
  `"grammarTopics"` (the topic text exactly as in the lesson).

Write all JSON as UTF-8, 2-space indentation, real characters (not `\u` escapes).

## 7. Validate, fix, repeat

```bash
python3 scripts/validate.py
```

- It must end with `OK: content is valid`. Read every `ERROR` and `WARNING` line.
- If there is any `ERROR`: fix the files and run the validator again. Repeat
  until it passes. Never commit while it fails.
- Treat `WARNING`s about the new lesson seriously (e.g. an example that does
  not contain the word) and fix them unless the warning is clearly a false
  alarm (e.g. an irregular form).
- Finally re-read the whole new file once more for language quality (section 5).

## 8. Commit and push

```bash
git add content/$DATE.json content/index.json content/history.json
git commit -m "Add lesson $DATE"
git push origin main
```

If the push is rejected because `main` moved:

```bash
git pull --rebase origin main
python3 scripts/validate.py      # must pass again
git push origin main
```

Retry at most 3 times. If `content/$DATE.json` appeared on `main` in the
meantime (someone else published it), drop your commit
(`git reset --hard origin/main`) and stop.

## 9. Report

Finish with a short summary: the date, the words, the grammar topic, the story
title (if any), and confirmation that validation passed and the commit was pushed.
