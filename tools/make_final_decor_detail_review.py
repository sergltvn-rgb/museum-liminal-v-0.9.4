from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('shots/decor_audit/after')
VIEW = ROOT / 'view'
TILES = ROOT / 'tiles'
OUT = ROOT / 'final_detail_review'
OUT.mkdir(parents=True, exist_ok=True)

NAMES = [
    'overview_archive', 'overview_mass', 'overview_restoration', 'overview_parking',
    'archive_stacks_west', 'archive_stacks_east', 'archive_catalogue',
    'lab_exhibit_sheet', 'lab_covered_west', 'lab_covered_east', 'lab_tool_tray',
    'mass_load_frame', 'mass_gallery_wall', 'mass_buckled_deck',
    'import_flashlight', 'import_vents', 'import_wall_clock', 'import_street_lamp',
    'import_benches', 'import_dumpsters',
    'service_hose_reel', 'service_ceiling_hatch', 'service_wall_vent',
    'light_emergency', 'service_exit_sign',
    'exterior_lamp', 'exterior_player_car', 'exterior_parked_car',
    'exterior_service_entrance', 'grounds_bench',
]

CELL_W, CELL_H = 640, 268
LABEL_H = 24
COLS, ROWS = 2, 2
FONT = ImageFont.load_default()

for sheet_index, offset in enumerate(range(0, len(NAMES), COLS * ROWS), 1):
    names = NAMES[offset:offset + COLS * ROWS]
    canvas = Image.new('RGB', (COLS * CELL_W, ROWS * (CELL_H + LABEL_H)), '#080a0c')
    draw = ImageDraw.Draw(canvas)
    for cell, name in enumerate(names):
        path = VIEW / f'{name}.jpg'
        frame = Image.open(path).convert('RGB')
        if frame.size != (CELL_W, CELL_H):
            raise RuntimeError(f'{path}: expected {(CELL_W, CELL_H)}, got {frame.size}')
        x = (cell % COLS) * CELL_W
        y = (cell // COLS) * (CELL_H + LABEL_H)
        canvas.paste(frame, (x, y))
        draw.rectangle((x, y + CELL_H, x + CELL_W, y + CELL_H + LABEL_H), fill='#111417')
        draw.text((x + 6, y + CELL_H + 6), name, fill='#ffffff', font=FONT)
        frame.close()
    out = OUT / f'final_detail_review_{sheet_index}.jpg'
    canvas.save(out, quality=90, optimize=True, subsampling=0)
    print(f'{out}\t{canvas.size}\t{out.stat().st_size}')

for name in ['lab_exhibit_sheet', 'lab_covered_west', 'lab_covered_east']:
    canvas = Image.new('RGB', (CELL_W * 2, CELL_H * 2), '#080a0c')
    for row in range(2):
        for col in range(2):
            path = TILES / f'{name}_r{row}c{col}.jpg'
            frame = Image.open(path).convert('RGB')
            if frame.size != (CELL_W, CELL_H):
                raise RuntimeError(f'{path}: expected {(CELL_W, CELL_H)}, got {frame.size}')
            canvas.paste(frame, (col * CELL_W, row * CELL_H))
            frame.close()
    out = OUT / f'{name}_tiles.jpg'
    canvas.save(out, quality=92, optimize=True, subsampling=0)
    print(f'{out}\t{canvas.size}\t{out.stat().st_size}')
