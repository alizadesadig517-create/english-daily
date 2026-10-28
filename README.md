# English Daily

A personal Android app for daily English practice, plus the daily content
pipeline that feeds it.

Every morning a scheduled Claude Code routine writes a new lesson (new words,
a short story and a grammar topic at your level, with Azerbaijani translations)
into `content/` on GitHub. The app downloads it, reminds you at your chosen
time, and tracks your progress and streaks. No accounts, no server, no API key.

```
app/                     Flutter app (Android)
content/YYYY-MM-DD.json  one lesson per day (Asia/Baku dates)
content/index.json       list of published dates, newest first
content/history.json     words and grammar topics already used (never repeated)
config/settings.json     your learner settings - the routine reads these
schema/lesson.schema.json  the lesson format (the contract between routine and app)
scripts/validate.py      checks lessons against the schema and the quality rules
routine/daily-content.md the full instructions for the daily routine
.github/workflows/       builds the APK and publishes it as a GitHub Release
```

---

## Setup (once)

Everything below can be done in a phone browser. GitHub's settings pages are
easier with **"Desktop site"** switched on in the browser menu.

### 1. Let the app read the lessons

Pick one:

- **Public repository (simplest):** the app reads lessons from public links.
  Repository → **Settings** → scroll to **Danger Zone** → **Change visibility**
  → Public. Nothing else to do.
- **Private repository:** keep it private and give the app a token
  (step 5). Without a token, a private repository cannot be read.

### 2. Create the signing key (so each new APK installs over the old one)

Android only updates an app if the new APK is signed with the same key. The key
lives in four repository secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, `KEY_PASSWORD`. A helper workflow creates all four for you:

1. **Make a temporary token.** github.com → your profile picture → **Settings**
   → **Developer settings** → **Personal access tokens** → **Fine-grained
   tokens** → **Generate new token**.
   - Name: `english-daily setup`, Expiration: 7 days
   - Repository access: **Only select repositories** → `english-daily`
   - Permissions → Repository permissions → **Secrets: Read and write**
   - **Generate token** and copy it.
2. **Save it as a secret.** Repository → **Settings** → **Secrets and
   variables** → **Actions** → **New repository secret**.
   Name `SETUP_TOKEN`, value: paste the token → **Add secret**.
3. **Run the helper.** Repository → **Actions** → **Create signing key** →
   **Run workflow** → **Run workflow**. Wait for the green tick (about 1 minute).
   The four signing secrets now exist (the passwords are random and never shown).
4. **Clean up.** Delete the `SETUP_TOKEN` secret (same page as step 2) and
   delete the token (same page as step 1).

Then run **Actions → Build APK → Run workflow** once, so the next APK is
signed with the new key.

> If the secrets are missing, the build still works but prints a warning and
> signs with a throw-away debug key - such an APK cannot update the previous one.
> Don't create a second key later: a different key means you must uninstall the
> app first (and lose your progress on the phone).

<details>
<summary>Alternative: create the key on a computer</summary>

```bash
keytool -genkeypair -keystore release.jks -storetype PKCS12 -alias english-daily \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=English Daily"
base64 -w0 release.jks > release.jks.b64     # macOS: base64 -i release.jks -o release.jks.b64
```

Add the secrets: `KEYSTORE_BASE64` = contents of `release.jks.b64`,
`KEYSTORE_PASSWORD` and `KEY_PASSWORD` = the password you typed (the same for
both), `KEY_ALIAS` = `english-daily`. Keep `release.jks` and the password safe.
</details>

### 3. Install the app

Every push to `main` that changes the app builds a new APK.

1. Repository → **Releases** (right side of the main page, or
   `https://github.com/alizadesadig517-create/english-daily/releases/latest`).
2. Tap **app-release.apk** to download it, then open it.
3. If Android asks, allow your browser to **install unknown apps**.
4. Updates: download the newest release and install it over the old app.
   Your progress stays.

(The APK is also attached to every run under **Actions → Build APK** as an
artifact.)

### 4. Create the daily routine

The routine is a scheduled Claude Code session that writes each day's lesson.

1. Open **claude.ai/code** (or the Claude app) and create a new
   **routine / scheduled task**:
   - **Repository:** `alizadesadig517-create/english-daily`
   - **Schedule:** every day at **04:47 Asia/Baku** (= 00:47 UTC; cron
     `47 0 * * *` in UTC). Early enough that the lesson is ready before your
     reminder; the app downloads it one hour before the reminder.
   - **Prompt:**
     ```
     Read routine/daily-content.md in this repository and follow it exactly.
     ```
2. The routine must be allowed to **push to `main`**. If its first run says the
   push was refused, open the routine's settings and allow pushing to any
   branch (unrestricted branch pushes) for this repository.
3. Run it once by hand to check: a new `content/<today>.json` should appear and
   `python3 scripts/validate.py` reports `OK`.

The routine never overwrites an existing day, never repeats a word or grammar
topic (it uses `content/history.json`), and only commits after the validator
passes.

### 5. (Optional) GitHub token in the app

With a token the app uses the GitHub API instead of public links. That works
with a **private** repository, and lets the app save your learning settings to
`config/settings.json` automatically.

1. Create a fine-grained token as in step 2.1, but with
   **Contents: Read and write** (instead of Secrets), and a long expiration.
2. In the app: **Settings → GitHub token** → paste → **Save**. It is stored in
   Android's encrypted storage.

## Changing your settings

Level, translation language, words per day, story on/off and minutes per day
are used by the routine, so they must reach `config/settings.json` on GitHub:

- **With a token:** change them in the app - it updates the file for you.
- **Without a token:** change them in the app (for the timer etc.) **and** edit
  `config/settings.json` on GitHub (open the file → pencil icon → edit →
  **Commit changes**):

```json
{
  "level": "B1",
  "translationLanguage": "az",
  "wordsPerDay": 5,
  "storyEnabled": true,
  "minutesPerDay": 15
}
```

Changes apply from the next day's lesson.

## Using the app

- **Today:** three sections - Words, Story, Grammar - and a timer. The day is
  done when every section is finished *or* you reach your daily minutes.
  The timer runs while a section is open.
- **Words:** swipe through cards; tap the speaker for pronunciation; tap a
  part of speech to see its translation, meaning, synonyms, antonyms,
  homonyms and examples.
- **Story:** tap any word for its meaning and the sentence translation.
  Long-press and drag to select a phrase. Today's words are highlighted.
  The translate button shows a translation under every sentence.
- **Grammar:** switch the explanation between English and your language, then
  do the exercise and check your answers.
- **Calendar:** green = done, yellow = partial, red = missed. Current and
  longest streak. Tap a past day to open its lesson.
- **Library:** all lessons. The page icon opens a "lesson card" you can share as
  an HTML page, a PDF or an image.
- **Reminder:** the notification has **Start** and **Snooze** (+30 min, +1 h,
  +2 h or a time you pick, today only). Settings shows the next reminder time.

## Troubleshooting

- **"Not ready yet"** - today's lesson hasn't been published. Check the
  routine's last run, or pull down on the Today screen later.
- **No reminders** - Settings → *Check notification permissions*, and make
  sure battery optimisation isn't blocking the app.
- **Lesson download fails with a private repo** - add a token (step 5).
- **Check content by hand:** `python3 scripts/validate.py`

## Developing

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The lesson format is defined in `schema/lesson.schema.json` and mirrored in
`app/lib/models/lesson.dart`; change both together.
