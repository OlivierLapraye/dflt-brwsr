"""Check Xcode's actual output, so a build without exported actions fails CI."""
import json
from pathlib import Path
import os

root = Path(__file__).resolve().parents[1]
configuration = os.environ.get("CONFIGURATION", "Release")
metadata = (
    Path(os.environ.get("DERIVED_DATA_PATH", root / ".build/xcode")) / "Build/Products" / configuration
    / "Default Browser.app/Contents/Resources/Metadata.appintents/extract.actionsdata"
)
data = json.loads(metadata.read_text())
expected = {
    "SetDefaultBrowserIntent", "GetDefaultBrowserIntent", "ListInstalledBrowsersIntent"
}
actual = set(data["actions"])
missing = expected - actual
if missing:
    raise SystemExit(f"Missing Shortcuts actions: {sorted(missing)}")
for identifier in expected:
    action = data["actions"][identifier]
    if not action["isDiscoverable"] or action["openAppWhenRun"]:
        raise SystemExit(f"Action must be discoverable and run in the background: {identifier}")
shortcuts = {shortcut["actionIdentifier"] for shortcut in data["autoShortcuts"]}
if not expected <= shortcuts:
    raise SystemExit("App Shortcuts provider did not export all three actions.")
entity = data["entities"]["BrowserEntity"]
if not entity.get("defaultQueryIdentifier"):
    raise SystemExit("Browser picker has no dynamic entity query.")
print(f"Verified {len(expected)} exported Shortcuts actions.")
