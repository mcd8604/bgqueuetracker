local GUI = {}
_G["WSGPremadeGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil
local bgLabels = {}
local WSGPremadeGUI_UpdateInterval = 1.0;

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
	mainFrame.TimeSinceLastUpdate = 0
	mainFrame:SetCallback("OnUpdate", function(self, elapsed)
		print('OnUpdate')
		self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed; 	  
		while (self.TimeSinceLastUpdate > WSGPremadeGUI_UpdateInterval) do
			local time = GetTime()
			for bgid, label in ipairs(bgLabels) do
				updateLabel(time, bgid, label)
			end
		  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - WSGPremadeGUI_UpdateInterval;
		end
	end)
	--mainFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

	local bgLabelGrp = AceGUI:Create("SimpleGroup")
	bgLabelGrp:SetFullWidth(true)
	bgLabelGrp:SetLayout("Flow")
	mainFrame:AddChild(bgLabelGrp)
	GUI:CreateBGLabel(1, bgLabelGrp)
	GUI:CreateBGLabel(2, bgLabelGrp)

	local button = AceGUI:Create("Button")
	button:SetText("Update")
	button:SetWidth(200)
	button:SetCallback("OnClick", function(self, elapsed)
		local time = GetTime()
		for bgid, label in ipairs(bgLabels) do
			updateLabel(time, bgid, label)
		end
	end)
	mainFrame:AddChild(button)
end

function GUI:CreateBGLabel(bgid, group)
	bgLabel = AceGUI:Create("Label")
	bgLabel:SetRelativeWidth(0.8)
	bgLabel:SetText('test')
	bgLabel.lastUpdate = GetTime()
	bgLabel.seconds = 0
	group:AddChild(bgLabel)
	table.insert(bgLabels, bgid, bgLabel)
end

function GUI:SetLabel(bgid, bgData)
	if(bgLabels[bgid] and bgData ) then
		bgLabels[bgid].bgData = bgData
	end
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

function updateLabel(time, bgid, label)
	label.seconds = label.seconds + (time - label.lastUpdate)	
	label.lastUpdate = time	
	text = ''
	bgData = label.bgData
	if(bgData.suspendedQueue) then
		text = string.format('%s: Suspended!', bgData.map)
	elseif( bgData.status == "active" and bgData.instanceID > 0 ) then
		text = string.format('%s: In BG', bgData.map)
	elseif( bgData.status == "confirm" ) then
		text = string.format("%s: %s", bgData.map, formatShortTime(bgData.confirmTime))
	elseif( bgData.status == "queued" ) then
		text = string.format("%s: %s (%s)", bgData.map, formatShortTime(bgData.waitTime + label.seconds or 0), formatShortTime(bgData.estTime or 0))
	end
	label:SetText(text)	
	-- Do a quick recheck incase the text got bigger in the update without something being removed/added
	--if( longestText < (self.text:GetStringWidth() + 10) ) then
	--	longestText = self.text:GetStringWidth() + 20
	--	mainFrame:SetWidth(longestText)
	--end
end