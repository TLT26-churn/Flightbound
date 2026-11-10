"""Build a combat animation reel from the addon's actual exported draw trees.

Run: luajit tests/flightbound-ui.lua --combat-preview
Then: python tools/build_flightbound_combat.py
No live game or save is accessed. Pillow composites the real font and textures.
"""
from pathlib import Path
from functools import lru_cache
from array import array
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json, subprocess, wave, hashlib, sys

ROOT = Path(__file__).resolve().parents[1]
TMP = Path('/tmp/flightbound-combat-preview')
M = json.loads((TMP/'manifest.json').read_text())
OUT = ROOT/'showcase'/('Flightbound-'+M['version'])
OUT.mkdir(parents=True, exist_ok=True)
IMPACT = M.get('mode')=='impact'
FPS, DURATION = M['fps'], M['duration']
W, H = 1280, 720
ORDER = {'BACKGROUND': 0, 'BORDER': 1, 'ARTWORK': 2, 'OVERLAY': 3}
warnings = set()
ART = dict(zip(['wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul'],
               ['howl','tide','flame','tusk','venom','roots','star','claw','acid','firebolt','gust','frost']))

def local(path):
    return ROOT/path.replace('Interface\\AddOns\\', '').replace('\\', '/')

@lru_cache(maxsize=256)
def font(size, pixel=True):
    return ImageFont.truetype(str(ROOT/'Flightbound/Art/Silkscreen.ttf' if pixel else '/usr/share/fonts/noto/NotoSans-Regular.ttf'),size)

@lru_cache(maxsize=2048)
def asset(path,w,h,flip=False):
    im=Image.open(path).convert('RGBA')
    if flip:im=ImageOps.mirror(im)
    return im.resize((w,h),Image.Resampling.NEAREST)

@lru_cache(maxsize=4096)
def text_surface(text,path,size,w,h,color,align,scale):
    im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im);f=ImageFont.truetype(str(local(path)),size)
    lines=[]
    for para in text.split('\n'):
        line=''
        for word in para.split(' '):
            trial=(line+' '+word).strip()
            if f.getlength(trial)>w and line:lines.append(line);line=word
            else:line=trial
        lines.append(line)
    spacing=size+2*scale
    if text and (len(lines)-1)*spacing+size>h+2:warnings.add((text,w,h))
    for i,line in enumerate(lines):
        tw=f.getlength(line);x=(w-tw)/2 if align=='CENTER' else w-tw if align=='RIGHT' else 0
        d.text((x,i*spacing),line,font=f,fill=color,anchor='lt')
    return im

def render_ui(index):
    scene=json.loads((TMP/f'ui-{index:04d}.json').read_text());im=Image.new('RGBA',(scene['width'],scene['height']))
    for v in sorted(scene['items'],key=lambda v:(v['frameLevel'],ORDER[v['layer']],v.get('sublevel',0),v['id'])):
        x,y,w,h=[round(v[k]) for k in ('x','y','width','height')]
        if w<=0 or h<=0:continue
        if v['kind']=='Texture':
            tile=asset(str(local(v['file'])),w,h,v.get('coords',[0])[0]==1) if v.get('file') else Image.new('RGBA',(w,h),tuple(round(255*c) for c in v['color']))
        else:
            tile=text_surface(v.get('text',''),v['font'],v['fontSize'],w,h,tuple(round(255*c) for c in v['color']),v.get('align'),v.get('scale',1))
        if v.get('alpha',1)<1:
            tile=tile.copy();tile.putalpha(tile.getchannel('A').point(lambda a:round(a*v['alpha'])))
        im.alpha_composite(tile,(x,y))
    return im

@lru_cache(maxsize=9)
def backdrop(theme):
    im=asset(str(ROOT/'Flightbound/Art/Battles'/f'{theme}.tga'),1440,720).crop((80,0,1360,720)).copy()
    im.alpha_composite(Image.new('RGBA',(W,H),(8,16,22,230)))
    ImageDraw.Draw(im).line((632,48,632,672),fill='#314545',width=1)
    return im

def wrapped(d,text,y,size=30):
    f=font(size);line=''
    for word in text.upper().split():
        trial=(line+' '+word).strip()
        if line and f.getlength(trial)>550:
            d.text((52,y),line,font=f,fill='#f0efe3',anchor='lt');y+=size+10;line=word
        else:line=trial
    d.text((52,y),line,font=f,fill='#f0efe3',anchor='lt')
    return y+size+12

def frame(index):
    t=index/FPS;c=min(len(M['clips'])-1,int(t/M['clipDuration']));clip=M['clips'][c]
    im=backdrop(clip['theme']).copy();d=ImageDraw.Draw(im)
    d.text((52,54),'FLIGHTBOUND '+M['version'],font=font(17),fill='#e4bd74',anchor='lt')
    d.text((52,90),'DAMAGE & CRITS' if IMPACT else 'BATTLE ANIMATIONS',font=font(29),fill='#f0efe3',anchor='lt')
    d.line((52,142,586,142),fill='#45635a')
    d.text((52,177),clip['label'].upper(),font=font(19),fill='#a9cab4',anchor='lt')
    y=wrapped(d,clip['move'],225)
    desc=f"{clip['form']} · Level {clip['level']}"
    d.text((52,max(y+8,316)),desc,font=font(19,False),fill='#b7c4c3',anchor='lt')
    d.text((52,369),'YOUR MOVE  /  ENEMY RESPONSE',font=font(14),fill='#e4bd74',anchor='lt')
    art=clip.get('art') or (ART[clip['id']] if clip['action']=='special' else {'strike':'slash','guard':'shield','focus':'focus','salve':'heal'}[clip['action']])
    for i in range(4):
        x=52+i*136
        d.rectangle((x,414,x+116,530),fill=(20,36,39,200),outline='#334c47')
        im.alpha_composite(asset(str(ROOT/'Flightbound/Art/Combat'/f'{art}_{i+1}.tga'),108,108),(x+4,418))
        d.text((x+58,547),f'{i+1:02}',font=font(12),fill='#899e96',anchor='mt')
    d.text((52,598),'By Whitebeard Tinkerton - US PVP',font=font(16,False),fill='#91a49b',anchor='lt')
    d.text((52,634),'Staged crits / gameplay chance ~12% / 1.5x damage' if IMPACT else '12 lineages / evolved effects / utility moves',font=font(16,False),fill='#91a49b',anchor='lt')
    im.alpha_composite(render_ui(index),(672,48));d=ImageDraw.Draw(im)
    d.text((52,686),'RENDERED ADDON UI / ISOLATED DEMO SAVE',font=font(10),fill='#82978c',anchor='lt')
    for i in range(len(M['clips'])):
        x=674+i*29
        d.rectangle((x,686,x+23,689),fill='#e4bd74' if i==c else '#799684' if i<c else '#29383a')
    return im.convert('RGB')

def audio():
    rate=44100;count=round(DURATION*rate);mix=array('f',[0])*count;decoded={}
    for event in M['audio']:
        path=str(local(event['path']))
        if path not in decoded:
            raw=subprocess.check_output(['ffmpeg','-v','error','-i',path,'-f','f32le','-ac','1','-ar',str(rate),'-'])
            decoded[path]=array('f');decoded[path].frombytes(raw)
        samples=decoded[path];limit=len(samples)
        if 'stop' in event:limit=min(limit,max(0,round((event['stop']-event['time'])*rate)))
        begin=round(event['time']*rate)
        for i in range(min(limit,count-begin)):
            mix[begin+i]+=samples[i]*min(1,(limit-i)/(rate*.006))*.9
    peak=max(abs(x) for x in mix);assert peak<1,peak
    pcm=array('h',(round(x*32767) for x in mix))
    with wave.open(str(TMP/'mix.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm.tobytes())

def main():
    sheet=Image.new('RGB',(1280,((len(M['clips'])+3)//4)*202),'#081016')
    for c in range(len(M['clips'])):
        shot=frame(round((c*M['clipDuration']+.6)*FPS));thumb=shot.resize((320,180),Image.Resampling.LANCZOS)
        x,y=(c%4)*320,(c//4)*202;sheet.paste(thumb,(x,y))
        ImageDraw.Draw(sheet).text((x+6,y+184),M['clips'][c]['label'],font=font(11,False),fill='white')
    sheet.save(OUT/'combat-storyboard.jpg',quality=93)
    frame(round((2*M['clipDuration']+.6)*FPS)).save(OUT/'combat-poster.png')
    assert not warnings,warnings
    if '--preview-only' in sys.argv:return
    audio();path=OUT/('Flightbound-impact-feedback.mp4' if IMPACT else 'Flightbound-combat-animations.mp4')
    cmd=['ffmpeg','-y','-v','warning','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r',str(FPS),'-i','-',
         '-i',str(TMP/'mix.wav'),'-c:v','libx264','-preset','medium','-crf','20','-threads','4','-pix_fmt','yuv420p',
         '-c:a','aac','-b:a','96k','-ac','2','-ar','48000','-t',str(DURATION),'-movflags','+faststart',
         '-metadata','title=Flightbound — Battle Animations',
         '-metadata','artist=Whitebeard Tinkerton - US PVP',
         '-metadata','comment='+M['provenance'],str(path)]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    try:
        for i in range(round(DURATION*FPS)):
            proc.stdin.write(frame(i).tobytes())
            if i%(FPS*5)==0:print(f'Encoding {i/FPS:.0f}/{DURATION:.2f}s',flush=True)
        proc.stdin.close();assert proc.wait()==0
    except BaseException:
        proc.kill();proc.wait();raise
    assert not warnings,warnings
    info={**M,'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'resolution':[W,H],'liveGameControlled':False,'liveSaveReadOrEdited':False,'publishedExternally':False}
    (OUT/'combat-info.json').write_text(json.dumps(info,indent=2)+'\n')
    print('Saved',path,flush=True)

if __name__=='__main__':main()
