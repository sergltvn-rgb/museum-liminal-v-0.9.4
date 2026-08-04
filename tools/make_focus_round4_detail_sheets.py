from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path('shots/decor_audit/focus_round4/view')
OUT = Path('shots/decor_audit/focus_round4')
CELL_W, CELL_H = 640, 268
LABEL_H = 28
COLS = 2

groups = [
    ['lab_exhibit_sheet_v4', 'lab_exhibit_sheet_v4_east',
     'lab_exhibit_sheet_v4_west', 'lab_exhibit_sheet_v4_high'],
    ['player_car_medium', 'player_car_medium_wide', 'vents_oblique'],
]

for sheet_index, group in enumerate(groups, start=1):
    rows = (len(group) + COLS - 1) // COLS
    canvas = Image.new('RGB', (COLS * CELL_W, rows * (CELL_H + LABEL_H)), (8, 8, 8))
    draw = ImageDraw.Draw(canvas)
    for index, name in enumerate(group):
        path = ROOT / f'{name}.jpg'
        with Image.open(path) as source:
            frame = source.convert('RGB')
            if frame.size != (CELL_W, CELL_H):
                raise RuntimeError(f'{path}: expected {(CELL_W, CELL_H)}, got {frame.size}')
            x = (index % COLS) * CELL_W
            y = (index // COLS) * (CELL_H + LABEL_H)
            canvas.paste(frame, (x, y))
        draw.text((x + 8, y + CELL_H + 6), name, fill=(240, 240, 240))
    out_path = OUT / f'focus_round4_detail_{sheet_index}.jpg'
    canvas.save(out_path, quality=94, optimize=True, subsampling=0)
    print(f'{out_path}\t{out_path.stat().st_size}')
