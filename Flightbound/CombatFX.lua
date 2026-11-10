local _,F=...
local G,U=F.Game,F.UI
local clamp=G.Clamp
local defs={
 wolf={art="howl",style="pulse"},murloc={art="tide",style="shot"},whelp={art="flame",style="shot"},
 boar={art="tusk",style="melee"},spider={art="venom",style="shot"},treant={art="roots",style="ground"},
 wisp={art="star",style="shot"},raptor={art="claw",style="melee"},ooze={art="acid",style="shot"},
 imp={art="firebolt",style="shot"},harpy={art="gust",style="shot"},ghoul={art="frost",style="ground"},
}
U.combatEffects=defs
local centers={player={64,150},enemy={264,80}}
local function impactTime(hit) return hit.source=="player" and .22 or hit.source=="enemy" and .72 or .86 end
function U.CurrentBattle() return U.duelView or G.db.battle end
function U.CurrentPet(role)
 if U.duelView then return U.duelView[role] end
 return role=="player" and G.Active() or G.db.battle.enemy
end
function U.BuildCombatFX()
 U.fxSprites={};U.fxNumbers={};U.fxNumberShadows={};U.fxCaptions={};U.fxCaptionShadows={}
 U.damagePops={};U.fxSparks={};U.hpChips={}
 for i=1,6 do
  local t=U.canvas:CreateTexture(nil,"ARTWORK",nil,i);t.fxPath="";t:Hide();U.fxSprites[i]=t
 end
 for i=1,6 do
  for n,pool in ipairs({U.fxNumberShadows,U.fxNumbers,U.fxCaptionShadows,U.fxCaptions}) do
   local t=U.canvas:CreateFontString(nil,"OVERLAY");t:SetDrawLayer("OVERLAY",n%2==0 and 5 or 4)
   t:SetFont(F.path.."Art\\Silkscreen.ttf",14,"");t.popFont=14
   t:SetSize(112,38);t:SetJustifyH("CENTER");t:SetJustifyV("TOP");t:Hide();pool[i]=t
  end
 end
 for i=1,8 do
  local t=U.canvas:CreateTexture(nil,"ARTWORK",nil,7);t:SetColorTexture(1,.77,.24,1);t:Hide();U.fxSparks[i]=t
 end
 for _,role in ipairs({"player","enemy"}) do
  local t=U.canvas:CreateTexture(nil,"OVERLAY",nil,1);t:Hide();U.hpChips[role]=t
 end
end
function U.HideCombatFX()
 for _,t in ipairs(U.fxSprites or {}) do t:Hide() end
 for _,pool in ipairs({U.fxNumbers or {},U.fxNumberShadows or {},U.fxCaptions or {},U.fxCaptionShadows or {},U.fxSparks or {}}) do
  for _,t in ipairs(pool) do t:Hide() end
 end
 for _,t in pairs(U.hpChips or {}) do t:Hide() end
end
function U.ClearDamagePops()
 for i in pairs(U.damagePops or {}) do U.damagePops[i]=nil end
end
function U.TickDamagePops(dt)
 for i,p in pairs(U.damagePops or {}) do
  p.age=p.age+dt
  if p.age>=p.duration or p.battle~=U.CurrentBattle() then U.damagePops[i]=nil end
 end
end
local function queuePop(hit,e,age)
 -- A fresh direct hit takes priority over an older burn tick in the same lane.
 if hit.source~="status" then for i,p in pairs(U.damagePops) do
  if p.hit.target==hit.target and p.hit.source=="status" then U.damagePops[i]=nil end
 end end
 local slot,oldest=1,-1
 for i=1,6 do
  if not U.damagePops[i] then slot=i;break end
  if U.damagePops[i].age>oldest then slot=i;oldest=U.damagePops[i].age end
 end
 U.damagePops[slot]={hit=hit,battle=e.battle,age=age,maxHP=G.MaxHP(e[hit.target]),
  duration=hit.source=="status" and .48 or hit.critical and .92 or .72}
end
function U.CombatPresentation()
 local e=U.effect
 return e and e.battle==U.CurrentBattle() and e.action~="flee" and not (e.action=="charm" and e.result=="caught") and e or nil
end
function U.CombatPet(role)
 local e=U.CombatPresentation();if not e then return U.CurrentPet(role) end
 local p={};for k,v in pairs(e[role]) do p[k]=v end
 for _,hit in ipairs(e.hits) do
  if hit.target==role then
   -- Healing has already resolved in the model; show it before the response.
   if role=="player" and e.age>=.12 then p.hp=hit.beforeHP end
   if e.age>=impactTime(hit) then p.hp=hit.afterHP end
  end
 end
 return p
end
function U.CombatLog()
 local e=U.CombatPresentation();if not e then return U.duelView and U.duelView.log or G.db.log end
 if e.duel then return e.finalLog end
 if e.age>=.52 then
  for _,hit in ipairs(e.hits) do if hit.source=="enemy" then
   return "Foe "..G.Name(e.enemy).." used "..(hit.special and G.Spec(e.enemy).move or "Strike").."!"
  end end
 end
 if e.action=="strike" or e.action=="special" then
  return G.Name(e.player).." used "..(e.action=="special" and G.Spec(e.player).move or "Strike").."!"
 elseif e.action=="guard" then return G.Name(e.player).." used "..F.defensiveMoves[e.player.id].."!"
 elseif e.action=="focus" then return G.Name(e.player).." is focusing its next special."
 elseif e.action=="salve" then return "A salve restores "..G.Name(e.player).."."
 elseif e.action=="swap" then return "Go, "..G.Name(e.player).."!" end
 return G.db.log
end
function U.AdvanceCombatEffect(dt)
 local e=U.effect;if not e then return end
 e.age=e.age+dt
 if e.battle~=U.CurrentBattle() then U.effect=nil;U.HideCombatFX();return end
 if not e.resultSound and e.age>=.90 then
  e.resultSound=true
  local sound=({win="victory",caught="catch",lost="defeat"})[e.result]
  if sound and F.Audio then F.Audio.Play(sound) end
 end
 if e.age>=e.duration then
  U.effect=nil;U.HideCombatFX();U.Render();return
 end
 if U.battleVisible then
  for _,hit in ipairs(e.hits or {}) do
   if hit.source=="enemy" and not hit.castSound and e.age>=.52 then
    hit.castSound=true;if F.Audio then F.Audio.Play(hit.special and "special" or "strike") end
   end
   if not hit.hitSound and e.age>=impactTime(hit) then
    hit.hitSound=true;queuePop(hit,e,e.age-impactTime(hit))
    if F.Audio then F.Audio.Play(hit.critical and "critical" or hit.blocked and "guard" or "hit") end
   end
  end
 end
 local phase=e.age>=.86 and 4 or e.age>=.72 and 3 or e.age>=.52 and 2 or e.age>=.22 and 1 or 0
 if phase~=e.phase then e.phase=phase;U.Render() end
end
local function flipbook(slot,art,frame,x,y,size,alpha,flip)
 local t=U.fxSprites[slot]
 local path=F.path.."Art\\Combat\\"..art.."_"..clamp(math.floor(frame),1,4)..".tga"
 if t.fxPath~=path then t:SetTexture(path,"CLAMP","CLAMP","NEAREST");t.fxPath=path end
 t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",math.floor(x-size/2),-math.floor(y-size/2));t:SetSize(size,size)
 if flip then t:SetTexCoord(1,0,0,1) else t:SetTexCoord(0,1,0,1) end
 t:SetAlpha(alpha or 1);t:Show()
end
local function attackFX(hit,t,e)
 if t<.04 or t>.46 then return end
 local caster,target=centers[hit.source],centers[hit.target]
 local def=hit.special and defs[hit.id] or {art=(hit.id=="raptor" and "claw" or "slash"),style="melee"}
 local tier=hit.special and hit.tier or 1;local size=48+(tier-1)*12
 local flip=hit.source=="enemy"
 if def.style=="shot" and t<.23 then
  local travel=clamp((t-.04)/.19,0,1)
  local x=caster[1]+(target[1]-caster[1])*travel
  local y=caster[2]+(target[2]-caster[2])*travel-math.sin(travel*math.pi)*12
  flipbook(1,def.art,1+travel*2,x,y,22+tier*6,1,flip)
 elseif def.style=="pulse" and t<.24 then
  flipbook(1,def.art,1+t/.08,caster[1],caster[2],36+t*100,.85,flip)
 end
 if tier==3 and t<.18 then flipbook(4,"focus",1+t/.06,caster[1],caster[2],34,.7,flip) end
 if t>=.15 then
  local progress=clamp((t-.15)/.31,0,.999);local frame=1+math.floor(progress*4)
  local ground=def.style=="ground" or def.art=="tide" or def.art=="acid"
  local cy=target[2]+(ground and 9 or 0)
  flipbook(2,def.art,frame,target[1],cy,size,1,flip)
  if tier>=2 and t>=.23 then
   flipbook(3,def.art,frame,target[1]+(flip and -7 or 7),cy-5,size+6,tier==3 and .5 or .3,flip)
  end
 end
end
local function popText(t,value,x,y,size,color,alpha)
 if t.popFont~=size then t:SetFont(F.path.."Art\\Silkscreen.ttf",size,"");t.popFont=size end
 t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",math.floor(x),-math.floor(y))
 t:SetText(value);t:SetTextColor(unpack(color));t:SetAlpha(alpha);t:Show()
end
local function drawPop(i,p)
 local hit,age=p.hit,p.age;local crit=hit.critical;local tick=hit.source=="status"
 local c=centers[hit.target]
 local pulse=age<.065 and age/.065 or age<.19 and 1-(age-.065)/.125 or 0
 local size=tick and 11 or (crit and 22 or 16)+math.floor(pulse*(crit and 9 or 6))
 local rise=math.floor((tick and 12 or 24)*(1-(1-clamp(age/.55,0,1))^2))
 local cx=c[1]+(hit.target=="enemy" and 1 or -1)*math.floor(math.min(age,.5)*10)
 local y=(hit.target=="enemy" and 75 or 156)+(tick and 28 or 0)-rise
 local alpha=math.min(1,(p.duration-age)/.24)
 local color=tick and {1,.65,.25,1} or crit and (age<.055 and {1,1,.94,1} or {1,.82,.25,1})
  or hit.blocked and {.58,.89,1,1} or hit.target=="player" and {1,.67,.56,1} or {1,.97,.82,1}
 local value=tostring(hit.amount)..(crit and "!" or "")
 popText(U.fxNumberShadows[i],value,cx-55,y+2,size,{.07,.05,.04,1},alpha)
 popText(U.fxNumbers[i],value,cx-56,y,size,color,alpha)
 local caption=crit and (hit.afterHP==0 and "CRITICAL K.O.!" or "CRITICAL!")
  or hit.afterHP==0 and "K.O.!" or hit.blocked and "BLOCKED"
  or (hit.multiplier or 1)>1 and "SUPER EFFECTIVE" or nil
 if caption and not tick then
  local captionSize=#caption>10 and 7 or 9
  popText(U.fxCaptionShadows[i],caption,cx-55,y-12,captionSize,{.07,.05,.04,1},alpha)
  popText(U.fxCaptions[i],caption,cx-56,y-13,captionSize,crit and {1,.66,.22,1} or color,alpha)
 end
 if crit and age<.32 then
  local phase=age/.32
  flipbook(6,"focus",1+math.floor(phase*4),c[1],c[2],58+phase*42,(1-phase)*.9,hit.source=="enemy")
  for j,t in ipairs(U.fxSparks) do
   local angle=j*math.pi/4;local radius=17+phase*35;local s=j%2==0 and 3 or 2
   t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",math.floor(c[1]+math.cos(angle)*radius),-math.floor(c[2]+math.sin(angle)*radius*.7))
   t:SetSize(s,s);t:SetAlpha(math.min(1,(.32-age)/.1));t:Show()
  end
 end
 -- A short gold chip follows the green HP fill, without changing actual HP.
 if not tick and age<.38 and U.CombatPet(hit.target).hp==hit.afterHP then
  local pos=U.hpPositions[hit.target];local x,y,w=pos.x,pos.y,pos.w
  local start=w*hit.afterHP/p.maxHP;local lost=w*(hit.beforeHP-hit.afterHP)/p.maxHP
  local remaining=1-clamp((age-.07)/.31,0,1);remaining=remaining*remaining
  local chip=U.hpChips[hit.target]
  if lost>0 and remaining>0 then
   chip:ClearAllPoints();chip:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x+start,-y);chip:SetSize(lost*remaining,5)
   chip:SetColorTexture(unpack(crit and {1,.76,.25,1} or {.91,.73,.47,1}));chip:Show()
  end
 end
end
function U.DrawCombatFX()
 U.HideCombatFX()
 if not U.battleVisible or not U.frame:IsShown() then U.ClearDamagePops();return end
 local e=U.CombatPresentation()
 if e then
  for _,hit in ipairs(e.hits) do
   if hit.source=="player" or hit.source=="enemy" then attackFX(hit,e.age-(hit.source=="enemy" and .5 or 0),e) end
  end
  local caster=centers[e.actor or "player"]
  if e.action=="guard" then
   local t=clamp(e.age/.95,0,.999);flipbook(5,"shield",e.age<.65 and 1+math.floor(math.min(.99,e.age/.25)*3) or 4,caster[1],caster[2],76,1-t*.4)
  elseif e.action=="focus" and e.age<.48 then flipbook(5,"focus",1+math.floor(e.age/.12),caster[1],caster[2],64,1)
  elseif e.action=="salve" and e.age<.48 then flipbook(5,"heal",1+math.floor(e.age/.12),64,150,64,1) end
 end
 for i,p in pairs(U.damagePops) do
  if p.battle==U.CurrentBattle() then drawPop(i,p) else U.damagePops[i]=nil end
 end
end
function U.CombatPose(m,x,y,w,h,alpha)
 local e=U.CombatPresentation();if not e or not U.battleVisible then return x,y,w,h,alpha end
 local sign=m.role=="player" and 1 or -1
 for _,hit in ipairs(e.hits) do
  local launch=hit.source=="enemy" and .5 or 0;local t=e.age-launch
  if hit.source==m.role and t>.04 and t<.38 then
   local def=hit.special and defs[hit.id] or {style="melee"}
   local pulse=math.sin((t-.04)/.34*math.pi)
   local distance=def.style=="melee" and (14+(hit.tier-1)*3) or 5
   x=x+sign*math.floor(pulse*distance/2)*2;y=y-sign*math.floor(pulse*4)
  elseif hit.target==m.role then
   local age=e.age-impactTime(hit)
   if age>=0 and age<(hit.critical and .23 or .17) then
    x=x+math.floor(math.sin(age*80)*(hit.critical and 7 or 4));alpha=math.floor(age*25)%2==0 and .55 or 1
   end
   if hit.afterHP==0 and age>=0 then alpha=math.max(.2,1-age*3) end
  end
 end
 return x,y,w,h,alpha
end
