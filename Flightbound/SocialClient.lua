-- Native WoW adapter. Only current friends and guildmates are admitted.
local _,F=...
local G,D=F.Game,F.Duel
local C={startStatus="Waiting for your character to finish loading.",recentWhispers={},manualWhispers={}};F.SocialClient=C
local function regional() return RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() end
local function plain(v) return type(v)=="string" and (not issecretvalue or not issecretvalue(v)) end
local function realm(value) return (value or ""):gsub("[%s%-]",""):lower() end
local function homeRealm() return GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or "" end
function C.Identity(name,server)
 if not plain(name) or name=="" or #name>150 or name:find("[|%c]") then return end
 -- Forever's full character names are regionally unique. Its internal shard
 -- labels are not part of whisper recipients or stable character identities.
 if regional() then
  local full=(name:match("^(.-)%-.+$") or name):gsub("^%s+",""):gsub("%s+$","")
  if full=="" then return end
  return full:lower(),full
 end
 local n,r=name:match("^(.-)%-(.+)$")
 if not n then n,r=name,server and server~="" and server or homeRealm() end
 if n=="" or realm(r)~=realm(homeRealm()) then return end
 return (n.."-"..realm(r)):lower(),n.."-"..(r:gsub("%s",""))
end
function C.Me()
 local name,server
 if regional() then
  local getName=UnitNameUnmodified or UnitName
  if not getName then return end
  local first,surname=getName("player")
  if not plain(first) or first=="" or not plain(surname) then return end
  local sep=Constants and Constants.CharacterNameSeparatorConsts and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
  local tail=sep..surname
  name=surname~="" and first:sub(-#tail)~=tail and first..tail or first
  return C.Identity(name)
 end
 if UnitFullName then name,server=UnitFullName("player") elseif UnitName then name,server=UnitName("player") end
 return C.Identity(name,server)
end
function C.Available()
 if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false,"This client has no addon messaging API." end
 if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return false,"Link paused during the game's chat lockdown." end
 -- Forever reports the outgoing-chat flag as true even when addon whispers
 -- work. Respect actual chat lockdown and SendAddonMessage's result instead.
 if not regional() and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() then
  return false,"The client currently restricts outgoing addon messages."
 end
 return true
end
function C.Contacts()
 if not C.Available() then return end
 local out={};local self=C.Me()
 local function add(name,server,online,kind)
  local key,full=C.Identity(name,server);if not key or key==self then return end
  local row=out[key] or {name=full,online=false};row[kind]=true;row.online=row.online or online==true;out[key]=row
 end
 if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
  for i=1,C_FriendList.GetNumFriends() do local f=C_FriendList.GetFriendInfoByIndex(i);if f then add(f.name,nil,f.connected,"friend") end end
 end
 if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
  local saved=F.Social and F.Social.saved
  local cache=saved and type(saved.bnCharacters)=="table" and saved.bnCharacters or {};local known={}
  if saved then saved.bnCharacters=cache end
  local function account(g,chars)
   local server=g and (g.realmName or g.realmDisplayName)
   if g and g.isInCurrentRegion~=false and (regional() or type(server)=="string" and server~="") and g.clientProgram=="WoW" and (not g.wowProjectID or not WOW_PROJECT_ID or g.wowProjectID==WOW_PROJECT_ID) then
    add(g.characterName,g.realmName or g.realmDisplayName,g.isOnline and not g.isWowMobile,"friend")
    local key,full=C.Identity(g.characterName,g.realmName or g.realmDisplayName)
    if key then chars[key]=full end
   end
  end
  for i=1,BNGetNumFriends() do
   local a=C_BattleNet.GetFriendAccountInfo(i)
   if a then
    -- Remember characters while their Battle.net account remains a current friend.
    -- Account identifiers stay local and are never included in network payloads.
    local tag=a.battleTag or tostring(a.bnetAccountID);known[tag]=true
    local chars=type(cache[tag])=="table" and cache[tag] or {};cache[tag]=chars;local n=0
    for key,full in pairs(chars) do
     n=n+1;if n<=30 and type(full)=="string" and C.Identity(full)==key then add(full,nil,false,"friend") else chars[key]=nil end
    end
    account(a.gameAccountInfo,chars)
    if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
     for j=1,C_BattleNet.GetFriendNumGameAccounts(i) do account(C_BattleNet.GetFriendGameAccountInfo(i,j),chars) end
    end
   end
  end
  for tag in pairs(cache) do if not known[tag] then cache[tag]=nil end end
 end
 if IsInGuild and IsInGuild() then
  local club=C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
  if club then
   local members=C_Club.GetClubMembers(club)
   -- An unloaded roster is not evidence that everyone left the guild.
   if not members or #members==0 then return end
   local presence=Enum.ClubMemberPresence
   for _,id in ipairs(members) do local m=C_Club.GetMemberInfo(club,id)
    if m then add(m.name,nil,m.presence==presence.Online or m.presence==presence.Away or m.presence==presence.Busy,"guild") end
   end
  elseif GetNumGuildMembers and GetGuildRosterInfo then
   local count=GetNumGuildMembers();if count==0 then return end
   for i=1,count do local name,_,_,_,_,_,_,_,online,_,_,_,_,mobile=GetGuildRosterInfo(i);add(name,nil,online and not mobile,"guild") end
  else return end
 end
 return out
end
local difficulties={story=1,adventure=2,veteran=3}
function F.RecordSocialDifficulty(id)
 local r=G.db and G.db.socialRecord
 if r and difficulties[id] and difficulties[id]<difficulties[r.lane] then r.lane=id end
end
function C.Score()
 local d=G.db;if not d or not d.trainer or #d.pets==0 then return end
 local r=d.socialRecord
 if type(r)~="table" or r.rules~=F.campaignRules or not difficulties[r.lane] then
  r={rules=F.campaignRules,lane=d.settings.difficulty,imported=(d.totalWins>0 or G.Badges()>0) and 1 or 0};d.socialRecord=r
 end
 F.RecordSocialDifficulty(d.settings.difficulty)
 local s=G.Stats()
 return {lane=r.lane,ending=s.ending,badges=G.Badges(),quests=s.quests,rivals=s.rivals,treasure=s.treasure,collection=s.collection,imported=r.imported==1 and 1 or 0}
end
function C.Ready(team)
 local ids=D.Team(team);local d=G.db
 if not ids or not d or not d.trainer or d.battle or d.pendingName or d.run or F.UI.effect then return false end
 for _,id in ipairs(ids) do if not G.Owns(id) then return false end end
 return true
end
local function changed(event)
 local U,S=F.UI,F.Social
 if U.UpdateDuelInvite then U.UpdateDuelInvite() end
 if S.session and event and U.QueueDuelAnimation then U.QueueDuelAnimation(event) end
 if U.frame and U.frame:IsShown() and (S.session or U.page=="social" or U.page=="leaderboard" or U.page=="duelteam") then U.Render() end
end
function C.NoteManualWhisper(message,chatType,language,target)
 if chatType=="WHISPER" then local key=C.Identity(target);if key then C.manualWhispers[key]=GetTime() end end
end
function C.FilterSystemMessage(_,event,message)
 if event~="CHAT_MSG_SYSTEM" or not plain(message) or not plain(ERR_CHAT_PLAYER_NOT_FOUND_S) then return false end
 local marker="\001"
 local pattern=ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("%%s",marker):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1"):gsub(marker,"(.+)")
 local target=message:match("^"..pattern.."$");local key=target and C.Identity(target)
 local sent=key and C.recentWhispers[key];local now=GetTime()
 if not sent or now-sent>8 then return false end
 if F.Social then F.Social:Unreachable(key) end
 -- Don't hide an ordinary whisper's error, even if we recently probed the
 -- same character. Keep this filter limited to our exact target and time window.
 if C.manualWhispers[key] and now-C.manualWhispers[key]<=12 then return false end
 return true
end
local function send(name,message,channel)
 if not C.Available() then return false,"chat restricted" end
 local key=name and C.Identity(name)
 if channel=="WHISPER" and key and message:match("^1|") then C.recentWhispers[key]=GetTime() end
 local success,value=pcall(C_ChatInfo.SendAddonMessage,F.socialPrefix,message,channel,name)
 C.lastSend=success and tostring(value) or "client refused"
 local results=Enum and Enum.SendAddonMessageResult
 local unreachable=results and ((results.InvalidTarget and value==results.InvalidTarget) or (results.TargetNotFound and value==results.TargetNotFound))
 if success and unreachable and key and F.Social then F.Social:Unreachable(key) end
 return success and (value==0 or value==true),C.lastSend,unreachable
end
function C.Start()
 if F.Social then return true end
 if not G.db then C.startStatus="Waiting for your campaign save to load.";return false end
 if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
  C.startStatus="This client has no addon messaging API.";return false
 end
 local me=C.Me();if not me then C.startStatus="Waiting for your full character name. Setup retries automatically.";return false end
 local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,F.socialPrefix)
 C.prefixResult=ok and tostring(result) or "error"
 if not ok or result==false or type(result)=="number" and result>1 then
  C.startStatus="Addon message registration failed ("..C.prefixResult.."). Use /fb linkstatus for details.";return false
 end
 if not C.chatFilterInstalled and ChatFrame_AddMessageEventFilter then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM",C.FilterSystemMessage);C.chatFilterInstalled=true
  if hooksecurefunc then
   if C_ChatInfo.SendChatMessage then hooksecurefunc(C_ChatInfo,"SendChatMessage",C.NoteManualWhisper) end
   if SendChatMessage then hooksecurefunc("SendChatMessage",C.NoteManualWhisper) end
  end
 end
 local env={me=function() return me end,now=GetTime,wall=GetServerTime or time,contacts=C.Contacts,score=C.Score,ready=C.Ready,available=C.Available,
  unavailableReason=function() local _,reason=C.Available();return reason end,
  send=function(name,message) return send(name,message,"WHISPER") end,
  inGuild=function() return IsInGuild and IsInGuild() end,
  guildHello=function(message) return send(nil,message,"GUILD") end,
  changed=changed,
  invite=function(peer)
   local row=F.Social.contacts[peer]
   DEFAULT_CHAT_FRAME:AddMessage("|cffc2d491Flightbound:|r "..(row and row.name or peer).." invited you to a duel. Click Accept Duel in the popup, or use /fb friends.")
   if F.UI.UpdateDuelInvite then F.UI.UpdateDuelInvite() end
  end}
 F.Social=F.NewSocial(env,FlightboundSocialDB);FlightboundSocialDB=F.Social.saved;F.Social:Refresh()
 C.startStatus="Link initialized. Waiting for online contacts."
 if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
 return true
end
function C.Status()
 local ok,reason=C.Available()
 local status=not F.Social and C.startStatus or not ok and reason or F.Social.status
 return status.." Name: "..(C.Me() or "pending")..". Prefix: "..(C.prefixResult or "not attempted")..". Last send: "..(C.lastSend or "none")..". Test: "..(C.testStatus or "not run").."."
end
function C.Test()
 if not C.Start() then return C.startStatus end
 local available,reason=C.Available();if not available then return reason end
 if C.probe then return "Already waiting for the self-whisper result." end
 local _,recipient=C.Me()
 local token="FBTEST:"..tostring(GetTime())..":"..tostring(GetServerTime and GetServerTime() or time())
 C.probe={token=token,expires=GetTime()+6}
 local ok,result=F.Social.env.send(recipient,token)
 if not ok then C.probe=nil;C.testStatus="send rejected ("..tostring(result)..")";return "Self-whisper "..C.testStatus.."." end
 C.testStatus="waiting for echo";return "Self-whisper sent. Waiting for its return; no contacts were messaged."
end
local events=CreateFrame("Frame");C.events=events
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","CHAT_MSG_ADDON","CHAT_MSG_SYSTEM","FRIENDLIST_UPDATE","BN_FRIEND_LIST_SIZE_CHANGED","BN_FRIEND_INFO_CHANGED","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","CLUB_MEMBER_UPDATED","CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED","CLUB_ADDED","CLUB_REMOVED","PLAYER_LOGOUT"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,...)
 if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then C.Start();return end
 local S=F.Social;if not S then return end
 if event=="CHAT_MSG_ADDON" then
  local prefix,message,channel,sender=...
  if prefix==F.socialPrefix and (channel=="WHISPER" or channel=="GUILD") then
   local key=C.Identity(sender)
   if channel=="WHISPER" and C.probe and message==C.probe.token and key==S.me then
    C.probe=nil;C.testStatus="received";DEFAULT_CHAT_FRAME:AddMessage("|cffc2d491Flightbound:|r Self-whisper received. Addon whispers work on this character.")
   elseif key then S:Receive(key,message,channel) end
  end
 elseif event=="CHAT_MSG_SYSTEM" then C.FilterSystemMessage(nil,event,...)
 elseif event=="PLAYER_LOGOUT" then S:Persist()
 else S.scanAt=0;if event=="PLAYER_GUILD_UPDATE" then S.guildAt=0 end end
end)
local elapsed,retry=0,0
events:SetScript("OnUpdate",function(_,dt)
 elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
 if GetTime then
  local now=GetTime()
  for key,at in pairs(C.recentWhispers) do if now-at>8 then C.recentWhispers[key]=nil end end
  for key,at in pairs(C.manualWhispers) do if now-at>12 then C.manualWhispers[key]=nil end end
 end
 if C.probe and GetTime()>=C.probe.expires then
  C.probe=nil;C.testStatus="no echo received";DEFAULT_CHAT_FRAME:AddMessage("|cffc2d491Flightbound:|r No self-whisper arrived. Use /fb linkstatus to check the send result.")
 end
 if F.Social then F.Social:Tick()
 elseif G.db and GetTime and GetTime()>=retry then
  retry=GetTime()+2;local before=C.startStatus;local started=C.Start()
  local U=F.UI
  if (started or before~=C.startStatus) and U.frame and U.frame:IsShown() then U.Render() end
 end
 if F.UI.UpdateDuelInvite then F.UI.UpdateDuelInvite() end
end)
