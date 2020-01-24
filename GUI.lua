local GUI = {}
_G["WSGPremadeGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local playerTable = {}
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
	mainFrame:SetWidth(600)
	mainFrame:SetLayout("List")
	mainFrame:EnableResize(false)
	--mainFrame.TimeSinceLastUpdate = 0
	--mainFrame:SetCallback("OnUpdate", function(self, elapsed)
	--	print('OnUpdate')
	--	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed; 	  
	--	while (self.TimeSinceLastUpdate > WSGPremadeGUI_UpdateInterval) do
	--		local time = GetTime()
	--		for bgid, label in ipairs(bgLabels) do
	--			updateLabel(time, bgid, label)
	--		end
	--	  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - WSGPremadeGUI_UpdateInterval;
	--	end
	--end)
	--mainFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

	local button = AceGUI:Create("Button")
	button:SetText("Update")
	button:SetWidth(200)
	button:SetCallback("OnClick", function(self, elapsed)
		for name, player in ipairs(playerTable) do
			updatePlayerDisplay(player)
		end
	end)
	mainFrame:AddChild(button)
end

function GUI:SetPlayerData(playerName, bgData)
	local player = playerTable[playerName]
	if player then
		--table.insert(player.bgs, bgData.bgid, bgData)
		player.bgs[bgData.bgid] = bgData
		player.lastUpdate = GetTime()
		player.elapsed = 0
	else
		g = GUI:CreatePlayerDisplayGroup(playerName)
		mainFrame:AddChild(g)
		player = {
			bgs = {},
			group = g,
			lastUpdate = GetTime(),
			elapsed = 0
		}
		player.bgs[bgData.bgid] = bgData
		playerTable[playerName] = player
	end
	updatePlayerDisplay(player)
end

function GUI:CreatePlayerDisplayGroup(playerName)
	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetLayout("Flow")
	playerLabel = AceGUI:Create("Label")
	playerLabel:SetRelativeWidth(0.8)
	playerLabel:SetText(playerName)
	group:AddChild(playerLabel)
	group.avLabel = GUI:CreateBGLabel(1)
	group:AddChild(group.avLabel)
	group.wsgLabel = GUI:CreateBGLabel(2)
	group:AddChild(group.wsgLabel)
	return group
end

function GUI:CreateBGLabel(bgid)
	local bgLabel = AceGUI:Create("Label")
	bgLabel:SetRelativeWidth(0.8)
	bgLabel:SetText('test')
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
		updatePlayerBGLabel(player.elapsed, player.bgs[1], player.group.avLabel)
		updatePlayerBGLabel(player.elapsed, player.bgs[2], player.group.wsgLabel)
		-- Do a quick recheck incase the text got bigger in the update without something being removed/added
		--if( longestText < (self.text:GetStringWidth() + 10) ) then
		--	longestText = self.text:GetStringWidth() + 20
		--	mainFrame:SetWidth(longestText)
		--end
	end
end

function updatePlayerBGLabel(elapsed, bgData, label)	
	text = ''
	if(bgData) then
		if(bgData.suspendedQueue) then
			text = string.format('%s: Suspended!', bgData.map)
		elseif( bgData.status == "active" and bgData.instanceID > 0 ) then
			text = string.format('%s: In BG', bgData.map)
		elseif( bgData.status == "confirm" ) then
			text = string.format("%s: %s", bgData.map, formatShortTime(bgData.confirmTime))
		elseif( bgData.status == "queued" ) then
			text = string.format("%s: %s (%s)", bgData.map, formatShortTime(bgData.waitTime + elapsed or 0), formatShortTime(bgData.estTime or 0))
		end
		label:SetText(text)	
	end
end