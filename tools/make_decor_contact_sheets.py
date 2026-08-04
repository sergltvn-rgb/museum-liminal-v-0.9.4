from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('shots/decor_audit/after')
VIEW = ROOT / 'view'
OUT = ROOT / 'sheets_small'
OUT.mkdir(parents=True, exist_ok=True)

GROUPS = {
    'overview': ('overview_',),
    'lobby': ('lobby_',),
    'atrium': ('atrium_',),
    'office': ('office_',),
    'storage': ('storage_',),
    'archive': ('archive_',),
    'lab': ('lab_',),
    'gravity': ('gravity_',),
    'time': ('time_',),
    'space': ('space_',),
    'mass': ('mass_',),
    'planetarium': ('planetarium_',),
    'imports': ('import_',),
    'service_lights': ('service_', 'light_'),
    'exterior': ('exterior_', 'drive_', 'grounds_'),
}

font = ImageFont.load_default()
all_files = sorted(VIEW.glob('*.jpg'))
used = set()
for group, prefixes in GROUPS.items():
    files = [p for p in all_files if p.stem.startswith(prefixes)]
    used.update(files)
    if not files:
        continue
    cols = 3
    tile_w, tile_h, label_h = 160, 90, 18
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * tile_w, rows * (tile_h + label_h)), '#17191b')
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(files):
        image = Image.open(path).convert('RGB')
        image.thumbnail((tile_w, tile_h), Image.Resampling.LANCZOS)
        x = (i % cols) * tile_w + (tile_w - image.width) // 2
        y0 = (i // cols) * (tile_h + label_h)
        y = y0 + (tile_h - image.height) // 2
        sheet.paste(image, (x, y))
        label = path.stem[:46]
        draw.rectangle((i % cols * tile_w, y0 + tile_h, (i % cols + 1) * tile_w, y0 + tile_h + label_h), fill='#24282c')
        draw.text((i % cols * tile_w + 4, y0 + tile_h + 3), label, fill='#f2f2f0', font=font)
    out = OUT / f'{group}_sheet.jpg'
    sheet.save(out, quality=45, optimize=True)
    print(f'{group}: {len(files)} -> {out}')

leftovers = [p.name for p in all_files if p not in used]
print(f'total={len(all_files)} grouped={len(used)} leftovers={len(leftovers)}')
for name in leftovers:
    print('LEFTOVER', name)
