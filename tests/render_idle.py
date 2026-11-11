"""Render actual addon draw calls/assets. WoW's native Friz font uses a local
serif substitute for headless previews; the installed addon uses the game font."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageChops
import json,sys
ROOT=Path(__file__).resolve().parents[1]
order={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3}
warnings=[]
def local(path):
    if path == 'Fonts\\FRIZQT__.TTF':
        return next(Path('/usr/share/fonts').rglob('DejaVuSerif.ttf'))
    return ROOT/Path(path.replace('Interface\\AddOns\\','').replace('\\','/'))
def render(name,tie_order='forward',save=True):
    scene=json.loads(Path('/tmp/flightbound-idle-'+name+'.json').read_text())
    im=Image.new('RGBA',(scene['width'],scene['height']))
    def draw_key(item):
        tie=item['id'] if tie_order=='forward' else -item['id'] if tie_order=='reverse' else (item['id']*7919)%104729
        return item['frameLevel'],order[item['layer']],item.get('sublevel',0),tie
    for item in sorted(scene['items'],key=draw_key):
        x,y=round(item['x']),round(item['y'])
        # Shared edges round to the same pixel, including nine-slice borders
        # positioned at half-pixels by a scaled WoW frame.
        w,h=round(item['x']+item['width'])-x,round(item['y']+item['height'])-y
        if w<=0 or h<=0: continue
        alpha=item.get('alpha',1)
        if item['kind']=='Texture':
            if item.get('file'):
                t=Image.open(local(item['file'])).convert('RGBA')
                coords=item.get('coords')
                if coords:
                    l,r,top,bottom=coords
                    if l>r:t=ImageOps.mirror(t);l,r=1-l,1-r
                    t=t.crop((round(l*t.width),round(top*t.height),round(r*t.width),round(bottom*t.height)))
                t=t.resize((w,h),Image.Resampling.NEAREST)
            else:
                t=Image.new('RGBA',(w,h),tuple(round(255*c) for c in item['color']))
        else:
            t=Image.new('RGBA',(w,h));d=ImageDraw.Draw(t)
            font=ImageFont.truetype(str(local(item['font'])),item['fontSize'])
            fill=tuple(round(255*c) for c in item['color'])
            lines=[]
            for para in item.get('text','').split('\n'):
                line=''
                for word in para.split(' '):
                    trial=(line+' '+word).strip()
                    if font.getlength(trial)>w and line:lines.append(line);line=word
                    else:line=trial
                lines.append(line)
            spacing=item['fontSize']+2*item.get('scale',1)
            if (len(lines)-1)*spacing+item['fontSize']>h+2 and item.get('text'):
                warnings.append((name,item['text'],w,h,len(lines)))
            for j,line in enumerate(lines):
                tw=font.getlength(line);align=item.get('align')
                tx=(w-tw)/2 if align=='CENTER' else w-tw if align=='RIGHT' else 0
                d.text((tx,j*spacing),line,font=font,fill=fill,anchor='lt')
        if alpha<1:t.putalpha(t.getchannel('A').point(lambda a:round(a*alpha)))
        im.alpha_composite(t,(x,y))
    if save:im.save('/tmp/flightbound-idle-'+name+'.png')
    return im

names=['start','click-impact','first-companion','welcome-back','first-boss','adventure','crew','world','loot','crew-page2']+['world-'+str(i) for i in range(1,10)]+['boss-'+str(i) for i in range(1,10)]
for name in names:
    shot=render(name)
    # Static composition checks skip ephemeral particles; animation is verified separately.
    if name=='start':
        for variant in ('reverse','shuffled'):
            assert not ImageChops.difference(shot,render(name,variant,False)).convert('RGB').getbbox(), name
frames=[render('anim-%03d'%i).convert('RGB') for i in range(1,91)]
assert any(ImageChops.difference(frames[0],f).getbbox() for f in frames[1:]), 'Animation must actually move'
frames[0].save('/tmp/flightbound-idle-animation.gif',save_all=True,append_images=frames[1:],duration=67,loop=0)
for warning in warnings: print('TEXT OVERFLOW:',warning)
print('Rendered',len(names),'screens and',len(frames),'animation frames;',len(warnings),'overflow warnings.')
raise SystemExit(bool(warnings))
