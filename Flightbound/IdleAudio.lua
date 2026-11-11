local _,F=...
local A={voices={},last={},mutedUntil=0};F.IdleAudio=A
local valid={hit=true,strike=true,critical=true,special=true,treasure=true,victory=true,defeat=true,catch=true,open=true,menu=true,guard=true}
function A.Stop()
 for _,h in ipairs(A.voices) do if StopSound then StopSound(h,80) end end
 A.voices={}
end
function A.Play(name)
 local d=F.Idle.db;local U=F.IdleUI
 if not valid[name] or not d or not d.settings.sound or not U or not U.frame or not U.frame:IsShown() or not PlaySoundFile then return end
 local now=GetTime();local gap=(name=="hit" or name=="strike") and .12 or .2
 if now-(A.last[name] or -100)<gap then return end;A.last[name]=now
 if #A.voices>=4 then local h=table.remove(A.voices,1);if StopSound then StopSound(h,50) end end
 -- Master respects WoW's master mute without depending on whether ordinary SFX is enabled.
 local ok,handle=PlaySoundFile(F.path.."Sounds\\"..name..".ogg","Master")
 if ok and handle then A.voices[#A.voices+1]=handle end
end
