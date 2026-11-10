local _,F=...
local A={};F.Audio=A
local allowed={menu=true,step=true,open=true,encounter=true,strike=true,special=true,hit=true,charm=true,
    catch=true,victory=true,defeat=true,heal=true,treasure=true,guard=true,critical=true}
function A.Stop()
    if A.handle and StopSound then StopSound(A.handle,50) end
    A.handle=nil
end
function A.Play(name)
    local d=F.Game.db
    if not allowed[name] or not d or d.settings.sound==false or not PlaySoundFile then return end
    if not F.UI or not F.UI.frame or not F.UI.frame:IsShown() then return end
    -- One voice prevents rapid movement/menu clicks from stacking loud sounds.
    A.Stop()
    local ok,handle=PlaySoundFile(F.path.."Sounds\\"..name..".ogg","SFX")
    if ok then A.handle=handle end
end
