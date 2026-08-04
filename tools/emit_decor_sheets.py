from pathlib import Path
import base64
import json

root = Path('shots/decor_audit/after/sheets_small')
payload = {
    path.name: base64.b64encode(path.read_bytes()).decode('ascii')
    for path in sorted(root.glob('*.jpg'))
}
encoded = json.dumps(payload, separators=(',', ':'))
print(encoded)
