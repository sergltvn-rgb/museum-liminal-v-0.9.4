from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('shots/decor_audit/after/sheets_small')
OUT = Path('shots/decor_audit/after/final_review')
OUT.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.load_default()
GROUPS = [
    ['overview', 'lobby', 'atrium'],
    ['office', 'storage', 'archive'],
    ['lab', 'gravity', 'time'],
    ['space', 'mass', 'planetarium'],
    ['imports', 'service_lights', 'exterior'],
]
LABEL_H = 24
for index, names in enumerate(GROUPS, 1):
    opened = []
    for name in names:
        path = ROOT / f'{name}_sheet.jpg'
        image = Image.open(path).convert('RGB')
        opened.append((name, image))
    width = max(image.width for _, image in opened)
    height = sum(LABEL_H + image.height for _, image in opened)
    canvas = Image.new('RGB', (width, height), '#090a0b')
    draw = ImageDraw.Draw(canvas)
    y = 0
    for name, image in opened:
        draw.rectangle((0, y, width, y + LABEL_H), fill='#111417')
        draw.text((6, y + 6), f'FINAL CONTACT: {name}', fill='#ffffff', font=FONT)
        y += LABEL_H
        canvas.paste(image, ((width - image.width) // 2, y))
        y += image.height
        image.close()
    out = OUT / f'final_contact_review_{index}.jpg'
    canvas.save(out, quality=88, optimize=True, subsampling=0)
    print(f'{out}\t{canvas.size}\t{out.stat().st_size}')
