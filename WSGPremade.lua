WSGPremade = LibStub("AceAddon-3.0"):NewAddon("WSGPremade", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local addonName = GetAddOnMetadata("WSGPremade", "Title");
local commPrefix = addonName .. "1";

local playerName = UnitName("player");
local playerBGTimes = {}
local prevBGData = {}
local groups = {}

function WSGPremade:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WSGPremadeDB", {
		factionrealm = {
			queueHistory = { {}, {} },
			currentQueueTimes = {}
		}
	}, true)
	playerBGTimes = self.db.factionrealm.currentQueueTimes
	--self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	
	DrawMinimapIcon();
	WSGPremadeGUI:PrepareGUI()
end

function WSGPremade:OnEnable()
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	--self:RegisterEvent("FRIENDLIST_UPDATE");
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, ...)
		return message:match("No player named") ~= nil
	end)
end

function WSGPremade:Reload()
end

function WSGPremade:UPDATE_BATTLEFIELD_STATUS(event, bgid)
	if(bgid == 1 or bgid == 2) then
		WSGPremade:CheckBGStatus(bgid)
	end
end

--function WSGPremade:FRIENDLIST_UPDATE()
--	if(nextBroadcastData ~= nil) then
--		local serializedData = WSGPremade:Serialize(nextBroadcastData)
--		nextBroadcastData = nil
--		WSGPremade:broadcastToFriends(serializedData)
--	end
--end

function WSGPremade:CheckBGStatus(bgid)
	local bgData = WSGPremade:GetBGStatus(bgid)		
	WSGPremade:UpdatePlayerBGTimes(bgData)
	WSGPremadeGUI:SetPlayerData(playerName, bgData, playerBGTimes)
	local serializedData = WSGPremade:Serialize(bgData, playerBGTimes)
	WSGPremade:broadcastToGroup(serializedData)
	--WSGPremade:broadcastToFriends(serializedData)
	--nextBroadcastData = bgData
	--C_FriendList.ShowFriends()
end

function WSGPremade:GetBGStatus(bgid)
	local status, map, instanceID, isRegistered, suspendedQueue, queueType, gameType, role = GetBattlefieldStatus(bgid)
	local bgData = {
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

function WSGPremade:UpdatePlayerBGTimes(bgData)
	--WSGPremade:Print(format('%s status=%s (%i)', bgData.map or '', bgData.status or '', bgData.waitTime))
	if playerBGTimes[bgData.bgid] == nil then
		--WSGPremade:Print("starting queue")
		WSGPremade:startQueue(bgData)
	end
	playerBGTimes[bgData.bgid].waitDuration = bgData.waitTime
	if(bgData.estTime > 0) then
		playerBGTimes[bgData.bgid].finalEst = bgData.estTime
	end
	if(bgData.status == "none") then
		-- queue ended
		--WSGPremade:Print("ending queue")
		table.insert(self.db.factionrealm.queueHistory[bgData.bgid], playerBGTimes[bgData.bgid])
		playerBGTimes[bgData.bgid] = nil
	elseif(bgData.status == "queued") then
		WSGPremade:checkPause(bgData)
	elseif(bgData.status == "confirm") then
		--WSGPremade:Print("confirm queue")
	elseif(bgData.status == "active") then
		--WSGPremade:Print("active queue")
		local runTime = GetBattlefieldInstanceRunTime() 
		--WSGPremade:Print(format('bg active: activeDuration=%i', runTime))
		playerBGTimes[bgData.bgid].activeDuration = runTime
	end
	prevBGData[bgData.bgid] = bgData
end

function WSGPremade:startQueue(bgData)
	--WSGPremade:Print(format('new queue started: waitTime=%i', bgData.waitTime))
	-- track the duration in queue (wait time)
	-- track the durations that a queue is paused
	-- track the duration for an active BG
	playerBGTimes[bgData.bgid] = {
		startTime = GetServerTime() - bgData.waitTime,
		waitDuration = bgData.waitTime,
		initialEst = bgData.estTime,
		finalEst = bgData.estTime,
		currentPause = nil,
		queuePauses = {},
		activeDuration = 0
	}
	self.db.factionrealm.currentQueueTimes[bgData.bgid] = playerBGTimes[bgData.bgid]
end

function WSGPremade:checkPause(bgData)
	if prevBGData and prevBGData[bgData.bgid] and bgData.waitTime > 2000 then
		local timeData = playerBGTimes[bgData.bgid]
		local prev = prevBGData[bgData.bgid]
		-- new pause starts if prev data has est time > 0 and current data has est == 0
		if not timeData.currentPause and (prev.estTime and prev.estTime > 0) and (not bgData.estTime or bgData.estTime == 0) then
			timeData.currentPause = { start = bgData.waitTime, stop = 0 }
			--WSGPremade:Print(format('new pause: start=%i', bgData.waitTime))
		-- pause continues if prev data has est time == 0 and current data has est == 0	
		-- pause ends if prev data has est time == 0 and current data has est > 0
		elseif timeData.currentPause and (not prev.estTime or prev.estTime == 0) and (bgData.estTime and bgData.estTime > 0) then
			timeData.currentPause.stop = bgData.waitTime
			table.insert(timeData.queuePauses, timeData.currentPause)
			timeData.currentPause = nil
			--WSGPremade:Print(format('pause end: stop=%i', bgData.waitTime))
		end
		--if bgData.estTime == 0 and then
		--	local numPauses = #(playerBGTimes[bgData.bgid].queuePauses)
		--	if(numPauses == 0 or playerBGTimes[bgData.bgid].queuePauses[numPauses].stop > 0) then
		--		-- new pause started
		--		table.insert(playerBGTimes[bgData.bgid].queuePauses, { start = bgData.waitTime, stop = 0 })
		--		WSGPremade:Print(format('new pause: start=%i', bgData.waitTime))
		--	else
		--		-- last pause ended
		--		playerBGTimes[bgData.bgid].queuePauses[#playerBGTimes[bgData.bgid].queuePauses].stop = bgData.waitTime
		--		WSGPremade:Print(format('pause end: stop=%i', bgData.waitTime))
		--	end
		--end
	end
end

function WSGPremade:GetGroupData()
	groupData = {}
	for i = 1, GetNumGroupMembers() do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
		if name then
			_, realm = UnitName(name)
			-- realm is nil if they're from the same realm
			if realm == nil or realm == '' then
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

function WSGPremade:broadcastToChannel(channel, msg)
	--ListChannelByName(GetChannelName('wsgpremade'))
	return
end

function WSGPremade:broadcastToFriends(msg)
	for i = 1, 1024 do
		-- connected, name, className, area, notes, guid, level, dnd, afk, rafLinkType, mobile
		local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
		if(friendInfo and friendInfo.name and friendInfo.connected) then
			WSGPremade:SendCommMessage(commPrefix, msg, "WHISPER", friendInfo.name);
		end
	end
end

function WSGPremade:broadcastToGroup(msg)
	if (IsInRaid()) then
		WSGPremade:SendCommMessage(commPrefix, msg, "RAID");
	elseif (IsInGroup(LE_PARTY_CATEGORY_HOME)) then
		WSGPremade:SendCommMessage(commPrefix, msg, "PARTY");
	end
	--for i = 1, GetNumGroupMembers() do
	--	name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
	--	if name then
	--		if UnitIsSameServer(name) and name ~= playerName and online then
	--			WSGPremade:SendCommMessage(commPrefix, msg, "WHISPER", name);
	--		end
	--	end
	--end
end

function WSGPremade:OnCommReceive(prefix, message, distribution, sender)
	local validSource = false
	if (distribution == "WHISPER") then
		local friendInfo = C_FriendList.GetFriendInfo(sender)
		if(friendInfo and friendInfo.name and friendInfo.connected) then
			validSource = true;
		end
	elseif(distribution == "RAID" or distribution == "PARTY") then
		validSource = true
	end
	if(validSource) then
		--and (UnitInRaid(sender) or UnitInParty(sender))
		local ok, bgData, bgTimes = WSGPremade:Deserialize(message);
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
		WSGPremadeGUI:SetPlayerData(sender, bgData, bgTimes)
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
