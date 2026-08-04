from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path('shots/decor_audit/after')
VIEW = ROOT / 'view'
TILES = ROOT / 'tiles'
OUT = ROOT / 'review'
OUT.mkdir(parents=True, exist_ok=True)

VIEW_W, VIEW_H = 640, 268
LABEL_H = 28
COLS = 2
remaining = [
    'overview_archive', 'overview_mass', 'overview_restoration', 'archive_catalogue',
    'mass_buckled_deck', 'mass_gallery_wall', 'import_street_lamp', 'import_benches',
    'import_dumpsters', 'exterior_lamp', 'exterior_parked_car', 'exterior_service_entrance',
]

for sheet_index in range(3):
    group = remaining[sheet_index * 4:(sheet_index + 1) * 4]
    canvas = Image.new('RGB', (COLS * VIEW_W, 2 * (VIEW_H + LABEL_H)), (8, 8, 8))
    draw = ImageDraw.Draw(canvas)
    for index, name in enumerate(group):
        path = VIEW / f'{name}.jpg'
        with Image.open(path) as source:
            frame = source.convert('RGB')
            if frame.size != (VIEW_W, VIEW_H):
                raise RuntimeError(f'{path}: expected {(VIEW_W, VIEW_H)}, got {frame.size}')
            x = (index % COLS) * VIEW_W
            y = (index // COLS) * (VIEW_H + LABEL_H)
            canvas.paste(frame, (x, y))
        draw.text((x + 8, y + VIEW_H + 6), name, fill=(240, 240, 240))
    out_path = OUT / f'remaining_after_detail_{sheet_index + 1}.jpg'
    canvas.save(out_path, quality=92, optimize=True, subsampling=0)
    print(f'{out_path}\t{out_path.stat().st_size}')

TILE_W, TILE_H = 640, 268
for name in ['archive_stacks_west', 'archive_stacks_east']:
    canvas = Image.new('RGB', (2 * TILE_W, 2 * TILE_H + LABEL_H), (8, 8, 8))
    draw = ImageDraw.Draw(canvas)
    for row in range(2):
        for col in range(2):
            path = TILES / f'{name}_r{row}c{col}.jpg'
            with Image.open(path) as source:
                tile = source.convert('RGB')
                if tile.size != (TILE_W, TILE_H):
                    raise RuntimeError(f'{path}: expected {(TILE_W, TILE_H)}, got {tile.size}')
                canvas.paste(tile, (col * TILE_W, row * TILE_H))
    draw.text((8, 2 * TILE_H + 6), f'{name} — native 2x2 tiles', fill=(240, 240, 240))
    out_path = OUT / f'{name}_tiles.jpg'
    canvas.save(out_path, quality=82, optimize=True, subsampling=2)
    print(f'{out_path}\t{out_path.stat().st_size}')
