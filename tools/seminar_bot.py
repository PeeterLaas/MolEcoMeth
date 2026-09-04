"""Record one seminar paper claim from an issue form into the register."""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from issue_form import append_row, finish, parse_fields, read_csv

REGISTER = "seminars/registrations.csv"

body = os.environ.get("ISSUE_BODY", "")
user = os.environ.get("ISSUE_USER", "")

fields = parse_fields(body)
name = fields.get("your name", "")
title = fields.get("paper title", "")
url = fields.get("doi or url", "")


def normalise(value: str) -> str:
    """Compare papers loosely: DOIs differ by prefix, titles by punctuation."""
    value = value.strip().lower()
    value = re.sub(r"^https?://(dx\.)?doi\.org/", "", value)
    value = re.sub(r"^https?://", "", value).rstrip("/")
    return re.sub(r"[^a-z0-9]+", "", value)


if not title or not url:
    finish(
        "❌ The registration needs both a paper title and a DOI or URL.\n\n"
        "Please open a new registration issue with both filled in."
    )
    sys.exit(0)

register = read_csv(REGISTER)

mine = [r for r in register if r["github_user"].lower() == user.lower()]
if mine:
    finish(
        f"❌ You have already claimed **{mine[0]['paper_title']}**.\n\n"
        "To change your paper, ask the lecturer in a plain issue rather than "
        "registering twice."
    )
    sys.exit(0)

for row in register:
    if normalise(row["paper_doi_or_url"]) == normalise(url) or \
       normalise(row["paper_title"]) == normalise(title):
        finish(
            f"❌ **@{row['github_user']}** claimed that paper first "
            "— registration is first come, first served.\n\n"
            "Please pick another one and open a new registration issue. The "
            "[register](https://peeterlaas.github.io/MolEcoMeth/seminars/) "
            "shows what is already taken."
        )
        sys.exit(0)

append_row(REGISTER, {
    "github_user": user,
    "student_name": name,
    "paper_title": title,
    "paper_doi_or_url": url,
    "presentation_date": "",
    "slides_file": "",
})

finish(
    f"✅ Registered **{name}** (@{user}) for:\n\n> {title}\n> {url}\n\n"
    "Next: bring your slides as a pull request into `seminars/slides/` before "
    "your slot — see [how to submit]"
    "(https://peeterlaas.github.io/MolEcoMeth/seminars/#submitting-your-slides)."
)
