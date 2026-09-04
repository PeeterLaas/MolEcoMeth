"""Shared helpers for the issue-form bots.

GitHub renders an issue form as markdown: each field becomes a `### Label`
heading followed by the value (or the literal `_No response_` when empty).
"""

import csv
import hashlib
import os
import re


def parse_fields(body: str) -> dict:
    """Map issue-form field labels to their submitted values."""
    fields = {}
    # Split on the headings the form generates, keeping the heading text.
    parts = re.split(r"^###\s+(.+?)\s*$", body or "", flags=re.MULTILINE)
    for label, value in zip(parts[1::2], parts[2::2]):
        value = value.strip()
        if value == "_No response_":
            value = ""
        fields[label.strip().lower()] = value
    return fields


def read_csv(path: str) -> list:
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def append_row(path: str, row: dict) -> None:
    """Append one row, preserving the existing header order."""
    with open(path, newline="", encoding="utf-8") as fh:
        header = next(csv.reader(fh))
    with open(path, "a", newline="", encoding="utf-8") as fh:
        csv.DictWriter(fh, fieldnames=header).writerow(
            {k: row.get(k, "") for k in header}
        )


def code_hash(session_id: str, code: str, pepper: str) -> str:
    """Hash a session code so the expected value can live in a repo students read.

    The pepper is an Actions secret, so a stored hash reveals nothing even
    though `data/sessions.csv` is visible to everyone with access.
    """
    material = f"{pepper}:{session_id}:{code.strip().lower()}"
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def finish(message: str, close: bool = True) -> None:
    """Hand the outcome back to the workflow through step outputs."""
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"close={'true' if close else 'false'}\n")
            fh.write("comment<<COMMENT_EOF\n")
            fh.write(message.rstrip() + "\n")
            fh.write("COMMENT_EOF\n")
    print(message)
