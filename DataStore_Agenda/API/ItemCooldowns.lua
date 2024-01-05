if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local addonName, addon = ...
local thisCharacterCooldowns

local TableInsert, TableRemove, format, strfind, gsub, select, tonumber = table.insert, table.remove, format, strfind, gsub, select, tonumber
local GetItemInfo, GetGameTime, C_DateAndTime, time, difftime, strsplit = GetItemInfo, GetGameTime, C_DateAndTime, time, difftime, strsplit

local trackedItems = {
	[39878] = 259200, -- Mysterious Egg, 3 days
	[44717] = 259200, -- Disgusting Jar, 3 days
	[94295] = 259200, -- Primal Egg, 3 days
	[153190] = 432000, -- Fel-Spotted Egg, 5 days
}

local lootMsg = gsub(LOOT_ITEM_SELF, "%%s", "(.+)")
local purchaseMsg = gsub(LOOT_ITEM_PUSHED_SELF, "%%s", "(.+)")

local function OnChatMsgLoot(event, arg)
	local link = select(3, strfind(arg, lootMsg)) or select(3, strfind(arg, purchaseMsg))
	if not link then return end

	local id = tonumber(link:match("item:(%d+)"))
	if not id then return end

	for itemID, duration in pairs(trackedItems) do
		if itemID == id then
			local name = GetItemInfo(itemID)
			if name then
				TableInsert(thisCharacterCooldowns, format("%s|%s|%s", name, time(), duration))
				addon:SendMessage("DATASTORE_ITEM_COOLDOWN_UPDATED", itemID)
			end
		end
	end
end

local function _GetItemCooldownInfo(character, index)
	local item = character[index]
	if item then
		local name, lastCheck, duration = strsplit("|", item)
		return name, tonumber(lastCheck), tonumber(duration)
	end
end


--[[ clientServerTimeGap

	Number of seconds between client time & server time
	A positive value means that the server time is ahead of local time.
	Ex: server: 21:05, local 21.02 could lead to something like 180 (or close to it, depending on seconds)
--]]
local clientServerTimeGap

local function _GetClientServerTimeGap()
	return clientServerTimeGap or 0
end

local timerHandle
local timeTable = {}	-- to pass as an argument to time()	see http://lua-users.org/wiki/OsLibraryTutorial for details
local lastServerMinute

local function SetClientServerTimeGap()
	-- this function is called every second until the server time changes (track minutes only)
	local serverHour, serverMinute = GetGameTime()

	if not lastServerMinute then		-- serverMinute not set ? this is the first pass, save it
		lastServerMinute = serverMinute
		return
	end

	if lastServerMinute == serverMinute then return end	-- minute hasn't changed yet, exit

	-- next minute ? do our stuff and stop
	addon:CancelTimer(timerHandle)

	lastServerMinute = nil	-- won't be needed anymore
	timerHandle = nil

	local info = C_DateAndTime.GetCurrentCalendarTime()
	
	timeTable.year = info.year
	timeTable.month = info.month
	timeTable.day = info.monthDay
	timeTable.hour = serverHour
	timeTable.min = serverMinute
	timeTable.sec = 0					-- minute just changed, so second is 0

	-- our goal is achieved, we can calculate the difference between server time and local time, in seconds.
	clientServerTimeGap = difftime(time(timeTable), time())

	addon:SendMessage("DATASTORE_CS_TIMEGAP_FOUND", clientServerTimeGap)
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		characterTables = {
			["DataStore_Agenda_ItemCooldowns"] = {
				-- *** Retail only ***
				GetNumItemCooldowns = function(character)
					return #character
				end,
				GetItemCooldownInfo = _GetItemCooldownInfo,
				HasItemCooldownExpired = function(character, index)
					local _, lastCheck, duration = _GetItemCooldownInfo(character, index)

					local expires = duration + lastCheck + _GetClientServerTimeGap()
					if (expires - time()) <= 0 then
						return true
					end
				end,
				DeleteItemCooldown = function(character, index)
					TableRemove(character, index)
				end,
			},
		}
	})

	DataStore:RegisterMethod(addon, "GetClientServerTimeGap", _GetClientServerTimeGap)

	thisCharacterCooldowns = DataStore:GetCharacterDB("DataStore_Agenda_ItemCooldowns")
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("CHAT_MSG_LOOT", OnChatMsgLoot)
	
	timerHandle = addon:ScheduleRepeatingTimer(SetClientServerTimeGap, 1)
end)
