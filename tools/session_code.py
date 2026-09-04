#!/usr/bin/env python3
"""Make the hash to paste into data/sessions.csv for a session code.

    SESSION_PEPPER=<the Actions secret> python3 tools/session_code.py w03 amplicon

Prints the value for that session's `code_hash` column. The code itself is
announced in class and never written down in the repository.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from issue_form import code_hash

if len(sys.argv) != 3:
    sys.exit(__doc__)

pepper = os.environ.get("SESSION_PEPPER")
if not pepper:
    sys.exit("Set SESSION_PEPPER to the same value as the repository secret.")

print(code_hash(sys.argv[1], sys.argv[2], pepper))
