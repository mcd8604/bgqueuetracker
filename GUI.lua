local GUI = {}
_G["WSGPremadeGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local playerTable = {}
local tabGroup = nil
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
	mainFrame:SetWidth(240)
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
	tabGroup:SetLayout("Fill")
	tabGroup:SetCallback("OnGroupSelected", function (c, e, g) GUI:DrawScrollListItems(c, e, g) end)
	tabGroup:SetStatusTable({})
	mainFrame:AddChild(tabGroup)

	tabGroup:SelectTab("group")
end

function GUI:DrawScrollListItems(container, event, group)
	container:ReleaseChildren()
	scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	container:AddChild(scroll)
	for name, player in pairs(playerTable) do
		local valid = false
		if group == "group" and (name == UnitName("player") or UnitInParty(name) or UnitInRaid(name)) then
			valid = true
		elseif group == "friends" then
			friendInfo = C_FriendList.GetFriendInfo(name) 
			if(friendInfo and friendInfo.name) then 
				valid = true
			end
		end
		if(valid) then
			player.display = GUI:CreatePlayerDisplay(player)
			updatePlayerDisplay(player)
			scroll:AddChild(player.display)
		end
	end
end

function GUI:SetGroupData(playerName, groupData)

end

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
	tabGroup:SelectTab(tabGroup.status.selected)
end

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
		local time = GetTime()
		player.elapsed = player.elapsed + (time - player.lastUpdate)	
		player.lastUpdate = time
		for bgid, bgData in pairs(player.bgs) do
			updatePlayerBGLabel(player.elapsed, bgData, player.bgLabels[bgid])
		end
		-- Do a quick recheck incase the text got bigger in the update without something being removed/added
		--if( longestText < (self.text:GetStringWidth() + 10) ) then
		--	longestText = self.text:GetStringWidth() + 20
		--	mainFrame:SetWidth(longestText)
		--end
	end
end

function updatePlayerBGLabel(elapsed, bgData, label)	
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
		if(text ~= nil) then
			label:SetText(string.format("- %s: %s", bgData.map, text))
		end
	end
end