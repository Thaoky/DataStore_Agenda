if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local addonName, addon = ...
local thisCharacterLFGDungeons

local GetLFGDungeonInfo, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, format = GetLFGDungeonInfo, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, format

local function ScanLFGDungeon(dungeonID)
   -- name, typeId, subTypeID, 
	-- minLvl, maxLvl, recLvl, minRecLvl, maxRecLvl, 
	-- expansionId, groupId, textureName, difficulty, 
	-- maxPlayers, dungeonDesc, isHoliday  = GetLFGDungeonInfo(dungeonID)
   
	local dungeonName, typeID, subTypeID, _, _, _, _, _, expansionID, _, _, difficulty = GetLFGDungeonInfo(dungeonID)
	
	-- unknown ? exit
	if not dungeonName then return end

	-- type 1 = instance, 2 = raid. We don't want the rest
	if typeID > 2 then return end

	-- difficulty levels we don't need
	--	0 = invalid (pvp 10v10 rated bg has this)
	-- 1 = normal (no lock)
	-- 8 = challenge
	-- 12 = normal mode scenario
	if (difficulty < 2) or (difficulty == 8) or (difficulty == 12) then return end

	-- how many did we kill in that instance ?
	local numEncounters, numCompleted = GetLFGDungeonNumEncounters(dungeonID)
	if not numCompleted or numCompleted == 0 then return end		-- no kills ? exit

	thisCharacterLFGDungeons = thisCharacterLFGDungeons or {}
	local dungeons = thisCharacterLFGDungeons
	local count = 0
	local key
	
	for i = 1, numEncounters do
		local bossName, _, isKilled = GetLFGDungeonEncounterInfo(dungeonID, i)

		key = format("%s.%s", dungeonID, bossName)
		if isKilled then
			dungeons[key] = true
			count = count + 1
		else
			dungeons[key] = nil
		end
	end

	-- save how many we have killed in that dungeon
	if count > 0 then
		dungeons[format("%s.Count", dungeonID)] = count
	end
end

local function ScanLFGDungeons()
	local dungeons = thisCharacterLFGDungeons
	if dungeons then wipe(dungeons) end
	
	for i = 1, 3000 do
		ScanLFGDungeon(i)
	end
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		characterTables = {
			["DataStore_Agenda_LFGDungeons"] = {
				-- *** Retail only ***
				IsBossAlreadyLooted = isRetail and function(character, dungeonID, boss)
					local key = format("%s.%s", dungeonID, boss)
					return character[key]
				end,
				GetLFGDungeonKillCount = isRetail and function(character, dungeonID)
					local key = format("%s.Count", dungeonID)
					return character[key] or 0
				end,
			},
		}
	})

	thisCharacterLFGDungeons = DataStore:GetCharacterDB("DataStore_Agenda_LFGDungeons")
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("LFG_UPDATE_RANDOM_INFO", ScanLFGDungeons)
	addon:ListenTo("ENCOUNTER_END", function(event, dungeonID, name, difficulty, raidSize, endStatus)
		ScanLFGDungeon(dungeonID)
		addon:SendMessage("DATASTORE_DUNGEON_SCANNED")
	end)
end)
