local F={}
for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap","Duel","Social"}) do assert(loadfile("Flightbound/"..n..".lua"))("Flightbound",F) end
local G=F.Game
G.Init(nil);G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start("wolf")
F.UI={};local clock=0
function GetTime() return clock end
function GetServerTime() return 1800000000+math.floor(clock) end
function GetNormalizedRealmName() return "ForeverPvP" end
function UnitFullName() return "Tester", "Forever PvP" end
WOW_PROJECT_ID=99
local friends={{name="Friend-ForeverPvP",connected=true},{name="Both-ForeverPvP",connected=true},{name="Offline",connected=false},{name="Foreign-OtherRealm",connected=true}}
C_FriendList={GetNumFriends=function() return #friends end,GetFriendInfoByIndex=function(i) return friends[i] end}
local accounts={{battleTag="Test#0000",gameAccountInfo={clientProgram="WoW",wowProjectID=99,characterName="BNet Friend",realmName="Forever PvP",isOnline=true}}}
local extra={{clientProgram="WoW",wowProjectID=99,characterName="Second Hero",realmName="ForeverPvP",isOnline=true},
 {clientProgram="WoW",wowProjectID=1,characterName="Wrong Project",realmName="ForeverPvP",isOnline=true},
 {clientProgram="WoW",wowProjectID=99,characterName="Unknown Realm",realmName="",isOnline=true},
 {clientProgram="WoW",wowProjectID=99,characterName="Foreign Friend",realmName="Elsewhere",isOnline=true}}
function BNGetNumFriends() return #accounts end
C_BattleNet={GetFriendAccountInfo=function(i) return accounts[i] end,GetFriendNumGameAccounts=function() return #extra end,GetFriendGameAccountInfo=function(_,i) return extra[i] end}
local inGuild,loaded=true,true
function IsInGuild() return inGuild end
Enum={ClubMemberPresence={Online=1,Away=2,Busy=3,Offline=4,OnlineMobile=5}}
local members={{name="Guildmate",presence=1},{name="Both",presence=2},{name="Mobile",presence=5},{name="Old Guildmate",presence=4},{name="Tester",presence=1}}
C_Club={GetGuildClubId=function() return 42 end,GetClubMembers=function() return loaded and {1,2,3,4,5} or nil end,GetMemberInfo=function(_,i) return members[i] end}
local restricted,locked,prefixResult,sendResult=false,false,0,0
local sent,chat={},{}
C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) assert(prefix=="FLIGHTBOUND");return prefixResult end,
 InChatMessagingLockdown=function() return locked end,AreOutgoingAddonChatMessagesRestricted=function() return restricted end,
 SendAddonMessage=function(prefix,message,channel,target) sent[#sent+1]={prefix,message,channel,target};return sendResult end}
DEFAULT_CHAT_FRAME={AddMessage=function(_,m) chat[#chat+1]=m end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,k,fn) self[k]=fn end} end
assert(loadfile("Flightbound/SocialClient.lua"))("Flightbound",F)
local C=F.SocialClient
assert(C.Identity("First Last-ForeverPvP")=="first last-foreverpvp")
assert(C.Identity("First Last","")=="first last-foreverpvp")
assert(not C.Identity("Foreign-OtherRealm"));assert(not C.Identity("Injected|name"))
C.events:OnEvent("PLAYER_LOGIN");local S=F.Social;assert(S and FlightboundSocialDB==S.saved)
local contacts=S.contacts
assert(contacts["both-foreverpvp"].friend and contacts["both-foreverpvp"].guild)
assert(contacts["guildmate-foreverpvp"].online and not contacts["mobile-foreverpvp"].online)
assert(not contacts["offline-foreverpvp"].online and contacts["bnet friend-foreverpvp"].friend and contacts["second hero-foreverpvp"].online)
assert(not contacts["tester-foreverpvp"] and not contacts["foreign-otherrealm"] and not contacts["wrong project-foreverpvp"] and not contacts["unknown realm-foreverpvp"])
-- Battle.net character cache survives going offline, but not unfriending.
accounts[1].gameAccountInfo=nil;extra={};S:Refresh()
assert(S.contacts["bnet friend-foreverpvp"] and not S.contacts["bnet friend-foreverpvp"].online)
accounts={};S:Refresh();assert(not S.contacts["bnet friend-foreverpvp"] and not next(S.saved.bnCharacters))
-- A temporarily unloaded guild roster does not erase cached records.
loaded=false;S:Refresh();assert(S.contacts["guildmate-foreverpvp"])
loaded=true;inGuild=false;S:Refresh();assert(not S.contacts["guildmate-foreverpvp"] and S.contacts["both-foreverpvp"].friend)
-- Incoming traffic requires the exact prefix, whisper channel and current contact.
local hello="1|H|"..F.version.."|1"
C.events:OnEvent("CHAT_MSG_ADDON","OTHER",hello,"WHISPER","Friend");assert(not S.peers["friend-foreverpvp"])
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",hello,"GUILD","Friend");assert(not S.peers["friend-foreverpvp"])
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",hello,"WHISPER","Stranger");assert(not S.peers["stranger-foreverpvp"])
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",hello,"WHISPER","Friend");assert(S:Compatible("friend-foreverpvp"))
assert(S.env.send("Friend-ForeverPvP",hello));assert(sent[#sent][3]=="WHISPER" and sent[#sent][4]=="Friend-ForeverPvP")
sendResult=7;assert(not S.env.send("Friend",hello));sendResult=0
restricted=true;local n=#sent;S:Tick();assert(#sent==n and not C.Contacts());assert(not S.env.send("Friend",hello));restricted=false
locked=true;assert(not C.Available());locked=false
-- Legacy guild roster fallback excludes mobile-only players.
inGuild=true;C_Club=nil
function GetNumGuildMembers() return 1 end
function GetGuildRosterInfo() return "Legacy",nil,nil,nil,nil,nil,nil,nil,true,nil,nil,nil,nil,true end
assert(C.Contacts()["legacy-foreverpvp"] and not C.Contacts()["legacy-foreverpvp"].online)
-- Readiness and leaderboard difficulty tracking cannot upgrade easier progress.
assert(C.Ready("1"));assert(not C.Ready("2"));G.db.battle={};assert(not C.Ready("1"));G.db.battle=nil
assert(C.Score().lane=="adventure");assert(G.SetDifficulty("veteran"));assert(C.Score().lane=="adventure")
assert(G.SetDifficulty("story"));assert(C.Score().lane=="story");assert(G.SetDifficulty("veteran"));assert(C.Score().lane=="story")
-- Registration enum: success and duplicate are accepted, refusal does not start.
F.Social=nil;prefixResult=3;C.Start();assert(not F.Social)
prefixResult=1;C.Start();assert(F.Social)
-- Forever returns first/surname, not name/realm. Reproduce the live failure:
-- UnitFullName -> Whitebeard, Tinkerton; realm -> CAMWOWUS1Realm8PvP;
-- prefix -> 0; outgoing restriction flag -> true even when whispers work.
function RegionalUniqueNamesEnabled() return true end
local first,surname="Whitebeard","Tinkerton"
function UnitFullName() return first,surname end
function UnitNameUnmodified() return first,surname end
function GetNormalizedRealmName() return "CAMWOWUS1Realm8PvP" end
Constants={CharacterNameSeparatorConsts={CHARACTERNAME_SURNAME_SEPARATOR=" "}}
F.Social=nil;FlightboundSocialDB=nil;inGuild=false;prefixResult=0;restricted=true
friends={{name="Aster Ashborne",connected=true},{name="Whitebeard Tinkerton",connected=true}}
accounts={{battleTag="Test#0000",gameAccountInfo={clientProgram="WoW",wowProjectID=99,characterName="Mira Sunfall",realmName="CAMWOWUS1Realm2PvP",isOnline=true}}}
assert(C.Me()=="whitebeard tinkerton");assert(C.Identity("Aster Ashborne-CAMWOWUS1Realm2PvP")=="aster ashborne")
assert(C.Start());S=F.Social
assert(S.me=="whitebeard tinkerton" and S.contacts["aster ashborne"] and S.contacts["mira sunfall"] and not S.contacts[S.me])
assert(C.Available(),"Forever's always-true outgoing flag incorrectly blocked comms")
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",hello,"WHISPER","Aster Ashborne");assert(S:Compatible("aster ashborne"))
assert(S.env.send(S.contacts["aster ashborne"].name,hello));assert(sent[#sent][4]=="Aster Ashborne")
local scorePacket="1|S|48|adventure|0|4|12|8|16|4|0"
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",scorePacket,"WHISPER","Aster Ashborne")
assert(#S:Rows("adventure")==1 and S:Rows("adventure")[1].owner=="aster ashborne")
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",hello,"WHISPER","Unknown Person");assert(not S.peers["unknown person"])
locked=true;n=#sent;S:Tick();assert(#sent==n and not C.Available() and S.status:find("lockdown"));locked=false;S:Tick();assert(not S.blocked)
-- Diagnostics send to self only, require the matching echo and honor errors.
n=#sent;assert(C.Test():find("Self%-whisper sent"));assert(#sent==n+1 and sent[#sent][4]=="Whitebeard Tinkerton")
local probe=C.probe.token;assert(C.Test():find("Already"));assert(#sent==n+1)
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",probe,"WHISPER","Unknown Person");assert(C.probe)
C.events:OnEvent("CHAT_MSG_ADDON","FLIGHTBOUND",probe,"WHISPER","Whitebeard Tinkerton");assert(not C.probe and C.testStatus=="received")
sendResult=7;assert(C.Test():find("rejected"));assert(not C.probe);sendResult=0
C.Test();clock=clock+7;C.events:OnUpdate(.2);assert(not C.probe and C.testStatus=="no echo received")
-- Names unavailable during login retry later, and already joined names stay whole.
F.Social=nil;first,surname=nil,nil;assert(not C.Start() and C.startStatus:find("full character name"))
first,surname="Whitebeard Tinkerton","Tinkerton";clock=clock+3;C.events:OnUpdate(.2)
assert(F.Social and F.Social.me=="whitebeard tinkerton")
assert(C.Status():find("whitebeard tinkerton"))
print("Native social adapter: realm and Forever full-name modes, real restriction-flag regression, delayed login, self-whisper tests, friend/guild admission, offline removal and lockdown passed.")
