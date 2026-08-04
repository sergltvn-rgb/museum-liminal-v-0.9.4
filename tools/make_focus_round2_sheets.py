from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path('shots/decor_audit/focus_round2/view')
OUT = Path('shots/decor_audit/focus_round2')
TILE_W, TILE_H = 300, 169
LABEL_H = 24
COLS = 4

names = [
    'lab_exhibit_sheet_v2', 'lab_covered_west_v2', 'lab_covered_east_v2',
    'tray_close_south', 'tray_close_east', 'tray_close_oblique', 'tray_near_overhead',
    'flashlight_close_south', 'flashlight_close_east', 'flashlight_close_oblique',
    'flashlight_close_west', 'vents_validated', 'clock_validated', 'hose_validated',
    'player_car_ne_wide', 'player_car_east', 'player_car_north',
    'exit_exact_close', 'exit_shift_east', 'exit_shift_west', 'exit_oblique',
    'emergency_exact_close', 'emergency_shift_west', 'emergency_shift_east',
    'emergency_oblique',
]

groups = [names[:14], names[14:]]
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
    out_path = OUT / f'focus_round2_sheet_{sheet_index}.jpg'
    canvas.save(out_path, quality=90, optimize=True)
    print(f'{out_path}\t{out_path.stat().st_size}')
