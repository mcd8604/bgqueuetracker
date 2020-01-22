WSGPremade = LibStub("AceAddon-3.0"):NewAddon("WSGPremade", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local addonName = GetAddOnMetadata("WSGPremade", "Title");
local commPrefix = addonName .. "4";

local playerName = UnitName("player");

function WSGPremade:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WSGPremadeDB", {
		factionrealm = {
			channelName = "WSGPremade"
		}
	}, true)

	--self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
	--ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_FILTER);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");

	DrawMinimapIcon();
	WSGPremadeGUI:PrepareGUI()
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

function WSGPremade:OnCommReceive(prefix, message, distribution, sender)
	--if (distribution == "WHISPER") then
	--end
end

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
