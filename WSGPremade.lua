WSGPremade = LibStub("AceAddon-3.0"):NewAddon("WSGPremade", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local addonName = GetAddOnMetadata("WSGPremade", "Title");
local commPrefix = addonName .. "1";

local playerName = UnitName("player");
local groups = {}

function WSGPremade:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WSGPremadeDB", {
		factionrealm = {
			channelName = "WSGPremade"
		}
	}, true)

	--self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
	--ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_FILTER);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	
	DrawMinimapIcon();
	WSGPremadeGUI:PrepareGUI()
end

function WSGPremade:OnEnable()
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	--self:RegisterEvent("FRIENDLIST_UPDATE");
end

function WSGPremade:Reload()
	self:UPDATE_BATTLEFIELD_STATUS()
end

local BG_ID_AV = 1
local BG_ID_WSG = 2
function WSGPremade:UPDATE_BATTLEFIELD_STATUS()
	WSGPremade:CheckBGStatus(BG_ID_AV)
	WSGPremade:CheckBGStatus(BG_ID_WSG)
end

--function WSGPremade:FRIENDLIST_UPDATE()
--end

function WSGPremade:GetBGStatus(bgid)
	local status, map, instanceID, isRegistered, suspendedQueue, queueType, gameType, role = GetBattlefieldStatus(bgid)
	bgData = {
		bgid = bgid,
		status = status,
		map = map,
		instanceID = instanceID,
		isRegistered = isRegistered, 
		suspendedQueue = suspendedQueue, 
		queueType = queueType, 
		gameType = gameType, 
		role = role,
		confirmTime = GetBattlefieldPortExpiration(bgid),
		waitTime = GetBattlefieldTimeWaited(bgid),
		estTime = GetBattlefieldEstimatedWaitTime(bgid),
		groupData = WSGPremade:GetGroupData()
	}
	return bgData
end

function WSGPremade:GetGroupData()
	groupData = {}
	for i = 1, GetNumGroupMembers() do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
		if name then
			_, realm = UnitName(name)
			-- realm is nil if they're from the same realm
			if realm == nil then
				groupData[name] = {
					class = class,
					isLead = rank == 2,
					zone = zone
				}
			end
		end
	end
	return groupData
end

function WSGPremade:CheckBGStatus(bgid)
	bgData = WSGPremade:GetBGStatus(bgid)
	WSGPremadeGUI:SetPlayerData(playerName, bgData)
	--WSGPremade:broadcastToGroup(WSGPremade:Serialize(bgData))
	WSGPremade:broadcastToFriends(WSGPremade:Serialize(bgData))
end

function WSGPremade:broadcastToChannel(channel, msg)
	--ListChannelByName(GetChannelName('wsgpremade'))
	return
end

function WSGPremade:broadcastToFriends(msg)
	for i = 1, 1024 do
		connected, name, className, area, notes, guid, level, dnd, afk, rafLinkType, mobile = C_FriendList.GetFriendInfoByIndex(i)
		if(connected and name) then
			WSGPremade:SendCommMessage(commPrefix, msg, "WHISPER", name);
		end
	end
end

function WSGPremade:broadcastToGroup(msg)
	for i = 1, GetNumGroupMembers() do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
		if name then
			_, realm = UnitName(name)
			-- realm is nil if they're from the same realm
			if realm == nil and name ~= playerName and online then
				WSGPremade:SendCommMessage(commPrefix, msg, "WHISPER", name);
			end
		end
	end
end

function WSGPremade:OnCommReceive(prefix, message, distribution, sender)
	if (distribution == "WHISPER" and (UnitInRaid(sender) or UnitInParty(sender))) then
		local ok, bgData = WSGPremade:Deserialize(message);
		if (not ok) then
			WSGPremade.Print(string.format('Could not deserialize data'))
			return;
		end
		if(bgData == nil) then
			WSGPremade.Print('bgData is nil')
			return
		end
		if (sender == UnitName("player")) then
			return;	-- Ignore broadcast messages from myself
		end
		WSGPremadeGUI:SetPlayerData(sender, bgData)
	end
end

-- CHAT COMMANDS
local options = {
	name = 'WSGPremade',
	type = 'group',
	args = {
		show = {
			type = 'execute',
			name = 'Show WSGPremade',
			desc = 'Show WSGPremade',
			func = function() WSGPremadeGUI:Toggle() end
		}
	}
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("WSGPremade", options, {"WSGPremade", "wsg"})

function WSGPremade:PLAYER_DEAD()
end

-- Minimap icon
function DrawMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("WSGPremade", LibStub("LibDataBroker-1.1"):NewDataObject("WSGPremade",
	{
		type = "data source",
		text = addonName,
		icon = "Interface\\Icons\\inv_cape_battlepvps1_d_01_horde",
		OnClick = function(self, button) 
			WSGPremadeGUI:Toggle()
		end,
	}), WSGPremade.db.minimapButton);
end
