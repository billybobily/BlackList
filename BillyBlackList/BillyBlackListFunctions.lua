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

-- Base64 encoding table
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Base64 encode function
function base64_encode(data)
	local result = ""
	local i = 1
	while i <= string.len(data) do
		local a = string.byte(data, i)
		local b = string.byte(data, i+1)
		local c = string.byte(data, i+2)
		
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local n1 = math.floor(n / 262144)
		local n2 = math.floor((n - n1 * 262144) / 4096)
		local n3 = math.floor((n - n1 * 262144 - n2 * 4096) / 64)
		local n4 = n - n1 * 262144 - n2 * 4096 - n3 * 64
		
		result = result .. string.sub(b64chars, n1+1, n1+1) .. string.sub(b64chars, n2+1, n2+1)
		
		if i+1 <= string.len(data) then
			result = result .. string.sub(b64chars, n3+1, n3+1)
		else
			result = result .. "="
		end
		
		if i+2 <= string.len(data) then
			result = result .. string.sub(b64chars, n4+1, n4+1)
		else
			result = result .. "="
		end
		
		i = i + 3
	end
	
	return result
end

-- Base64 decode function
function base64_decode(data)
	data = string.gsub(data, "[^" .. b64chars .. "=]", "")
	local result = ""
	local i = 1
	
	while i <= string.len(data) do
		local c1 = string.sub(data, i, i)
		local c2 = string.sub(data, i+1, i+1)
		local c3 = string.sub(data, i+2, i+2)
		local c4 = string.sub(data, i+3, i+3)
		
		local n1 = string.find(b64chars, c1) - 1
		local n2 = string.find(b64chars, c2) - 1
		local n3 = (c3 == "=") and 0 or (string.find(b64chars, c3) - 1)
		local n4 = (c4 == "=") and 0 or (string.find(b64chars, c4) - 1)
		
		local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
		local b1 = math.floor(n / 65536)
		local b2 = math.floor((n - b1 * 65536) / 256)
		local b3 = n - b1 * 65536 - b2 * 256
		
		result = result .. string.char(b1)
		if c3 ~= "=" then
			result = result .. string.char(b2)
		end
		if c4 ~= "=" then
			result = result .. string.char(b3)
		end
		
		i = i + 4
	end
	
	return result
end

-- Helper function to escape special characters for export
local function EscapeForExport(str)
	if not str or str == "" then
		return ""
	end
	-- Replace newlines and @ symbols with escape sequences
	str = string.gsub(str, "\\", "\\\\")  -- Escape backslashes first
	str = string.gsub(str, "\n", "\\n")   -- Escape newlines
	str = string.gsub(str, "\r", "\\r")   -- Escape carriage returns
	str = string.gsub(str, "@", "\\a")    -- Escape @ symbols
	return str
end

-- Helper function to unescape special characters for import
local function UnescapeForImport(str)
	if not str or str == "" then
		return ""
	end
	-- Replace escape sequences back to actual characters
	str = string.gsub(str, "\\a", "@")    -- Unescape @ symbols
	str = string.gsub(str, "\\r", "\r")   -- Unescape carriage returns
	str = string.gsub(str, "\\n", "\n")   -- Unescape newlines
	str = string.gsub(str, "\\\\", "\\")  -- Unescape backslashes last
	return str
end

-- Encode blacklist to shareable string
function BlackList:EncodeBlacklist()
	local list = self:GetActiveList()
	local encoded = {}
	
	for i = 1, table.getn(list) do
		local player = list[i]
		if player and player["name"] then
			-- Format: name@reason@added@level@class@race@expiry
			local expiryStr = ""
			if player["expiry"] and player["expiry"] ~= "" then
				expiryStr = tostring(player["expiry"])
			end
			
			-- Escape special characters in text fields
			local entry = EscapeForExport(player["name"]) .. "@" ..
			              EscapeForExport(player["reason"] or "") .. "@" ..
			              (player["added"] or 0) .. "@" ..
			              EscapeForExport(player["level"] or "") .. "@" ..
			              EscapeForExport(player["class"] or "") .. "@" ..
			              EscapeForExport(player["race"] or "") .. "@" ..
			              expiryStr
			table.insert(encoded, entry)
		end
	end
	
	-- Join all entries with newlines
	return table.concat(encoded, "\n")
end

-- Decode and import blacklist from string
function BlackList:DecodeAndImportBlacklist(importString, overwrite)
	if not importString or importString == "" then
		self:AddMessage("BlackList: Nothing to import.", "yellow")
		return 0
	end
	
	-- Trim leading/trailing whitespace but preserve internal newlines
	importString = string.gsub(importString, "^%s+", "")
	importString = string.gsub(importString, "%s+$", "")
	
	local imported = {}
	
	-- Split by newlines to get individual entries
	local lines = {}
	for line in string.gfind(importString, "[^\n]+") do
		if line ~= "" then
			table.insert(lines, line)
		end
	end
	
	if BlackList:GetOption("debugMode", false) then
		DEFAULT_CHAT_FRAME:AddMessage("BlackList: [IMPORT DEBUG] Found " .. table.getn(lines) .. " lines", 1, 1, 0)
	end
	
	-- Parse each line (@-delimited format with escaping)
	for _, line in ipairs(lines) do
		-- Split by @ manually to ensure exactly 7 parts
		local parts = {}
		local current = ""
		local len = string.len(line)
		
		for i = 1, len do
			local char = string.sub(line, i, i)
			if char == "@" then
				table.insert(parts, current)
				current = ""
			else
				current = current .. char
			end
		end
		-- Add the last part
		table.insert(parts, current)
		
		if BlackList:GetOption("debugMode", false) then
			DEFAULT_CHAT_FRAME:AddMessage("BlackList: [IMPORT DEBUG] Line: " .. line, 1, 1, 0)
			DEFAULT_CHAT_FRAME:AddMessage("BlackList: [IMPORT DEBUG] Parts count: " .. table.getn(parts), 1, 1, 0)
			for i = 1, table.getn(parts) do
				DEFAULT_CHAT_FRAME:AddMessage("  Part[" .. i .. "]: '" .. parts[i] .. "'", 0.8, 0.8, 0.8)
			end
		end
		
		if table.getn(parts) >= 3 and parts[1] ~= "" then
			-- Minimum required: name, reason, added
			local addedTime = tonumber(parts[3])
			if not addedTime or addedTime == 0 then
				addedTime = time()
			end
			
			local expiryTime = nil
			if parts[7] and parts[7] ~= "" then
				expiryTime = tonumber(parts[7])
			end
			
			-- Unescape special characters in text fields
			local player = {
				["name"] = UnescapeForImport(parts[1]),
				["reason"] = UnescapeForImport(parts[2] or ""),
				["added"] = addedTime,
				["level"] = UnescapeForImport(parts[4] or ""),
				["class"] = UnescapeForImport(parts[5] or ""),
				["race"] = UnescapeForImport(parts[6] or ""),
				["expiry"] = expiryTime
			}
			
			table.insert(imported, player)
		end
	end
	
	if table.getn(imported) == 0 then
		self:AddMessage("BlackList: No valid entries found in import data.", "yellow")
		return 0
	end
	
	local list = self:GetActiveList()
	local addedCount = 0
	local updatedCount = 0
	
	if overwrite then
		-- Clear existing list and replace with imported data
		for i = table.getn(list), 1, -1 do
			table.remove(list, i)
		end
		for _, player in ipairs(imported) do
			table.insert(list, player)
		end
		addedCount = table.getn(imported)
		self:AddMessage("BlackList: Replaced blacklist with " .. addedCount .. " imported player(s).", "yellow")
	else
		-- Merge with existing list, keeping most recent entries
		local existingPlayers = {}
		for i = 1, table.getn(list) do
			if list[i] and list[i]["name"] then
				existingPlayers[list[i]["name"]] = {
					index = i,
					added = list[i]["added"] or 0
				}
			end
		end
		
		for _, player in ipairs(imported) do
			local existing = existingPlayers[player["name"]]
			local playerAdded = player["added"] or 0
			
			if not existing then
				-- New player, add to list
				table.insert(list, player)
				existingPlayers[player["name"]] = {
					index = table.getn(list),
					added = playerAdded
				}
				addedCount = addedCount + 1
			elseif playerAdded > existing.added then
				-- Imported entry is newer, replace existing
				list[existing.index] = player
				existingPlayers[player["name"]].added = playerAdded
				updatedCount = updatedCount + 1
			end
			-- If existing entry is newer or same age, keep it (do nothing)
		end
		
		if addedCount > 0 or updatedCount > 0 then
			local msg = "BlackList: Imported " .. addedCount .. " new player(s)"
			if updatedCount > 0 then
				msg = msg .. ", updated " .. updatedCount .. " existing player(s)"
			end
			self:AddMessage(msg .. ".", "yellow")
		else
			self:AddMessage("BlackList: No new or updated entries in import data.", "yellow")
		end
	end
	
	-- Update UI if visible
	local standaloneFrame = getglobal("BlackListStandaloneFrame")
	if standaloneFrame and standaloneFrame:IsVisible() then
		self:UpdateStandaloneUI()
	end
	
	return addedCount + updatedCount
end
