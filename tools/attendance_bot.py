"""Record one attendance claim from an issue form into data/attendance.csv."""

import datetime as dt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from issue_form import append_row, code_hash, finish, parse_fields, read_csv

SESSIONS = "data/sessions.csv"
ATTENDANCE = "data/attendance.csv"

body = os.environ.get("ISSUE_BODY", "")
user = os.environ.get("ISSUE_USER", "")
pepper = os.environ.get("SESSION_PEPPER", "")

fields = parse_fields(body)
# The dropdown value is "w03 — The molecular toolkit"; the id is the first token.
session_id = fields.get("session", "").split()[0] if fields.get("session") else ""
code = fields.get("session code", "")

sessions = {s["session_id"]: s for s in read_csv(SESSIONS)}

if not session_id or session_id not in sessions:
    finish(
        f"❌ I could not tell which session this is (`{session_id or 'empty'}`).\n\n"
        "Please open a new attendance issue and pick a session from the dropdown."
    )
    sys.exit(0)

session = sessions[session_id]

if session.get("open", "").strip().lower() != "yes":
    finish(
        f"❌ **{session_id}** is not accepting attendance right now.\n\n"
        "The form is open during the session and closes shortly after it ends. "
        "If you were there and missed the window, say so in a plain issue and it "
        "will be corrected by hand."
    )
    sys.exit(0)

expected = session.get("code_hash", "").strip()
if expected:
    if not pepper:
        finish(
            "⚠️ This session needs a code, but the checking secret is not "
            "configured. The lecturer has been left this issue to sort out.",
            close=False,
        )
        sys.exit(0)
    if code_hash(session_id, code, pepper) != expected:
        finish(
            "❌ That session code is not right.\n\n"
            "Check the spelling — it is not case sensitive — and open a new "
            "attendance issue with the correct one."
        )
        sys.exit(0)

already = [
    r for r in read_csv(ATTENDANCE)
    if r["session_id"] == session_id and r["github_user"].lower() == user.lower()
]
if already:
    finish(
        f"✅ You were already logged for **{session_id}** "
        f"({session['topic']}). Nothing more to do."
    )
    sys.exit(0)

append_row(ATTENDANCE, {
    "session_id": session_id,
    "date": session["date"],
    "github_user": user,
    "recorded_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
})

finish(
    f"✅ Logged **@{user}** for **{session_id}** — {session['topic']} "
    f"({session['date']}).\n\n"
    "It appears on the [participation page]"
    "(https://peeterlaas.github.io/MolEcoMeth/participation.html) "
    "once the site rebuilds."
)
