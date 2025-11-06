--[[
    BillyBlackList - WoW 1.12 (Classic) / Turtle WoW Addon
    
    COMPATIBILITY NOTES:
    - Uses Lua 5.0 (NOT 5.1+)
    - DO NOT USE: # operator, continue keyword, _G[] indexing
    - USE INSTEAD: table.getn(), break/return, getglobal()
    - Frame System: UIParent hierarchy, DIALOG strata preferred
    - pfUI Integration: Optional UI styling addon (detect and apply conditionally)
--]]

BlackList = {};

BlackList_Blocked_Channels = {"SAY", "YELL", "WHISPER", "PARTY", "RAID", "RAID_WARNING", "GUILD", "OFFICER", "EMOTE", "TEXT_EMOTE", "CHANNEL", "CHANNEL_JOIN", "CHANNEL_LEAVE"};

Already_Warned_For = {};
Already_Warned_For["WHISPER"] = {};
Already_Warned_For["TARGET"] = {};
Already_Warned_For["PARTY_INVITE"] = {};
Already_Warned_For["PARTY"] = {};

BlackListedPlayers = {};

-- Track previous party size to detect joins vs leaves
local PreviousPartySize = 0;

local SLASH_TYPE_ADD = 1;
local SLASH_TYPE_REMOVE = 2;

-- Function to handle onload event
function BlackList:OnLoad()

	-- constructions
	self:InsertUI();
	self:RegisterEvents();
	self:HookFunctions();
	self:RegisterSlashCmds();

	-- Disable share list button if it exists
	if FriendsFrameShareListButton then
		FriendsFrameShareListButton:Disable();
	end
	
	-- Initialize pfUI integration if available
	if InitializePfUIIntegration then
		InitializePfUIIntegration();
	end
	
	-- Create minimap button
	self:CreateMinimapButton();

end

-- Registers events to be recieved
function BlackList:RegisterEvents()

	local frame = getglobal("BlackListTopFrame");

	-- register events
	frame:RegisterEvent("VARIABLES_LOADED");
	frame:RegisterEvent("PLAYER_TARGET_CHANGED");
	frame:RegisterEvent("PARTY_INVITE_REQUEST");
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED");

end

local Orig_ChatFrame_OnEvent;
local Orig_InviteByName;
local Orig_UnitPopup_OnClick;

-- Hooks onto the functions needed
function BlackList:HookFunctions()

	Orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
	ChatFrame_OnEvent = BlackList_ChatFrame_OnEvent;

	Orig_InviteByName = InviteByName;
	InviteByName = BlackList_InviteByName;
	
	-- Hook UnitPopup menu clicks (for right-click portrait invites)
	Orig_UnitPopup_OnClick = UnitPopup_OnClick;
	UnitPopup_OnClick = BlackList_UnitPopup_OnClick;
	
	DEFAULT_CHAT_FRAME:AddMessage("BlackList: Hooks installed", 0, 1, 0);

end

-- Helper function to format alert messages with optional reason
local function FormatBlacklistAlert(playerName, baseMessage, action)
	local showReasons = BlackList:GetOption("showReasons", false)
	if showReasons then
		local index = BlackList:GetIndexByName(playerName)
		if index > 0 then
			local player = BlackList:GetPlayerByIndex(index)
			if player and player["reason"] and player["reason"] ~= "" then
				local reason = player["reason"]
				-- Truncate reason if too long (max 30 characters)
				if string.len(reason) > 30 then
					reason = string.sub(reason, 1, 27) .. "..."
				end
				return "BlackList: " .. playerName .. " " .. baseMessage .. " (Reason: " .. reason .. ")"
			end
		end
	end
	return "BlackList: " .. playerName .. " " .. baseMessage
end

-- Hooked ChatFrame_OnEvent function (like SuperIgnore does)
function BlackList_ChatFrame_OnEvent(event)
	
	-- Handle whisper blocking/warning - check BEFORE any other processing
	if event == "CHAT_MSG_WHISPER" then
		local name = arg2;
		
		-- Helper function to check if player is on ignore list (standard or SuperIgnore)
		local function IsIgnored(playerName)
			-- Check if SuperIgnore is loaded and use its API
			if SI_FilterIsPlayerIgnored then
				-- SuperIgnore's function checks its extended ignore list
				if SI_FilterIsPlayerIgnored(playerName) then
					return true
				end
			end
			
			-- Also check standard ignore list (50 player limit)
			for i = 1, GetNumIgnores() do
				if GetIgnoreName(i) == playerName then
					return true
				end
			end
			return false
		end
		
		-- Check if player is blacklisted
		local blacklistIndex = BlackList:GetIndexByName(name)
		if blacklistIndex > 0 then
			local player = BlackList:GetPlayerByIndex(blacklistIndex);
			
			-- If player is BOTH blacklisted AND on ignore list, ALWAYS block
			if IsIgnored(name) then
				-- Block completely - don't call original handler or show warnings
				return;
			end
			
			-- If prevent whispers is enabled, ALWAYS block (even if also on ignore list)
			if (BlackList:GetOption("preventWhispers", true)) then
				-- Warn if enabled
				if (BlackList:GetOption("warnWhispers", true)) then
					local alreadywarned = false;
					
					for key, warnedname in pairs(Already_Warned_For["WHISPER"]) do
						if (name == warnedname) then
							alreadywarned = true;
						end
					end
					
					if (not alreadywarned) then
						table.insert(Already_Warned_For["WHISPER"], name);
						local message = FormatBlacklistAlert(name, "whispered you. (Blocked)")
						BlackList:AddMessage(message, "yellow");
					end
				end
				-- Block the whisper completely - do NOT call original handler
				return;
			end
			
			-- If prevent whispers is disabled but warn is enabled, still warn
			if (BlackList:GetOption("warnWhispers", true)) then
				local alreadywarned = false;
				
				for key, warnedname in pairs(Already_Warned_For["WHISPER"]) do
					if (name == warnedname) then
						alreadywarned = true;
					end
				end
				
				if (not alreadywarned) then
					table.insert(Already_Warned_For["WHISPER"], name);
					local message = FormatBlacklistAlert(name, "whispered you.")
					BlackList:AddMessage(message, "yellow");
				end
			end
			
			-- Fall through to original handler (will be filtered by ignore list if also ignored)
		end
	end
	
	-- Call the original handler for all non-blocked messages
	Orig_ChatFrame_OnEvent(event);
end

-- Old MessageEventHandler function - DEPRECATED, keeping for reference
function BlackList_MessageEventHandler(event)

	local warnplayer, warnname = false, nil;

	if (strsub(event, 1, 8) == "CHAT_MSG") then
		local type = strsub(event, 10);

		for key, channel in pairs(BlackList_Blocked_Channels) do
			if (type == channel) then
				-- search for player name
				local name = arg2;
				
				if (BlackList:GetIndexByName(name) > 0) then
					local player = BlackList:GetPlayerByIndex(BlackList:GetIndexByName(name));
					
					-- Check if we should block whispers
					if (type == "WHISPER" and BlackList:GetOption("preventWhispers", true)) then
						-- respond to whisper
						if (name ~= UnitName("player")) then
							SendChatMessage(PLAYER_IGNORING, "WHISPER", nil, name);
						end
						-- block communication
						return;
					end
					
					-- Check if we should warn about whispers (independent of blocking)
					if (type == "WHISPER" and BlackList:GetOption("warnWhispers", true)) then
						local alreadywarned = false;

						for key, warnedname in pairs(Already_Warned_For["WHISPER"]) do
							if (name == warnedname) then
								alreadywarned = true;
							end
						end

						if (not alreadywarned) then
							table.insert(Already_Warned_For["WHISPER"], name);
							warnplayer = true;
							warnname = name;
							if BlackList:GetOption("debugMode", false) then
								DEFAULT_CHAT_FRAME:AddMessage("BlackList DEBUG: Setting up warning for " .. name, 0.5, 0.5, 0.5);
							end
						end
					end
				end
			end
		end
	end

	local returnvalue = Orig_ChatFrame_MessageEventHandler(event);

	if (warnplayer) then
		BlackList:AddMessage("BlackList: " .. warnname .. " is blacklisted and whispered you.", "yellow");
	end

	return returnvalue;

end

-- Hooked InviteByName function
function BlackList_InviteByName(name)
	if (BlackList:GetOption("preventMyInvites", true)) then
		if (BlackList:GetIndexByName(name) > 0) then
			local message = FormatBlacklistAlert(name, "is blacklisted. Invite blocked.")
			BlackList:AddMessage(message, "yellow");
			if BlackList:GetOption("debugMode", false) then
				DEFAULT_CHAT_FRAME:AddMessage("BlackList: [DEBUG] Blocked InviteByName for " .. name, 1, 0, 0)
			end
			return;
		end
	end

	Orig_InviteByName(name);
end

-- Hooked UnitPopup_OnClick function (for right-click portrait invites)
function BlackList_UnitPopup_OnClick()
	-- Get the dropdown info
	local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU);
	local button = this.value;
	local unit = dropdownFrame.unit;
	local name = dropdownFrame.name;
	
	-- Check if this is an invite action (INVITE, PARTY_INVITE, or RAID_INVITE)
	if button == "INVITE" or button == "PARTY_INVITE" or button == "RAID_INVITE" then
		local targetName = name or (unit and UnitName(unit))
		
		if targetName and BlackList:GetOption("preventMyInvites", true) then
			if BlackList:GetIndexByName(targetName) > 0 then
				local message = FormatBlacklistAlert(targetName, "is blacklisted. Invite blocked.")
				BlackList:AddMessage(message, "yellow");
				if BlackList:GetOption("debugMode", false) then
					DEFAULT_CHAT_FRAME:AddMessage("BlackList: [DEBUG] Blocked UnitPopup invite for " .. targetName, 1, 0, 0)
				end
				-- Close the dropdown but don't call the original function
				CloseDropDownMenus();
				return;
			end
		end
	end
	
	-- Call the original function for all other cases
	Orig_UnitPopup_OnClick();
end

-- Registers slash cmds
function BlackList:RegisterSlashCmds()

	SlashCmdList["BlackList"]   = function(args)
							BlackList:HandleSlashCmd(SLASH_TYPE_ADD, args)
						end;
	SLASH_BlackList1 = "/blacklist";
	SLASH_BlackList2 = "/bl";

	SlashCmdList["RemoveBlackList"]   = function(args)
								BlackList:HandleSlashCmd(SLASH_TYPE_REMOVE, args)
							end;
	SLASH_RemoveBlackList1 = "/removeblacklist";
	SLASH_RemoveBlackList2 = "/removebl";

	SlashCmdList["CheckBlackList"]   = function(args)
								BlackList:CheckGroup()
							end;
	SLASH_CheckBlackList1 = "/blcheck";

end

-- Handles the slash cmds
function BlackList:HandleSlashCmd(type, args)

	if (type == SLASH_TYPE_ADD) then
		if (args == "") then
			self:AddPlayer("target");
		else
			local name = args;
			local reason = "";
			local index = string.find(args, " ", 1, true);
			if (index) then
				-- space found, have reason in args
				name = string.sub(args, 1, index - 1);
				reason = string.sub(args, index + 1);
			end

			self:AddPlayer(name, reason);
		end
	elseif (type == SLASH_TYPE_REMOVE) then
		if (args == "") then
			self:RemovePlayer("target");
		else
			self:RemovePlayer(args);
		end
	end

end

-- Function to handle events
function BlackList:HandleEvent(event)

	if (event == "VARIABLES_LOADED") then
		if (not BlackListedPlayers[GetRealmName()]) then
			BlackListedPlayers[GetRealmName()] = {};
		end
		if (not BlackListOptions) then
			BlackListOptions = {};
		end
		-- Remove expired entries on load
		self:RemoveExpired()
	elseif (event == "PLAYER_TARGET_CHANGED") then
		-- search for player name
		local name = UnitName("target");
		local faction, localizedFaction = UnitFactionGroup("target");
		if (BlackList:GetIndexByName(name) > 0) then
			local player = BlackList:GetPlayerByIndex(BlackList:GetIndexByName(name));
			
			-- Auto-update player info from target if unknown
			if (player["level"] == "" or player["class"] == "" or player["race"] == "") then
				if UnitIsPlayer("target") then
					player["level"] = UnitLevel("target") .. ""
					player["class"] = UnitClass("target") or ""
					local race, raceEn = UnitRace("target")
					player["race"] = race or ""
				end
			end

			if (BlackList:GetOption("warnTarget", true)) then
				-- warn player
				local alreadywarned = false;

				for warnedname, timepassed in pairs(Already_Warned_For["TARGET"]) do
					if ((name == warnedname) and (GetTime() < timepassed+10)) then
						alreadywarned = true;
					end
				end

				if (not alreadywarned) then
					Already_Warned_For["TARGET"][name]=GetTime();
					if (BlackList:GetOption("playSounds", true)) then
						PlaySound("PVPTHROUGHQUEUE");
					end
					BlackList:AddMessage("BlackList: " .. name .. " is blacklisted - " .. player["reason"], "yellow");
				end
			end
		end
	elseif (event == "PARTY_INVITE_REQUEST") then
		-- search for player name
		local name = arg1;
		if (BlackList:GetIndexByName(name) > 0) then
			local player = BlackList:GetPlayerByIndex(BlackList:GetIndexByName(name));

			if (BlackList:GetOption("preventInvites", false)) then
				-- decline party invite
				DeclineGroup();
				StaticPopup_Hide("PARTY_INVITE");
				BlackList:AddMessage("BlackList: Declined party invite from blacklisted player " .. name .. ".", "yellow");
			else
				-- warn player
				local alreadywarned = false;

				for key, warnedname in pairs(Already_Warned_For["PARTY_INVITE"]) do
					if (name == warnedname) then
						alreadywarned = true;
					end
				end

				if (not alreadywarned) then
					table.insert(Already_Warned_For["PARTY_INVITE"], name);
					BlackList:AddMessage("BlackList: " .. name .. " is blacklisted and invited you to a party.", "yellow");
				end
			end
		end
	elseif (event == "PARTY_MEMBERS_CHANGED") then
		-- Only warn when party size increases (someone joined), not when it decreases (someone left)
		local currentPartySize = GetNumPartyMembers();
		
		if currentPartySize > PreviousPartySize then
			-- Party grew, check for blacklisted players
			for i = 0, currentPartySize, 1 do
				-- search for player name
				local name = UnitName("party" .. i);
				if (BlackList:GetIndexByName(name) > 0) then
					local player = BlackList:GetPlayerByIndex(BlackList:GetIndexByName(name));

					if (BlackList:GetOption("warnPartyJoin", true)) then
						-- Always warn about blacklisted players in party (no cache)
						-- Play warning sound if enabled
						if (BlackList:GetOption("playSounds", true)) then
							PlaySound("RaidWarning");
						end
						
						-- Format message with optional reason
						local message = FormatBlacklistAlert(name, "")
						
						-- Display prominent warning
						BlackList:AddMessage("==========================================", "yellow");
						BlackList:AddMessage("WARNING: Blacklisted player in your party!", "yellow");
						BlackList:AddMessage(message, "yellow");
						BlackList:AddMessage("==========================================", "yellow");
					end
				end
			end
		end
		
		-- Update the tracked party size
		PreviousPartySize = currentPartySize;
	end

end

-- Blacklists the given player, sets the ignore flag to be 'ignore' and enters the given reason
function BlackListPlayer(player, reason)

	BlackList:AddPlayer(player, reason);

end

-- Create minimap button
function BlackList:CreateMinimapButton()
	local button = CreateFrame("Button", "BlackListMinimapButton", Minimap)
	button:SetWidth(31)
	button:SetHeight(31)
	button:SetFrameStrata("MEDIUM")
	button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -10, 10)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	
	-- Icon
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
	
	-- Border
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT", -2, 2)
	
	-- Click handler
	button:SetScript("OnClick", function()
		if arg1 == "LeftButton" then
			BlackList:ToggleStandaloneWindow()
		elseif arg1 == "RightButton" then
			BlackList:ShowNewOptions()
		end
	end)
	
	-- Drag handler
	button:SetScript("OnDragStart", function()
		this:StartMoving()
	end)
	
	button:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
	end)
	
	-- Tooltip
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("BlackList")
		GameTooltip:AddLine("Left-click: Toggle BlackList", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Options", 1, 1, 1)
		GameTooltip:Show()
	end)
	
	
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	
	DEFAULT_CHAT_FRAME:AddMessage("BlackList: Minimap button created", 0, 1, 0)
end

