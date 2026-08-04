from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path('shots/decor_audit/focus_round3/view')
OUT = Path('shots/decor_audit/focus_round3')
TILE_W, TILE_H = 300, 169
LABEL_H = 24
COLS = 3

names = [
    'lab_exhibit_sheet_v3', 'lab_exhibit_sheet_v3_east',
    'lab_covered_west_v3', 'lab_covered_east_v3',
    'tray_final', 'flashlight_final', 'vents_final', 'clock_final', 'hose_final',
    'player_car_final', 'player_car_final_wide',
    'exit_final', 'exit_final_oblique',
    'emergency_final', 'emergency_final_oblique',
    'atrium_north_fittings', 'atrium_east_fittings', 'east_exit_final',
]

groups = [names[:9], names[9:]]
for sheet_index, group in enumerate(groups, start=1):
    rows = (len(group) + COLS - 1) // COLS
    canvas = Image.new('RGB', (COLS * TILE_W, rows * (TILE_H + LABEL_H)), (8, 8, 8))
    draw = ImageDraw.Draw(canvas)
    for index, name in enumerate(group):
        path = ROOT / f'{name}.jpg'
        with Image.open(path) as source:
            tile = source.convert('RGB').resize((TILE_W, TILE_H), Image.Resampling.LANCZOS)
        x = (index % COLS) * TILE_W
        y = (index // COLS) * (TILE_H + LABEL_H)
        canvas.paste(tile, (x, y))
        draw.text((x + 6, y + TILE_H + 5), name, fill=(235, 235, 235))
    out_path = OUT / f'focus_round3_sheet_{sheet_index}.jpg'
    canvas.save(out_path, quality=90, optimize=True)
    print(f'{out_path}\t{out_path.stat().st_size}')
