"""Reject signatures that macOS App Intents cannot identify by signing team."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
configuration = os.environ.get("CONFIGURATION", "Release")
app = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    root / ".build/xcode/Build/Products" / configuration / "Default Browser.app"
)
verification = subprocess.run(
    ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
    capture_output=True, text=True,
)
if verification.returncode:
    raise SystemExit(f"Invalid app signature: {verification.stderr.strip()}")
details = subprocess.run(
    ["/usr/bin/codesign", "--display", "--verbose=2", str(app)],
    capture_output=True, text=True, check=True,
).stderr
match = re.search(r"^TeamIdentifier=(.+)$", details, re.MULTILINE)
team = match.group(1) if match else None
if not team or team == "not set" or "Signature=adhoc" in details:
    raise SystemExit(
        "This app has no certificate-backed Team ID. Shortcuts can discover its "
        "actions but macOS will reject the connection. In Xcode, select your "
        "development team and the Apple Development signing certificate, then rebuild. "
        "Do not use 'Sign to Run Locally'."
    )
expected = os.environ.get("DEVELOPMENT_TEAM")
if expected and team != expected:
    raise SystemExit(f"Wrong signing team: expected {expected}, found {team}.")
print(f"Verified app signature with Team ID {team}.")
