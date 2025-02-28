--[[	*** DataStore_Agenda ***
Written by : Thaoky, EU-Marécages de Zangar
April 2nd, 2011
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter

local TableInsert, TableRemove, format, strsplit = table.insert, table.remove, format, strsplit
local C_Calendar, C_DateAndTime, time, date = C_Calendar, C_DateAndTime, time, date

local function ScanCalendar()
	-- Save the current month
	local currentMonthInfo = C_Calendar.GetMonthInfo()
	local dateInfo = C_DateAndTime.GetCurrentCalendarTime()

	-- Set the calendar to this month & year
	C_Calendar.SetAbsMonth(dateInfo.month, dateInfo.year)
	
	local char = thisCharacter
	char.Calendar = nil

	local today = date("%Y-%m-%d")
	local now = date("%H:%M")

	-- Save this month (from today) + 6 following months
	-- for monthOffset = 0, 6 do
	for monthOffset = 0, 0 do
		local charMonthInfo = C_Calendar.GetMonthInfo(monthOffset)
		local month, year, numDays = charMonthInfo.month, charMonthInfo.year, charMonthInfo.numDays
		local startDay = (monthOffset == 0) and dateInfo.monthDay or 1

		for day = startDay, numDays do
			for i = 1, C_Calendar.GetNumDayEvents(monthOffset, day) do		-- number of events that day ..

				-- http://www.wowwiki.com/API_CalendarGetDayEvent
				local info = C_Calendar.GetDayEvent(monthOffset, day, i)
				local calendarType = info.calendarType
				local inviteStatus = info.inviteStatus
				
				-- 8.0 : for some events, the calendar type may be nil, filter them out
				if calendarType and calendarType ~= "HOLIDAY" and calendarType ~= "RAID_LOCKOUT" and calendarType ~= "RAID_RESET" then
										
					-- don't save holiday events, they're the same for all chars, and would be redundant..who wants to see 10 fishing contests every Sunday ? =)

					local eventDate = format("%04d-%02d-%02d", year, month, day)
					local eventTime = format("%02d:%02d", info.startTime.hour, info.startTime.minute)

					-- Only add events older than "now"
					if eventDate > today or (eventDate == today and eventTime > now) then
						char.Calendar = char.Calendar or {}
						TableInsert(char.Calendar, format("%s|%s|%s|%d|%d", eventDate, eventTime, info.title, info.eventType, inviteStatus ))
					end
				end
			end
		end
	end

	-- Restore current month
	C_Calendar.SetAbsMonth(currentMonthInfo.month, currentMonthInfo.year)

	AddonFactory:Broadcast("DATASTORE_CALENDAR_SCANNED")
	char.lastUpdate = time()
end

local function OnCalendarUpdateEventList()
	-- The Calendar addon is LoD, and most functions return nil if the calendar is not loaded, so unless the CalendarFrame is valid, exit right away
	if not CalendarFrame then return end

	-- prevent CalendarSetAbsMonth from triggering a scan (= avoid infinite loop)
	addon:StopListeningTo("CALENDAR_UPDATE_EVENT_LIST")
	ScanCalendar()
	addon:ListenTo("CALENDAR_UPDATE_EVENT_LIST", OnCalendarUpdateEventList)
end

local function _GetCalendarEventInfo(character, index)
	local event = character.Calendar[index]
	if event then
		return strsplit("|", event)		-- eventDate, eventTime, title, eventType, inviteStatus
	end
end


AddonFactory:OnAddonLoaded(addonName, function()
	DataStore:RegisterModule({
		addon = addon,
		addonName = addonName,
		rawTables = {
			"DataStore_Agenda_Options"
		},
		characterTables = {
			["DataStore_Agenda_Characters"] = {
				GetNumCalendarEvents = function(character)
					return character.Calendar and #character.Calendar or 0
				end,
				GetCalendarEventInfo = _GetCalendarEventInfo,
				HasCalendarEventExpired = function(character, index)
					local eventDate, eventTime = _GetCalendarEventInfo(character, index)
					
					if eventDate and eventTime then
						local today = date("%Y-%m-%d")
						local now = date("%H:%M")

						if eventDate < today or (eventDate == today and eventTime <= now) then
							return true
						end
					end
				end,
				DeleteCalendarEvent = function(character, index)
					if character.Calendar then
						TableRemove(character.Calendar, index)
					end
				end,
			},
		}
	})
	
	thisCharacter = DataStore:GetCharacterDB("DataStore_Agenda_Characters", true)
end)

AddonFactory:OnAddonLoaded("Blizzard_Calendar", function()
	addon:ListenTo("CALENDAR_UPDATE_EVENT_LIST", OnCalendarUpdateEventList)
end)

AddonFactory:OnPlayerLogin(function()
	-- Only register after setting the current month !
	local info = C_DateAndTime.GetCurrentCalendarTime()
	C_Calendar.SetAbsMonth(info.month, info.year)
end)
