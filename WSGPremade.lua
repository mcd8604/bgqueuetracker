BGQueueTracker = LibStub("AceAddon-3.0"):NewAddon("BGQueueTracker", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local addonName = GetAddOnMetadata("BGQueueTracker", "Title");
local commPrefix = addonName .. "1";

local playerName = UnitName("player");
local playerBGTimes = {}
local prevBGData = {}
local groups = {}
-- NOTE: bgData.map is always empty when status is none, so bgid needs to be mapped to the
-- map name on queue start and looked up for queue end
local idMap = {}

function BGQueueTracker:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("BGQueueTrackerDB", {
		factionrealm = {
			queueHistory = { 
				["Warsong Gulch"]	= {},
				["Alterac Valley"]	= {},
				["Arathi Basin"]	= {} 
			},
			currentQueueTimes = {}
		}
	}, true)
	playerBGTimes = self.db.factionrealm.currentQueueTimes
	--self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	
	DrawMinimapIcon();
	BGQueueTrackerGUI:PrepareGUI()
end

function BGQueueTracker:OnEnable()
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	--self:RegisterEvent("FRIENDLIST_UPDATE");
	--ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, ...)
	--	return message:match("No player named") ~= nil
	--end)
end

function BGQueueTracker:Reload()
end

function BGQueueTracker:GROUP_ROSTER_UPDATE(event)
end

function BGQueueTracker:UPDATE_BATTLEFIELD_STATUS(event, bgid)
	BGQueueTracker:CheckBGStatus(bgid)
end

--function BGQueueTracker:FRIENDLIST_UPDATE()
--	if(nextBroadcastData ~= nil) then
--		local serializedData = BGQueueTracker:Serialize(nextBroadcastData)
--		nextBroadcastData = nil
--		BGQueueTracker:broadcastToFriends(serializedData)
--	end
--end

function BGQueueTracker:CheckBGStatus(bgid)
	local bgData = BGQueueTracker:GetBGStatus(bgid)
	BGQueueTracker:UpdatePlayerBGTimes(bgid, bgData)
	BGQueueTrackerGUI:SetPlayerData(playerName, bgData, playerBGTimes)
	--local serializedData = BGQueueTracker:Serialize(bgData, playerBGTimes)
	--BGQueueTracker:broadcastToGroup(serializedData)
	--BGQueueTracker:broadcastToFriends(serializedData)
	--nextBroadcastData = bgData
	--C_FriendList.ShowFriends()
end

function BGQueueTracker:GetBGStatus(bgid)
	local status, map, instanceID, isRegistered, suspendedQueue, queueType, gameType, role = GetBattlefieldStatus(bgid)
	local bgData = {
		status = status,
		map = map or idMap[bgid],
		instanceID = instanceID,
		isRegistered = isRegistered, 
		suspendedQueue = suspendedQueue, 
		queueType = queueType, 
		gameType = gameType, 
		role = role,
		confirmTime = GetBattlefieldPortExpiration(bgid),
		waitTime = GetBattlefieldTimeWaited(bgid),
		estTime = GetBattlefieldEstimatedWaitTime(bgid),
		groupData = BGQueueTracker:GetGroupData()
	}
	return bgData
end

function BGQueueTracker:UpdatePlayerBGTimes(bgid, bgData)
	local t = GetServerTime()
	--BGQueueTracker:Print(format('%s status=%s (%i)', bgData.map or '', bgData.status or '', bgData.waitTime))
	if(bgData.status == "none") then
		-- queue ended
		if bgData.map then
			BGQueueTracker:Print(format("ending queue: %s", bgData.map))
			table.insert(self.db.factionrealm.queueHistory[bgData.map], playerBGTimes[bgData.map])
			playerBGTimes[bgData.map] = nil
			idMap[bgid] = nil
		--else
		--	BGQueueTracker.Print(format('queue ended but %i is not mapped', bgid))
		end
	elseif(bgData.status == "queued") then
		if idMap[bgid] == nil then
			BGQueueTracker:Print("starting queue")
			BGQueueTracker:startQueue(bgData)
			idMap[bgid] = bgData.map
		end
		if(bgData.estTime > 0) then
			playerBGTimes[bgData.map].finalEst = bgData.estTime
		end
		playerBGTimes[bgData.map].waitSeconds = t - playerBGTimes[bgData.map].startTime
		BGQueueTracker:checkPause(bgData)
	elseif(bgData.status == "confirm") then
		playerBGTimes[bgData.map].confirmStartTime = t
		playerBGTimes[bgData.map].waitSeconds = t - playerBGTimes[bgData.map].startTime
		--BGQueueTracker:Print("confirm queue")
	elseif(bgData.status == "active") then
		--BGQueueTracker:Print("active queue")
		playerBGTimes[bgData.map].activeStartTime = t

		-- TODO move run time to different event handler
		--local runTime = GetBattlefieldInstanceRunTime() 
		--BGQueueTracker:Print(format('bg active: activeDuration=%i', runTime))
		--playerBGTimes[bgData.map].activeDuration = runTime
	end
	if bgData.map then
		prevBGData[bgData.map] = bgData
	end
end

function BGQueueTracker:startQueue(bgData)
	--BGQueueTracker:Print(format('new queue started: waitTime=%i', bgData.waitTime))
	-- track the duration in queue (wait time)
	-- track the durations that a queue is paused
	-- track the duration for an active BG
	local s = bgData.waitTime/1000
	playerBGTimes[bgData.map] = {
		startTime = GetServerTime() - s,
		waitSeconds = s,
		confirmStartTime = 0,
		initialEst = bgData.estTime,
		finalEst = bgData.estTime,
		currentPause = nil,
		queuePauses = {},
		activeStartTime = 0,
		activeDuration = 0
	}
	self.db.factionrealm.currentQueueTimes[bgData.map] = playerBGTimes[bgData.map]
end

function BGQueueTracker:checkPause(bgData)
	if prevBGData and prevBGData[bgData.map] and bgData.waitTime > 2000 then
		local timeData = playerBGTimes[bgData.map]
		local prev = prevBGData[bgData.map]
		-- new pause starts if prev data has est time > 0 and current data has est == 0
		if not timeData.currentPause and (prev.estTime and prev.estTime > 0) and (not bgData.estTime or bgData.estTime == 0) then
			timeData.currentPause = { start = bgData.waitTime, stop = 0 }
			--BGQueueTracker:Print(format('new pause: start=%i', bgData.waitTime))
		-- pause continues if prev data has est time == 0 and current data has est == 0	
		-- pause ends if prev data has est time == 0 and current data has est > 0
		elseif timeData.currentPause and (not prev.estTime or prev.estTime == 0) and (bgData.estTime and bgData.estTime > 0) then
			timeData.currentPause.stop = bgData.waitTime
			table.insert(timeData.queuePauses, timeData.currentPause)
			timeData.currentPause = nil
			--BGQueueTracker:Print(format('pause end: stop=%i', bgData.waitTime))
		end
		--if bgData.estTime == 0 and then
		--	local numPauses = #(playerBGTimes[bgData.map].queuePauses)
		--	if(numPauses == 0 or playerBGTimes[bgData.map].queuePauses[numPauses].stop > 0) then
		--		-- new pause started
		--		table.insert(playerBGTimes[bgData.map].queuePauses, { start = bgData.waitTime, stop = 0 })
		--		BGQueueTracker:Print(format('new pause: start=%i', bgData.waitTime))
		--	else
		--		-- last pause ended
		--		playerBGTimes[bgData.map].queuePauses[#playerBGTimes[bgData.map].queuePauses].stop = bgData.waitTime
		--		BGQueueTracker:Print(format('pause end: stop=%i', bgData.waitTime))
		--	end
		--end
	end
end

function BGQueueTracker:GetGroupData()
	groupData = {}
	numGroupMembers = GetNumGroupMembers()
	if numGroupMembers == 0 then 
		groupData[playerName] = {}
	else
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
	end
	return groupData
end

function BGQueueTracker:broadcastToChannel(channel, msg)
	--ListChannelByName(GetChannelName('BGQueueTracker'))
	return
end

function BGQueueTracker:broadcastToFriends(msg)
	for i = 1, 1024 do
		-- connected, name, className, area, notes, guid, level, dnd, afk, rafLinkType, mobile
		local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
		if(friendInfo and friendInfo.name and friendInfo.connected) then
			BGQueueTracker:SendCommMessage(commPrefix, msg, "WHISPER", friendInfo.name);
		end
	end
end

function BGQueueTracker:broadcastToGroup(msg)
	if (IsInRaid()) then
		BGQueueTracker:SendCommMessage(commPrefix, msg, "RAID");
	elseif (IsInGroup(LE_PARTY_CATEGORY_HOME)) then
		BGQueueTracker:SendCommMessage(commPrefix, msg, "PARTY");
	end
	--for i = 1, GetNumGroupMembers() do
	--	name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
	--	if name then
	--		if UnitIsSameServer(name) and name ~= playerName and online then
	--			BGQueueTracker:SendCommMessage(commPrefix, msg, "WHISPER", name);
	--		end
	--	end
	--end
end

function BGQueueTracker:OnCommReceive(prefix, message, distribution, sender)
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
		local ok, bgData, bgTimes = BGQueueTracker:Deserialize(message);
		if (not ok) then
			BGQueueTracker.Print(string.format('Could not deserialize data'))
			return;
		end
		if(bgData == nil) then
			BGQueueTracker.Print('bgData is nil')
			return
		end
		if (sender == UnitName("player")) then
			return;	-- Ignore broadcast messages from myself
		end
		BGQueueTrackerGUI:SetPlayerData(sender, bgData, bgTimes)
	end
end

-- CHAT COMMANDS
local options = {
	name = 'BGQueueTracker',
	type = 'group',
	args = {
		show = {
			type = 'execute',
			name = 'Show BGQueueTracker',
			desc = 'Show BGQueueTracker',
			func = function() BGQueueTrackerGUI:Toggle() end
		},
		purge = {
			type = 'execute',
			name = 'Purge Queue History',
			desc = 'Delete all historical queue data',
			func = function() 
				BGQueueTracker.db.factionrealm.queueHistory = { 
					["Warsong Gulch"]	= {},
					["Alterac Valley"]	= {},
					["Arathi Basin"]	= {} 
				}
			end
		}
	},
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("BGQueueTracker", options, {"BGQueueTracker", "bgq"})

function BGQueueTracker:PLAYER_DEAD()
end

-- Minimap icon
function DrawMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("BGQueueTracker", LibStub("LibDataBroker-1.1"):NewDataObject("BGQueueTracker",
	{
		type = "data source",
		text = addonName,
		icon = "Interface\\Icons\\inv_cape_battlepvps1_d_01_horde",
		OnClick = function(self, button) 
			BGQueueTrackerGUI:Toggle()
		end,
	}), BGQueueTracker.db.minimapButton);
end
