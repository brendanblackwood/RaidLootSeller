local RLS_LONG_ADDON_NAME_PREFIX = '<RaidLootSeller> '
local RLS_SHORT_ADDON_NAME_PREFIX = '<RLS> '

local function CanUseRaidWarning()
	return UnitIsGroupLeader('player') or UnitIsGroupAssistant('player')
end

local function GetBroadcastChannel(isHighPriority)
	local channel
	if IsInGroup() then
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			if CanUseRaidWarning() and isHighPriority then 
				channel = 'RAID_WARNING' -- RAID_WARNING
			else
				channel = 'INSTANCE_CHAT' -- INSTANCE_CHAT
			end
		elseif IsInRaid() then
			if CanUseRaidWarning() and isHighPriority then 
				channel = 'RAID_WARNING' -- RAID_WARNING
			else
				channel = 'RAID' -- RAID
			end
		else	
			channel = 'PARTY' -- PARTY
		end
	else
		channel = 'EMOTE'  -- for testing purposes
	end
	return channel
end

function RLS_GetFullName(name, realm)
	if name == nil then
		return nil
	elseif realm == nil then
		return name
	else
		return name .. '-' .. realm
	end
end

function RLS_GetUnitNameWithRealm(unit)
	local guid
	if unit ~= nil then
		guid = UnitGUID(unit)
	end
	if guid ~= nil then
		local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
		if not realm or realm == '' then
			realm = GetRealmName()
		end
		return RLS_GetFullName(name, realm)
	else
		return nil
	end
end

function RLS_GetNameWithoutRealm(name)
	return (Ambiguate(name, 'short'))
end

function RLS_SendBroadcast(message, isHighPriority)
	SendChatMessage(RLS_SHORT_ADDON_NAME_PREFIX .. message, GetBroadcastChannel(isHighPriority))
end	

function RLS_SendWhisper(message, person)
	SendChatMessage(RLS_SHORT_ADDON_NAME_PREFIX .. message, 'WHISPER', nil, person)
end

function RLS_CreateEmptyTooltip(rows)
  local tip = CreateFrame('GameTooltip')
	local leftside = {}
	local rightside = {}
	local L, R
    for i = 1, rows do
        L, R = tip:CreateFontString(), tip:CreateFontString()
        L:SetFontObject(GameFontNormal)
        R:SetFontObject(GameFontNormal)
        tip:AddFontStrings(L, R)
        leftside[i] = L
		rightside[i] = R
    end
    tip.leftside = leftside
	tip.rightside = rightside
    return tip
end
