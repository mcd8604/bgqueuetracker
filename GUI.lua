local GUI = {}
_G["WSGPremadeGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame = nil

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

	-- Player Standings
	local playerStandingsGrp = AceGUI:Create("SimpleGroup")
	playerStandingsGrp:SetFullWidth(true)
	playerStandingsGrp:SetLayout("Flow")
	mainFrame:AddChild(playerStandingsGrp)

	playerStandings = AceGUI:Create("Label")
	playerStandings:SetRelativeWidth(0.8)
	playerStandings:SetText('Test')
	playerStandingsGrp:AddChild(playerStandings)
end
