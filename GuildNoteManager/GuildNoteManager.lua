-- Author: Josh 'Kkthnx' Russell 2024
-- Addon Name: GuildNoteManager

-- Cache frequently used global functions and values
local UnitFullName = UnitFullName
local IsInGuild = IsInGuild
local CanEditPublicNote = CanEditPublicNote
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local GetMaxPlayerLevel = GetMaxPlayerLevel
local GetProfessions = GetProfessions
local GetSpellTabInfo = GetSpellTabInfo
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetAverageItemLevel = GetAverageItemLevel
local GuildRosterSetPublicNote = GuildRosterSetPublicNote
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumGuildMembers = GetNumGuildMembers

-- Constants
local GN_UPDATE = "GN_UPDATE"

-- Addon message prefix registration
C_ChatInfo.RegisterAddonMessagePrefix(GN_UPDATE)

-- Slash commands
local GNOTE_ON_COMMAND = "/gnoteon"
local GNOTE_OFF_COMMAND = "/gnoteoff"
local GNOTE_HELP_COMMAND = "/gnotehelp" -- Define GNOTE_HELP_COMMAND here

-- Slash command functions
SLASH_GNOTEON1 = GNOTE_ON_COMMAND
SLASH_GNOTEOFF1 = GNOTE_OFF_COMMAND
SLASH_GNOTEHELP1 = GNOTE_HELP_COMMAND

local GuildNoteToggle = GuildNoteManagerDB

-- Function for printing messages with color
local function PrintMessage(message, color)
	color = color or "00a3cc" -- Default color if not provided
	print("|cFF" .. color .. message .. "|r")
end

-- Function to get player's full name and realm
local function GetPlayerFullName()
	local playerName, playerRealm = UnitFullName("player")
	if not playerName or not playerRealm then
		PrintMessage("Failed to retrieve player's full name.", "ff3333") -- Light red for failure
		return nil, nil -- Unable to get player's full name
	end
	return playerName, playerRealm
end

-- Function to check if the player is in a guild
local function IsPlayerInGuild()
	return IsInGuild()
end

-- Function to check if the player can edit their public note
local function CanPlayerEditNote()
	return CanEditPublicNote()
end

-- Function to check if the player is at max level
local function IsPlayerAtMaxLevel()
	local maxLevel = GetMaxLevelForPlayerExpansion() or GetMaxPlayerLevel()
	local playerLevel = UnitLevel("player")
	return playerLevel >= maxLevel
end

-- Function to check if the player has any professions
local function DoesPlayerHaveProfessions()
	local prof1, prof2 = GetProfessions()
	return prof1 or prof2
end

-- Function to get player's primary professions
local function GetPrimaryProfessions()
	local professions = {}
	local prof1, prof2 = GetProfessions()
	if prof1 then
		local profName1 = GetSpellTabInfo(prof1)
		table.insert(professions, profName1:sub(1, 3):upper()) -- Extract first two letters and convert to uppercase
	end
	if prof2 then
		local profName2 = GetSpellTabInfo(prof2)
		table.insert(professions, profName2:sub(1, 3):upper()) -- Extract first two letters and convert to uppercase
	end
	return professions
end

-- Slash command handlers
function SlashCmdList.GNOTEON()
	GuildNoteManagerDB = true
	GuildNoteToggle = true
	PrintMessage("Auto Guild Note login message on", "00cc00") -- Green for positive action
end

function SlashCmdList.GNOTEOFF()
	GuildNoteManagerDB = false
	GuildNoteToggle = false
	PrintMessage("Auto Guild Note login message off", "cc0000") -- Red for negative action
end

function SlashCmdList.GNOTEHELP()
	PrintMessage("Type /gnoteon to turn login messages on.", "00a3cc") -- Default color
	PrintMessage("Type /gnoteoff to turn login messages off.", "00a3cc") -- Default color
	-- PrintMessage("Type " .. GNOTE_UPDATE_COMMAND .. " to update your guild note manually.", "00a3cc")  -- Default color
end

-- Function to set guild note by name
local function SetGuildNoteByName(sender, rmessage)
	local playerName, playerRealm = GetPlayerFullName()
	if not playerName or not playerRealm then
		PrintMessage("Failed to retrieve player's full name.", "ff3333") -- Light red for failure
		return -- Unable to get player's full name
	end

	print("Player name: " .. playerName) -- Debugging message
	print("Player realm: " .. playerRealm) -- Debugging message

	local specAndLvl = ""
	if IsPlayerAtMaxLevel() then
		local currentSpec = GetSpecialization() or 0
		local currentSpecName = select(2, GetSpecializationInfo(currentSpec)) or "None"
		local shortSpecName = currentSpecName:gsub("(%a)%a*%s*", "%1"):upper() -- Extract first letters and convert to uppercase
		local myitemLvl = ("%.2f"):format(GetAverageItemLevel())
		specAndLvl = shortSpecName .. "-" .. myitemLvl
	else
		specAndLvl = "Leveling"
	end

	if IsPlayerInGuild() then
		if CanPlayerEditNote() then
			local professions = GetPrimaryProfessions()
			local professionString = ""
			if DoesPlayerHaveProfessions() and IsPlayerAtMaxLevel() then
				professionString = " / " .. table.concat(professions, "-")
			end

			local numTotal = GetNumGuildMembers()
			for i = 1, numTotal do
				local fname, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
				if fname == sender then
					if publicNote ~= rmessage and GuildNoteManagerDB then
						PrintMessage("-------------------------------------------------", "666666") -- Gray for separator
						PrintMessage("PLAYER: " .. playerName .. "-" .. playerRealm .. " Note was updated to " .. rmessage .. professionString, "ff9933") -- Orange for player update message with professions
						PrintMessage("-------------------------------------------------", "666666") -- Gray for separator
					end
					GuildRosterSetPublicNote(i, rmessage .. professionString)
					PrintMessage("Guild note updated for player: " .. fname, "339933") -- Dark green for success
					return
				end
			end
			PrintMessage("Failed to update guild note for player: " .. sender, "cc3333") -- Dark red for failure
		else
			PrintMessage("Insufficient permission to edit public note.", "cc3333") -- Dark red for failure
		end
	else
		PrintMessage("Not in a guild. Cannot update guild note.", "cc3333") -- Dark red for failure
	end
end

-- Add a flag to track whether the function is currently executing
local isUpdatingGuildNote = false

-- Event handling function
local function OnEvent(self, event, ...)
	if event == "PLAYER_LOGIN" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
		-- Check if the function is already executing, if so, return early
		if isUpdatingGuildNote then
			return
		end

		-- Set the flag to true to indicate that the function is executing
		isUpdatingGuildNote = true

		local playerName, playerRealm = GetPlayerFullName()
		if not playerName or not playerRealm then
			PrintMessage("Failed to get player's full name.", "ff3333") -- Light red for failure
			isUpdatingGuildNote = false -- Reset the flag
			return -- Unable to get player's full name
		end

		print("Player name: " .. playerName) -- Debugging message
		print("Player realm: " .. playerRealm) -- Debugging message

		local currentSpec = GetSpecialization() or 0
		local currentSpecName = select(2, GetSpecializationInfo(currentSpec)) or "None"
		local shortSpecName = currentSpecName:gsub("(%a)%a*%s*", "%1"):upper() -- Extract first letters and convert to uppercase
		local myitemLvl = ("%.2f"):format(GetAverageItemLevel())
		local specAndLvl = shortSpecName .. "-" .. myitemLvl

		if event == "PLAYER_LOGIN" then
			PrintMessage(" ", "000000") -- Black for spacing
			PrintMessage("Auto Guild Note Loaded", "ff7f00") -- Orange for notification
			PrintMessage("", "000000") -- Black for spacing
			PrintMessage("Type " .. GNOTE_HELP_COMMAND .. " to see help information", "00a3cc") -- Default color for help message
			PrintMessage("Type " .. GNOTE_ON_COMMAND .. " to turn login messages on.", "00cc00") -- Green for positive action
			PrintMessage("Type " .. GNOTE_OFF_COMMAND .. " to turn login messages off.", "cc0000") -- Red for negative action
			PrintMessage("", "000000") -- Black for spacing
		end

		if GuildNoteManagerDB and event == "PLAYER_LOGIN" then
			PrintMessage("-------------------------------------------------", "666666") -- Gray for separator
			PrintMessage("PLAYER: " .. playerName .. "-" .. playerRealm .. " logged on as " .. specAndLvl, "0066cc") -- Blue for player login message
			PrintMessage("-------------------------------------------------", "666666") -- Gray for separator
			print(" ")
		end

		if event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" and IsPlayerAtMaxLevel() then
			SetGuildNoteByName(playerName .. "-" .. playerRealm, specAndLvl)
		end

		-- Reset the flag after a short delay (debouncing)
		C_Timer.After(1, function()
			isUpdatingGuildNote = false
		end)
	end
end

-- Event registration
local GuildNoteManager = CreateFrame("Frame")
GuildNoteManager:RegisterEvent("PLAYER_LOGIN")
GuildNoteManager:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
GuildNoteManager:SetScript("OnEvent", OnEvent)
