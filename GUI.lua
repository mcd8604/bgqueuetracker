local GUI = {}
_G["WSGPremadeGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local playerTable = {}
local groupList = {}
local tabGroup = nil
--local tree = {}
--local treeView = nil
--local WSGPremadeGUI_UpdateInterval = 1.0;

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
	_G["WSGPremadeGUI_MainFrame"] = mainFrame
	tinsert(UISpecialFrames, "WSGPremadeGUI_MainFrame")	-- allow ESC close
	mainFrame:SetTitle("WSG Premade")
	mainFrame:SetWidth(420)
	mainFrame:SetLayout("Fill")
	mainFrame:EnableResize(true)
	--mainFrame.TimeSinceLastUpdate = 0
	--mainFrame:SetCallback("OnUpdate", function(self, elapsed)
	--	print('OnUpdate')
	--	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed; 	  
	--	while (self.TimeSinceLastUpdate > WSGPremadeGUI_UpdateInterval) do
	--		local time = GetTime()
	--		for name, player in pairs(playerTable) do
	--			for bgid, label in pairs(player.bgLabels) do
	--				updateLabel(time, bgid, label)
	--			end
	--		end
	--	  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - WSGPremadeGUI_UpdateInterval;
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
	tabGroup:SetTabs({{text="Group", value="group"}, {text="Friends", value="friends"}})
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
		--treeView = AceGUI:Create("TreeGroup")
		--treeView:SetTree(tree)
		--container:AddChild(treeView)
		local tableHeader = GUI:CreateTableHeader()
		container:AddChild(tableHeader)
		container:AddChild(scroll)
		GUI:DrawGroups(scroll)
	elseif currentTab == "friends" then
		--for name, player in pairs(playerTable) do
		--	GUI:DrawPlayerLabels(name, player, group, scroll)
		--end
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
	btn:SetText("Alterac Valley")
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("Label")
	btn:SetWidth(120)
	btn:SetText("Warsong Gulch")
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
				row = GUI:CreatePlayerRow(name, player.elapsed, player.bgs[1], player.bgs[2])
			else 
				row = GUI:CreatePlayerRow(name, 0, nil, nil)
			end
			groupWidget:AddChild(row)
		end
		container:AddChild(groupWidget)
	end	
end

function GUI:CreatePlayerRow(name, elapsed, av, wsg)
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")

	local btn = AceGUI:Create("Label")
	btn:SetWidth(80)
	btn:SetText(name)
	row:AddChild(btn)
	
	if(elapsed) then
		if(av) then 
			btn = AceGUI:Create("Label")
			btn:SetWidth(120)
			btn:SetText(getBGText(elapsed, av, false))
			row:AddChild(btn)
		end
		if(wsg) then
			btn = AceGUI:Create("Label")
			btn:SetWidth(120)
			btn:SetText(getBGText(elapsed, wsg, false))
			row:AddChild(btn)
		end
	end
	
	return row
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

function GUI:SetPlayerData(playerName, bgData)
	player = playerTable[playerName]
	if player then
		--table.insert(player.bgs, bgData.bgid, bgData)
		player.bgs[bgData.bgid] = bgData
		player.lastUpdate = GetTime()
		player.elapsed = 0
	else
		player = {
			name = playerName,
			bgs = {},
			display = {},
			bgLabels = {},
			lastUpdate = GetTime(),
			elapsed = 0
		}
		player.bgs[bgData.bgid] = bgData
		playerTable[playerName] = player
	end
	GUI:AddGroup(bgData.groupData)
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
	for bgid, bgData in pairs(player.bgs) do
		if(bgData ~= nil) then
			bgLabel = GUI:CreateBGLabel(bgid)
			player.bgLabels[bgid] = bgLabel 
			group:AddChild(bgLabel)
		end
	end
	return group
end

function GUI:CreateBGLabel(bgid)
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
	if( seconds < 0 ) then
		seconds = 0
	end
	if( hours > 0 ) then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

function updatePlayerDisplay(player)
	if player then
		updatePlayerTime(player)
		for bgid, bgData in pairs(player.bgs) do
			player.bgLabels[bgid]:SetText(getBGText(player.elapsed, bgData, true))
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