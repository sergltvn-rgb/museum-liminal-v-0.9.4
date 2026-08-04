from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('shots/decor_audit/probes/view')
OUT = Path('shots/decor_audit/probes')
GROUPS = [
    [('lab_tray', ['lab_tray_a','lab_tray_b','lab_tray_c','lab_tray_d']),
     ('flashlight', ['flashlight_a','flashlight_b','flashlight_c','flashlight_d']),
     ('vents', ['vents_east','vents_west','vents_south','vents_north']),
     ('clock', ['clock_south','clock_north','clock_east','clock_west'])],
    [('hose', ['hose_east','hose_west','hose_south','hose_north']),
     ('player_car', ['player_car_ne','player_car_se','player_car_n','player_car_s']),
     ('exit', ['exit_south','exit_north','exit_east','exit_west']),
     ('emergency', ['emergency_south','emergency_north','emergency_east','emergency_west'])],
]
CELL_W, CELL_H, LABEL_H = 320, 180, 24
font = ImageFont.load_default()
for sheet_index, rows in enumerate(GROUPS, start=1):
    canvas = Image.new('RGB', (CELL_W * 4, (CELL_H + LABEL_H) * len(rows)), (15, 15, 15))
    draw = ImageDraw.Draw(canvas)
    for row_index, (_group, names) in enumerate(rows):
        y = row_index * (CELL_H + LABEL_H)
        for col, name in enumerate(names):
            image = Image.open(ROOT / f'{name}.jpg').convert('RGB')
            image.thumbnail((CELL_W, CELL_H), Image.Resampling.LANCZOS)
            x = col * CELL_W
            canvas.paste(image, (x + (CELL_W-image.width)//2, y + (CELL_H-image.height)//2))
            draw.text((x + 5, y + CELL_H + 5), name, fill=(245,245,245), font=font)
    path = OUT / f'probe_sheet_{sheet_index}.jpg'
    canvas.save(path, quality=90, optimize=True)
    print(path, path.stat().st_size)
