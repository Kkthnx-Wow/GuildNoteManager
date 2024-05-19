-- Cache frequently used global functions and values
local table_insert = table.insert
local C_ChatInfo_RegisterAddonMessagePrefix = C_ChatInfo.RegisterAddonMessagePrefix
local CanEditPublicNote = CanEditPublicNote
local GetAverageItemLevel = GetAverageItemLevel
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumGuildMembers = GetNumGuildMembers
local GetProfessions = GetProfessions
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpellTabInfo = GetSpellTabInfo
local GuildRosterSetPublicNote = GuildRosterSetPublicNote
local IsInGuild = IsInGuild
local UnitFullName = UnitFullName
local UnitLevel = UnitLevel

-- Constants
local GNM_UPDATE = "GNM_UPDATE"

-- Addon message prefix registration
C_ChatInfo_RegisterAddonMessagePrefix(GNM_UPDATE)

-- Initialize the localization table
local gnmLocale = {}

-- Set localized strings based on the client's locale
if GetLocale() == "deDE" then
	-- German (deDE) localization
	gnmLocale["Leveling"] = "Leveling" -- German translation needed
	gnmLocale["GNM: "] = "GNM: " -- German translation needed
	gnmLocale["Note was updated to "] = " Notiz wurde aktualisiert zu " -- Example German translation
elseif GetLocale() == "esES" then
	-- Spanish (esES) localization
	gnmLocale["Leveling"] = "Nivelación" -- Spanish translation needed
	gnmLocale["GNM: "] = "GNM: " -- Spanish translation needed
	gnmLocale["Note was updated to "] = " La nota se actualizó a " -- Example Spanish translation
elseif GetLocale() == "frFR" then
	-- French (frFR) localization
	gnmLocale["Leveling"] = "Nivelación" -- French translation needed
	gnmLocale["GNM: "] = "GNM: " -- French translation needed
	gnmLocale["Note was updated to "] = " La note a été mise à jour à " -- Example French translation
elseif GetLocale() == "itIT" then
	-- Italian (itIT) localization
	gnmLocale["Leveling"] = "Livellamento" -- Italian translation needed
	gnmLocale["GNM: "] = "GNM: " -- Italian translation needed
	gnmLocale["Note was updated to "] = " Nota aggiornata a " -- Example Italian translation
elseif GetLocale() == "ruRU" then
	-- Russian (ruRU) localization
	gnmLocale["Leveling"] = "прокачка" -- Russian translation needed
	gnmLocale["GNM: "] = "ГНМ: " -- Russian translation needed
	gnmLocale["Note was updated to "] = " Примечание обновлено до " -- Example Russian translation
elseif GetLocale() == "koKR" then
	-- Korean (koKR) localization
	gnmLocale["Leveling"] = "레벨링" -- Korean translation needed
	gnmLocale["GNM: "] = "GNM: " -- Korean translation needed
	gnmLocale["Note was updated to "] = " 노트가 업데이트되었습니다 " -- Example Korean translation
elseif GetLocale() == "zhCN" then
	-- Simplified Chinese (zhCN) localization
	gnmLocale["Leveling"] = "等级提升" -- Simplified Chinese translation needed
	gnmLocale["GNM: "] = "GNM: " -- Simplified Chinese translation needed
	gnmLocale["Note was updated to "] = " 注释已更新为 " -- Example Simplified Chinese translation
elseif GetLocale() == "zhTW" then
	-- Traditional Chinese (zhTW) localization
	gnmLocale["Leveling"] = "等級提升" -- Traditional Chinese translation needed
	gnmLocale["GNM: "] = "GNM: " -- Traditional Chinese translation needed
	gnmLocale["Note was updated to "] = " 註釋已更新為 " -- Example Traditional Chinese translation
else
	-- Default to English localization
	gnmLocale["Leveling"] = "Leveling"
	gnmLocale["GNM: "] = "GNM: "
	gnmLocale["Note was updated to "] = " Note was updated to "
end

-- Function to print messages with color
local function PrintMessage(message, color)
	color = color or "00a3cc" -- Default color if not provided
	print("|cFF" .. color .. message .. "|r")
end

-- Function to get player's full name and realm
local function GetPlayerFullName()
	local playerName, playerRealm = UnitFullName("player")
	return playerName, playerRealm
end

-- Functions to check if the player is at max level or trial account
local function XPIsUserDisabled()
	return IsXPUserDisabled()
end

local function XPIsTrialMax()
	return (IsRestrictedAccount() or IsTrialAccount() or IsVeteranTrialAccount()) and (UnitLevel("player") == 20)
end

local function IsPlayerAtMaxLevel()
	return IsLevelAtEffectiveMaxLevel(UnitLevel("player")) or XPIsUserDisabled() or XPIsTrialMax()
end

-- Function to check if the player has any professions
local function DoesPlayerHaveProfessions()
	local prof1, prof2 = GetProfessions()
	return prof1 or prof2
end

local function GetPrimaryProfessions()
	local professions = {}
	local prof1, prof2 = GetProfessions()
	if prof1 then
		local profName1 = GetSpellTabInfo(prof1)
		table_insert(professions, profName1:sub(1, 3):upper()) -- Extract first three letters and convert to uppercase
	end
	if prof2 then
		local profName2 = GetSpellTabInfo(prof2)
		table_insert(professions, profName2:sub(1, 3):upper()) -- Extract first three letters and convert to uppercase
	end
	return professions
end

-- Function to set guild note by name
local function SetGuildNoteByName(sender, rmessage)
	local playerName, playerRealm = GetPlayerFullName()
	if not playerName or not playerRealm then
		return -- Unable to get player's full name
	end

	if IsInGuild() and CanEditPublicNote() then
		local professions = GetPrimaryProfessions()
		local professionString = ""
		if DoesPlayerHaveProfessions() and IsPlayerAtMaxLevel() then
			professionString = " / " .. table.concat(professions, "-")
		end

		local numTotal = GetNumGuildMembers()
		for i = 1, numTotal do
			local fname, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
			if fname == sender then
				if publicNote ~= rmessage then
					PrintMessage(gnmLocale["GNM: "] .. playerName .. "-" .. playerRealm .. gnmLocale["Note was updated to "] .. rmessage .. professionString, "ff9933") -- Orange for player update message with professions
				end
				GuildRosterSetPublicNote(i, rmessage .. professionString)
				return
			end
		end
	end
end

-- Function to handle debouncing of guild note updates
local debouncingTimer
local function HandleDebouncing()
	if debouncingTimer then
		debouncingTimer:Cancel() -- Cancel previous debouncing timer if it exists
	end
	debouncingTimer = C_Timer.NewTimer(0.5, SetGuildNoteByName) -- Schedule a new debouncing timer
end

-- Add a flag to track whether the function is currently executing
local isUpdatingGuildNote = false

-- Event handling function
local function OnEvent(self, event, ...)
	-- Check if the function is already executing, if so, return early
	if isUpdatingGuildNote then
		return
	end

	-- Set the flag to true to indicate that the function is executing
	isUpdatingGuildNote = true

	-- Capture the unit parameter
	local unit = ... or "player" -- If ... is empty, default to "player"

	-- If ... is not empty, remove unit from it
	if select("#", ...) > 0 then
		unit = select(1, ...) -- Extract unit from ...
	end

	local playerName, playerRealm = GetPlayerFullName()
	if not playerName or not playerRealm then
		isUpdatingGuildNote = false -- Reset the flag
		return -- Unable to get player's full name
	end

	local specAndLvl = ""
	local currentSpec = GetSpecialization() or 0
	local _, currentSpecName = GetSpecializationInfo(currentSpec)
	local shortSpecName = currentSpecName and currentSpecName:gsub("(%a)%a*%s*", "%1"):upper() or "??"
	local myitemLvl = ("%.2f"):format(GetAverageItemLevel())

	if IsPlayerAtMaxLevel() then
		specAndLvl = shortSpecName .. "-" .. myitemLvl
	else
		specAndLvl = shortSpecName .. " - " .. myitemLvl .. " - " .. gnmLocale["Leveling"]
	end

	if event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" and unit == "player" then
		SetGuildNoteByName(playerName .. "-" .. playerRealm, specAndLvl)
		HandleDebouncing()
	end

	if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then -- Handle specialization change event
		-- Add a short delay to ensure event stability
		C_Timer.After(0.5, function()
			-- Update the specialization information after the delay
			local newSpec = GetSpecialization() or 0
			local _, newSpecName = GetSpecializationInfo(newSpec)
			shortSpecName = newSpecName and newSpecName:gsub("(%a)%a*%s*", "%1"):upper() or "??"

			-- Update the guild note
			SetGuildNoteByName(playerName .. "-" .. playerRealm, specAndLvl)
		end)
	end

	-- Reset the flag after a short delay (debouncing)
	C_Timer.After(1, function()
		isUpdatingGuildNote = false
	end)
end

-- Event registration
local GuildNoteManager = CreateFrame("Frame")
GuildNoteManager:RegisterEvent("PLAYER_LOGIN")
GuildNoteManager:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
GuildNoteManager:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
GuildNoteManager:SetScript("OnEvent", OnEvent)
