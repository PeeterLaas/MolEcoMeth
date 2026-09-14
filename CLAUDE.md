# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Quarto website that *is* the course MLB7052.LT (Kaasaegsed meetodid
molekulaarses ökoloogias / Modern Molecular Methods in Ecology, Tallinn
University / TalTech, 2026/2027 autumn). The site is in Estonian. It holds
the six revealjs lecture decks, the syllabus and schedule pages, and the
seminar register — all rendered to GitHub Pages by CI. It is not an R package or
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

`data/schedule.csv` is **one row per topic, not per week**. A Friday that covers
two topics, or carries an extra session, has two rows with the same `week`; the
optional `time` column is shown beside the date. Read it through
`course_schedule()`, which adds the derived `date` — pages that need seminar or
practical dates filter on `kind` and format with `et_session_list()` rather than
writing dates into prose.

### The freeze split — the thing most likely to break a build

`_freeze/` **is committed**. Lecture decks execute `tidyverse` and friends
locally and CI serves them from the cache; the publish workflow installs only a
short list of light packages (`rmarkdown`, `yaml`, `readr`, `dplyr`, `knitr`,
`htmltools`, `tibble`).

- Edited a deck? Render it locally and commit the updated `_freeze/` with the
  `.qmd`, or the CI build fails. This is why `update.sh` renders by default.
- The three data-driven pages (`index.qmd`, `schedule.qmd`,
  `seminars/index.qmd`) set `execute: freeze: false`, because they must pick up
  CSV changes — the seminar bot's, and yours to `data/schedule.csv`. Any library they use must exist in
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

### Attendance is not in this repository

It is kept by the lecturer outside GitHub: each session has a short task, and
an Apps Script collects the replies into a Google Sheet. A GitHub-based system
(issue form, bot, peppered session codes, `participation.qmd`) existed until
2026-09-14 and was removed because students found GitHub too much for
something done every week. Do not rebuild it; the site only says that
attendance is counted from the task replies.

### Seminar registration: issue form → CSV → website

An issue opened from `.github/ISSUE_TEMPLATE/seminar.yml` carries the `seminar`
label, which triggers `.github/workflows/issue-forms.yml` to run
`tools/seminar_bot.py`. The bot appends a row to `seminars/registrations.csv`,
hands its reply back through `finish()` (writes `comment`/`close` as step
outputs), and the workflow commits, pulls-rebases-pushes with retries, comments
and closes. `concurrency: course-data` serialises the runs.

`tools/issue_form.py` is the shared layer: issue-form body parsing (`### Label`
headings, `_No response_` for empty), CSV append that preserves header order,
and `finish()`.

- **The `seminar` label must exist in the repository.** GitHub applies an issue
  form's labels only if they already exist; otherwise the issue arrives
  unlabelled and the workflow silently skips it.
- The form's field labels stay English, because `parse_fields()` looks values up
  by label (`your name`, `paper title`, `doi or url`) and renaming one breaks
  every submission.
- `seminars/registrations.csv` is bot-written. When editing it from a script,
  write with `lineterminator="\n"`: Python's `csv` defaults to CRLF and turns a
  one-cell edit into a whole-file diff.

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
  `data/schedule.csv` are Estonian — the 2026/2027
  intake has no non-Estonian speakers. The six revealjs decks are still
  English. Write new site copy in Estonian; leave the decks alone unless the
  whole set is being converted.
- `MolEcoMeth/`, `www/`, `app.R`, `deploy.R` and `rsconnect/` are leftovers from
  an unrelated Shiny app. They are git-ignored and excluded from the render;
  leave them alone.
- `*.pdf` is git-ignored (source lecture PDFs and the textbook are large and not
  ours to redistribute), except `seminars/slides/*.pdf`.
