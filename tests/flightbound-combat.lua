-- Called by the UI harness: real game actions, deterministic fixtures, no live save.
local F,G,U,snapshot,json=...
local function low(a,b) return b and a or 1 end
local function reset(id,level)
 U.frame:Hide();U.page=nil;U.trainerDraft=nil;U.evolving=nil
 G.Init(nil,low);G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start(id or "wolf")
 G.Active().level=level or 8;G.Active().hp=G.MaxHP(G.Active())
 G.db.totalWins=10;G.db.scene=nil;G.db.evolutions={};G.db.showChapter=false
 assert(G.Encounter(false,{id="boar",level=20,kind="wild"}))
 G.db.battle.enemy.hp=500;G.db.battle.enemy.maxHP=500 -- low RNG rolls choose a special.
 U.Open(true)
end
local function hidden()
 for _,t in ipairs(U.fxSprites) do assert(not t.shown,"Effect leaked across a screen transition") end
 for _,t in ipairs(U.fxNumbers) do assert(not t.shown,"Damage number leaked across a screen transition") end
end
local function capture(name)
 local render=U.Render;U.Render=function() end;snapshot(name);U.Render=render
end
local function shownText(value)
 if U.zone:IsShown() and U.zoneTitle:GetText()==U.Title(value) then return true end
 for _,t in ipairs(U.pools.text) do if t.shown and t.text==value then return true end end
 return false
end
for _,id in ipairs(F.order) do for tier,level in ipairs({3,8,16}) do
 reset(id,level);local before=G.Active().hp;local foe=G.db.battle.enemy.hp
 assert(U.Turn("special"));local e=U.effect
 assert(e.player.id==id and e.player.hp==before and e.enemy.hp==foe)
 assert(e.hits[1].source=="player" and e.hits[1].special and e.hits[1].tier==tier)
 assert(e.hits[2].source=="enemy" and e.hits[2].special,"Enemy's resolved random move must animate correctly")
 assert(not U.actions[1]:IsEnabled() and not U.Turn("strike"),"A second input must not spend another turn")
 assert(U.CombatPet("enemy").hp==foe and U.CombatPet("player").hp==before)
 local committed=json(G.db)
 U.Animate(.10);assert(not U.fxNumbers[1].shown)
 U.Animate(.15);assert(U.CombatPet("enemy").hp==e.hits[1].afterHP)
 assert(U.fxSprites[2].shown and U.fxSprites[2].file:find(U.combatEffects[id].art.."_",1,true))
 assert(U.fxNumbers[1].shown and U.fxNumbers[1].text==tostring(e.hits[1].amount))
 capture("fx-"..id.."-"..tier)
 U.Animate(.50);assert(U.CombatPet("player").hp==e.hits[2].afterHP)
 assert(U.fxNumbers[2].shown and U.fxSprites[2].coords[1]==1,"Enemy effects must face the player")
 if tier==3 then capture("fx-enemy-"..id) end
 assert(json(G.db)==committed,"Presentation must not mutate the resolved turn")
 U.Animate(1);assert(not U.effect);hidden()
 assert(#U.fxSprites==6 and #U.fxNumbers==6,"Effects must reuse a fixed pool")
end end
for _,action in ipairs({"strike","guard","focus","salve"}) do
 reset("murloc",8);if action=="salve" then G.Active().hp=10 end
 assert(U.Turn(action));U.Animate(.25)
 if action=="strike" then assert(U.fxSprites[2].file:find("slash",1,true))
 else assert(U.fxSprites[5].shown) end
 capture("fx-"..action);U.Animate(1);hidden()
end
-- Knockouts delay result controls until impact, with no phantom retaliation.
reset("whelp",16);G.db.battle.enemy.hp=1;assert(U.Turn("special"))
assert(U.effect.result=="win" and #U.effect.hits==1)
assert(not shownText("VICTORY!") and not U.actions[1]:IsEnabled())
U.Animate(.25);assert(U.CombatPet("enemy").hp==0);capture("fx-knockout")
U.Animate(1);assert(shownText("VICTORY!") and U.actions[1]:IsEnabled());hidden()
-- Damage over time still follows a live enemy response, even when it ends combat.
reset("whelp",16);G.db.battle.enemy.hp=1;G.db.battle.burn=1
assert(U.Turn("guard"));assert(#U.effect.hits==2 and U.effect.hits[1].source=="enemy" and U.effect.hits[2].source=="status")
U.Animate(.75);assert(U.fxNumbers[1].shown and U.CombatPet("enemy").hp==1)
U.Animate(.12);assert(U.CombatPet("enemy").hp==0 and U.fxNumbers[2].shown);capture("fx-burn")
-- A forced swap cannot replace the fainting sprite before the hit lands.
reset("wolf",8);G.db.pets[2]=G.NewPet("murloc",8);G.Active().hp=1
assert(U.Turn("strike"));assert(G.Active().id=="murloc" and U.CombatPet("player").id=="wolf")
U.Animate(.75);assert(U.CombatPet("player").hp==0);capture("fx-faint")
U.Animate(1);assert(U.CombatPet("player").id=="murloc")
-- Help and close/reopen must not retain effects or roll back a committed turn.
reset("whelp",8);assert(U.Turn("special"));U.Animate(.25);U.SavePosition();local committed=json(G.db)
U.page="help";U.Render();hidden();U.Animate(.1);hidden()
U.page=nil;U.Render();assert(U.fxSprites[2].shown)
U.frame:Hide();assert(not U.effect);hidden();U.Open(true);hidden();assert(json(G.db)==committed)
assert(not U.Turn("special"),"Cooldown must survive interrupted presentation")
local ok,trace=G.Action("swap",99);assert(not ok and not trace)
-- Crit feedback is tied to real damage, lingers independently of turn input,
-- and cleans up across menus, repeated actions and window close.
local play=PlaySoundFile;local heard={}
PlaySoundFile=function(path,channel) heard[#heard+1]=path;return play(path,channel) end
reset("whelp",16)
G.random=function(a,b) return a==92 and b==108 and 108 or low(a,b) end
assert(U.Turn("special"));local e=U.effect
assert(e.hits[1].critical and e.hits[2].critical)
U.Animate(.21);assert(not U.fxNumbers[1].shown,"No number before impact")
U.Animate(.07);assert(U.fxNumbers[1].text==e.hits[1].amount.."!" and U.fxNumbers[1].fontSize>=29)
assert(U.fxCaptions[1].text=="CRITICAL!" and U.fxSparks[1].shown and U.hpChips.enemy.shown)
capture("fx-critical-player")
U.Animate(.5);assert(U.fxCaptions[2].shown and U.fxCaptions[2].text=="CRITICAL!");capture("fx-critical-enemy")
local criticalSounds=0;for _,path in ipairs(heard) do if path:find("critical.ogg",1,true) then criticalSounds=criticalSounds+1 end end
assert(criticalSounds==2,"One critical sound per actual critical hit")
U.Animate(.22);assert(not U.effect and U.actions[1]:IsEnabled() and U.fxNumbers[2].shown,"Lingering numbers must not delay controls")
capture("fx-critical-linger")
U.page="help";U.Render();hidden();assert(not next(U.damagePops));U.page=nil;U.Render();hidden()
reset("wolf",16);G.db.battle.enemy.hp=1;G.random=function(a,b) return a==92 and b==108 and 108 or low(a,b) end
assert(U.Turn("strike"));U.Animate(.28);assert(U.fxCaptions[1].text=="CRITICAL K.O.!");capture("fx-critical-ko")
U.frame:Hide();hidden();assert(not next(U.damagePops));U.Open(true);hidden()
reset("murloc",8);G.random=function(a,b) return a==92 and b==108 and 108 or low(a,b) end
assert(U.Turn("guard"));assert(U.effect.hits[1].critical and U.effect.hits[1].blocked)
U.Animate(.78);capture("fx-critical-blocked");U.Animate(1);hidden()
reset("wolf",16);G.db.settings.sound=false;heard={}
G.random=function(a,b) return a==92 and b==108 and 108 or low(a,b) end
assert(U.Turn("strike"));U.Animate(.28);assert(#heard==0,"Crit sound must respect mute")
U.frame:Hide();PlaySoundFile=play
print("Critical feedback: real damage, peak size, labels, sparks, HP chips, one sound per crit, linger/input, mute and cleanup passed.")
print("Combat FX: all 36 specials, enemy responses, HP/damage timing, utility moves, knockouts, burn, swaps and interruption checks passed.")
