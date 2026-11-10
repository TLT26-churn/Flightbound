"""Render the actual addon draw trees into a captioned, shareable MP4 trailer.

Uses existing artwork and real UI animation exports, plus original synthesized
trailer music and the addon's sound events. No desktop/game capture required.
Run the Lua export first: luajit tests/flightbound-ui.lua --showcase
"""
from pathlib import Path
from functools import lru_cache
from PIL import Image, ImageDraw, ImageFont, ImageOps
from array import array
import json, math, subprocess, wave, sys, hashlib

ROOT = Path(__file__).resolve().parents[1]
TMP = Path('/tmp/flightbound-showcase')
OUT = ROOT / 'showcase/Flightbound-4.5.0'
OUT.mkdir(parents=True, exist_ok=True)
MANIFEST = json.loads((TMP/'manifest.json').read_text())
UI_FPS, DURATION, FPS = MANIFEST['fps'], MANIFEST['duration'], 30
W, H = 1280, 720
PIXEL = ROOT/'Flightbound/Art/Silkscreen.ttf'
SANS = Path('/usr/share/fonts/noto/NotoSans-Regular.ttf')
BOLD = Path('/usr/share/fonts/noto/NotoSans-Bold.ttf')
INK, MUTED, GOLD, MINT = '#f0efe3', '#b0babb', '#e4bd74', '#9fcca8'
LAYER = {'BACKGROUND': 0, 'BORDER': 1, 'ARTWORK': 2, 'OVERLAY': 3}
warnings = set()

def local(path):
    return ROOT/path.replace('Interface\\AddOns\\', '').replace('\\', '/')

@lru_cache(maxsize=256)
def font(size, kind='sans'):
    return ImageFont.truetype(str(PIXEL if kind=='pixel' else BOLD if kind=='bold' else SANS), size)

@lru_cache(maxsize=2048)
def asset(path, w, h, flip=False):
    im = Image.open(path).convert('RGBA')
    if flip: im = ImageOps.mirror(im)
    return im.resize((w, h), Image.Resampling.NEAREST)

@lru_cache(maxsize=4096)
def text_surface(text, path, size, w, h, color, align, scale):
    im = Image.new('RGBA', (w,h)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(str(local(path)), size)
    lines = []
    for para in text.split('\n'):
        line = ''
        for word in para.split(' '):
            trial = (line+' '+word).strip()
            if f.getlength(trial)>w and line: lines.append(line); line=word
            else: line=trial
        lines.append(line)
    spacing = size+2*scale
    if text and (len(lines)-1)*spacing+size>h+2: warnings.add((text,w,h))
    for j,line in enumerate(lines):
        tw=f.getlength(line);x=(w-tw)/2 if align=='CENTER' else w-tw if align=='RIGHT' else 0
        d.text((x,j*spacing),line,font=f,fill=color,anchor='lt')
    return im

def render_ui(index):
    scene=json.loads((TMP/f'ui-{index:04d}.json').read_text())
    im=Image.new('RGBA',(scene['width'],scene['height']))
    for v in sorted(scene['items'],key=lambda v:(v['frameLevel'],LAYER[v['layer']],v.get('sublevel',0),v['id'])):
        x,y,w,h=[round(v[k]) for k in ('x','y','width','height')]
        if w<=0 or h<=0:continue
        if v['kind']=='Texture':
            if v.get('file'):tile=asset(str(local(v['file'])),w,h,v.get('coords',[0])[0]==1)
            else:tile=Image.new('RGBA',(w,h),tuple(round(255*c) for c in v['color']))
        else:
            tile=text_surface(v.get('text',''),v['font'],v['fontSize'],w,h,
                tuple(round(255*c) for c in v['color']),v.get('align'),v.get('scale',1))
        alpha=v.get('alpha',1)
        if alpha<1:
            tile=tile.copy();tile.putalpha(tile.getchannel('A').point(lambda a:round(a*alpha)))
        im.alpha_composite(tile,(x,y))
    return im

# Editorial timing. All UI operations themselves come from the Lua demo save.
SECTIONS=[
 (0,4,'intro','A POCKET ADVENTURE','FLIGHTBOUND','Azeroth.\nPocket-sized.'),
 (4,9,'trainer','01 / CREATE','YOUR HERO.\nYOUR STORY.','Choose your race, class and gender.\nPick your first companion.'),
 (9,17,'explore','02 / EXPLORE','FIND YOUR\nOWN WAY.','Walk the dungeon yourself.\nFind treasure, keys and secrets.'),
 (17,25,'battle','03 / BATTLE','MAKE EVERY\nMOVE COUNT.','Named abilities. Type advantages.\nDefense with a cooldown.'),
 (25,32,'tame','04 / BEFRIEND','TAME A FRIEND.\nMAKE IT YOURS.','Weaken wild creatures.\nName your newest companion.'),
 (32,39,'evolve','05 / EVOLVE','SMALL STARTS.\nBIG EVOLUTIONS.','12 creature lineages.\nNew forms at levels 6 and 14.'),
 (39,49.5,'worlds','06 / ADVENTURE','EIGHT DUNGEONS.\nONE CAMPAIGN.','Restore the skyways,\none windstone at a time.'),
 (49.5,55,'outro','READY FOR TAKEOFF?','YOUR NEXT\nFLIGHT PATH\nSTARTS HERE.','Opens automatically in flight.\nPlay anytime with /fb.'),
]
THEMES=['elwynn','westfall','darkshore','ashenvale','ungoro','blackrock','winterspring','silithus']
ZONE_NAMES=['Goldshire Cellars','Westfall Mines','Drowned Ruins','Moonwell Hollow','Lost Crater Temple','Blackrock Warrens','Frostwing Hollow','The Silithid Nest']

def section(t):return next(s for s in SECTIONS if s[0]<=t<s[1])

@lru_cache(maxsize=9)
def backdrop(theme):
    im=asset(str(ROOT/'Flightbound/Art/Battles'/f'{theme}.tga'),1440,720).crop((80,0,1360,720)).copy()
    im.alpha_composite(Image.new('RGBA',(W,H),(7,14,20,226)))
    d=ImageDraw.Draw(im)
    # Quiet vertical rhythm and a frame around the actual addon, not fake UI.
    d.line((632,56,632,664),fill=(149,182,168,36),width=1)
    d.rectangle((680,56,1232,680),fill=(0,0,0,95))
    return im

def fit_font(text,size,max_width,kind='pixel'):
    while max(font(size,kind).getlength(line) for line in text.split('\n'))>max_width:size-=1
    return font(size,kind)

def block(d,xy,text,size=21,color=INK,kind='sans',gap=10,width=530):
    f=fit_font(text,size,width,kind);x,y=xy
    for line in text.split('\n'):
        d.text((x,y),line,font=f,fill=color,anchor='lt');y+=f.size+gap
    return y

def pill(d,x,y,text,width=None):
    f=font(14,'pixel');width=width or math.ceil(f.getlength(text))+28
    d.rounded_rectangle((x,y,x+width,y+34),radius=4,fill='#17272b',outline='#46645f',width=1)
    d.text((x+14,y+10),text,font=f,fill=MINT,anchor='lt')
    return width

def creature(im,name,x,y,size,t,phase=0):
    bob=round(3*math.sin(t*math.pi*2+phase))
    im.alpha_composite(asset(str(ROOT/'Flightbound/Art'/f'{name}.tga'),size,size),(x,y+bob))

last_index,last_ui=-1,None
def video_frame(t):
    global last_index,last_ui
    start,end,key,kicker,title,body=section(t)
    zone=min(7,1+int((t-39)/1.5)) if key=='worlds' else 3 if key=='outro' else 0
    im=backdrop(THEMES[zone]).copy();d=ImageDraw.Draw(im)
    d.text((56,39),'FLIGHTBOUND',font=font(19,'pixel'),fill=MINT,anchor='lt')
    d.text((56,69),'AN ADDON FOR WOW FOREVER',font=font(12,'pixel'),fill=MUTED,anchor='lt')
    # Slight caption arrival, with the game footage always legible.
    age=t-start;shift=round(9*max(0,1-age/.35)**2)
    y=161+shift
    d.rectangle((56,y-22,91,y-19),fill=GOLD)
    block(d,(56,y),kicker,14,GOLD,'pixel',width=548)
    y+=42
    title_size=52 if key=='intro' else 38 if key=='worlds' else 40
    y=block(d,(56,y),title,title_size,INK,'pixel',gap=13,width=552)+25
    y=block(d,(56,y),body,34 if key=='intro' else 21,MUTED,'sans',gap=9,width=546)
    if key=='intro':
        for i,(name,label) in enumerate([('wolf','WOLF'),('murloc','MURLOC'),('whelp','WHELP')]):
            creature(im,name,64+i*174,439,138,t,i)
            d.text((133+i*174,588),label,font=font(13,'pixel'),fill=MINT,anchor='mt')
        d.text((56,630),'EXPLORE  /  BATTLE  /  EVOLVE',font=font(15,'pixel'),fill=GOLD,anchor='lt')
    elif key=='trainer':
        for i,name in enumerate(['trainer_human_2','trainer_orc_1','trainer_nightelf_2']):creature(im,name,66+i*174,450,132,t,i)
        pill(d,56,606,'YOUR RACE. YOUR CLASS. YOUR NAME.')
    elif key=='explore':
        pill(d,56,470,'ARROWS: MOVE');pill(d,56,517,'SPACE: INTERACT')
        for i,name in enumerate(['key','chest','camp']):
            im.alpha_composite(asset(str(ROOT/'Flightbound/Art/Symbols'/f'{name}.tga'),60,60),(56+i*88,582))
    elif key=='battle':
        for i,label in enumerate(['1 STRIKE','2 SPECIAL','3 DEFENSE']):pill(d,56+i*176,479,label,163)
        pill(d,56,528,'4 BAG / TEAM    5 TAME    6 FOCUS',526)
        d.text((56,601),'KEYS ON. WINDOW FOCUSED. YOUR TURN.',font=font(13,'pixel'),fill=MUTED,anchor='lt')
    elif key=='tame':
        creature(im,'wolf',180,443,170,t)
        pill(d,168,625,'HELLO, NIBBLE!')
    elif key=='evolve':
        for i,(name,label) in enumerate([('whelp','START'),('whelp_2','LEVEL 6'),('whelp_3','LEVEL 14')]):
            creature(im,name,57+i*175,460,150,t,i)
            d.text((132+i*175,630),label,font=font(13,'pixel'),fill=GOLD,anchor='mt')
    elif key=='worlds':
        block(d,(56,461),ZONE_NAMES[zone].upper(),21,GOLD,'pixel',width=546)
        for i,name in enumerate(THEMES):
            x=56+(i%4)*137;y=517+(i//4)*65
            tile=asset(str(ROOT/'Flightbound/Art/Battles'/f'{name}.tga'),124,62)
            im.alpha_composite(tile,(x,y))
            if i==zone:d.rectangle((x-2,y-2,x+125,y+63),outline=GOLD,width=2)
    else:
        pill(d,56,555,'TYPE /FB TO OPEN',305)
        d.text((56,616),'WINDOWS + LINUX  /  v4.5.0',font=font(14,'pixel'),fill=MUTED,anchor='lt')
    index=min(DURATION*UI_FPS-1,int(t*UI_FPS))
    if index!=last_index:last_ui=render_ui(index);last_index=index
    im.alpha_composite(last_ui,(672,48))
    d=ImageDraw.Draw(im)
    for event in reversed(MANIFEST['markers']):
        age=t-event['time']
        if age<0:continue
        if age>.35:break
        if event['kind']=='move' and 17<=t<25:
            n={'strike':1,'special':2,'guard':3,'focus':6}.get(event['label'])
            if n and n<=3:
                x=672+16+(n-1)*132;y=48+558
                d.rectangle((x-2,y-2,x+125,y+37),outline=GOLD,width=2)
    # Persistent, unobtrusive provenance makes this honest as a headless demo.
    d.text((56,682),'v4.5.0 / RENDERED ADDON UI',font=font(10,'pixel'),fill='#81918e',anchor='lt')
    for i,s in enumerate(SECTIONS):
        x=674+i*69;completed=t>=s[1];current=s[0]<=t<s[1]
        d.rectangle((x,685,x+57,688),fill=GOLD if current else '#799684' if completed else '#29383a')
    # Clean opening and closing fades only; retain crisp pixel art in between.
    opacity=min(1,t/.45,(DURATION-t)/.8)
    if opacity<1:
        black=Image.new('RGBA',(W,H),(7,14,20,255));im=Image.blend(black,im,max(0,opacity))
    return im.convert('RGB')

def make_audio():
    rate=44100;count=round(DURATION*rate);mix=array('f',[0])*count
    def note(start,duration,midi,amp,shape='triangle'):
        begin=round(start*rate);length=round(duration*rate);hz=440*2**((midi-69)/12)
        for j in range(min(length,count-begin)):
            phase=j*hz/rate
            val=(1 if phase%1<.25 else -1/3) if shape=='pulse' else 4*abs((phase+.25)%1-.5)-1
            env=min(1,j/(rate*.006),(length-j)/(rate*.04))
            mix[begin+j]+=amp*val*env
    roots=[40,48,43,38];chords=[[64,67,71],[60,64,67],[62,67,71],[62,66,69]]
    melody=[[76,79,83,81,79,76,74,71],[76,79,84,83,79,76,72,74],
            [79,83,86,83,81,79,76,74],[78,81,86,84,81,78,74,71]]
    for bar in range(28):
        start=bar*2;ci=bar%4
        if start>=DURATION:break
        for beat in range(4):note(start+beat*.5,.43,roots[ci]+(12 if beat==2 else 0),.037)
        for step in range(8):
            note(start+step*.25,.18,chords[ci][step%3],.011,'pulse')
            if bar%4!=3 or step<6:note(start+step*.25,.20,melody[ci][step],.024,'pulse')
    # Short, original resolving cadence for the closing title.
    for i,pitch in enumerate([71,74,76,79,83,88]):note(51+i*.4,.32 if i<5 else 1.3,pitch,.033)
    for i in range(count):
        fade=min(1,i/(rate*.7),(count-i)/(rate*1.6));mix[i]*=max(0,fade)
    decoded={}
    for event in MANIFEST['audio']:
        path=str(local(event['path']))
        if path not in decoded:
            raw=subprocess.check_output(['ffmpeg','-v','error','-i',path,'-f','f32le','-ac','1','-ar',str(rate),'-'])
            decoded[path]=array('f');decoded[path].frombytes(raw)
        samples=decoded[path];limit=len(samples)
        if 'stop' in event:limit=min(limit,max(0,round((event['stop']-event['time'])*rate)))
        if limit<rate*.004:continue
        begin=round(event['time']*rate)
        for i in range(min(limit,count-begin)):
            fade=min(1,(limit-i)/(rate*.006));mix[begin+i]+=samples[i]*.9*fade
    peak=max(abs(x) for x in mix);assert peak<1,peak
    pcm=array('h',(round(max(-1,min(1,x))*32767) for x in mix))
    with wave.open(str(TMP/'mix.wav'),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(pcm.tobytes())
    print('Original soundtrack and',len(MANIFEST['audio']),'timed addon sound events mixed. Peak:',round(peak,3),flush=True)

def make_previews():
    moments=[1.7,5,10.8,13.8,19.5,21,27.8,30.8,34.6,37.3,40,41.2,44.2,46,48.5,52]
    sheet=Image.new('RGB',(1280,4*202),(7,14,20));d=ImageDraw.Draw(sheet)
    for i,t in enumerate(moments):
        frame=video_frame(t);thumb=frame.resize((320,180),Image.Resampling.LANCZOS)
        x=(i%4)*320;y=(i//4)*202;sheet.paste(thumb,(x,y))
        d.text((x+8,y+184),f'{t:04.1f}s  {section(t)[2]}',font=font(11),fill=INK)
    sheet.save(OUT/'storyboard.jpg',quality=93)
    video_frame(1.7).save(OUT/'Flightbound-poster.png')
    for t in [13.8,21,27.8,34.6,48.5,52]:video_frame(t).save(TMP/f'check-{t}.png')
    if warnings:raise RuntimeError('UI text overflow: '+repr(warnings))
    print('Poster and 16-shot storyboard rendered.',flush=True)

def make_video():
    path=OUT/'Flightbound-showcase.mp4'
    cmd=['ffmpeg','-y','-v','warning','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-',
        '-i',str(TMP/'mix.wav'),'-c:v','libx264','-preset','medium','-crf','21','-maxrate','1300k','-bufsize','2600k',
        '-threads','4','-pix_fmt','yuv420p','-profile:v','high','-level','3.1','-c:a','aac','-b:a','96k','-ac','2',
        '-af','loudnorm=I=-18:TP=-1.5:LRA=7','-ar','48000','-t',str(DURATION),'-movflags','+faststart',
        '-metadata','title=Flightbound — Azeroth Pocket Adventure',
        '-metadata','comment=Rendered from Flightbound 4.5.0 addon UI. Isolated demo saves. Original trailer music.',str(path)]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    try:
        for i in range(DURATION*FPS):
            proc.stdin.write(video_frame(i/FPS).tobytes())
            if i%(FPS*5)==0:print(f'Encoding {i//FPS:02d}/{DURATION}s',flush=True)
        proc.stdin.close();assert proc.wait()==0
    except BaseException:
        proc.kill();proc.wait();raise
    assert not warnings,warnings
    assert path.stat().st_size<10*1024*1024,'Share export exceeded 10 MiB'
    metadata={'title':'Flightbound — Azeroth Pocket Adventure','addonVersion':MANIFEST['version'],
        'durationSeconds':DURATION,'resolution':[W,H],'fps':FPS,'file':path.name,'bytes':path.stat().st_size,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'provenance':MANIFEST['provenance'],
        'music':'Original synthesized chiptune composed for this trailer; not an in-game music feature.',
        'soundEffects':'Flightbound bundled original Ogg sounds, timed from real addon audio calls.',
        'sections':[{'start':s[0],'end':s[1],'id':s[2],'title':s[4]} for s in SECTIONS],
        'liveGameControlled':False,'liveSaveReadOrEdited':False,'publishedExternally':False}
    (OUT/'showcase-info.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print('Finished:',path,round(path.stat().st_size/1024/1024,2),'MiB',flush=True)

if __name__=='__main__':
    make_previews()
    if '--preview-only' not in sys.argv:
        make_audio();make_video()
