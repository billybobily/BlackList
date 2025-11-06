--[[
    BillyBlackList Functions - Core blacklist management
    
    COMPATIBILITY NOTES:
    - WoW 1.12 (Classic) / Turtle WoW
    - Lua 5.0: Use table.getn() not #, getglobal() not _G[]
    - Time functions: time() for timestamps, date() for formatting
    - Expiry system: nil = forever, number = unix timestamp
    
    STORAGE STRUCTURE:
    BlackListedPlayers[realm] = {player1, player2, ...}
    - All characters on the same realm share the same blacklist
    - Data is saved per-realm in SavedVariables
--]]

-- Get the active blacklist (always realm-wide, shared across all characters)
function BlackList:GetActiveList()
	local realm = GetRealmName()
	
	-- Initialize realm table if it doesn't exist
	if not BlackListedPlayers[realm] then
		BlackListedPlayers[realm] = {}
	end
	
	-- Return the realm-wide list (shared across all characters)
	return BlackListedPlayers[realm]
end

function BlackList:AddPlayer(player, reason)

function BlackList:AddPlayer(player, reason)

	-- handle player
	if (player == "" or player == nil) then
		return;
	elseif (player == "target") then
		if (UnitIsPlayer("target")) then
			name = UnitName("target");
			level = UnitLevel("target") .. "";
			class = UnitClass("target");
			race, raceEn = UnitRace("target");
		else
			StaticPopup_Show("BLACKLIST_PLAYER");
			return;
		end
	else
		name = player;
		level = "";
		class = "";
		race = "";
	end
	
	-- Prevent blacklisting yourself
	if (name == UnitName("player")) then
		self:AddMessage("BlackList: You cannot blacklist yourself.", "yellow");
		return;
	end
	
	if (self:GetIndexByName(name) > 0) then
		self:AddMessage(name .. " " .. ALREADY_BLACKLISTED, "yellow");
		return;
	end

	-- handle reason
	if (reason == nil) then
		reason = "";
	end

	-- timestamp
	added = time();

	-- lower the name and upper the first letter, not for chinese and korean though
	if ((GetLocale() ~= "zhTW") and (GetLocale() ~= "zhCN") and (GetLocale() ~= "koKR")) then
		local _, len = string.find(name, "[%z\1-\127\194-\244][\128-\191]*");
		name = string.upper(string.sub(name, 1, len)) .. string.lower(string.sub(name, len + 1));
	end
	
	player = {["name"] = name, ["reason"] = reason, ["added"] = added, ["level"] = level, ["class"] = class, ["race"] = race, ["expiry"] = nil};
	table.insert(self:GetActiveList(), player);

	self:AddMessage(name .. " " .. ADDED_TO_BLACKLIST, "yellow");
	
	-- Try to update info immediately from target or group
	self:TryUpdatePlayerInfo(name)

	-- Update standalone UI if it exists
	local standaloneFrame = getglobal("BlackListStandaloneFrame")
	if standaloneFrame and standaloneFrame:IsVisible() then
		self:UpdateStandaloneUI()
	end

end

function BlackList:RemovePlayer(player)

	-- handle player
	if (player == "target") then
		name = UnitName("target");
	else
		name = player;
	end

	if (name == nil) then
		index = self:GetSelectedBlackList();
	else
		index = self:GetIndexByName(name);
	end

	if (index == 0) then
		self:AddMessage(PLAYER_NOT_FOUND, "yellow");
		return;
	end

	name = self:GetNameByIndex(index);

	table.remove(self:GetActiveList(), index);

	self:AddMessage(name .. " " .. REMOVED_FROM_BLACKLIST, "yellow");

	-- Update standalone UI if it exists
	local standaloneFrame = getglobal("BlackListStandaloneFrame")
	if standaloneFrame and standaloneFrame:IsVisible() then
		self:UpdateStandaloneUI()
		-- Close details window if no players left or if removed player was selected
		local detailsFrame = getglobal("BlackListStandaloneDetailsFrame")
		if detailsFrame and detailsFrame:IsVisible() then
			if self:GetNumBlackLists() == 0 then
				detailsFrame:Hide()
			end
		end
	end

end

function BlackList:UpdateDetails(index, reason)

	-- update player
	local player = self:GetPlayerByIndex(index);
	-- for old version i have to convert old name format (there was no format...) in new "Name" format
	if ((GetLocale() ~= "zhTW") and (GetLocale() ~= "zhCN") and (GetLocale() ~= "koKR")) then
		local _, len = string.find(player["name"], "[%z\1-\127\194-\244][\128-\191]*");
		player["name"] = string.upper(string.sub(player["name"], 1, len)) .. string.lower(string.sub(player["name"], len + 1));
	end
	if (reason ~= nil) then
		player["reason"] = reason;
	end

	table.remove(self:GetActiveList(), index);
	table.insert(self:GetActiveList(), index, player);

end

-- Returns the number of blacklisted players
function BlackList:GetNumBlackLists()

	return table.getn(self:GetActiveList());

end

-- Returns the index of the player given by name
function BlackList:GetIndexByName(name)

	for i = 1, self:GetNumBlackLists() do
		if (self:GetNameByIndex(i) == name) then
			return i
		end
	end

	return 0

end

-- Returns the name of the player given by index
function BlackList:GetNameByIndex(index)

	if (index < 1 or index > self:GetNumBlackLists()) then
		return nil;
	end

	player = self:GetActiveList()[index];
	return player["name"];

end

-- Returns the player object given by index
function BlackList:GetPlayerByIndex(index)

	if (index < 1 or index > self:GetNumBlackLists()) then
		return nil
	end

	player = self:GetActiveList()[index];
	return player;

end

function BlackList:AddMessage(msg, color)

	local r = 0.0; g = 0.0; b = 0.0;

	if (color == "red") then
		r = 1.0; g = 0.0; b = 0.0;
	elseif (color == "yellow") then
		r = 1.0; g = 1.0; b = 0.0;
	end

	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
	end

end

function BlackList:AddErrorMessage(msg, color, timeout)

	local r = 0.0; g = 0.0; b = 0.0;

	if (color == "red") then
		r = 1.0; g = 0.0; b = 0.0;
	elseif (color == "yellow") then
		r = 1.0; g = 1.0; b = 0.0;
	end

	if (DEFAULT_CHAT_FRAME) then
		UIErrorsFrame:AddMessage(msg, r, g, b, nil, timeout);
	end

end

function GetFaction(race, returnText)

	local factions = {"Alliance", "Horde", "Unknown"};
	local faction = 0;

	if	     (race == "Human" or
			race == "Dwarf" or
			race == "Night Elf" or
			race == "Gnome" or
			race == "Draenei") then
		faction = 1;
	elseif     (race == "Orc" or
			race == "Undead" or
			race == "Tauren" or
			race == "Troll" or
			race == "Blood Elf") then
		faction = 2;
	else
		faction = 3;
	end

	if (returnText) then
		return factions[faction];
	else
		return faction;
	end

end

-- Try to update player info from target or party/raid
function BlackList:TryUpdatePlayerInfo(playerName)
	local index = self:GetIndexByName(playerName)
	if index <= 0 then return end
	
	local player = self:GetPlayerByIndex(index)
	if not player then return end
	
	-- Always try to update from available sources (levels can change)
	
	-- Check current target
	if UnitExists("target") and UnitIsPlayer("target") and UnitName("target") == playerName then
		player["level"] = UnitLevel("target") .. ""
		player["class"] = UnitClass("target") or ""
		local race, raceEn = UnitRace("target")
		player["race"] = race or ""
		return
	end
	
	-- Check raid members
	if GetNumRaidMembers() > 0 then
		for i = 1, GetNumRaidMembers() do
			if UnitName("raid"..i) == playerName then
				player["level"] = UnitLevel("raid"..i) .. ""
				player["class"] = UnitClass("raid"..i) or ""
				local race, raceEn = UnitRace("raid"..i)
				player["race"] = race or ""
				return
			end
		end
	end
	
	-- Check party members
	if GetNumPartyMembers() > 0 then
		for i = 1, GetNumPartyMembers() do
			if UnitName("party"..i) == playerName then
				player["level"] = UnitLevel("party"..i) .. ""
				player["class"] = UnitClass("party"..i) or ""
				local race, raceEn = UnitRace("party"..i)
				player["race"] = race or ""
				return
			end
		end
	end
end

-- Check current party/raid for blacklisted players
function BlackList:CheckGroup()
	local numBlacklisted = 0
	local blacklistedNames = {}
	local groupSize = 0
	local groupType = "Party"
	
	-- Check if in raid
	if GetNumRaidMembers() > 0 then
		groupSize = GetNumRaidMembers()
		groupType = "Raid"
		
		for i = 1, groupSize do
			local name = UnitName("raid"..i)
			if name and self:GetIndexByName(name) > 0 then
				numBlacklisted = numBlacklisted + 1
				table.insert(blacklistedNames, name)
			end
		end
	-- Check if in party
	elseif GetNumPartyMembers() > 0 then
		groupSize = GetNumPartyMembers()
		groupType = "Party"
		
		-- Check party members (doesn't include player)
		for i = 1, groupSize do
			local name = UnitName("party"..i)
			if name and self:GetIndexByName(name) > 0 then
				numBlacklisted = numBlacklisted + 1
				table.insert(blacklistedNames, name)
			end
		end
	else
		self:AddMessage("BlackList: You are not in a group.", "yellow")
		return
	end
	
	-- Report results
	if numBlacklisted > 0 then
		self:AddMessage("BlackList: Found " .. numBlacklisted .. " blacklisted player(s) in your " .. groupType .. ":", "red")
		for _, name in ipairs(blacklistedNames) do
			local player = self:GetPlayerByIndex(self:GetIndexByName(name))
			local reason = player["reason"]
			if reason and reason ~= "" then
				self:AddMessage("  - " .. name .. " (Reason: " .. reason .. ")", "red")
			else
				self:AddMessage("  - " .. name, "red")
			end
		end
	else
		self:AddMessage("BlackList: No blacklisted players found in your " .. groupType .. ".", "green")
	end
end

-- Update player info from current target
function BlackList:UpdatePlayerInfoFromTarget(index)
	if index <= 0 or index > self:GetNumBlackLists() then
		return false
	end
	
	local player = self:GetPlayerByIndex(index)
	if not player then return false end
	
	-- Check if target is the same player
	if UnitIsPlayer("target") and UnitName("target") == player["name"] then
		-- Update info from target
		player["level"] = UnitLevel("target") .. ""
		player["class"] = UnitClass("target") or ""
		local race, raceEn = UnitRace("target")
		player["race"] = race or ""
		return true
	end
	
	return false
end

-- Set expiry for a blacklisted player
function BlackList:SetExpiry(index, weeks)
	if index <= 0 or index > self:GetNumBlackLists() then
		return
	end
	
	local player = self:GetPlayerByIndex(index)
	if not player then return end
	
	if weeks and weeks > 0 then
		-- Set expiry timestamp (weeks * 7 days * 24 hours * 60 minutes * 60 seconds)
		player["expiry"] = time() + (weeks * 7 * 24 * 60 * 60)
	else
		-- Forever - remove expiry
		player["expiry"] = nil
	end
	
	-- Update UI if visible
	local standaloneFrame = getglobal("BlackListStandaloneFrame")
	if standaloneFrame and standaloneFrame:IsVisible() then
		self:UpdateStandaloneUI()
	end
end

-- Get formatted expiry text for display
function BlackList:GetExpiryText(player)
	if not player or not player["expiry"] then
		return nil
	end
	
	local now = time()
	local expiry = player["expiry"]
	
	if expiry <= now then
		return "|cFFFF00FF[expired]|r"
	end
	
	local remaining = expiry - now
	local weeks = math.floor(remaining / (7 * 24 * 60 * 60))
	local days = math.floor(remaining / (24 * 60 * 60))
	
	if weeks > 0 then
		return "|cFFFF00FF[" .. weeks .. "w left]|r"
	elseif days > 0 then
		return "|cFFFF00FF[" .. days .. "d left]|r"
	else
		return "|cFFFF00FF[<1d left]|r"
	end
end

-- Check and remove expired blacklist entries
function BlackList:RemoveExpired()
	local now = time()
	local removed = {}
	
	for i = self:GetNumBlackLists(), 1, -1 do
		local player = self:GetPlayerByIndex(i)
		if player and player["expiry"] and player["expiry"] <= now then
			table.insert(removed, player["name"])
			table.remove(self:GetActiveList(), i)
		end
	end
	
	if table.getn(removed) > 0 then
		for _, name in ipairs(removed) do
			self:AddMessage("BlackList: " .. name .. " expired and was removed.", "yellow")
		end
		
		-- Update UI if visible
		local standaloneFrame = getglobal("BlackListStandaloneFrame")
		if standaloneFrame and standaloneFrame:IsVisible() then
			self:UpdateStandaloneUI()
		end
	end
end
