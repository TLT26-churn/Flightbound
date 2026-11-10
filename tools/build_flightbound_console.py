"""Build console chrome/portraits from bundled UI slices and existing sprites.

All outputs use power-of-two TGA dimensions for WoW client compatibility.
Console.lua crops the transparent padding with texture coordinates.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'Flightbound' / 'Art'
OUT = ROOT / 'Console'
OUT.mkdir(exist_ok=True)

def save(image, name):
    width, height = (1 << (n - 1).bit_length() for n in image.size)
    padded = Image.new('RGBA', (width, height))
    padded.alpha_composite(image, (0, 0))
    padded.save(OUT / (name + '.tga'))

for name in ('wow_button', 'wow_button_down'):
    save(Image.open(OUT / (name + '.tga')).convert('RGBA').crop((0, 0, 80, 22)), name)

edge = Image.open(OUT / 'wow_border.tga').convert('RGBA')
frame = Image.new('RGBA', (588, 650))
for index, x, y in ((4,0,0),(5,556,0),(6,0,618),(7,556,618)):
    frame.alpha_composite(edge.crop((index*32,0,(index+1)*32,32)), (x,y))
for index, x in ((0,0),(1,556)):
    tile=edge.crop((index*32,0,(index+1)*32,32))
    for y in range(32,618,32):
        frame.alpha_composite(tile.crop((0,0,32,min(32,618-y))), (x,y))
for index,y in ((2,0),(3,618)):
    tile=edge.crop((index*32,0,(index+1)*32,32)).rotate(-90)
    for x in range(32,556,32):
        frame.alpha_composite(tile.crop((0,0,min(32,556-x),32)), (x,y))
save(frame, 'frame')

species={'wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul'}
for path in ROOT.glob('*.tga'):
    if not (path.stem.startswith('trainer_') or path.stem.split('_')[0] in species):
        continue
    sprite=Image.open(path).convert('RGBA')
    sprite=sprite.crop(sprite.getbbox())
    scale=max(40/sprite.width,40/sprite.height)
    sprite=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)), Image.Resampling.NEAREST)
    portrait=Image.new('RGBA',(44,44))
    draw=ImageDraw.Draw(portrait)
    for bounds,color in (((0,0,43,43),'#080909'),((1,1,42,42),'#b8954a'),((3,3,40,40),'#1d2922')):
        draw.ellipse(bounds,fill=color)
    crop=Image.new('RGBA',(38,38))
    crop.alpha_composite(sprite,((38-sprite.width)//2,(38-sprite.height)//3))
    mask=Image.new('L',(38,38))
    ImageDraw.Draw(mask).ellipse((0,0,37,37),fill=255)
    portrait.paste(crop,(3,3),mask)
    save(portrait,path.stem+'_portrait')

for path in OUT.glob('*.tga'):
    with Image.open(path) as im:
        assert all(n > 0 and not n & (n-1) for n in im.size), path
print('Console assets built; all TGA dimensions are powers of two.')
