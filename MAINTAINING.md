# Maintaining the course

Notes for whoever is running MLB7052.LT. Students want
[README.md](README.md) and the [website](https://peeterlaas.github.io/MolEcoMeth/)
instead.

The repository is the course: slides, schedule and seminar register all live
here, and the published site is a rendering of it. Attendance does not — see
[Attendance](#attendance) below.

## Layout

```
index.qmd            home page
syllabus.qmd         full syllabus
schedule.qmd         week-by-week plan, dates derived from _quarto.yml
topics.qmd           the four blocks, and which method answers which question
materials.qmd        books, software, databases, datasets
seminars/
  index.qmd          seminar register and submission instructions
  registrations.csv  written by the seminar bot
  slides/            student uploads (linked, never rendered)
lectures/            the six revealjs decks
data/
  schedule.csv       the teaching plan, one row per topic
assets/              lecture figures and logos
css/                 site.scss (website) and lectures.scss (decks)
tools/               the seminar-registration bot
```

## Day to day

```bash
./start.sh                        # once: first commit + create the private repo
./update.sh "Add week 8 slides"     # render, commit, push
./update.sh -n "Fix a typo"         # same, skipping the render
```

`update.sh` renders before committing on purpose — see the freeze note below.

Building by hand:

```bash
quarto render                       # whole site, into _site/
quarto render lectures/loeng4.qmd   # one deck
quarto preview                      # live reload while editing
```

Lecture decks are cached in `_freeze/`, which **is** committed: CI publishes the
site without re-running the decks' R code. If you change a deck, render it
locally and commit the updated `_freeze/` along with the `.qmd`.

Two scripts are injected into every deck from `lectures/_metadata.yml`:
`tools/fit-slides.html` shrinks a slide whose content overflows, and
`tools/zoom-figures.html` makes each figure open full-screen when clicked
(click, Esc or the × to come back). Editing either one means re-rendering the
decks so they pick it up — `./update.sh` does that.

The three data-driven pages (home, schedule, seminars) set `freeze: false`,
because they must pick up CSV changes the seminar bot makes.

## Setting up the GitHub side

### 1. Create the repository

`./start.sh` does this: renames the branch to `main` (GitHub and the
workflows expect that name), makes the first commit, and creates the private
repository. By hand it is:

```bash
git branch -m master main
git add -A
git commit -m "Reorganise as a course website"
gh repo create MolEcoMeth --private --source=. --remote=origin --push
```

If the owner is not `peeterlaas`, update `course-repo` and `site-url` in
`_quarto.yml`, and the repository URL in `.github/CODEOWNERS`.

### 2. Turn on Pages

Settings → Pages → Source: **GitHub Actions**. Publishing Pages from a private
repository needs GitHub Pro, Team, or Enterprise — free-plan accounts can only
publish from a public repository. The *source* stays private either way; the
*site* is public unless you are on Enterprise with access control.

### 3. Add the students

Settings → Collaborators → add each student with **Write**.

Write access lets them push a branch and open a pull request with their slides.
It does **not** let them change the course: the *Seminar guard* workflow fails
any pull request from a non-maintainer that touches anything outside
`seminars/`. Make that check required:

Settings → Rules → New ruleset, targeting the default branch:

- Require a pull request before merging (0 approvals)
- Require status checks to pass → **Seminar guard / guard**
- Block force pushes
- Bypass list: **Repository admin**

GitHub has no per-directory write permission, so this check *is* the
restriction. One residual gap comes with write access: a collaborator can run
workflows on their own branch. If that matters for your setup, give students
**Read** instead and have them work from forks — the same workflows still run as
checks, and you merge by hand.

Read access alone is enough for claiming a seminar paper, since that is an
issue form. Only uploading slides needs write or a fork.

### 4. Create the `seminar` label

Issues → Labels → New label, named exactly `seminar`. GitHub applies an issue
form's labels only if they already exist, so without it every registration
arrives unlabelled and the bot never runs.

## Attendance

Attendance is not recorded in this repository. Each session has a short task,
and an Apps Script collects the replies into a Google Sheet, which is the
record the oral examination is scaled against.

A GitHub-based system — an issue form, a bot and peppered session codes — was
tried in the first weeks of 2026 and removed: for students new to GitHub it was
too much to do every week. It is in the history before 2026-09-14 if it is ever
wanted again.

## Adding a lecture

1. Write `lectures/<name>.qmd`, copying the YAML header from any existing deck.
2. Put its figures in `assets/<name>/` and reference them as `/assets/<name>/…`
   — project-relative paths work from any depth.
3. Add the deck to the sidebar in `_quarto.yml` and to `data/schedule.csv`.
4. `quarto render lectures/<name>.qmd`, then commit the deck and `_freeze/`.

## What is deliberately not in the repository

- The source lecture PDFs and the textbook (`*.pdf` is ignored) — large, and not
  ours to redistribute. Extracted teaching figures under `assets/` are used
  under institutional permissions.
- The 100 MB EEA bathing-water table; the
  [materials page](materials.qmd) says where to get it.
- Rendered HTML. CI builds it.
