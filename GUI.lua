local GUI = {}
_G["BGQueueTrackerGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local playerTable = {}
local groupList = {}
local tabGroup = nil
--local tree = {}
--local treeView = nil
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
	--		for name, player in pairs(playerTable) do
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
	--	playerTable = {}
	--	scroll:ReleaseChildren()
	--end)
	--mainFrame:AddChild(button)

	tabGroup = AceGUI:Create("TabGroup")
	tabGroup:SetTabs({
		{text="Group", value="group"}, 
		--{text="Friends", value="friends"}, 
		{text="WSG History", value="Warsong Gulch"}, 
		{text="AV History", value="Alterac Valley"}, 
		{text="AB History", value="Arathi Basin"}
	})
	tabGroup:SetLayout("Flow")
	tabGroup:SetCallback("OnGroupSelected", function (c, e, g) GUI:DrawScrollFrame(c, e, g) end)
	tabGroup:SetStatusTable({})
	mainFrame:AddChild(tabGroup)

	tabGroup:SelectTab("group")
end

function GUI:DrawScrollFrame(container, event, group)
	container:ReleaseChildren()
	scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	if group == "group" then
		mainFrame:SetWidth(600)
		--treeView = AceGUI:Create("TreeGroup")
		--treeView:SetTree(tree)
		--container:AddChild(treeView)
		local tableHeader = GUI:CreateTableHeader()
		container:AddChild(tableHeader)
		container:AddChild(scroll)
		GUI:DrawGroups(scroll)
	elseif group == "friends" then
		mainFrame:SetWidth(600)
		--for name, player in pairs(playerTable) do
		--	GUI:DrawPlayerLabels(name, player, group, scroll)
		--end
	elseif group == "Warsong Gulch" or group == "Alterac Valley" or group == "Arathi Basin" then
		GUI:DrawHistory(group, container, scroll)
		mainFrame:SetWidth(600)
	end
end

function GUI:CreateTableHeader()
	local tableHeader = AceGUI:Create("SimpleGroup")
	tableHeader:SetFullWidth(true)
	tableHeader:SetLayout("Flow")

	local btn = AceGUI:Create("Label")
	btn:SetWidth(80)
	btn:SetText("Name")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(120)
	btn:SetText("Warsong Gulch")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(120)
	btn:SetText("Alterac Valley")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(120)
	btn:SetText("Arathi Basin")
	tableHeader:AddChild(btn)
	
	return tableHeader
end

function GUI:DrawGroups(container)
	for i, group in ipairs(groupList) do
		local groupWidget = AceGUI:Create("SimpleGroup")
		groupWidget:SetFullWidth(true)
		local groupHeader = AceGUI:Create("Heading")
		groupHeader:SetText("Group")
		groupHeader:SetFullWidth(true)
		groupWidget:AddChild(groupHeader)
		updatePlayerTime(player)
		for name, playerGroupData in pairs(group) do
			local player = playerTable[name]
			local row = nil
			if(player) then
				row = GUI:CreatePlayerRow(name, player)
			else 
				row = GUI:CreatePlayerRow(name, nil)
			end
			groupWidget:AddChild(row)
		end
		container:AddChild(groupWidget)
	end	
end

function GUI:CreatePlayerRow(name, player)
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")

	local btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(80)
	btn:SetText(name)
	row:AddChild(btn)
	
	if(player) then
		for i, map in ipairs(BGQueueTracker.MapNames) do
			bg = player.bgs[map]
			btn = AceGUI:Create("InteractiveLabel")
			btn:SetWidth(120)
			if(bg) then 
				btn:SetText(getBGText(player.elapsed, bg, false))
				GUI:setTimeTooltip(btn, player.timeData[map])
			else
				btn:SetText("")
			end
			btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
			row:AddChild(btn)
		end
	end
	
	return row
end

function GUI:setTimeTooltip(widget, data)
	if(data) then
		widget:SetCallback("OnEnter", function (widget, event) 
			GameTooltip:SetOwner(mainFrame.frame, "ANCHOR_CURSOR");
			GameTooltip:SetText("Queue Details", 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine("Start Time:", date("%x %X", data.startTime), 1,1,1, 1,1,1)
			local waitDuration = data.waitSeconds * 1000
			GameTooltip:AddDoubleLine("Time Waited:", formatShortTime(waitDuration), 1,1,1, 1,1,1)
			GameTooltip:AddDoubleLine("Initial Estimate:", formatShortTime(data.initialEst), 1,1,1, 1,1,1)
			GameTooltip:AddDoubleLine("Current Estimate:", formatShortTime(data.finalEst), 1,1,1, 1,1,1)
			if(data.queuePauses) then
				local totalPauseDuration = 0
				GameTooltip:AddLine(format("Pauses (%i)", #data.queuePauses), 1, 1, 1, 1, 1)
				for i, p in ipairs(data.queuePauses) do
					local pauseDuration = p.stop - p.start
					if(pauseDuration > 0) then
						totalPauseDuration = totalPauseDuration + pauseDuration
					end
					GameTooltip:AddLine(
						format(
							"(%s)",
							--"%s to %s (%s)", 
							--date("%H:%M:%S", data.startTime + p.start), 
							--date("%H:%M:%S", data.startTime + p.stop), 
							formatShortTime(pauseDuration)
						), 1, 1, 1, 1, 1)
				end
				GameTooltip:AddDoubleLine("Total Time Paused:", formatShortTime(totalPauseDuration), 1,1,1, 1,1,1)
				local adjustedEst = data.finalEst + totalPauseDuration
				--GameTooltip:AddDoubleLine("Adjusted Estimate:", formatShortTime(adjustedEst), 1,1,1, 0.5,0.5,1)
				if(data.confirmStartTime > 0) then
					GameTooltip:AddDoubleLine("Pop Time:", date("%X", data.confirmStartTime), 1,1,1, 1,1,1)
				else
					local remaining = adjustedEst - waitDuration
					r,g,b = 0.5,1,0.5
					local isNegative = remaining < 0
					local remainingPrefix = ''
					if isNegative then
						r,g,b = 1,0.5,0.5
						remainingPrefix = '-'
					end
					GameTooltip:AddDoubleLine("Remaining Time:", remainingPrefix..formatShortTime(math.abs(remaining)), 1,1,1, r,g,b)
					GameTooltip:AddDoubleLine("Expected Pop:", date("%X", GetServerTime() + (remaining/1000)), 1,1,1, 0.5,0.5,1)
				end
			end
			GameTooltip:Show()
		end)
		widget:SetCallback("OnLeave", function (widget, event) GameTooltip:Hide() end)
	end
end

--function GUI:DrawPlayerLabel(name, player, currentTab, parentContainer)
--	local valid = false
--	if currentTab == "group" and (name == UnitName("player") or UnitInParty(name) or UnitInRaid(name)) then
--		valid = true
--	elseif currentTab == "friends" then
--		friendInfo = C_FriendList.GetFriendInfo(name) 
--		if(friendInfo and friendInfo.name) then 
--			valid = true
--		end
--	end
--	if(valid) then
--		player.display = GUI:CreatePlayerDisplay(player)
--		updatePlayerDisplay(player)
--		parentContainer:AddChild(player.display)
--	end
--end

function GUI:SetPlayerData(playerName, bgData, groupData, bgTimes)
	player = playerTable[playerName]
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
		playerTable[playerName] = player
	end
	GUI:AddGroup(groupData)
	--GUI:PopulateTree()

	-- Cause re-draw
	tabGroup:SelectTab(tabGroup.status.selected)
end

function GUI:AddGroup(groupData)
	if (groupData and next(groupData) ~= nil) then
		intersections = GUI:RemoveIntersectingGroups(groupData)
		table.insert(groupList, groupData)
	end
end

function GUI:RemoveIntersectingGroups(groupData)
	for i, group in ipairs(groupList) do
		local c = 0
		for playerName, playerData in pairs(groupData) do
			if(group[playerName] ~= nil) then
				c = c + 1
			end
		end
		if(c > 0) then
			table.remove(groupList, i)
		end
	end
end

--function GUI:PopulateTree()
--	if(treeView) then
--		tree = {}
--		--for i, group in ipairs(groupList) do
--		--	local groupNode = { children = {} }
--		--	updatePlayerTime(player)
--		--	for name, playerGroupData in pairs(group) do
--		--		print(name)
--		--		local playerNode = { 
--		--			value = name,
--		--			text = name,
--		--			children = {}
--		--		}
--		--		local player = playerTable[name]
--		--		if(player) then
--		--			for bgid, bgData in pairs(player.bgs) do
--		--				local bgNode = {
--		--					value = bgid,
--		--					text = getBGText(player.elapsed, bgData)
--		--				}
--		--				table.insert(playerNode.children, bgNode)
--		--			end
--		--			table.insert(groupNode.children, playerNode)
--		--		end
--		--	end
--		--	table.insert(tree, groupNode)
--		--end
--		--local groupNode = { children = {} }
--		for name, player in pairs(playerTable) do
--			local playerNode = createPlayerNode(player)
--			table.insert(tree, playerNode)
--		end
--		--table.insert(tree, groupNode)
--	end
--end

--function createPlayerNode(player)
--	local playerNode = {}
--	if(player) then
--		playerNode = { 
--			value = player.name,
--			text = player.name,
--			children = {}
--		}
--		for bgid, bgData in pairs(player.bgs) do
--			local bgNode = {
--				value = bgid,
--				text = getBGText(player.elapsed, bgData)
--			}
--			table.insert(playerNode.children, bgNode)
--		end
--	end
--	return playerNode
--end

function GUI:CreatePlayerDisplay(player)
	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")
	playerLabel = AceGUI:Create("Label")
	playerLabel:SetRelativeWidth(1)
	playerLabel:SetText(player.name)
	group:AddChild(playerLabel)
	for map, bgData in pairs(player.bgs) do
		if(bgData ~= nil) then
			bgLabel = GUI:CreateBGLabel(map)
			player.bgLabels[map] = bgLabel 
			group:AddChild(bgLabel)
		end
	end
	return group
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
	local time = GetTime()
	player.elapsed = player.elapsed + (time - player.lastUpdate)	
	player.lastUpdate = time
end

function getBGText(elapsed, bgData, prependMap)
	text = nil
	if(bgData) then
		if(bgData.suspendedQueue) then
			text = 'Suspended!'
		elseif(bgData.status == "active" and bgData.instanceID > 0) then
			text = 'In BG'
		elseif(bgData.status == "confirm") then
			text = formatShortTime(bgData.confirmTime)
		elseif(bgData.status == "queued") then
			text = string.format("%s (%s)", formatShortTime(bgData.waitTime + elapsed or 0), formatShortTime(bgData.estTime or 0))
		end
		if(text ~= nil and prependMap) then
			text = string.format("%s: %s", bgData.map, text)
		end
	end
	return text
end

function GUI:DrawHistory(map, container, scroll)
	local tableHeader = GUI:CreateHistoryTableHeader()
	container:AddChild(tableHeader)
	container:AddChild(scroll)	
	for i, queue in ipairs(BGQueueTracker.db.factionrealm.queueHistory[map]) do
		scroll:AddChild(GUI:CreateHistoryRow(queue))
	end	
end

function GUI:CreateHistoryTableHeader()
	local tableHeader = AceGUI:Create("SimpleGroup")
	tableHeader:SetFullWidth(true)
	tableHeader:SetLayout("Flow")

	local btn = AceGUI:Create("Label")
	btn:SetWidth(120)
	btn:SetText("Queue Start")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(90)
	btn:SetText("Initial Estimate")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(90)
	btn:SetText("Final Estimate")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(90)
	btn:SetText("Wait Time")
	tableHeader:AddChild(btn)
	
	return tableHeader
end

function GUI:CreateHistoryRow(queue)
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")

	local btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(120)
	btn:SetText(date("%x %X", queue.startTime or 0))
	row:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(90)
	btn:SetText(formatShortTime(queue.initialEst or 0))
	row:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(90)
	btn:SetText(formatShortTime(queue.finalEst or 0))
	row:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(90)
	btn:SetText(formatShortTime(queue.waitSeconds * 1000))
	row:AddChild(btn)
	
	return row
end