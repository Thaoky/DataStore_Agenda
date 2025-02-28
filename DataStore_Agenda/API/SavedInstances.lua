local addonName, addon = ...
local thisCharacter
local thisCharacterDungeons
local thisCharacterBossKills

local dungeons

local TableInsert, format, strsplit, tonumber = table.insert, format, strsplit, tonumber
local GetNumSavedInstances, GetSavedInstanceInfo, GetSavedInstanceEncounterInfo = GetNumSavedInstances, GetSavedInstanceInfo, GetSavedInstanceEncounterInfo
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local function InsertSavedInstance(key, value)
	local charID = DataStore.ThisCharID
	dungeons[charID] = dungeons[charID] or {}

	dungeons[charID][key] = value
end


local function ScanDungeonIDs()
	-- Save nothing if there is no data
	thisCharacterBossKills = nil

	for i = 1, GetNumSavedInstances() do
		local instanceName, instanceID, instanceReset, difficulty, _, extended, _, isRaid, maxPlayers, difficultyName, numEncounters = GetSavedInstanceInfo(i)

		if instanceReset > 0 then		-- in 3.2, instances with reset = 0 are also listed (to support raid extensions)
			extended = extended and 1 or 0
			isRaid = isRaid and 1 or 0

			if difficulty > 1 then
				instanceName = format("%s %s", instanceName, difficultyName)
			end

			local key = format("%s|%s", instanceName, instanceID)

			InsertSavedInstance(key, format("%s|%s|%s|%s", instanceReset, time(), extended, isRaid))

			-- Vanilla & LK
			if not isRetail then
				-- Bosses killed in this dungeon
				thisCharacterBossKills = thisCharacterBossKills or {}
				thisCharacterBossKills[key] = {}
				
				for encounterIndex = 1, numEncounters do
					local name, _, isKilled = GetSavedInstanceEncounterInfo(i, encounterIndex)
					isKilled = isKilled and 1 or 0
					
					TableInsert(thisCharacterBossKills[key], format("%s|%s", name, isKilled))
				end
			end
		end
	end
	
	thisCharacter.lastUpdate = time()
	AddonFactory:Broadcast("DATASTORE_DUNGEON_IDS_SCANNED")
end

local function OnBossKill(event, encounterID, encounterName)
	-- To do
	-- print("event:" .. (event or "nil"))
	-- print("encounterID:" .. (encounterID or "nil"))
	-- print("encounterName:" .. (encounterName or "nil"))
end

local function _GetSavedInstanceInfo(characterID, key)
	local char = dungeons[characterID]
	if not char then return end
	
	local instanceInfo = char[key]
	if not instanceInfo then return end

	local hasExpired
	local reset, lastCheck, isExtended, isRaid = strsplit("|", instanceInfo)

	return tonumber(reset), tonumber(lastCheck), (isExtended == "1") and true or nil, (isRaid == "1") and true or nil
end

local function _HasSavedInstanceExpired(character, key)
	local reset, lastCheck = _GetSavedInstanceInfo(character, key)
	if not reset or not lastCheck then return end

	local hasExpired
	local expiresIn = reset - (time() - lastCheck)

	if expiresIn <= 0 then	-- has expired
		hasExpired = true
	end

	return hasExpired, expiresIn
end

local function _DeleteSavedInstance(characterID, key)
	local char = dungeons[characterID]
	if char then
		char[key] = nil
	end
end

AddonFactory:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		addon = addon,
		characterIdTables = {
			["DataStore_Agenda_SavedInstances"] = {
					--[[	Typical usage:

						for dungeonKey, _ in pairs(DataStore:GetSavedInstances(character) do
							myvar1, myvar2, .. = DataStore:GetSavedInstanceInfo(character, dungeonKey)
						end
					--]]
				GetSavedInstances = function(characterID) return dungeons[characterID] end,
				GetSavedInstanceInfo = _GetSavedInstanceInfo,
				HasSavedInstanceExpired = _HasSavedInstanceExpired,
				DeleteSavedInstance = _DeleteSavedInstance,
			},
		},
		characterTables = {
			["DataStore_Agenda_BossKills"] = {
				-- *** Vanilla & LK only ***
				GetSavedInstanceNumEncounters = (not isRetail) and function(character, key)
					return character[key] and #character[key] or 0
				end,
				GetSavedInstanceEncounterInfo = (not isRetail) and function(character, key, index)
					local info = character[key]
					if info then
						local name, isKilled = strsplit("|", info[index])
						return name, (isKilled == "1") and true or nil
					end
				end,
			},
		}
	})

	thisCharacter = DataStore:GetCharacterDB("DataStore_Agenda_Characters")
	dungeons = DataStore_Agenda_SavedInstances
	thisCharacterBossKills = DataStore:GetCharacterDB("DataStore_Agenda_BossKills")
end)

AddonFactory:OnPlayerLogin(function()

	if not isRetail then
		addon:ListenTo("PLAYER_ALIVE", ScanDungeonIDs)
		addon:ListenTo("BOSS_KILL", OnBossKill)
	end
	
	addon:ListenTo("UPDATE_INSTANCE_INFO", ScanDungeonIDs)
	addon:ListenTo("RAID_INSTANCE_WELCOME", function()	RequestRaidInfo() end)
	addon:ListenTo("CHAT_MSG_SYSTEM", function(event, arg)
		if arg and tostring(arg) == INSTANCE_SAVED then
			RequestRaidInfo()
		end
	end)
end)
