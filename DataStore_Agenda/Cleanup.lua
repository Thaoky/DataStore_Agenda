--[[	*** DataStore_Agenda ***
Written by : Thaoky, EU-Marécages de Zangar
January 5th, 2024

This file manages the cleanup of expired dungeons
--]]

local options
local format, tonumber, date, GetCVar = format, tonumber, date, GetCVar

local daysPerMonth = { 31,28,31,30,31,30,31,31,30,31,30,31 }

local function GetNextWeeklyReset(weeklyResetDay)
	local year = tonumber(date("%Y"))
	local month = tonumber(date("%m"))
	local day = tonumber(date("%d"))
	local todaysWeekDay = tonumber(date("%w"))
	local numDays = 0		-- number of days to add
	
	-- how many days should we add to today's date ?
	if todaysWeekDay < weeklyResetDay then					-- if it is Monday (1), and reset is on Wednesday (3)
		numDays = weeklyResetDay - todaysWeekDay		-- .. then we add 2 days
	elseif todaysWeekDay > weeklyResetDay then			-- if it is Friday (5), and reset is on Wednesday (3)
		numDays = weeklyResetDay - todaysWeekDay + 7	-- .. then we add 5 days (3 - 5 + 7)
	else
		-- Same day : if the weekly reset period has passed, add 7 days, if not yet, than 0 days
		numDays = (tonumber(date("%H")) > options.WeeklyResetHour) and 7 or 0
	end
	
	-- if numDays == 0 then return end
	if numDays == 0 then return date("%Y-%m-%d") end
	
	local newDay = day + numDays	-- 25th + 2 days = 27, or 28th + 10 days = 38 days (used to check days overflow in a month)
	
	if (year % 4 == 0) and (year % 100 ~= 0 or year % 400 == 0) then	-- is leap year ?
		daysPerMonth[2] = 29
	end	
	
	-- no overflow ? (25th + 2 days = 27, we stay in the same month)
	if newDay <= daysPerMonth[month] then
		return format("%04d-%02d-%02d", year, month, newDay)
	end
	
	-- we have a "day" overflow, but still in the same year
	if month <= 11 then
		-- 27/03 + 10 days = 37 - 31 days in March, so 6/04
		return format("%04d-%02d-%02d", year, month + 1, newDay - daysPerMonth[month])
	end
	
	-- at this point, we had a day overflow in December, so jump to next year
	return format("%04d-%02d-%02d", year + 1, 1, newDay - daysPerMonth[month])
end

local function GetWeeklyResetDayByRegion(region)
	local day = 2		-- default to US, 2 = Tuesday
	
	if region then
		if region == "EU" then 
			day = 3 
		elseif region == "CN" or region == "KR" or region == "TW" then
			day = 4
		end
	end
	
	return day
end

local function InitializeWeeklyParameters()
	local weeklyResetDay = GetWeeklyResetDayByRegion(GetCVar("portal"))

	options.WeeklyResetDay = weeklyResetDay
	options.WeeklyResetHour = 6			-- 6 am should be ok in most zones
	options.NextWeeklyReset = GetNextWeeklyReset(weeklyResetDay)
end

DataStore:OnPlayerLogin(function()
	-- Clear expired dungeons
	options = DataStore_Agenda_Options

	-- WeeklyResetDay = nil,		-- weekday (0 = Sunday, 6 = Saturday)
	-- WeeklyResetHour = nil,		-- 0 to 23
	-- NextWeeklyReset = nil,
	
	local weeklyResetDay = options.WeeklyResetDay
	
	if not weeklyResetDay then			-- if the weekly reset day has not been set yet ..
		InitializeWeeklyParameters()
		return	-- initial pass, nothing to clear
	end
	
	local nextReset = options.NextWeeklyReset
	if not nextReset then		-- heal broken data
		InitializeWeeklyParameters()
		nextReset = options.NextWeeklyReset -- retry
	end
	
	local today = date("%Y-%m-%d")

	if (today < nextReset) then return end		-- not yet ? exit
	if (today == nextReset) and (tonumber(date("%H")) < options.WeeklyResetHour) then return end
	
	-- at this point, we may reset
	if DataStore_Agenda_LFGDungeons then
		wipe(DataStore_Agenda_LFGDungeons)
	end
	
	-- finally, set the next reset day
	options.NextWeeklyReset = GetNextWeeklyReset(weeklyResetDay)
end)
