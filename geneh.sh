#!/usr/bin/env bash
# Generate the attendance code hash for a session.
#
#   ./geneh.sh w01 amplicon        print the hash for session w01, code "amplicon"
#   ./geneh.sh -w w01 amplicon     also write it into data/sessions.csv and open the session
#   ./geneh.sh --init              create a pepper for this machine, once
#
# The hash is sha256("<pepper>:<session_id>:<code>"), with the code lowercased.
# Because it is peppered with a secret, data/sessions.csv can stay readable by
# students without the code leaking. The code itself is only ever spoken in class.
#
# The pepper is read from $SESSION_PEPPER, or from .session_pepper in this
# folder (git-ignored). It must match the SESSION_PEPPER secret on the
# repository, or the bot will reject every submission.
set -euo pipefail
cd "$(dirname "$0")"

PEPPER_FILE=.session_pepper
SESSIONS=data/sessions.csv

# --- ./geneh.sh --init -------------------------------------------------------
if [ "${1:-}" = "--init" ]; then
  if [ -s "$PEPPER_FILE" ]; then
    echo "$PEPPER_FILE already exists — leaving it alone." >&2
    echo "Delete it by hand if you really mean to start over (every stored hash" >&2
    echo "in $SESSIONS becomes invalid and must be regenerated)." >&2
    exit 1
  fi
  umask 077
  openssl rand -hex 32 > "$PEPPER_FILE"
  echo "Wrote $PEPPER_FILE (git-ignored, mode 600)."
  echo
  echo "Now give GitHub the same value, or the attendance bot cannot check codes:"
  echo
  echo "  gh secret set SESSION_PEPPER --repo PeeterLaas/MolEcoMeth < $PEPPER_FILE"
  echo
  echo "Keep a copy somewhere safe. Losing it means regenerating every hash."
  exit 0
fi

write=no
if [ "${1:-}" = "-w" ] || [ "${1:-}" = "--write" ]; then
  write=yes
  shift
fi

if [ $# -ne 2 ]; then
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 1
fi

session="$1"
code="$2"

# --- the pepper --------------------------------------------------------------
pepper="${SESSION_PEPPER:-}"
if [ -z "$pepper" ] && [ -r "$PEPPER_FILE" ]; then
  pepper=$(tr -d '[:space:]' < "$PEPPER_FILE")
fi
if [ -z "$pepper" ]; then
  echo "No pepper. Run './geneh.sh --init' once, or set SESSION_PEPPER." >&2
  exit 1
fi

# --- is that a real session? -------------------------------------------------
if ! cut -d, -f1 "$SESSIONS" | grep -qx "$session"; then
  echo "No session '$session' in $SESSIONS. Known ids:" >&2
  cut -d, -f1 "$SESSIONS" | tail -n +2 | paste -sd' ' >&2
  exit 1
fi

# The hash itself comes from tools/session_code.py, which shares its
# implementation with the bot that checks the submissions — one definition,
# so the two can never drift apart.
hash=$(SESSION_PEPPER="$pepper" python3 tools/session_code.py "$session" "$code")

if [ "$write" = no ]; then
  echo "$hash"
  exit 0
fi

python3 - "$SESSIONS" "$session" "$hash" <<'PY'
import csv, sys

path, session, digest = sys.argv[1:4]
with open(path, newline="", encoding="utf-8") as fh:
    rows = list(csv.DictReader(fh))
    fields = rows[0].keys()

for row in rows:
    if row["session_id"] == session:
        row["code_hash"] = digest
        row["open"] = "yes"
        print(f"{session}  {row['date']}  {row['topic']}  ->  open=yes")

with open(path, "w", newline="", encoding="utf-8") as fh:
    # lineterminator: csv writes CRLF by default, which would rewrite
    # every line of the file and turn a one-cell edit into a 16-line diff.
    w = csv.DictWriter(fh, fieldnames=list(fields), lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
PY

echo
echo "$SESSIONS updated. Announce the code in class, then publish it:"
echo
echo "  ./update.sh -n \"Open $session\""
