# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Quarto website that *is* the course MLB7052.LT (Kaasaegsed meetodid
molekulaarses ökoloogias / Modern Molecular Methods in Ecology, Tallinn
University / TalTech, 2026/2027 autumn). The site is in Estonian. It holds
the six revealjs lecture decks, the syllabus and schedule pages, and the
attendance and seminar records — all rendered to GitHub Pages by CI. It is not an R package or
a Shiny app, and there is no test suite; `quarto render` is the check.

`README.md` is written for students, `MAINTAINING.md` for whoever runs the
course — read the latter for the GitHub-side setup (Pages, collaborators,
required checks, secrets) that is not repeated here.

## Commands

```bash
./update.sh "Add week 8 slides"   # render, commit, push  ← the normal way to publish
./update.sh -n "Fix a typo"       # same, skipping the render (text-only changes)

quarto render                     # whole site into _site/
quarto render lectures/loeng4.qmd # one deck
quarto preview                    # live reload while editing

./geneh.sh --init                 # once per machine: create .session_pepper
./geneh.sh w03 amplicon           # print the code hash for a session
./geneh.sh -w w03 amplicon        # …and write it into data/sessions.csv, open=yes
```

`quarto` is often not on `PATH` (it ships inside RStudio); `update.sh` falls
back to `/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto`.

## Architecture

### One place for course facts

`_quarto.yml` carries the course metadata (`course-code`, `course-title-*`,
`course-repo`, `semester`, `semester-start`, logo paths) alongside the site
config. Pages read it through `course_meta()` in `R/course.R`, which walks up to
the project root and parses the YAML directly — Quarto does not hand
project-level metadata to the knitr engine. Never hardcode a date, a title or
the repo URL in a page; every schedule date is derived as
`semester-start + 7 * (week - 1)`, so moving the semester is a one-line change.

`R/course.R` also forces a UTF-8 `LC_CTYPE`, because under a C locale (CI, some
shells) `kable()` escapes the Estonian titles to `<U+00F6>`.

### The freeze split — the thing most likely to break a build

`_freeze/` **is committed**. Lecture decks execute `tidyverse` and friends
locally and CI serves them from the cache; the publish workflow installs only a
short list of light packages (`rmarkdown`, `yaml`, `readr`, `dplyr`, `tidyr`,
`knitr`, `htmltools`, `tibble`).

- Edited a deck? Render it locally and commit the updated `_freeze/` with the
  `.qmd`, or the CI build fails. This is why `update.sh` renders by default.
- The four data-driven pages (`index.qmd`, `schedule.qmd`, `participation.qmd`,
  `seminars/index.qmd`) set `execute: freeze: false`, because they must pick up
  CSV changes the bots commit. Any library they use must exist in
  `.github/workflows/publish.yml`; adding one to those pages means adding it
  there too.

### Estonian, and the three traps in it

Quarto 1.5 ships no `_language-et.yml`, so the interface strings — TOC title,
search, callout headings — are supplied by hand in the `language:` block of
`_quarto.yml`. Anything Quarto renders itself that appears in English is a
missing key there, not a missed translation in a page.

Dates go through `et_date()`, `et_date_long()` and `et_date_weekday()` in
`R/course.R`, never `%B` or `%a`. `et_EE.UTF-8` is not installed on the CI
runner, so a locale-based month name silently comes out English on the
published site — the same reason the file forces `LC_CTYPE`.

**Estonian ordinals break Pandoc.** `1. nädal` at the start of a paragraph is a
valid ordered-list marker: digits, a period, a space. Inside the raw-HTML
lecture cards in `index.qmd` it turned every `<p>` into an `<ol>` and swallowed
the closing `</div>` tags, and in a list continuation line it opens a nested
list. Keep an ordinal off the start of a line and off the start of a paragraph;
`04.09.2026` is safe because there is no space after the period. `quarto render`
reports this as `[WARNING] Div … unclosed`.

### Data flow: issue forms → CSV → website

An issue opened from `.github/ISSUE_TEMPLATE/attendance.yml` or `seminar.yml`
carries a label that triggers `.github/workflows/issue-forms.yml`, which runs
`tools/attendance_bot.py` or `tools/seminar_bot.py`. A bot appends a row to a
CSV, hands its reply back through `finish()` (writes `comment`/`close` as step
outputs), and the workflow commits, pulls-rebases-pushes with retries, comments
and closes. `concurrency: course-data` serialises the runs — a room full of
students submits at once.

`tools/issue_form.py` is the shared layer: issue-form body parsing (`### Label`
headings, `_No response_` for empty), CSV append that preserves header order,
`code_hash()`, and `finish()`.

- `data/sessions.csv` gates attendance: a row must have `open` = `yes`, and its
  `code_hash` must match, or the bot rejects the claim (an empty `code_hash`
  accepts anything).
- The session dropdown in `attendance.yml` must stay in sync with the
  `session_id` values in `data/sessions.csv` — the bot takes the id from the
  first token of the selected option. The text after the dash is free, and is
  kept in Estonian to match the CSV; the form's **field labels** stay English,
  because `parse_fields()` looks values up by label (`session`, `session code`,
  `your name`, `paper title`, `doi or url`) and renaming one breaks every
  submission.
- `data/attendance.csv` and `seminars/registrations.csv` are bot-written. When
  editing them from a script, write with `lineterminator="\n"`: Python's `csv`
  defaults to CRLF and turns a one-cell edit into a whole-file diff.

### Session codes

`sha256("<pepper>:<session_id>:<lowercased code>")`, defined once in
`issue_form.code_hash()` and used by both the bot and the local helpers, so the
two cannot drift. The pepper lives in `.session_pepper` (git-ignored, mode 600)
locally and as the `SESSION_PEPPER` Actions secret; **they must be identical**
or every submission is rejected. Peppering is what lets `data/sessions.csv`
stay readable by students without leaking the code, which is only ever spoken
in class.

### Student write access

Students are collaborators with Write, so the restriction is enforced as a
required check: `.github/workflows/seminar-guard.yml` fails any pull request
from a non-admin/maintain author that touches anything outside `seminars/`, and
auto-squash-merges the ones that do not. `seminars/slides/` is excluded from the
render list in `_quarto.yml` on purpose — Quarto must never execute code that
arrives by pull request.

## Conventions

- **Figures in decks** use project-absolute paths, `/assets/<deck>/fig.png`, so
  they resolve from any depth. Paths in a deck's YAML header (theme, logos,
  filters) are file-relative instead: `../css/lectures.scss`,
  `../assets/logos/…`.
- **New deck**: copy the YAML header from an existing one, put figures in
  `assets/<name>/`, then add it to the sidebar in `_quarto.yml` and to
  `data/schedule.csv`. `lectures/_metadata.yml` applies
  `include-after-body: ../tools/fit-slides.html` to every deck.
- **A `.qmd` runs from its own directory.** `seminars/index.qmd` sources
  `../R/course.R` and reads `registrations.csv`; top-level pages use `R/course.R`
  and `data/…`.
- **Styling** is two SCSS files sharing the Tallinn University red `#990000`:
  `css/site.scss` (website) and `css/lectures.scss` (decks).
- **The website is Estonian, the decks are English.** Every `.qmd` outside
  `lectures/`, the sidebar, the navbar, the footer and the topic strings in
  `data/schedule.csv` and `data/sessions.csv` are Estonian — the 2026/2027
  intake has no non-Estonian speakers. The six revealjs decks are still
  English. Write new site copy in Estonian; leave the decks alone unless the
  whole set is being converted.
- `MolEcoMeth/`, `www/`, `app.R`, `deploy.R` and `rsconnect/` are leftovers from
  an unrelated Shiny app. They are git-ignored and excluded from the render;
  leave them alone.
- `*.pdf` is git-ignored (source lecture PDFs and the textbook are large and not
  ours to redistribute), except `seminars/slides/*.pdf`.
