"""Render the addon draw tree using its actual pixel font and sprite assets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageChops
import json,sys
ROOT=Path(__file__).resolve().parents[1]
order={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3}
warnings=[]
def local(path):
    return ROOT/Path(path.replace('Interface\\AddOns\\','').replace('\\','/'))
def render(name,tie_order='forward',save=True):
    scene=json.loads(Path('/tmp/flightbound-'+name+'.json').read_text())
    im=Image.new('RGBA',(scene['width'],scene['height']))
    def draw_key(item):
        tie=item['id'] if tie_order=='forward' else -item['id'] if tie_order=='reverse' else (item['id']*7919)%104729
        return item['frameLevel'],order[item['layer']],item.get('sublevel',0),tie
    for item in sorted(scene['items'],key=draw_key):
        x,y,w,h=[round(item[k]) for k in ('x','y','width','height')]
        if w<=0 or h<=0: continue
        alpha=item.get('alpha',1)
        if item['kind']=='Texture':
            if item.get('file'):
                t=Image.open(local(item['file'])).convert('RGBA')
                if item.get('coords',[0])[0]==1:t=ImageOps.mirror(t)
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
    if save:im.save('/tmp/flightbound-'+name+'.png')
    return im
names=['creator','starter','entrance','dungeon','corridor','battle','cleared-path','team','rename','team-long-name','journal','help','menu','shop','awards','story','citadel','arena','settings','ending','dungeons','evolution-2','evolution-3','battle-evolved','locked-door','unlocked-door']
names += ['trainer-%d-%d'%(i,g) for i in range(1,11) for g in (1,2)]
names += ['forms-'+id for id in ['wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul']]
names += [prefix+str(z) for z in range(1,9) for prefix in ('entrance-','map-','chart-','complete-')]
names += ['zoom-32','zoom-48','map-edge-3','map-edge-4']
names += ['keys-active','keys-ready','keys-combat','keys-typing','keys-held','keys-menu']
names += ['tame-name','tame-name-long']
names += [prefix+str(z) for z in range(1,9) for prefix in ('theme-objects-','theme-looted-')]
names += ['plate-detail','plate-spent']
names += ['moves-'+id+'-'+str(tier) for id in ['wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul'] for tier in (1,2,3)]
names += ['battle-cooldowns','battle-bag','battle-defense']
names += [prefix+str(z) for z in range(1,9) for prefix in ('battle-theme-','battle-theme-win-')]
names += ['battle-theme-finale','battle-theme-arena','battle-theme-lowhp','battle-theme-help','battle-theme-return']
names += ['fx-'+id+'-'+str(tier) for id in ['wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul'] for tier in (1,2,3)]
names += ['fx-enemy-'+id for id in ['wolf','murloc','whelp','boar','spider','treant','wisp','raptor','ooze','imp','harpy','ghoul']]
names += ['fx-'+state for state in ['strike','guard','focus','salve','knockout','burn','faint']]
names += ['battle-result-keys']
names += ['fx-critical-'+state for state in ['player','enemy','linger','ko','blocked']]
names += ['social-'+state for state in ['unavailable','club','club-page2','board-all','board-guild','board-friends','board-empty','team','team-page2','invite','duel-start','duel-impact','duel-waiting','duel-swap','duel-options','duel-result','duel-reconnecting','duel-disconnected','sync-off']]
sheet=Image.new('RGBA',(4*380,((len(names)+3)//4)*468),(20,25,29,255))
for i,name in enumerate(names):
    shot=render(name);x,y=(i%4)*380+10,(i//4)*468+24
    thumb=shot.resize((360,round(shot.height*360/shot.width)),Image.Resampling.NEAREST)
    sheet.alpha_composite(thumb,(x,y));ImageDraw.Draw(sheet).text((x,y-18),name,fill='white')
    if '--check-layer-order' in sys.argv:
        for variant in ('reverse','shuffled'):
            alternate=render(name,variant,False)
            if ImageChops.difference(shot,alternate).convert('RGB').getbbox():
                alternate.save('/tmp/flightbound-'+name+'-'+variant+'.png')
                raise AssertionError(name+': appearance depends on unspecified equal-priority drawing order ('+variant+')')
sheet.save('/tmp/flightbound-preview.png')
if '--animation' in sys.argv:
    frames=[render('anim-%02d'%i).convert('RGB') for i in range(1,61)]
    frames[0].save('/tmp/flightbound-animation.gif',save_all=True,append_images=frames[1:],duration=83,loop=0)
for warning in warnings:print('TEXT OVERFLOW:',warning)
print('Rendered',len(names),'screens;',len(warnings),'text overflow warnings.')
raise SystemExit(bool(warnings))
