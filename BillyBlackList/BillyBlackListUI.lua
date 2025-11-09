--[[
	BillyBlackList UI - pfUI Integration & Frame Management
	
	COMPATIBILITY NOTES:
	- WoW 1.12 (Classic) / Turtle WoW
	- Lua 5.0: Use table.getn() not #, getglobal() not _G[]
	- Frame System: DIALOG strata, UIParent parent, OnUpdate for timers
	- pfUI Integration: Optional styling addon (detect via pfUI global)
	- UIDropDownMenu: Classic dropdown system for selections
	- FauxScrollFrame: For scrollable lists (use FauxScrollFrame_Update)
	
	Integration features:
	- Hooks into BlackList frame initialization like pfUI does for Blizzard frames
	- Uses pfUI's SkinTab, CreateBackdrop, and SkinButton functions
	- Maintains full compatibility without pfUI
--]]

local SelectedIndex = 1;
BLACKLISTS_TO_DISPLAY = 18;
FRIENDS_FRAME_BLACKLIST_HEIGHT = 16;

Classes = {"", "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"};
Races = {"", "Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Orc", "Undead", "Tauren", "Troll", "Blood Elf"};

-- pfUI Integration - Modern approach using hooks like pfUI does
local function IsPfUIActive()
	return pfUI and pfUI.api and pfUI.api.CreateBackdrop
end

local function StyleBlackListFrames()
	if not IsPfUIActive() then return end
	
	-- Style the main options frame
	if BlackListOptionsFrame and not BlackListOptionsFrame.pfuiStyled then
		pfUI.api.CreateBackdrop(BlackListOptionsFrame, nil, true)
		pfUI.api.CreateBackdropShadow(BlackListOptionsFrame)
		BlackListOptionsFrame.pfuiStyled = true
	end
	
	-- Style the details frame  
	if BlackListDetailsFrame and not BlackListDetailsFrame.pfuiStyled then
		pfUI.api.CreateBackdrop(BlackListDetailsFrame, nil, true)
		pfUI.api.CreateBackdropShadow(BlackListDetailsFrame)
		BlackListDetailsFrame.pfuiStyled = true
	end
	
	-- Get pfUI's border size for consistent tab spacing (using pfUI's GetBorderSize function)
	local rawborder, border = 1, 1
	if pfUI.api.GetBorderSize then
		rawborder, border = pfUI.api.GetBorderSize()
	end
	local tabSpacing = border * 2 + 1
	
	-- If spacing is too small, use a minimum value that looks good
	if tabSpacing < 5 then
		tabSpacing = 6  -- Reasonable default that matches pfUI's visual style
	end
	
	-- Style ALL the BlackList tabs to match pfUI tabs
	if FriendFrameToggleTab3 and not FriendFrameToggleTab3.pfuiStyled then
		pfUI.api.SkinTab(FriendFrameToggleTab3)
		-- Reposition with pfUI's spacing calculation
		FriendFrameToggleTab3:ClearAllPoints()
		FriendFrameToggleTab3:SetPoint("LEFT", FriendsFrameToggleTab2, "RIGHT", tabSpacing, 0)
		FriendFrameToggleTab3.pfuiStyled = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled FriendFrameToggleTab3 with spacing=" .. tabSpacing)
	end
	
	if IgnoreFrameToggleTab3 and not IgnoreFrameToggleTab3.pfuiStyled then
		pfUI.api.SkinTab(IgnoreFrameToggleTab3)
		-- Reposition with pfUI's spacing calculation
		IgnoreFrameToggleTab3:ClearAllPoints()
		IgnoreFrameToggleTab3:SetPoint("LEFT", IgnoreFrameToggleTab2, "RIGHT", tabSpacing, 0)
		IgnoreFrameToggleTab3.pfuiStyled = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled IgnoreFrameToggleTab3 with spacing=" .. tabSpacing)
	end
	
	if BlackListFrameToggleTab3 and not BlackListFrameToggleTab3.pfuiStyled then
		pfUI.api.SkinTab(BlackListFrameToggleTab3)
		BlackListFrameToggleTab3.pfuiStyled = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled BlackListFrameToggleTab3")
	end
	
	-- Style the BlackListFrame's own tabs (when viewing the BlackList tab)
	-- These are: BlackListFrameToggleTab1 (Friends), BlackListFrameToggleTab2 (Ignore), BlackListFrameToggleTab3 (BlackList)
	local blTab1 = getglobal("BlackListFrameToggleTab1")
	if blTab1 and not blTab1.pfuiStyledInternal then
		pfUI.api.SkinTab(blTab1)
		-- Position it like pfUI does: anchor to scroll frame
		blTab1:ClearAllPoints()
		blTab1:SetPoint("BOTTOMLEFT", FriendsFrameBlackListScrollFrame, "TOPLEFT", 0, tabSpacing)
		blTab1.pfuiStyledInternal = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled BlackListFrameToggleTab1 with spacing=" .. tabSpacing)
	end
	
	local blTab2 = getglobal("BlackListFrameToggleTab2")
	if blTab2 and not blTab2.pfuiStyledInternal then
		pfUI.api.SkinTab(blTab2)
		-- Reposition with pfUI's spacing calculation
		blTab2:ClearAllPoints()
		blTab2:SetPoint("LEFT", blTab1, "RIGHT", tabSpacing, 0)
		blTab2.pfuiStyledInternal = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled BlackListFrameToggleTab2 with spacing=" .. tabSpacing)
	end
	
	local blTab3 = getglobal("BlackListFrameToggleTab3")
	if blTab3 and not blTab3.pfuiStyledInternal then
		pfUI.api.SkinTab(blTab3)
		-- Reposition with pfUI's spacing calculation
		blTab3:ClearAllPoints()
		blTab3:SetPoint("LEFT", blTab2, "RIGHT", tabSpacing, 0)
		blTab3.pfuiStyledInternal = true
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Styled BlackListFrameToggleTab3 with spacing=" .. tabSpacing)
	end
end

-- Delayed styling function to ensure pfUI and tabs are ready
local function DelayedStyleTabs()
	local attempts = 0
	local maxAttempts = 10
	
	local styler = CreateFrame("Frame")
	styler:SetScript("OnUpdate", function()
		attempts = attempts + 1
		
		if IsPfUIActive() and (FriendFrameToggleTab3 or IgnoreFrameToggleTab3 or BlackListFrameToggleTab3) then
			StyleBlackListFrames()
			this:SetScript("OnUpdate", nil) -- Stop trying once successful
			if BlackList:GetOption("debugMode", false) then
				DEFAULT_CHAT_FRAME:AddMessage("BlackList: pfUI integration complete")
			end
		elseif attempts >= maxAttempts then
			this:SetScript("OnUpdate", nil) -- Give up after max attempts
			if BlackList:GetOption("debugMode", false) then
				if not IsPfUIActive() then
					DEFAULT_CHAT_FRAME:AddMessage("BlackList: pfUI not detected, using standard styling")
				else
					DEFAULT_CHAT_FRAME:AddMessage("BlackList: Could not find tabs to style")
				end
			end
		end
	end)
end

-- SuperIgnore-style Options System
local BlackListOptionsFrame_New = nil

local function CreateBlackListFrame(name, width, parent, x, y)
	local f = CreateFrame("Frame", name, parent)
	f:SetWidth(width)
	f:SetHeight(400)  -- Set a reasonable height
	f:SetFrameStrata("DIALOG")  -- Ensure it appears above other UI elements
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
		tile = true, tileSize = 32,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		insets = {left = 11, right = 12, top = 12, bottom = 11},
	})
	f:EnableMouse(true)
	f:Hide()
	
	-- Apply pfUI styling if available
	if IsPfUIActive() then
		pfUI.api.CreateBackdrop(f, nil, true)
		if pfUI.api.CreateBackdropShadow then
			pfUI.api.CreateBackdropShadow(f)
		end
	end
	
	return f
end

local function CreateBlackListHeader(frame, text, fontSize, pad)
	local t = frame:CreateFontString(nil, "OVERLAY", frame)
	t:SetPoint("TOP", frame, "TOP", 0, pad)
	t:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
	t:SetTextColor(1, 0.82, 0)  -- Gold color like SuperIgnore
	t:SetText(text)
	return t
end

local function CreateBlackListOption(frame, name, desc, pad, onclick)
	local c = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
	c:SetHeight(20)
	c:SetWidth(20)
	c:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, pad)
	c:SetScript("OnClick", function()
		-- Convert GetChecked() result (1/nil) to proper boolean (true/false)
		local checked = c:GetChecked() and true or false
		onclick(checked)
	end)
	
	-- Apply pfUI styling if available
	if IsPfUIActive() and pfUI.api.SkinCheckbox then
		pfUI.api.SkinCheckbox(c)
	end
	
	local ct = frame:CreateFontString(nil, "OVERLAY", frame)
	ct:SetPoint("LEFT", c, "RIGHT", 5, 0)
	ct:SetFont("Fonts\\FRIZQT__.TTF", 11)
	ct:SetTextColor(1, 1, 1)  -- White text
	ct:SetText(desc)
	ct:SetWidth(240)  -- Set max width for text wrapping
	ct:SetJustifyH("LEFT")
	-- Note: SetWordWrap doesn't exist in Classic WoW 1.12
	
	return c, ct
end

local function CreateBlackListCloseButton(frame)
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	
	-- Apply pfUI styling if available
	if IsPfUIActive() and pfUI.api.SkinCloseButton then
		-- pfUI uses -6, -6 offset for close buttons
		pfUI.api.SkinCloseButton(closeBtn, frame.backdrop or frame, -6, -6)
	else
		closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
	end
	
	closeBtn:SetScript("OnClick", function() frame:Hide() end)
	
	return closeBtn
end

local function CreateNewOptionsFrame()
	if BlackListOptionsFrame_New then
		return BlackListOptionsFrame_New
	end
	
	-- Create the main frame (backdrop is applied inside CreateBlackListFrame)
	BlackListOptionsFrame_New = CreateBlackListFrame("BlackListOptionsFrame_New", 300, UIParent, 0, 0)
	local f = BlackListOptionsFrame_New
	
	-- Add close button AFTER frame creation (so backdrop exists)
	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetScript("OnClick", function() f:Hide() end)
	
	-- Apply pfUI styling to close button if available
	if IsPfUIActive() and pfUI.api.SkinCloseButton then
		pfUI.api.SkinCloseButton(closeBtn, f.backdrop or f, -6, -6)
	else
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	end
	
	local pad = -15
	
	-- Title
	CreateBlackListHeader(f, "Blacklist Options", 14, pad)
	pad = pad - 25
	
	-- General Settings Section
	CreateBlackListHeader(f, "General Settings", 11, pad)
	pad = pad - 22
	
	local playSounds, playSoundsText = CreateBlackListOption(f, "BL_PlaySounds", "Play warning sounds", pad, function(checked)
		BlackList:ToggleOption("playSounds", checked)
	end)
	pad = pad - 22
	
	local warnTarget, warnTargetText = CreateBlackListOption(f, "BL_WarnTarget", "Warn when targeting blacklisted players", pad, function(checked)
		BlackList:ToggleOption("warnTarget", checked)
	end)
	pad = pad - 22
	
	local showReasons, showReasonsText = CreateBlackListOption(f, "BL_ShowReasons", "Add blacklist reason to all alerts", pad, function(checked)
		BlackList:ToggleOption("showReasons", checked)
	end)
	pad = pad - 22
	
	local debugMode, debugModeText = CreateBlackListOption(f, "BL_DebugMode", "Enable debug messages", pad, function(checked)
		BlackList:ToggleOption("debugMode", checked)
	end)
	pad = pad - 32  -- Extra space before next section
	
	-- Communication Section
	CreateBlackListHeader(f, "Communication", 11, pad)
	pad = pad - 22
	
	local preventWhispers, preventWhispersText = CreateBlackListOption(f, "BL_PreventWhispers", "Prevent whispers from blacklisted players", pad, function(checked)
		BlackList:ToggleOption("preventWhispers", checked)
	end)
	pad = pad - 32
	
	local warnWhispers, warnWhispersText = CreateBlackListOption(f, "BL_WarnWhispers", "Warn when blacklisted players whisper you", pad, function(checked)
		BlackList:ToggleOption("warnWhispers", checked)
	end)
	pad = pad - 32
	
	-- Group Management Section
	CreateBlackListHeader(f, "Group Management", 11, pad)
	pad = pad - 22
	
	local preventInvites, preventInvitesText = CreateBlackListOption(f, "BL_PreventInvites", "Prevent blacklisted players from inviting you", pad, function(checked)
		BlackList:ToggleOption("preventInvites", checked)
	end)
	pad = pad - 32
	
	local preventMyInvites, preventMyInvitesText = CreateBlackListOption(f, "BL_PreventMyInvites", "Prevent yourself from inviting blacklisted players", pad, function(checked)
		BlackList:ToggleOption("preventMyInvites", checked)
	end)
	pad = pad - 32
	
	local warnPartyJoin, warnPartyJoinText = CreateBlackListOption(f, "BL_WarnPartyJoin", "Warn when blacklisted players join your party", pad, function(checked)
		BlackList:ToggleOption("warnPartyJoin", checked)
	end)
	
	-- Adjust frame height to fit content compactly with bottom padding
	f:SetHeight(math.abs(pad) + 35)
	
	-- Store references for updating
	f.checkboxes = {
		{checkbox = playSounds, option = "playSounds", default = true},
		{checkbox = warnTarget, option = "warnTarget", default = true},
		{checkbox = debugMode, option = "debugMode", default = false},  -- Off by default
		{checkbox = showReasons, option = "showReasons", default = false},  -- Off by default
		{checkbox = preventWhispers, option = "preventWhispers", default = true},
		{checkbox = warnWhispers, option = "warnWhispers", default = true},
		{checkbox = preventInvites, option = "preventInvites", default = false},  -- Off by default
		{checkbox = preventMyInvites, option = "preventMyInvites", default = true},  -- On by default
		{checkbox = warnPartyJoin, option = "warnPartyJoin", default = true}
	}
	
	return f
end

function BlackList:ShowNewOptions()
	local frame = CreateNewOptionsFrame()
	
	-- Close details window if open
	local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
	if detailsFrame and detailsFrame:IsVisible() then
		detailsFrame:Hide()
	end
	
	-- Close shared window if open
	local sharedFrame = getglobal("BlackListSharedFrame")
	if sharedFrame and sharedFrame:IsVisible() then
		sharedFrame:Hide()
	end
	
	-- Toggle behavior: if already shown, hide it
	if frame:IsVisible() then
		frame:Hide()
		return
	end
	
	-- Position relative to BlackListStandaloneFrame or FriendsFrame
	frame:ClearAllPoints()
	local mainFrame = getglobal("BlackListStandaloneFrame")
	if mainFrame and mainFrame:IsVisible() then
		-- Position relative to standalone window
		frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
	elseif IsPfUIActive() and FriendsFrame and FriendsFrame.backdrop then
		frame:SetPoint("TOPLEFT", FriendsFrame.backdrop, "TOPRIGHT", 10, 0)
	elseif FriendsFrame then
		frame:SetPoint("TOPLEFT", FriendsFrame, "TOPRIGHT", 10, 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
	end
	
	-- Update checkbox states
	if frame.checkboxes then
		for _, data in ipairs(frame.checkboxes) do
			data.checkbox:SetChecked(self:GetOption(data.option, data.default))
		end
	end
	
	frame:Show()
end

-- Hook into BlackList UI functions like pfUI hooks into Blizzard functions
local originalShowOptions = nil
local originalUpdateUI = nil

local function InitializePfUIIntegration()
	if not IsPfUIActive() then return end
	
	-- Hook the ShowOptions function to apply styling when frames are shown
	if BlackList and BlackList.ShowOptions and not originalShowOptions then
		originalShowOptions = BlackList.ShowOptions
		BlackList.ShowOptions = function(self)
			originalShowOptions(self)
			StyleBlackListFrames()
		end
	end
	
	-- Hook the UpdateUI function to ensure styling is maintained
	if BlackList and BlackList.UpdateUI and not originalUpdateUI then
		originalUpdateUI = BlackList.UpdateUI  
		BlackList.UpdateUI = function(self)
			originalUpdateUI(self)
			StyleBlackListFrames()
		end
	end
end

-- Make the function globally accessible for XML OnLoad scripts
_G.InitializePfUIIntegration = InitializePfUIIntegration

-- Phrase variables
PLAYER_IGNORING 			= "Player is ignoring you.";

PLAYER_NOT_FOUND			= "Player not found.";
ALREADY_BLACKLISTED		= "is already blacklisted.";
ADDED_TO_BLACKLIST		= "added to blacklist."
REMOVED_FROM_BLACKLIST		= "removed from blacklist."

BLACKLIST				= "BlackList";
BLACKLIST_PLAYER 			= "BlackList Player";
REMOVE_PLAYER 			= "Remove Player";
OPTIONS 				= "Options";
SHARE_LIST				= "Share List";

BLACK_LIST_DETAILS_OF		= "BlackList Details of";
LEVEL					= "Level";
BLACK_LISTED			= "BlackListed:";
REASON				= "Reason:";
IS_BLACKLISTED			= "is on your blacklist.";

BINDING_HEADER_BLACKLIST	= "BlackList";
BINDING_NAME_TOGGLE_BLACKLIST	= "Toggle BlackList";

-- Inserts all of the UI elements
function BlackList:InsertUI()

	-- Create standalone BlackList window (no FriendsFrame integration)
	self:CreateStandaloneWindow();

	-- Create name prompt
	StaticPopupDialogs["BLACKLIST_PLAYER"] = {
		text = "Enter name of player to blacklist:",
		button1 = "Accept",
		button2 = "Cancel",
		OnShow = function()
			getglobal(this:GetName().."EditBox"):SetText("");
		end,
		OnAccept = function()
			BlackListPlayer(getglobal(this:GetParent():GetName().."EditBox"):GetText());
		end,
		hasEditBox = 1,
		timeout = 0,
		whileDead = 1,
		exclusive = 1,
		hideOnEscape = 1
		};

end
-- Reposition child windows relative to main frame
function BlackList:RepositionChildWindows()
	local mainFrame = getglobal("BlackListStandaloneFrame")
	if not mainFrame then return end
	
	-- Reposition details frame (aligned with upper right corner)
	local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
	if detailsFrame and detailsFrame:IsVisible() then
		detailsFrame:ClearAllPoints()
		detailsFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
	end
	
	-- Reposition options frame (aligned with upper right corner)
	local optionsFrame = getglobal("BlackListOptionsFrame_New")
	if optionsFrame and optionsFrame:IsVisible() then
		optionsFrame:ClearAllPoints()
		optionsFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
	end
	
	-- Reposition shared frame (aligned with upper right corner)
	local sharedFrame = getglobal("BlackListSharedFrame")
	if sharedFrame and sharedFrame:IsVisible() then
		sharedFrame:ClearAllPoints()
		sharedFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
	end
end

function BlackList:CreateStandaloneWindow()
	-- Create main frame
	local frame = CreateFrame("Frame", "BlackListStandaloneFrame", UIParent)
	frame:SetWidth(350)
	frame:SetHeight(450)
	frame:SetFrameStrata("DIALOG")  -- Ensure it appears above other UI elements
	-- Position like FriendsFrame/CharacterFrame (left side of screen)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:Hide()
	
	-- Add to UISpecialFrames so Escape key closes it
	table.insert(UISpecialFrames, "BlackListStandaloneFrame")
	
	-- Make frame draggable by creating a drag area at the top
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		this:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		-- Reposition child windows when main frame moves
		BlackList:RepositionChildWindows()
	end)
	
	-- Set default backdrop first
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = {left = 11, right = 12, top = 12, bottom = 11}
	})
	
	-- Apply pfUI styling on first show (when pfUI is fully loaded)
	frame:SetScript("OnShow", function()
		if IsPfUIActive() and pfUI and pfUI.api and pfUI.api.CreateBackdrop then
			if not this.pfuiStyled then
				if BlackList:GetOption("debugMode", false) then
					DEFAULT_CHAT_FRAME:AddMessage("BlackList: Applying pfUI styling to main window", 0, 1, 0)
				end
				pfUI.api.CreateBackdrop(this, nil, true)
				this.pfuiStyled = true
			end
			
			-- Always check and apply close button styling (even after pfuiStyled is set)
			local closeBtn = this.closeBtn
			if closeBtn and pfUI.api.SkinCloseButton and not closeBtn.pfuiStyled then
				closeBtn:ClearAllPoints()
				pfUI.api.SkinCloseButton(closeBtn, this.backdrop or this, -6, -6)
				closeBtn.pfuiStyled = true
			end
		end
	end)
	
	-- Title
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", frame, "TOP", 0, -15)
	title:SetText("Blacklist")
	
	-- Close button (will be styled by pfUI in OnShow event if available)
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function() frame:Hide() end)
	frame.closeBtn = closeBtn  -- Store reference for pfUI styling
	
	-- Close sub-windows when main window closes
	frame:SetScript("OnHide", function()
		local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
		if detailsFrame and detailsFrame:IsVisible() then
			detailsFrame:Hide()
		end
		local optionsFrame = getglobal("BlackListOptionsFrame_New")
		if optionsFrame and optionsFrame:IsVisible() then
			optionsFrame:Hide()
		end
		local sharedFrame = getglobal("BlackListSharedFrame")
		if sharedFrame and sharedFrame:IsVisible() then
			sharedFrame:Hide()
		end
	end)
	
	-- Add title bar for dragging indication
	local dragArea = CreateFrame("Frame", nil, frame)
	dragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	dragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	dragArea:SetHeight(40)
	dragArea:EnableMouse(true)
	dragArea:RegisterForDrag("LeftButton")
	dragArea:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	dragArea:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		BlackList:RepositionChildWindows()
	end)
	
	-- Create scroll frame for player list
	local scrollFrame = CreateFrame("ScrollFrame", "BlackListStandaloneScrollFrame", frame, "FauxScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -45)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 90)
	scrollFrame:SetScript("OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll(16, function() BlackList:UpdateStandaloneUI() end)
	end)
	
	-- Get and configure the scrollbar
	local scrollBar = getglobal("BlackListStandaloneScrollFrameScrollBar")
	if scrollBar then
		scrollBar:Show()
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -16, -16)
		scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 16)
		
		-- Apply pfUI styling to scrollbar if available
		if IsPfUIActive() and pfUI.api.SkinScrollbar then
			pfUI.api.SkinScrollbar(scrollBar)
		end
	end
	
	-- Create player list buttons (19 visible at a time - fits the scroll area)
	for i = 1, 19 do
		local button = CreateFrame("Button", "BlackListStandaloneButton"..i, frame)
		button:SetWidth(298)
		button:SetHeight(16)
		
		if i == 1 then
			button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
		else
			button:SetPoint("TOP", getglobal("BlackListStandaloneButton"..(i-1)), "BOTTOM", 0, 0)
		end
		
		-- Name text
		local nameText = button:CreateFontString("BlackListStandaloneButton"..i.."Name", "OVERLAY", "GameFontNormal")
		nameText:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -3)
		nameText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -50, -3)
		nameText:SetJustifyH("LEFT")
		
		-- Expiry text (right-aligned)
		local expiryText = button:CreateFontString("BlackListStandaloneButton"..i.."Expiry", "OVERLAY", "GameFontNormalSmall")
		expiryText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -5, -3)
		expiryText:SetJustifyH("RIGHT")
		
		-- Highlight texture
		local highlight = button:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(button)
		button:SetHighlightTexture(highlight)
		
		-- Click handler
		button:SetScript("OnClick", function()
			-- Save current player's reason before switching
			local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
			if detailsFrame and detailsFrame.SaveReason then
				detailsFrame.SaveReason()
			end
			
			BlackList:SetSelectedBlackList(this:GetID())
			BlackList:UpdateStandaloneUI()
			BlackList:ShowStandaloneDetails()
		end)
	end
	
	-- Add Player button (bottom left)
	local addBtn = CreateFrame("Button", "BlackListStandalone_AddButton", frame, "UIPanelButtonTemplate")
	addBtn:SetWidth(100)
	addBtn:SetHeight(22)
	addBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 45)
	addBtn:SetText("Add Player")
	addBtn:SetScript("OnClick", function()
		-- Check if we have a valid player target (but not yourself)
		if UnitExists("target") and UnitIsPlayer("target") and UnitName("target") ~= UnitName("player") then
			local targetName = UnitName("target")
			
			-- Check if already blacklisted
			if BlackList:GetIndexByName(targetName) > 0 then
				BlackList:AddMessage("BlackList: " .. targetName .. " is already blacklisted.", "yellow")
				return
			end
			
			-- Add target with full info
			BlackList:AddPlayer("target")
			BlackList:UpdateStandaloneUI()
		else
			-- No valid target (or targeting yourself), show prompt
			StaticPopup_Show("BLACKLIST_PLAYER")
		end
	end)
	
	-- Remove button (bottom left, under Add)
	local removeBtn = CreateFrame("Button", "BlackListStandalone_RemoveButton", frame, "UIPanelButtonTemplate")
	removeBtn:SetWidth(100)
	removeBtn:SetHeight(22)
	removeBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
	removeBtn:SetText("Remove")
	removeBtn:SetScript("OnClick", function()
		local index = BlackList:GetSelectedBlackList()
		if index and index > 0 then
			local player = BlackList:GetPlayerByIndex(index)
			if player then
				BlackList:RemovePlayer(player["name"])
				BlackList:UpdateStandaloneUI()
			end
		end
	end)
	
	-- Options button (bottom right)
	local optionsBtn = CreateFrame("Button", "BlackListStandalone_OptionsButton", frame, "UIPanelButtonTemplate")
	optionsBtn:SetWidth(100)
	optionsBtn:SetHeight(22)
	optionsBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 45)
	optionsBtn:SetText("Options")
	optionsBtn:SetScript("OnClick", function()
		BlackList:ShowNewOptions()
	end)
	
	-- Share button (bottom right, under Options)
	local sharedBtn = CreateFrame("Button", "BlackListStandalone_SharedButton", frame, "UIPanelButtonTemplate")
	sharedBtn:SetWidth(100)
	sharedBtn:SetHeight(22)
	sharedBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
	sharedBtn:SetText("Share")
	sharedBtn:SetScript("OnClick", function()
		BlackList:ShowSharedWindow()
	end)
	
	-- Apply pfUI styling to buttons if available
	if IsPfUIActive() then
		pfUI.api.CreateBackdrop(addBtn, nil, true)
		pfUI.api.CreateBackdrop(removeBtn, nil, true)
		pfUI.api.CreateBackdrop(optionsBtn, nil, true)
		pfUI.api.CreateBackdrop(sharedBtn, nil, true)
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("BlackList: Standalone window created", 0, 1, 0)
end

-- Update a specific row in the standalone list (for live updates without full refresh)
function BlackList:UpdateStandaloneListRow(playerIndex)
	local scrollFrame = getglobal("BlackListStandaloneScrollFrame")
	if not scrollFrame then return end
	
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	
	-- Find which button shows this player index
	for i = 1, 19 do
		local button = getglobal("BlackListStandaloneButton"..i)
		if button and button:GetID() == playerIndex then
			local nameText = getglobal("BlackListStandaloneButton"..i.."Name")
			if nameText then
				local player = self:GetPlayerByIndex(playerIndex)
				if player then
					local displayText = player["name"]
					
					-- Add reason in brackets if it exists
					if player["reason"] and player["reason"] ~= "" then
						local reason = player["reason"]
						-- Replace newlines with spaces for display
						reason = string.gsub(reason, "\n", " ")
						reason = string.gsub(reason, "\r", " ")
						-- Truncate reason if too long (max 30 characters)
						if string.len(reason) > 30 then
							reason = string.sub(reason, 1, 27) .. "..."
						end
						displayText = player["name"] .. " |cFFFFFFFF[" .. reason .. "]|r"
					end
					
					nameText:SetText(displayText)
				end
			end
			break
		end
	end
end

function BlackList:ToggleStandaloneWindow()
	local frame = getglobal("BlackListStandaloneFrame")
	if frame then
		if frame:IsVisible() then
			frame:Hide()
		else
			-- Remove expired entries before showing
			self:RemoveExpired()
			frame:Show()
			self:UpdateStandaloneUI()
		end
	end
end

function BlackList:UpdateStandaloneUI()
	local numBlackLists = BlackList:GetNumBlackLists()
	local selectedBlackList = self:GetSelectedBlackList()
	
	-- Set default selection
	if numBlackLists > 0 then
		if selectedBlackList == 0 or selectedBlackList > numBlackLists then
			self:SetSelectedBlackList(1)
			selectedBlackList = 1
		end
		-- Enable remove button
		local removeBtn = getglobal("BlackListStandalone_RemoveButton")
		if removeBtn then removeBtn:Enable() end
	else
		-- Disable remove button
		local removeBtn = getglobal("BlackListStandalone_RemoveButton")
		if removeBtn then removeBtn:Disable() end
	end
	
	-- Update scroll frame
	local scrollFrame = getglobal("BlackListStandaloneScrollFrame")
	if not scrollFrame then return end
	
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	
	-- Update each button (19 buttons visible)
	for i = 1, 19 do
		local index = i + offset
		local button = getglobal("BlackListStandaloneButton"..i)
		local nameText = getglobal("BlackListStandaloneButton"..i.."Name")
		local expiryText = getglobal("BlackListStandaloneButton"..i.."Expiry")
		
		if button and nameText then
			button:SetID(index)
			
			if index <= numBlackLists then
				local player = self:GetPlayerByIndex(index)
				local displayText = player["name"]
				
				-- Add reason in brackets if it exists
				if player["reason"] and player["reason"] ~= "" then
					local reason = player["reason"]
					-- Replace newlines with spaces for display
					reason = string.gsub(reason, "\n", " ")
					reason = string.gsub(reason, "\r", " ")
					-- Truncate reason if too long (max 30 characters)
					if string.len(reason) > 30 then
						reason = string.sub(reason, 1, 27) .. "..."
					end
					displayText = player["name"] .. " |cFFFFFFFF[" .. reason .. "]|r"
				end
				
				nameText:SetText(displayText)
				
				-- Show expiry if exists
				if expiryText then
					local expiryDisplay = self:GetExpiryText(player)
					if expiryDisplay then
						expiryText:SetText(expiryDisplay)
						expiryText:Show()
					else
						expiryText:Hide()
					end
				end
				
				button:Show()
				
				-- Update highlight
				if index == selectedBlackList then
					button:LockHighlight()
				else
					button:UnlockHighlight()
				end
			else
				button:Hide()
			end
		end
	end
	
	-- Update scroll frame (19 visible buttons, 16 pixels height each)
	FauxScrollFrame_Update(scrollFrame, numBlackLists, 19, 16)
end

function BlackList:ShowStandaloneDetails()
	local player = self:GetPlayerByIndex(self:GetSelectedBlackList())
	if not player then return end
	
	-- Create or get details frame
	local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
	if not detailsFrame then
		detailsFrame = CreateFrame("Frame", "BlackListStandaloneDetailsFrame", UIParent)
		detailsFrame:SetWidth(300)
		detailsFrame:SetHeight(250)
		detailsFrame:SetFrameStrata("DIALOG")  -- Ensure it appears above other UI elements
		-- Position aligned with upper right corner of main frame
		local mainFrame = getglobal("BlackListStandaloneFrame")
		if mainFrame then
			detailsFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
		else
			detailsFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
		end
		detailsFrame:SetMovable(false)
		detailsFrame:EnableMouse(true)
		detailsFrame:SetClampedToScreen(true)
		
		-- Set default backdrop first
		detailsFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = {left = 11, right = 12, top = 12, bottom = 11}
		})
		
		-- Apply pfUI styling immediately if available (like options frame)
		if IsPfUIActive() and pfUI and pfUI.api and pfUI.api.CreateBackdrop then
			pfUI.api.CreateBackdrop(detailsFrame, nil, true)
			detailsFrame.pfuiStyled = true
		end
		
		-- OnShow handler to close options window
		detailsFrame:SetScript("OnShow", function()
			-- Close options when details is opened
			local optionsFrame = getglobal("BlackListOptionsFrame_New")
			if optionsFrame and optionsFrame:IsVisible() then
				optionsFrame:Hide()
			end
			-- Close shared window when details is opened
			local sharedFrame = getglobal("BlackListSharedFrame")
			if sharedFrame and sharedFrame:IsVisible() then
				sharedFrame:Hide()
			end
		end)
		
		-- Title
		local title = detailsFrame:CreateFontString("BlackListStandaloneDetails_Title", "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", detailsFrame, "TOP", 0, -15)
		
		-- Close button
		local closeBtn = CreateFrame("Button", nil, detailsFrame, "UIPanelCloseButton")
		closeBtn:SetScript("OnClick", function()
			CloseDropDownMenus()
			detailsFrame:Hide()
		end)
		
		-- Apply pfUI styling to close button immediately if available
		if IsPfUIActive() and pfUI.api.SkinCloseButton then
			pfUI.api.SkinCloseButton(closeBtn, detailsFrame.backdrop or detailsFrame, -6, -6)
		else
			closeBtn:SetPoint("TOPRIGHT", detailsFrame, "TOPRIGHT", -5, -5)
		end
		
		-- Details window is static, not draggable
		
		-- Level/Class text
		local levelText = detailsFrame:CreateFontString("BlackListStandaloneDetails_Level", "OVERLAY", "GameFontNormal")
		levelText:SetPoint("TOPLEFT", detailsFrame, "TOPLEFT", 20, -50)
		
		-- Race text
		local raceText = detailsFrame:CreateFontString("BlackListStandaloneDetails_Race", "OVERLAY", "GameFontNormal")
		raceText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -5)
		
		-- Date added text
		local dateText = detailsFrame:CreateFontString("BlackListStandaloneDetails_Date", "OVERLAY", "GameFontNormalSmall")
		dateText:SetPoint("TOPLEFT", raceText, "BOTTOMLEFT", 0, -10)
		dateText:SetTextColor(0.7, 0.7, 0.7)
		
		-- Expiry dropdown
		local expiryLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		expiryLabel:SetPoint("TOPLEFT", dateText, "BOTTOMLEFT", 0, -10)
		expiryLabel:SetText("Duration:")
		
		local expiryDropdown = CreateFrame("Frame", "BlackListStandaloneDetails_ExpiryDropdown", detailsFrame, "UIDropDownMenuTemplate")
		expiryDropdown:SetPoint("TOPLEFT", expiryLabel, "BOTTOMLEFT", -15, -5)
		
		UIDropDownMenu_SetWidth(100, expiryDropdown)
		UIDropDownMenu_SetText("", expiryDropdown)  -- Start with empty text
		UIDropDownMenu_Initialize(expiryDropdown, function(self, level)
			local info = {}
			
			info.text = "Forever"
			info.value = 0
			info.func = function()
				BlackList:SetExpiry(detailsFrame.currentPlayerIndex, 0)
				UIDropDownMenu_SetText("", expiryDropdown)
				-- Immediately update the expiry text
				local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
				if expiryDateText then
					expiryDateText:SetText("Expires: Never")
				end
				BlackList:UpdateDetailsExpiry()
			end
			UIDropDownMenu_AddButton(info, level)
			
			info = {}
			info.text = "1 Week"
			info.value = 1
			info.func = function()
				BlackList:SetExpiry(detailsFrame.currentPlayerIndex, 1)
				UIDropDownMenu_SetText("", expiryDropdown)
				-- Immediately update the expiry text
				local player = BlackList:GetPlayerByIndex(detailsFrame.currentPlayerIndex)
				if player and player["expiry"] then
					local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
					if expiryDateText then
						local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
						expiryDateText:SetText("Expires: " .. expiryDateStr)
					end
				end
				BlackList:UpdateDetailsExpiry()
			end
			UIDropDownMenu_AddButton(info, level)
			
			info = {}
			info.text = "2 Weeks"
			info.value = 2
			info.func = function()
				BlackList:SetExpiry(detailsFrame.currentPlayerIndex, 2)
				UIDropDownMenu_SetText("", expiryDropdown)
				-- Immediately update the expiry text
				local player = BlackList:GetPlayerByIndex(detailsFrame.currentPlayerIndex)
				if player and player["expiry"] then
					local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
					if expiryDateText then
						local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
						expiryDateText:SetText("Expires: " .. expiryDateStr)
					end
				end
				BlackList:UpdateDetailsExpiry()
			end
			UIDropDownMenu_AddButton(info, level)
			
			info = {}
			info.text = "3 Weeks"
			info.value = 3
			info.func = function()
				BlackList:SetExpiry(detailsFrame.currentPlayerIndex, 3)
				UIDropDownMenu_SetText("", expiryDropdown)
				-- Immediately update the expiry text
				local player = BlackList:GetPlayerByIndex(detailsFrame.currentPlayerIndex)
				if player and player["expiry"] then
					local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
					if expiryDateText then
						local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
						expiryDateText:SetText("Expires: " .. expiryDateStr)
					end
				end
				BlackList:UpdateDetailsExpiry()
			end
			UIDropDownMenu_AddButton(info, level)
			
			info = {}
			info.text = "4 Weeks"
			info.value = 4
			info.func = function()
				BlackList:SetExpiry(detailsFrame.currentPlayerIndex, 4)
				UIDropDownMenu_SetText("", expiryDropdown)
				-- Immediately update the expiry text
				local player = BlackList:GetPlayerByIndex(detailsFrame.currentPlayerIndex)
				if player and player["expiry"] then
					local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
					if expiryDateText then
						local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
						expiryDateText:SetText("Expires: " .. expiryDateStr)
					end
				end
				BlackList:UpdateDetailsExpiry()
			end
			UIDropDownMenu_AddButton(info, level)
		end)
		
		-- Expiry date display
		local expiryDateText = detailsFrame:CreateFontString("BlackListStandaloneDetails_ExpiryDate", "OVERLAY", "GameFontNormalSmall")
		expiryDateText:SetPoint("TOPLEFT", expiryDropdown, "BOTTOMLEFT", 15, -3)
		expiryDateText:SetTextColor(0.7, 0.7, 0.7)
		
		-- Reason label
		local reasonLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		reasonLabel:SetPoint("TOPLEFT", expiryDateText, "BOTTOMLEFT", 0, -10)
		reasonLabel:SetText("Reason:")
		
		-- Reason text box (simple multiline, no scroll, 2-3 lines max)
		local reasonBox = CreateFrame("Frame", "BlackListStandaloneDetails_ReasonBox", detailsFrame)
		reasonBox:SetPoint("TOPLEFT", reasonLabel, "BOTTOMLEFT", 0, -5)
		reasonBox:SetPoint("RIGHT", detailsFrame, "RIGHT", -15, 0)
		reasonBox:SetHeight(45)
		
		-- Backdrop for reason box
		reasonBox:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 4, right = 4, top = 4, bottom = 4}
		})
		reasonBox:SetBackdropColor(0, 0, 0, 0.5)
		
		local reasonText = CreateFrame("EditBox", "BlackListStandaloneDetails_ReasonText", reasonBox)
		reasonText:SetPoint("TOPLEFT", 5, -5)
		reasonText:SetPoint("BOTTOMRIGHT", -5, 5)
		reasonText:SetMultiLine(true)
		reasonText:SetMaxLetters(150)
		reasonText:SetAutoFocus(false)
		reasonText:SetFontObject(GameFontHighlight)
		
		-- Function to save reason
		local function SaveReason()
			-- Use the stored index, not the currently selected one
			local index = detailsFrame.currentPlayerIndex
			if index and index > 0 then
				local player = BlackList:GetPlayerByIndex(index)
				if player then
					local text = reasonText:GetText()
					if text ~= player["reason"] then
						player["reason"] = text
						if BlackList:GetOption("debugMode", false) then
							DEFAULT_CHAT_FRAME:AddMessage("BlackList: Reason saved for " .. player["name"], 0, 1, 0)
						end
						-- Update just the specific row in the standalone list
						BlackList:UpdateStandaloneListRow(index)
					end
				end
			end
		end
		
		-- Save on Escape key
		reasonText:SetScript("OnEscapePressed", function()
			this:ClearFocus()
			SaveReason()
		end)
		
		-- Save when details window is hidden
		detailsFrame:SetScript("OnHide", function()
			CloseDropDownMenus()
			SaveReason()
		end)
		
		-- Store reference to SaveReason so it can be called from outside
		detailsFrame.SaveReason = SaveReason
	end
	
	-- Close any open dropdowns before switching players
	CloseDropDownMenus()
	
	-- Save previous player's reason before showing new one
	if detailsFrame.SaveReason and detailsFrame.currentPlayerIndex then
		detailsFrame.SaveReason()
	end
	
	-- Store the current player index for saving
	detailsFrame.currentPlayerIndex = self:GetSelectedBlackList()
	
	-- Try to update player info from target or group
	self:TryUpdatePlayerInfo(player["name"])
	
	-- Update details
	local title = getglobal("BlackListStandaloneDetails_Title")
	if title then
		title:SetText("Details: " .. player["name"])
	end
	
	local levelText = getglobal("BlackListStandaloneDetails_Level")
	if levelText then
		if player["level"] == "" and player["class"] == "" and player["race"] == "" then
			-- No info at all
			levelText:SetText("No information available")
		elseif player["level"] == "" and player["class"] == "" then
			levelText:SetText("Unknown Level, Class")
		elseif player["level"] == "" then
			levelText:SetText("Unknown Level " .. player["class"])
		elseif player["class"] == "" then
			levelText:SetText("Level " .. player["level"] .. " Unknown Class")
		else
			levelText:SetText("Level " .. player["level"] .. " " .. player["class"])
		end
	end
	
	local raceText = getglobal("BlackListStandaloneDetails_Race")
	if raceText then
		if player["level"] == "" and player["class"] == "" and player["race"] == "" then
			-- Hide race line if no info at all
			raceText:SetText("")
		else
			local race = player["race"] ~= "" and player["race"] or "Unknown Race"
			raceText:SetText(race)
		end
	end
	
	local dateText = getglobal("BlackListStandaloneDetails_Date")
	if dateText then
		local dateStr = date("%I:%M%p on %b %d, 20%y", player["added"])
		dateText:SetText("Blacklisted: " .. dateStr)
	end
	
	-- Update expiry dropdown (always reset to empty)
	local expiryDropdown = getglobal("BlackListStandaloneDetails_ExpiryDropdown")
	if expiryDropdown then
		UIDropDownMenu_SetText("", expiryDropdown)  -- Always show empty
	end
	
	-- Update expiry date display
	local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
	if expiryDateText then
		if player["expiry"] then
			local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
			expiryDateText:SetText("Expires: " .. expiryDateStr)
		else
			expiryDateText:SetText("Expires: Never")
		end
	end
	
	local reasonText = getglobal("BlackListStandaloneDetails_ReasonText")
	if reasonText then
		reasonText:SetText(player["reason"] or "")
	end
	
	-- Apply pfUI styling if available and not yet applied
	if not detailsFrame.pfuiStyled and IsPfUIActive() and pfUI and pfUI.api and pfUI.api.CreateBackdrop then
		pfUI.api.CreateBackdrop(detailsFrame, nil, true)
		detailsFrame.pfuiStyled = true
	end
	
	detailsFrame:Show()
end

-- Show Shared window for import/export
function BlackList:ShowSharedWindow()
	local sharedFrame = getglobal("BlackListSharedFrame")
	
	-- Close other sub-windows before showing this one
	local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
	if detailsFrame and detailsFrame:IsVisible() then
		detailsFrame:Hide()
	end
	
	local optionsFrame = getglobal("BlackListOptionsFrame_New")
	if optionsFrame and optionsFrame:IsVisible() then
		optionsFrame:Hide()
	end
	
	if not sharedFrame then
		-- Create the Shared window
		sharedFrame = CreateFrame("Frame", "BlackListSharedFrame", UIParent)
		sharedFrame:SetWidth(450)
		sharedFrame:SetHeight(400)
		sharedFrame:SetFrameStrata("DIALOG")
		sharedFrame:SetMovable(true)
		sharedFrame:EnableMouse(true)
		sharedFrame:SetClampedToScreen(true)
		
		-- Position next to main window
		local mainFrame = getglobal("BlackListStandaloneFrame")
		if mainFrame then
			sharedFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
		else
			sharedFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		
		-- Add to UISpecialFrames so Escape key closes it
		table.insert(UISpecialFrames, "BlackListSharedFrame")
		
		-- Set default backdrop
		sharedFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = {left = 11, right = 12, top = 12, bottom = 11}
		})
		
		-- Apply pfUI styling on first show
		sharedFrame:SetScript("OnShow", function()
			if IsPfUIActive() and pfUI and pfUI.api and pfUI.api.CreateBackdrop then
				if not this.pfuiStyled then
					pfUI.api.CreateBackdrop(this, nil, true)
					this.pfuiStyled = true
				end
				
				local closeBtn = this.closeBtn
				if closeBtn and pfUI.api.SkinCloseButton and not closeBtn.pfuiStyled then
					closeBtn:ClearAllPoints()
					pfUI.api.SkinCloseButton(closeBtn, this.backdrop or this, -6, -6)
					closeBtn.pfuiStyled = true
				end
			end
		end)
		
		-- Title
		local title = sharedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", sharedFrame, "TOP", 0, -15)
		title:SetText("Share Blacklist")
		
		-- Close button
		local closeBtn = CreateFrame("Button", nil, sharedFrame, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", sharedFrame, "TOPRIGHT", -5, -5)
		closeBtn:SetScript("OnClick", function() sharedFrame:Hide() end)
		sharedFrame.closeBtn = closeBtn
		
		-- Instructions text
		local instructions = sharedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		instructions:SetPoint("TOPLEFT", sharedFrame, "TOPLEFT", 20, -40)
		instructions:SetPoint("TOPRIGHT", sharedFrame, "TOPRIGHT", -20, -40)
		instructions:SetJustifyH("LEFT")
		instructions:SetText("Export/import blacklist to share with other accounts.")
		
		-- Create scroll frame for text
		local scrollFrame = CreateFrame("ScrollFrame", "BlackListSharedScrollFrame", sharedFrame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", sharedFrame, "TOPLEFT", 20, -65)
		scrollFrame:SetPoint("BOTTOMRIGHT", sharedFrame, "BOTTOMRIGHT", -40, 80)
		
		-- Create a backdrop for the scroll frame to make it visible
		scrollFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 4, right = 4, top = 4, bottom = 4}
		})
		scrollFrame:SetBackdropColor(0, 0, 0, 0.8)
		scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		
		-- Create edit box for the encoded data
		local editBox = CreateFrame("EditBox", "BlackListSharedEditBox", scrollFrame)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(GameFontHighlightSmall)
		editBox:SetWidth(380)
		editBox:SetHeight(240)
		editBox:SetMaxLetters(0)
		editBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		
		-- Make text selectable
		editBox:SetScript("OnTextChanged", function()
			-- Auto-scroll to bottom when text changes
			scrollFrame:UpdateScrollChildRect()
		end)
		
		scrollFrame:SetScrollChild(editBox)
		sharedFrame.editBox = editBox
		
		-- Export button
		local exportBtn = CreateFrame("Button", "BlackListShared_ExportButton", sharedFrame, "UIPanelButtonTemplate")
		exportBtn:SetWidth(120)
		exportBtn:SetHeight(22)
		exportBtn:SetPoint("BOTTOMLEFT", sharedFrame, "BOTTOMLEFT", 20, 45)
		exportBtn:SetText("Export")
		exportBtn:SetScript("OnClick", function()
			local encoded = BlackList:EncodeBlacklist()
			editBox:SetText(encoded)
			editBox:HighlightText()
			editBox:SetFocus()
			BlackList:AddMessage("BlackList: Exported " .. BlackList:GetNumBlackLists() .. " player(s). Press Ctrl+C to copy.", "yellow")
		end)
		
		-- Import button
		local importBtn = CreateFrame("Button", "BlackListShared_ImportButton", sharedFrame, "UIPanelButtonTemplate")
		importBtn:SetWidth(120)
		importBtn:SetHeight(22)
		importBtn:SetPoint("BOTTOMLEFT", sharedFrame, "BOTTOMLEFT", 150, 45)
		importBtn:SetText("Import")
		importBtn:SetScript("OnClick", function()
			local text = editBox:GetText()
			local overwriteCheck = getglobal("BlackListShared_OverwriteCheck")
			local overwrite = overwriteCheck and overwriteCheck:GetChecked()
			
			local count = BlackList:DecodeAndImportBlacklist(text, overwrite)
			if count > 0 then
				-- Clear the text box after successful import
				editBox:SetText("")
			end
		end)
		
		-- Overwrite checkbox
		local overwriteCheck = CreateFrame("CheckButton", "BlackListShared_OverwriteCheck", sharedFrame, "UICheckButtonTemplate")
		overwriteCheck:SetPoint("BOTTOMLEFT", sharedFrame, "BOTTOMLEFT", 20, 15)
		overwriteCheck:SetWidth(24)
		overwriteCheck:SetHeight(24)
		
		local overwriteLabel = sharedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		overwriteLabel:SetPoint("LEFT", overwriteCheck, "RIGHT", 0, 0)
		overwriteLabel:SetText("Overwrite existing blacklist on import")
		
		-- Close button at bottom right
		local closeBottomBtn = CreateFrame("Button", nil, sharedFrame, "UIPanelButtonTemplate")
		closeBottomBtn:SetWidth(80)
		closeBottomBtn:SetHeight(22)
		closeBottomBtn:SetPoint("BOTTOMRIGHT", sharedFrame, "BOTTOMRIGHT", -20, 15)
		closeBottomBtn:SetText("Close")
		closeBottomBtn:SetScript("OnClick", function() sharedFrame:Hide() end)
		
		-- Apply pfUI styling to buttons if available
		if IsPfUIActive() then
			pfUI.api.CreateBackdrop(exportBtn, nil, true)
			pfUI.api.CreateBackdrop(importBtn, nil, true)
			pfUI.api.CreateBackdrop(closeBottomBtn, nil, true)
		end
		
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Shared window created", 0, 1, 0)
	end
	
	-- Position relative to main window
	sharedFrame:ClearAllPoints()
	local mainFrame = getglobal("BlackListStandaloneFrame")
	if mainFrame and mainFrame:IsVisible() then
		-- Position relative to standalone window
		sharedFrame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 10, 0)
	else
		sharedFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	
	-- Clear the edit box when opening
	local editBox = sharedFrame.editBox
	if editBox then
		editBox:SetText("")
		editBox:ClearFocus()
	end
	
	sharedFrame:Show()
end

function BlackList:ClickBlackList()

	index = this:GetID();

	self:SetSelectedBlackList(index);

	self:UpdateUI();

	self:ShowDetails();

end

function BlackList:SetSelectedBlackList(index)

	SelectedIndex = index;

end

function BlackList:GetSelectedBlackList()

	return SelectedIndex;

end

function BlackList:ShowTab()

	FriendsFrameTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft");
	FriendsFrameTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight");
	FriendsFrameBottomLeft:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-BotLeft");
	FriendsFrameBottomRight:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-BotRight");
	FriendsFrameTitleText:SetText("Blacklist");
	FriendsFrame_ShowSubFrame("BlackListFrame");
	self:UpdateUI();

end

function BlackList:ToggleTab()

	ToggleFriendsFrame();

	if (BlackListFrame:IsVisible()) then
		BlackListFrame:Hide();
	else
		BlackList:ShowTab();
	end

end

function BlackList:ShowDetails()

	-- Close options window if open
	local optionsFrame = getglobal("BlackListStandaloneOptionsFrame")
	if optionsFrame and optionsFrame:IsVisible() then
		optionsFrame:Hide()
	end

	-- get player
	local player = self:GetPlayerByIndex(self:GetSelectedBlackList());

	-- update details
	getglobal("BlackListDetailsName"):SetText(BLACK_LIST_DETAILS_OF .. " " .. player["name"]);

	local level, race = "", "";
	if (player["level"] == "" and player["class"] == "") then
		level = "Unknown Level, Class";
	elseif (player["level"] == "") then
		level = "Unknown Level " .. player["class"];
	elseif (player["class"] == "") then
		level = "Level " .. player["level"] .. " Unknown Class";
	else
		level = "Level " .. player["level"] .. " " .. player["class"];
	end
	if (player["race"] == "") then
		race = "Unknown Race";
	else
		race = player["race"];
	end
	getglobal("BlackListDetailsLevel"):SetText(level);
	getglobal("BlackListDetailsRace"):SetText(race);

	if (GetFaction(player["race"]) == 1) then
		getglobal("BlackListDetailsFactionInsignia"):SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions.blp");
		getglobal("BlackListDetailsFactionInsignia"):SetTexCoord(0, 0.5, 0, 1);
	elseif (GetFaction(player["race"]) == 2) then
		getglobal("BlackListDetailsFactionInsignia"):SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions.blp");
		getglobal("BlackListDetailsFactionInsignia"):SetTexCoord(0.5, 1, 0, 1);
	else
		getglobal("BlackListDetailsFactionInsignia"):SetTexture(0, 0, 0, 0);
	end

	local date = date("%I:%M%p on %b %d, 20%y", player["added"]);
	getglobal("BlackListDetailsBlackListedText"):SetText(date);

	-- update reason
	getglobal("BlackListDetailsFrameReasonTextBox"):SetText(player["reason"]);

	getglobal("BlackListDetailsFrame"):Show();

end

function BlackList_Update()

	BlackList:UpdateUI();

end

function BlackList:UpdateUI()

	local numBlackLists = BlackList:GetNumBlackLists();
	local nameText, name;
	local blacklistButton;
	local selectedBlackList = self:GetSelectedBlackList();

	if (numBlackLists > 0) then
		if (selectedBlackList == 0 or selectedBlackList > numBlackLists) then
			self:SetSelectedBlackList(1);
			selectedBlackList = 1;
		end
		if FriendsFrameRemovePlayerButton then
			FriendsFrameRemovePlayerButton:Enable();
		end
	else
		if FriendsFrameRemovePlayerButton then
			FriendsFrameRemovePlayerButton:Disable();
		end
	end

	local blacklistOffset = FauxScrollFrame_GetOffset(FriendsFrameBlackListScrollFrame);
	local blacklistIndex;
	for i=1, BLACKLISTS_TO_DISPLAY, 1 do
		blacklistIndex = i + blacklistOffset;
		nameText = getglobal("FriendsFrameBlackListButton" .. i .. "ButtonTextName");
		nameText:SetText(self:GetNameByIndex(blacklistIndex));
		blacklistButton = getglobal("FriendsFrameBlackListButton" .. i);
		blacklistButton:SetID(blacklistIndex);

		-- Update the highlight
		if (blacklistIndex == selectedBlackList) then
			blacklistButton:LockHighlight();
		else
			blacklistButton:UnlockHighlight();
		end

		if (blacklistIndex > numBlackLists) then
			blacklistButton:Hide();
		else
			blacklistButton:Show();
		end
	end

	-- ScrollFrame stuff
	FauxScrollFrame_Update(FriendsFrameBlackListScrollFrame, numBlackLists, BLACKLISTS_TO_DISPLAY, FRIENDS_FRAME_BLACKLIST_HEIGHT);

end

function BlackList:ShowOptions()
	-- Use the new SuperIgnore-style options instead of the old XML frame
	self:ShowNewOptions()
end

function BlackList:ToggleOption(optionName, value)
	if (not BlackListOptions) then
		BlackListOptions = {};
	end
	BlackListOptions[optionName] = value;
	
	-- Clear warning cache when whisper options change
	if optionName == "preventWhispers" or optionName == "warnWhispers" then
		Already_Warned_For["WHISPER"] = {};
		if self:GetOption("debugMode", false) then
			DEFAULT_CHAT_FRAME:AddMessage("BlackList: Cleared whisper warning cache", 1, 1, 0);
		end
	end
	
	-- Debug output
	if self:GetOption("debugMode", false) then
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: Set " .. optionName .. " = " .. tostring(value), 1, 1, 0);
	end
end

function BlackList:GetOption(optionName, defaultValue)
	if (not BlackListOptions) then
		BlackListOptions = {};
	end
	if (BlackListOptions[optionName] == nil) then
		return defaultValue;
	end
	return BlackListOptions[optionName];
end

function BlackList:UpdateOptionsUI()
	-- Set default values if not set
	getglobal("BlackListOptionsCheckButton1"):SetChecked(self:GetOption("playSounds", true));
	getglobal("BlackListOptionsCheckButton2"):SetChecked(self:GetOption("warnTarget", true));
	getglobal("BlackListOptionsCheckButton3"):SetChecked(self:GetOption("preventWhispers", true));
	getglobal("BlackListOptionsCheckButton4"):SetChecked(self:GetOption("warnWhispers", true));
	getglobal("BlackListOptionsCheckButton5"):SetChecked(self:GetOption("preventInvites", false));
	getglobal("BlackListOptionsCheckButton6"):SetChecked(self:GetOption("preventMyInvites", true));
	getglobal("BlackListOptionsCheckButton7"):SetChecked(self:GetOption("warnPartyJoin", true));
end

-- Update expiry display after changing dropdown
function BlackList:UpdateDetailsExpiry()
	-- Update the expiry date display in the details window
	local detailsFrame = getglobal("BlackListStandaloneDetails")
	if detailsFrame and detailsFrame.currentPlayerIndex then
		local player = self:GetPlayerByIndex(detailsFrame.currentPlayerIndex)
		if player then
			local expiryDateText = getglobal("BlackListStandaloneDetails_ExpiryDate")
			if expiryDateText then
				if player["expiry"] then
					local expiryDateStr = date("%I:%M%p on %b %d, 20%y", player["expiry"])
					expiryDateText:SetText("Expires: " .. expiryDateStr)
				else
					expiryDateText:SetText("Expires: Never")
				end
			end
		end
	end
	
	-- Refresh the main list to show updated expiry
	self:UpdateStandaloneUI()
end
