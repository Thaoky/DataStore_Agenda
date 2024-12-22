 if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local addonName, addon = ...
local thisCharacter
local dungeons

local DataStore = DataStore
local GetLFGDungeonInfo, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, format = GetLFGDungeonInfo, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, format

local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

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

	local info = {}
	local count = 0
	local key
	
	for i = 1, numEncounters do
		local bossName, _, isKilled = GetLFGDungeonEncounterInfo(dungeonID, i)

		key = format("%s.%s", dungeonID, bossName)
		if isKilled then
			info[key] = true
			count = count + 1
		else
			info[key] = nil
		end
	end

	-- save how many we have killed in that dungeon
	if count > 0 then
		info[format("%s.Count", dungeonID)] = count
		dungeons[DataStore.ThisCharID] = info
	end
end

local function ScanLFGDungeons()
	if thisCharacter then wipe(thisCharacter) end
	
	for i = 1, 3000 do
		ScanLFGDungeon(i)
	end
end

AddonFactory:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		addon = addon,
		characterIdTables = {
			["DataStore_Agenda_LFGDungeons"] = {
				-- *** Retail only ***
				IsBossAlreadyLooted = isRetail and function(characterID, dungeonID, boss)
					if dungeons[characterID] then
						local key = format("%s.%s", dungeonID, boss)
						return dungeons[characterID][key]
					end
				end,
				GetLFGDungeonKillCount = isRetail and function(characterID, dungeonID)
					if not dungeons[characterID] then return 0 end
					
					local key = format("%s.Count", dungeonID)
					return dungeons[characterID][key] or 0
				end,
			},
		}
	})

	dungeons = DataStore_Agenda_LFGDungeons
end)

AddonFactory:OnPlayerLogin(function()
	addon:ListenTo("LFG_UPDATE_RANDOM_INFO", ScanLFGDungeons)
	addon:ListenTo("ENCOUNTER_END", function(event, dungeonID, name, difficulty, raidSize, endStatus)
		ScanLFGDungeon(dungeonID)
		DataStore:Broadcast("DATASTORE_DUNGEON_SCANNED")
	end)
end)
