if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local addonName, addon = ...
local contacts

local C_FriendList = C_FriendList

local function ScanContacts()

	-- Only friends, not real id, as they're always visible
	-- These vary per character
	for i = 1, C_FriendList.GetNumFriends() do	
	   local name, level, class, zone, isOnline, note = C_FriendList.GetFriendInfoByIndex(i)

		if name then
			contacts[name] = contacts[name] or {}
			
			local contact = contacts[name]
			contact.note = note
			contact.level = isOnline and level	-- only valid if friend is online
			contact.class = isOnline and class	-- only valid if friend is online
			contact.friendOf = DataStore.ThisChar
		end
	end
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		rawTables = {
			"DataStore_Agenda_Contacts"
		},
	})
	
	DataStore:RegisterMethod(addon, "GetContacts", function() return contacts end)
	DataStore:RegisterMethod(addon, "GetContactInfo", function(name)
		if contacts[name] then
			local contact = contacts[name]
			return contact.level, contact.class, contact.note
		end
	end)

	contacts = DataStore_Agenda_Contacts
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("PLAYER_ALIVE", ScanContacts)
	addon:ListenTo("FRIENDLIST_UPDATE", ScanContacts)
end)
