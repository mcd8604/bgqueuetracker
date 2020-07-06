local GUI = {}
_G["BGQueueTrackerGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local tabGroup = nil
--local BGQueueTrackerGUI_UpdateInterval = 1.0;

function GUI:Show(skipUpdate, sort_column)
	mainFrame:Show()
end

function GUI:Hide()
	if (mainFrame) then
		mainFrame:Hide()
	end
end

function GUI:Toggle()
	if (mainFrame and mainFrame:IsShown()) then
		GUI:Hide()
	else
		GUI:Show()
	end
end

function GUI:Reset()
	GUI:PrepareGUI()
end

function GUI:PrepareGUI()
	self.groupList = {}
	self.playerTable = {}
	mainFrame = AceGUI:Create("Window")
	mainFrame:Hide()
	_G["BGQueueTrackerGUI_MainFrame"] = mainFrame
	tinsert(UISpecialFrames, "BGQueueTrackerGUI_MainFrame")	-- allow ESC close
	mainFrame:SetTitle("BG Queue Tracker")
	mainFrame:SetWidth(600)
	mainFrame:SetLayout("Fill")
	mainFrame:EnableResize(true)
	--mainFrame.TimeSinceLastUpdate = 0
	--mainFrame:SetCallback("OnUpdate", function(self, elapsed)
	--	print('OnUpdate')
	--	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed; 	  
	--	while (self.TimeSinceLastUpdate > BGQueueTrackerGUI_UpdateInterval) do
	--		local time = GetTime()
	--		for name, player in pairs(self.playerTable) do
	--			for bgid, label in pairs(player.bgLabels) do
	--				updateLabel(time, bgid, label)
	--			end
	--		end
	--	  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - BGQueueTrackerGUI_UpdateInterval;
	--	end
	--end)
	--mainFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

	--local button = AceGUI:Create("Button")
	--button:SetText("Clear")
	--button:SetFullWidth(true)
	--button:SetCallback("OnClick", function(self, elapsed)
	--	self.playerTable = {}
	--	scroll:ReleaseChildren()
	--end)
	--mainFrame:AddChild(button)

	self.tabsData = {
		{ value = "group",			displayText = "Queues",		create = self.CreateGroupTimesTable,frameWidth = 600 },
		--{ value = "friends",		displayText = "Friends",	create = self.CreateFriendsTable,	frameWidth = 600 },
		{ value = "Warsong Gulch",	displayText = "WSG History",create = self.CreateHistoryTable,	frameWidth = 600 },
		{ value = "Alterac Valley",	displayText = "AV History", create = self.CreateHistoryTable,	frameWidth = 600 },
		{ value = "Arathi Basin",	displayText = "AB History", create = self.CreateHistoryTable,	frameWidth = 600 },
		{ value = "log",			displayText = "Event Log", 	create = self.CreateEventLogTable,	frameWidth = 600 },
	}
	self:CreateTabGroup()
end

function GUI:CreateTabGroup()
	tabGroup = AceGUI:Create("TabGroup")
	local tabs = {}
	for i, tabData in ipairs(self.tabsData) do
		table.insert(tabs, { text = tabData.displayText, value = i })
	end
	tabGroup:SetTabs(tabs)
	tabGroup:SetLayout("Flow")
	tabGroup:SetCallback("OnGroupSelected", function (c, e, g) GUI:DrawScrollFrame(c, e, g) end)
	tabGroup:SetStatusTable({})
	mainFrame:AddChild(tabGroup)
	tabGroup:SelectTab(1)
end

function GUI:DrawScrollFrame(container, event, i)
	container:ReleaseChildren()
	local tabData = self.tabsData[i]
	mainFrame:SetWidth(tabData.frameWidth)
	tabData.create(self, tabData.value, container)
end

function GUI:CreateEventLogTable(map, container)

end

function GUI:CreateFriendsTable(value, container)
	--for name, player in pairs(self.playerTable) do
	--	GUI:DrawPlayerLabels(name, player, group, scroll)
	--end
end

function GUI:CreateHistoryTable(map, container)
	local fieldMetaData = {
		{ fieldName = "Queue Start", columnWidth = 120 },
		{ fieldName = "Initial Estimate", columnWidth = 90 },
		{ fieldName = "Final Estimate", columnWidth = 90 },
		{ fieldName = "Wait Time", columnWidth = 90 }
	}
	DisplayTable:new(container, fieldMetaData, GUI:CreateHistoryRows(map))
end

function GUI:CreateHistoryRows(map)
	local rowData = {}
	for i, queue in ipairs(BGQueueTracker.db.factionrealm.queueHistory[map]) do
		table.insert(rowData, {
			{ displayText = date("%x %X", queue.startTime or 0) },
			{ displayText = formatShortTime(queue.initialEst or 0) },
			{ displayText = formatShortTime(queue.finalEst or 0) },
			{ displayText = formatShortTime(queue.waitSeconds * 1000) }
		})
	end
	return { { groupHeading = '', rowData = rowData } }
end

function GUI:CreateGroupTimesTable(value, container)
	local fieldMetaData = { 
		{ fieldName = "Name", columnWidth = 80 },
		{ fieldName = "Warsong Gulch", columnWidth = 120 },
		{ fieldName = "Alterac Valley", columnWidth = 120 },
		{ fieldName = "Arathi Basin", columnWidth = 120 } 
	}
	DisplayTable:new(container, fieldMetaData, GUI:CreateGroupTimesGroups())
end

function GUI:CreateGroupTimesGroups()
	local rowDataArray = {}
	for i, group in ipairs(self.groupList) do
		local rows = {}
		for name, playerGroupData in pairs(group) do
			local player = self.playerTable[name]
			updatePlayerTime(player)
			table.insert(rows, GUI:CreatePlayerRow(name, player))
		end
		table.insert(rowDataArray, { groupHeading = 'Group', rowData = rows })
	end	
	return rowDataArray
end

function GUI:CreatePlayerRow(name, player)
	local row = { { displayText = name } }
	if(player) then
		for i, map in ipairs(BGQueueTracker.MapNames) do
			bg = player.bgs[map]
			field = { displayText = "" }
			if(bg) then 
				field = { 
					displayText = getBGText(player.elapsed, bg, false),
					toolTipFunction = GUI.appendQueueDataToTooltip,
					toolTipData = { map = map, data = bg, timeData = player.timeData[map] }
				}
			end
			table.insert(row, field)
		end
	end	
	return row
end

function GUI.appendQueueDataToTooltip(tooltip, queueData)
	local map = queueData.map
	local bgData = queueData.bgData
	local timeData = queueData.timeData
	local soloGroup = ''
	local paused = ''
	if bgData then
		if bgData.asGroup == true then
			soloGroup = '(Group)'
		else
			soloGroup = '(Solo)'
		end
		if not bgData.estTime or bgData.estTime == 0 then
			paused = '|cFFFF0000*Paused*'
		end
	end
	tooltip:AddDoubleLine(format("|r%s |cFF00CFCF%s", map, soloGroup), paused)
	if timeData then
		tooltip:AddDoubleLine("Start Time:", date("%x %X", timeData.startTime), 1,1,1, 1,1,1)
		local waitDuration = timeData.waitSeconds * 1000
		tooltip:AddDoubleLine("Time Waited:", formatShortTime(waitDuration), 1,1,1, 1,1,1)
		tooltip:AddDoubleLine("Initial Estimate:", formatShortTime(timeData.initialEst), 1,1,1, 1,1,1)
		tooltip:AddDoubleLine("Current Estimate:", formatShortTime(timeData.finalEst), 1,1,1, 1,1,1)
		if(timeData.queuePauses) then
			local totalPauseDuration = 0
			tooltip:AddLine(format("Pauses (%i)", #timeData.queuePauses), 1, 1, 1, 1, 1)
			for i, p in ipairs(timeData.queuePauses) do
				local pauseDuration = p.stop - p.start
				if(pauseDuration > 0) then
					totalPauseDuration = totalPauseDuration + pauseDuration
				end
				tooltip:AddLine(
					format(
						"(%s)",
						--"%s to %s (%s)", 
						--date("%H:%M:%S", timeData.startTime + p.start), 
						--date("%H:%M:%S", timeData.startTime + p.stop), 
						formatShortTime(pauseDuration)
					), 1, 1, 1, 1, 1)
			end
			tooltip:AddDoubleLine("Total Time Paused:", formatShortTime(totalPauseDuration), 1,1,1, 1,1,1)
			local adjustedEst = timeData.finalEst + totalPauseDuration
			--tooltip:AddDoubleLine("Adjusted Estimate:", formatShortTime(adjustedEst), 1,1,1, 0.5,0.5,1)
			if(timeData.confirmStartTime > 0) then
				tooltip:AddDoubleLine("Pop Time:", date("%X", timeData.confirmStartTime), 1,1,1, 1,1,1)
			else
				local remaining = adjustedEst - waitDuration
				r,g,b = 0.5,1,0.5
				local isNegative = remaining < 0
				local remainingPrefix = ''
				if isNegative then
					r,g,b = 1,0.5,0.5
					remainingPrefix = '-'
				end
				tooltip:AddDoubleLine("Remaining Time:", remainingPrefix..formatShortTime(math.abs(remaining)), 1,1,1, r,g,b)
				tooltip:AddDoubleLine("Expected Pop:", date("%X", GetServerTime() + (remaining/1000)), 1,1,1, 0.5,0.5,1)
			end
		end
	end
end

function GUI:SetPlayerData(playerName, bgData, groupData, bgTimes)
	player = self.playerTable[playerName]
	if player then
		--table.insert(player.bgs, bgData.bgid, bgData)
		player.bgs = bgData
		player.lastUpdate = GetTime()
		player.elapsed = 0
		player.timeData = bgTimes
	else
		player = {
			name = playerName,
			bgs = bgData,
			display = {},
			bgLabels = {},
			timeData = {},
			lastUpdate = GetTime(),
			elapsed = 0
		}
		self.playerTable[playerName] = player
	end
	GUI:AddGroup(groupData)
	--GUI:PopulateTree()

	-- Cause re-draw
	tabGroup:SelectTab(tabGroup.status.selected)
end

function GUI:AddGroup(groupData)
	if (groupData and next(groupData) ~= nil) then
		intersections = GUI:RemoveIntersectingGroups(groupData)
		table.insert(self.groupList, groupData)
	end
end

function GUI:RemoveIntersectingGroups(groupData)
	for i, group in ipairs(self.groupList) do
		local c = 0
		for playerName, playerData in pairs(groupData) do
			if(group[playerName] ~= nil) then
				c = c + 1
			end
		end
		if(c > 0) then
			table.remove(self.groupList, i)
		end
	end
end

function GUI:CreateBGLabel(map)
	local bgLabel = AceGUI:Create("Label")
	bgLabel:SetRelativeWidth(1)
	return bgLabel
end

function formatShortTime(milliseconds)
	local seconds = milliseconds / 1000
	local hours = 0
	local minutes = 0
	if( seconds >= 3600 ) then
		hours = floor(seconds / 3600)
		seconds = mod(seconds, 3600)
	end
	if( seconds >= 60 ) then
		minutes = floor(seconds / 60)
		seconds = mod(seconds, 60)
	end	
	--if( seconds < 0 ) then
	--	seconds = 0
	--end
	if( hours > 0 ) then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

function updatePlayerDisplay(player)
	if player then
		updatePlayerTime(player)
		for map, bgData in pairs(player.bgs) do
			player.bgLabels[map]:SetText(getBGText(player.elapsed, bgData, true))
		end
		-- Do a quick recheck incase the text got bigger in the update without something being removed/added
		--if( longestText < (self.text:GetStringWidth() + 10) ) then
		--	longestText = self.text:GetStringWidth() + 20
		--	mainFrame:SetWidth(longestText)
		--end
	end
end

function updatePlayerTime(player)
	if player then
		local time = GetTime()
		player.elapsed = player.elapsed + (time - player.lastUpdate)	
		player.lastUpdate = time
	end
end

function getBGText(elapsed, bgData, prependMap)
	local text = nil
	if(bgData) then
		if(bgData.suspendedQueue) then
			text = 'Suspended!'
		elseif(bgData.status == "active") then
			text = 'In BG'
		elseif(bgData.status == "confirm") then
			text = formatShortTime(bgData.confirmTime)
		elseif(bgData.status == "queued") then
			local curEstimate = ''
			if not bgData.estTime or bgData.estTime == 0 then
				curEstimate = 'Paused'
			else
				curEstimate = formatShortTime(bgData.estTime)
			end
			text = string.format("%s (%s)", formatShortTime(bgData.waitTime + elapsed or 0), curEstimate)
		end
		if(text ~= nil and prependMap) then
			text = string.format("%s: %s", bgData.map, text)
		end
	end
	return text
end