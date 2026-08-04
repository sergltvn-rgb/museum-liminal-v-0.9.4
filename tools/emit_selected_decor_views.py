from __future__ import annotations

import base64
import json
from pathlib import Path

NAMES = [
    "overview_archive", "overview_mass", "overview_restoration", "overview_parking",
    "archive_stacks_west", "archive_stacks_east", "archive_catalogue",
    "lab_exhibit_sheet", "lab_covered_west", "lab_covered_east", "lab_tool_tray",
    "mass_load_frame", "mass_gallery_wall", "mass_buckled_deck",
    "import_flashlight", "import_vents", "import_wall_clock", "import_street_lamp",
    "import_benches", "import_dumpsters",
    "service_hose_reel", "service_ceiling_hatch", "service_wall_vent",
    "light_emergency", "service_exit_sign",
    "exterior_lamp", "exterior_player_car", "exterior_parked_car",
    "exterior_service_entrance", "grounds_bench",
]
root = Path("shots/decor_audit/after/view")
payload = {}
missing = []
for name in NAMES:
    path = root / f"{name}.jpg"
    if not path.exists():
        missing.append(name)
        continue
    payload[path.name] = base64.b64encode(path.read_bytes()).decode("ascii")
encoded = json.dumps(payload, separators=(",", ":"))
print(encoded)
if missing:
    print("---MISSING---", ",".join(missing))
