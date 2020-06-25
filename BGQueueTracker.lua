BGQueueTracker = LibStub("AceAddon-3.0"):NewAddon("BGQueueTracker", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local addonName = GetAddOnMetadata("BGQueueTracker", "Title");
local commPrefix = addonName .. "1";

local playerName = UnitName("player");
local curBGData = {}
local prevBGData = {}
local groups = {}

function BGQueueTracker:OnInitialize()
	self.MapNames = {"Warsong Gulch", "Alterac Valley", "Arathi Basin"}
	self.db = LibStub("AceDB-3.0"):New("BGQueueTrackerDB", {
		factionrealm = {
			queueHistory = { 
				["Warsong Gulch"]	= {},
				["Alterac Valley"]	= {},
				["Arathi Basin"]	= {} 
			},
			minimapButton = {hide = false},
		}
	}, true)
	--self.states = {
	--	isConfirming = false,
	--	isActive = false
	--}
	--self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	
	DrawMinimapIcon();
	BGQueueTrackerGUI:PrepareGUI()
end

function BGQueueTracker:OnEnable()
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	self:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")	
	--self:RegisterEvent("UPDATE_ACTIVE_BATTLEFIELD")	
	--self:RegisterEvent("BATTLEFIELD_QUEUE_TIMEOUT")	
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

--function BGQueueTracker:FRIENDLIST_UPDATE()
--	if(nextBroadcastData ~= nil) then
--		local serializedData = BGQueueTracker:Serialize(nextBroadcastData)
--		nextBroadcastData = nil
--		BGQueueTracker:broadcastToFriends(serializedData)
--	end
--end

function BGQueueTracker:UPDATE_BATTLEFIELD_STATUS(event, battleFieldIndex)
	-- ignore the first status update when entering a BG, because it will be a 'none' status and cause the queues to end prematurely
	--if isEnteringBG then
	--	if GetBattlefieldInstanceRunTime() > 0 then
	--		BGQueueTracker:Print("finished entering")
	--		isEnteringBG = false
	--	else
	--		BGQueueTracker:Print("still entering")
	--	end
	--else
		--BGQueueTracker:Print("UPDATE_BATTLEFIELD_STATUS")
		--local instance, instanceType = IsInInstance();
		--self.states.isActive = instance and instanceType == "pvp"

		prevBGData = curBGData
		curBGData = {}
		--GetMaxBattlefieldId()=3
		for i=1,3 do
			bgData = BGQueueTracker:GetBGStatus(i)
			if bgData.map then
				curBGData[bgData.map] = bgData
			end
		end
		curTimeData = BGQueueTracker:UpdatePlayerBGTimes()
		groupData = BGQueueTracker:GetGroupData()
		BGQueueTrackerGUI:SetPlayerData(playerName, curBGData, groupData, curTimeData)
		
		--local serializedData = BGQueueTracker:Serialize(bgData, self.db.factionrealm.currentQueueTimes)
		--BGQueueTracker:broadcastToGroup(serializedData)
		--BGQueueTracker:broadcastToFriends(serializedData)
		--nextBroadcastData = bgData
		--C_FriendList.ShowFriends()
	--end
end

function BGQueueTracker:PLAYER_ENTERING_BATTLEGROUND(event)
	BGQueueTracker:Print("PLAYER_ENTERING_BATTLEGROUND")
	--self.states.isConfirming = false
	--self.states.isActive = true
end

function BGQueueTracker:UPDATE_ACTIVE_BATTLEFIELD(event)
	BGQueueTracker:Print("UPDATE_ACTIVE_BATTLEFIELD")
end

function BGQueueTracker:BATTLEFIELD_QUEUE_TIMEOUT(event)
	BGQueueTracker:Print("BATTLEFIELD_QUEUE_TIMEOUT")
end

function BGQueueTracker:GetBGStatus(battleFieldIndex)
	local status, map, teamSize, registeredMatch, suspendedQueue, queueType, gameType, unknown, role, asGroup, shortDescription, longDescription = GetBattlefieldStatus(battleFieldIndex)
	local bgData = {
		status = status,
		map = map,
		instanceID = instanceID,
		isRegistered = isRegistered, 
		suspendedQueue = suspendedQueue, 
		queueType = queueType, 
		gameType = gameType, 
		role = role,
		asGroup = asGroup,
		confirmTime = GetBattlefieldPortExpiration(battleFieldIndex),
		waitTime = GetBattlefieldTimeWaited(battleFieldIndex),
		estTime = GetBattlefieldEstimatedWaitTime(battleFieldIndex)
	}
	return bgData
end

function BGQueueTracker:UpdatePlayerBGTimes()
	local t = GetServerTime()
	local curTimeData = {}
	for i, map in ipairs(self.MapNames) do
		local mapCurTimeData = self.db.factionrealm.queueHistory[map][1]
		if curBGData[map] then
			local bgData = curBGData[map]
			--BGQueueTracker:Print(format('%s status=%s (%i)', bgData.map or '', bgData.status or '', bgData.waitTime))
			if(bgData.status == "queued") then
				-- check for new queue only if not in a BG
				if UnitInBattleground('player') == nil then --and self.states.isConfirming == false and self.states.isActive == false then
					-- if the current queue for this map is active or confirm status (meaning the last queue finished already)
					local isNewQueue = mapCurTimeData == nil or mapCurTimeData.confirmStartTime > 0 or mapCurTimeData.activeStartTime > 0
					if isNewQueue == false then
						-- or if the startTime is different (meaning the last one was canceled and this is a new entry)
						-- if the startTime of the new bgData precedes the receipt time of the last time data, then it's likely the same queue entry
						local startTime = t - (bgData.waitTime/1000)
						local lastReceiptTime = mapCurTimeData.startTime + mapCurTimeData.waitSeconds
						isNewQueue = startTime > lastReceiptTime and mapCurTimeData.waitSeconds > 15
						--BGQueueTracker:Print(format("Queue start time diff: %i", diff))
						--isNewQueue = diff > 1
					end
					-- then start a new queue
					if isNewQueue then
						mapCurTimeData = BGQueueTracker:startQueue(bgData)
						table.insert(self.db.factionrealm.queueHistory[map], 1, mapCurTimeData)
					end
				end
				if(bgData.estTime > 0) then
					mapCurTimeData.finalEst = bgData.estTime
				end
				-- why am i not just using bgData.waitTime/1000?
				-- note - this should be calculated periodically in a separate update and re-drawn in the UI
				mapCurTimeData.waitSeconds = t - mapCurTimeData.startTime
				BGQueueTracker:checkPause(bgData)
			elseif(bgData.status == "confirm") then
				--self.states.isConfirming = true
				--self.states.isActive = false
				mapCurTimeData.confirmStartTime = t
				mapCurTimeData.waitSeconds = t - mapCurTimeData.startTime
				--BGQueueTracker:Print("confirm queue")
			elseif(bgData.status == "active") then
				--self.states.isConfirming = false
				--self.states.isActive = true
				--BGQueueTracker:Print("active queue")
				mapCurTimeData.activeStartTime = t
				-- TODO move run time to different event handler
				--local runTime = GetBattlefieldInstanceRunTime() 
				--BGQueueTracker:Print(format('bg active: activeDuration=%i', runTime))
				--mapCurTimeData.activeDuration = runTime
			elseif(bgData.status == "none") then
				BGQueueTracker:Print(format("Queue Status 'none': %s", map))
			end
			self.db.factionrealm.queueHistory[map][1] = mapCurTimeData
			curTimeData[map] = mapCurTimeData
		--else
		--	-- track a grace period and if it has passed, end the queue
		--	if mapCurTimeData.endingTimestamp <= 0 then
		--		mapCurTimeData.endingTimestamp = t
		--	elseif t - mapCurTimeData.endingTimestamp > 2000 then
		--		-- queue ended
		--		BGQueueTracker:Print(format("Ending Queue: %s", map))
		--		-- TODO - think.. does it actually need to end?
		--	end
		end
	end
	return curTimeData
end

function BGQueueTracker:startQueue(bgData)
	--BGQueueTracker:Print(format("Starting New Queue: %s", bgData.map))
	--BGQueueTracker:Print(format('new queue started: waitTime=%i', bgData.waitTime))
	-- track the duration in queue (wait time)
	-- track the durations that a queue is paused
	-- track the duration for an active BG
	local s = bgData.waitTime/1000
	local newTimesData = {
		startTime = GetServerTime() - s,
		waitSeconds = s,
		confirmStartTime = 0,
		initialEst = bgData.estTime,
		finalEst = bgData.estTime,
		currentPause = nil,
		queuePauses = {},
		activeStartTime = 0,
		activeDuration = 0,
		endingTimestamp = 0
	}
	return newTimesData
end

function BGQueueTracker:checkPause(bgData)
	if prevBGData and prevBGData[bgData.map] and bgData.waitTime > 2000 then
		local timeData = self.db.factionrealm.queueHistory[bgData.map][1]
		local prev = prevBGData[bgData.map]
		local curPause = timeData.queuePauses[1]
		-- new pause starts if prev data has est time > 0 and current data has est == 0
		if (not curPause or curPause.ended) and (prev.estTime and prev.estTime > 0) and (not bgData.estTime or bgData.estTime == 0) then
			table.insert(timeData.queuePauses, 1, { start = bgData.waitTime, stop = bgData.waitTime, ended = false })
			--BGQueueTracker:Print(format('new pause: start=%i', bgData.waitTime))		
		elseif curPause and (not prev.estTime or prev.estTime == 0) then			
			-- pause continues if prev data has est time == 0 and current data has est == 0	
			timeData.queuePauses[1].stop = bgData.waitTime
			-- pause ends if prev data has est time == 0 and current data has est > 0
			if (bgData.estTime and bgData.estTime > 0) then
				timeData.queuePauses[1].ended = true
				--BGQueueTracker:Print(format('pause end: stop=%i', bgData.waitTime))
			end
		end
		--if bgData.estTime == 0 and then
		--	local numPauses = #(self.db.factionrealm.currentQueueTimes[bgData.map].queuePauses)
		--	if(numPauses == 0 or self.db.factionrealm.currentQueueTimes[bgData.map].queuePauses[numPauses].stop > 0) then
		--		-- new pause started
		--		table.insert(self.db.factionrealm.currentQueueTimes[bgData.map].queuePauses, { start = bgData.waitTime, stop = 0 })
		--		BGQueueTracker:Print(format('new pause: start=%i', bgData.waitTime))
		--	else
		--		-- last pause ended
		--		self.db.factionrealm.currentQueueTimes[bgData.map].queuePauses[#self.db.factionrealm.currentQueueTimes[bgData.map].queuePauses].stop = bgData.waitTime
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
		icon = "Interface\\Icons\\ability_townwatch",
		OnClick = function(self, button) 
			--if (button == "RightButton") then
			--elseif (button == "MiddleButton") then
			BGQueueTrackerGUI:Toggle()
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(format("%s", addonName));
			tooltip:AddLine("|cFFCFCFCFLeft Click: |rOpen BG Queue Tracker");
			--GetMaxBattlefieldId()=3
			for map, data in pairs(curBGData) do
				BGQueueTracker:Print(data.asGroup)
				timeData = BGQueueTracker.db.factionrealm.queueHistory[map][1]
				if timeData then
					tooltip:AddLine(' ')
					BGQueueTrackerGUI:appendQueueDataToTooltip(tooltip, map, data, timeData)
				end
			end
		end
	}), BGQueueTracker.db.factionrealm.minimapButton);
end
