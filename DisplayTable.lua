
local AceGUI = LibStub("AceGUI-3.0")

DisplayTable = {}

--	container is any parent GUI Widget
--	fieldMetaDataExample = {
--		[1] = { fieldName = 'field 1', columnWidth = 100 },
--		[2] = { fieldName = 'field 2', columnWidth = 200 },
--		[3] = { fieldName = 'field 3', columnWidth = 300 }
--	}
--	rowDataArrayExample = {
--		[1] = { 
--			groupHeading = 'Heading Text',
--			rowData = {
--				[1] = { 
--					[1] = { displayText = 'row1_field1Value', toolTipFunction = functionReference, toolTipData = functionInput1 },
--					[2] = { displayText = 'row1_field2Value', toolTipFunction = functionReference, toolTipData = functionInput2 },
--					[3] = { displayText = 'row1_field3Value', toolTipFunction = functionReference, toolTipData = functionInput3 }
--				},
--				[..]
--			}
--		},
--		[..]
--	}
function DisplayTable:new(container, fieldMetaData, rowDataArray)
	newObject = {}
	setmetatable(newObject, self)
	self.__index = self
	newObject.container = container
	newObject.fieldMetaData = fieldMetaData or {}
	newObject.rowDataArray = rowDataArray or {}
	newObject:CreateHeader()
	newObject:CreateScrollFrame()
	return newObject
end

function DisplayTable:CreateHeader() 
	self.tableHeader = AceGUI:Create("SimpleGroup")
	self.tableHeader:SetFullWidth(true)
	self.tableHeader:SetLayout("Flow")	
	for i, metaData in ipairs(self.fieldMetaData) do
		local label = AceGUI:Create("Label")
		label:SetText(metaData.fieldName)
		label:SetWidth(metaData.columnWidth)
		self.tableHeader:AddChild(label)
	end
	self.container:AddChild(self.tableHeader)
end

function DisplayTable:CreateScrollFrame()
	self.scrollFrame = AceGUI:Create("ScrollFrame")
	self.scrollFrame:SetLayout("Flow")
	self.scrollFrame:SetFullWidth(true)
	self.scrollFrame:SetFullHeight(true)
	self.container:AddChild(self.scrollFrame)
	self:CreateRowGroups()
end

function DisplayTable:CreateRowGroups()
	for groupIndex, group in ipairs(self.rowDataArray) do
		local groupWidget = AceGUI:Create("SimpleGroup")
		groupWidget:SetFullWidth(true)
		if group.groupHeading then
			groupWidget:AddChild(self:CreateGroupHeading(group.groupHeading))
		end
		for groupRowIndex, rowData in ipairs(group.rowData or {}) do
			groupWidget:AddChild(self:CreateRow(rowData))
		end
		self.scrollFrame:AddChild(groupWidget)
	end
end

function DisplayTable:CreateGroupHeading(headingText)
	local groupHeading = AceGUI:Create("Heading")
	groupHeading:SetText(headingText)
	groupHeading:SetFullWidth(true)
	return groupHeading
end

function DisplayTable:CreateRow(rowData)
	local row = AceGUI:Create("SimpleGroup")
	row:SetFullWidth(true)
	row:SetLayout("Flow")
	for i, cellData in ipairs(rowData) do
		row:AddChild(self:CreateCell(i, cellData))
	end
	return row
end

function DisplayTable:CreateCell(columnIndex, cellData)
	local iLabel = nil
	if columnIndex and cellData then
		local metaData = self.fieldMetaData[columnIndex]
		if metaData then
			iLabel = AceGUI:Create("InteractiveLabel")
			iLabel:SetWidth(metaData.columnWidth)
			iLabel:SetText(cellData.displayText)
			-- TODO configure highlight color
			iLabel.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
			if cellData.toolTipFunction and cellData.toolTipData then
				self:SetCellTooltip(iLabel, cellData)
			end
		end
	end
	return iLabel
end

function DisplayTable:SetCellTooltip(cellWidget, cellData)
	cellWidget:SetCallback("OnEnter", function (widget, event) 
		GameTooltip:SetOwner(self.container.frame, "ANCHOR_CURSOR");
		cellData.toolTipFunction(GameTooltip, cellData.toolTipData)
		GameTooltip:Show()
	end)
	cellWidget:SetCallback("OnLeave", function (widget, event) GameTooltip:Hide() end)
end