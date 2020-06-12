RaidLootSeller = LibStub("AceAddon-3.0"):NewAddon("RaidLootSeller", "AceTimer-3.0", "AceEvent-3.0")

-- indexes of array returned by GetFullItemInfo()
local FII_ITEM = "ITEM"                                  -- contains the actual item
local FII_NAME = "NAME"                                  -- return value 1 of Blizzard API call GetItemInfo()
local FII_LINK = "LINK"                                  -- return value 2 of Blizzard API call GetItemInfo()
local FII_QUALITY = "QUALITY"                            -- return value 3 of Blizzard API call GetItemInfo()
local FII_BASE_ILVL = "BASE_ILVL"                        -- return value 4 of Blizzard API call GetItemInfo()
local FII_REQUIRED_LEVEL = "REQUIRED_LEVEL"              -- return value 5 of Blizzard API call GetItemInfo()
local FII_TYPE = "TYPE"                                  -- return value 6 of Blizzard API call GetItemInfo()
local FII_SUB_TYPE = "SUB_TYPE"                          -- return value 7 of Blizzard API call GetItemInfo()
local FII_MAX_STACK = "MAX_STACK"                        -- return value 8 of Blizzard API call GetItemInfo()
local FII_ITEM_EQUIP_LOC = "ITEM_EQUIP_LOC"              -- return value 9 of Blizzard API call GetItemInfo()
local FII_TEXTURE = "TEXTURE"                            -- return value 10 of Blizzard API call GetItemInfo()
local FII_VENDOR_PRICE = "VENDOR_PRICE"                  -- return value 11 of Blizzard API call GetItemInfo()
local FII_CLASS = "CLASS"                                -- return value 12 of Blizzard API call GetItemInfo()
local FII_SUB_CLASS = "SUB_CLASS"                        -- return value 13 of Blizzard API call GetItemInfo()
local FII_BIND_TYPE = "BIND_TYPE"                        -- return value 14 of Blizzard API call GetItemInfo()
local FII_EXPAC_ID = "EXPAC_ID"                          -- return value 15 of Blizzard API call GetItemInfo()
local FII_ITEM_SET_ID = "ITEM_SET_ID"                    -- return value 16 of Blizzard API call GetItemInfo()
local FII_IS_CRAFTING_REAGENT = "IS_CRAFTING_REAGENT"    -- return value 17 of Blizzard API call GetItemInfo()
local FII_IS_EQUIPPABLE = "IS_EQUIPPABLE"                -- true if the item is equippable, false otherwise
local FII_IS_RELIC = "IS_RELIC"                          -- true if item is a relic, false otherwise
local FII_REAL_ILVL = "REAL_ILVL"                        -- real ilvl, derived from tooltip
local FII_RELIC_TYPE = "RELIC_TYPE"                      -- relic type, derived from tooltip
local FII_CLASSES = "CLASSES"                            -- uppercase string of classes that can use the item (ex: tier); nil if item is not class-restricted

local SELL_MESSAGE = 'SELL'

local bidTimers = {}  -- list of timers so we can cancel them

local whisperedItems = {}  -- list of items we've whispered to people; index is character name-realm, content is item

local currentBid = 0
local currentMinimumBid = 0
local currentBidder = nil

local numOfQueuedRollItems = 0
local queuedRollOwners = {}
local queuedRollItems = {}

local currentRollOwner = nil
local currentRollItem = nil
local currentRolls = {}

local RLS_RANDOM_ROLL_RESULT_PATTERN = _G.RANDOM_ROLL_RESULT
      RLS_RANDOM_ROLL_RESULT_PATTERN = RLS_RANDOM_ROLL_RESULT_PATTERN:gsub('%%s', '(.+)')
      RLS_RANDOM_ROLL_RESULT_PATTERN = RLS_RANDOM_ROLL_RESULT_PATTERN:gsub('%%d %(%%d%-%%d%)', '(%%d+) %%((%%d+)%%-(%%d+)%%)')
      RLS_RANDOM_ROLL_RESULT_PATTERN = '^' .. RLS_RANDOM_ROLL_RESULT_PATTERN .. '$'

local RLS_ITEM_LEVEL_PATTERN = _G.ITEM_LEVEL
RLS_ITEM_LEVEL_PATTERN = RLS_ITEM_LEVEL_PATTERN:gsub('%%d', '(%%d+)')  -- 'Item Level (%d+)'

local RLS_RELIC_TOOLTIP_TYPE_PATTERN = _G.RELIC_TOOLTIP_TYPE
RLS_RELIC_TOOLTIP_TYPE_PATTERN = RLS_RELIC_TOOLTIP_TYPE_PATTERN:gsub('%%s', '(.+)')  -- '(.+) Artifact Relic'

local RLS_CLASSES_ALLOWED_PATTERN = _G.ITEM_CLASSES_ALLOWED
      RLS_CLASSES_ALLOWED_PATTERN = RLS_CLASSES_ALLOWED_PATTERN:gsub('%%s', '(.+)') 

function RaidLootSeller:OnInitialize()
    local defaults = {
        profile = {
            enabled = true,
            delay = 20,
            displayInstructions = false,
              monitorInstanceChat = false,
            bidIncrement = 5000,
            price = {
                INVTYPE_AMMO = 25000,
                INVTYPE_HEAD = 25000,
                INVTYPE_NECK = 25000,
                INVTYPE_SHOULDER = 25000,
                INVTYPE_BODY = 25000,
                INVTYPE_CHEST = 25000,
                INVTYPE_ROBE = 25000,
                INVTYPE_WAIST = 25000,
                INVTYPE_LEGS = 25000,
                INVTYPE_FEET = 25000,
                INVTYPE_WRIST = 25000,
                INVTYPE_HAND = 25000,
                INVTYPE_FINGER = 25000,
                INVTYPE_TRINKET = 30000,
                INVTYPE_CLOAK = 25000,
                INVTYPE_WEAPON = 30000,
                INVTYPE_SHIELD = 30000,
                INVTYPE_2HWEAPON = 30000,
                INVTYPE_WEAPONMAINHAND = 30000,
                INVTYPE_WEAPONOFFHAND = 30000,
                INVTYPE_HOLDABLE = 30000,
                INVTYPE_RANGED = 30000,
                INVTYPE_THROWN = 30000,
                INVTYPE_RANGEDRIGHT = 30000,
                INVTYPE_RELIC = 25000,
                INVTYPE_TABARD = 25000,
                INVTYPE_BAG = 25000,
                INVTYPE_QUIVER = 25000
            }
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RaidLootSellerDB", defaults, true)

    local optionsTable = {
        type = "group",
        args = {
            toggle = {
                order = 0,
                name = "Enable",
                desc = "Enables / disables the addon",
                type = "toggle",
                width = "full",
                set = function(info,val) self:ToggleEnableDisable(info, val) end,
                get = function(info) return self.db.profile.enabled end,
            },
            b1 = {
                order = 1,
                type = "header",
                name = "Options"
            },
            displayInstructions = {
                order = 2,
                name = "Show usage instructions in raid chat when a boss is killed (requires raid leader or assist).",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.displayInstructions = val end,
                get = function(info) return self.db.profile.displayInstructions end,
            },
            monitorInstanceChat = {
                order = 3,
                name = "Respond to 'sell [Item]' messages in party/raid chat (requires leader or assist).",
                type = "toggle",
                width = "full",
                set = function(info,val) self:ToggleMonitorInstanceChat(info, val) end,
                get = function(info) return self.db.profile.monitorInstanceChat end,
            },
            delay = {
                order = 4,
                name = "Bid Timer",
                desc = "Set the amount of time an item should be up for auction in seconds.",
                type = "range",
                width = "double",
                min = 15,
                max = 30,
                step = 5,
                set = function(info,val) self.db.profile.delay = val end,
                get = function(info) return self.db.profile.delay end
            },
            bidIncrement = {
                order = 5,
                name = "Bid Increment",
                desc = "Set the amount of gold a user must bid above the current bid.",
                type = "range",
                width = "double",
                min = 1000,
                max = 50000,
                step = 1000,
                set = function(info,val) self.db.profile.bidIncrement = val end,
                get = function(info) return self.db.profile.bidIncrement end
            },
            announce = {
                order = 6,
                name = "announce",
                desc = "Announce usage instructions to group.",
                type = "execute",
                func = function() self:BroadcastInstructions() end
            },
            sell = {
                order = 6,
                name = "sell",
                desc = "Allow auctioneer to list an item for sale",
                type = "execute",
                func = function(info)
                    self:QueueItem(UnitName("player"), string.match(info.input, 'sell (|.+|r)'))
                    if currentItem == nil then
                        self:AskForRolls()
                    end
                end
            }
        }
    }
    
    LibStub("AceConfig-3.0"):RegisterOptionsTable("RaidLootSeller", optionsTable, {"rls"})
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RaidLootSeller", "RaidLootSeller");

    if (self.db.profile.enabled) then
        print("<RLS> RaidLootSeller Enabled")
        self:RegisterEvent("CHAT_MSG_WHISPER", "WhisperReceivedEvent")
        self:RegisterEvent("ENCOUNTER_END", "EncounterEndedEvent")

        if (self.db.profile.monitorInstanceChat) then
            self:MonitorInstanceChat()
        end
    end
end

function RaidLootSeller:OnDisable()
end

function RaidLootSeller:ToggleEnableDisable(info, val)
    if (val) then
        if (self.db.profile.enabled == false) then
            print('<RLS> RaidLootSeller has been enabled.')
            self:RegisterEvent("CHAT_MSG_WHISPER", "WhisperReceivedEvent")
            self:RegisterEvent("ENCOUNTER_END", "EncounterEndedEvent")
            if (self.db.profile.monitorInstanceChat) then
                self:MonitorInstanceChat()
            end
        end
    else
        print('<RLS> RaidLootSeller has been disabled.')
        self:UnregisterEvent("CHAT_MSG_WHISPER", "WhisperReceivedEvent")
        self:UnregisterEvent("ENCOUNTER_END", "EncounterEndedEvent")
        self:UnmonitorInstanceChat()
    end
    self.db.profile.enabled = val
end

function RaidLootSeller:ToggleMonitorInstanceChat(info, val)
    if (val) then
        if (self.db.profile.monitorInstanceChat == false) then
            self:MonitorInstanceChat()
        end
    else
        self:UnmonitorInstanceChat()
    end
    self.db.profile.monitorInstanceChat = val
end

function RaidLootSeller:MonitorInstanceChat()
    self:RegisterEvent("CHAT_MSG_RAID", "ChatReceivedEvent")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "ChatReceivedEvent")
    self:RegisterEvent("CHAT_MSG_PARTY", "ChatReceivedEvent")
    self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "ChatReceivedEvent")
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", "ChatReceivedEvent")
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", "ChatReceivedEvent")
end

function RaidLootSeller:UnmonitorInstanceChat()
    self:UnregisterEvent("CHAT_MSG_RAID", "ChatReceivedEvent")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER", "ChatReceivedEvent")
    self:UnregisterEvent("CHAT_MSG_PARTY", "ChatReceivedEvent")
    self:UnregisterEvent("CHAT_MSG_PARTY_LEADER", "ChatReceivedEvent")
    self:UnregisterEvent("CHAT_MSG_INSTANCE_CHAT", "ChatReceivedEvent")
    self:UnregisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", "ChatReceivedEvent")
end

function RaidLootSeller:EncounterEndedEvent(event, ...)
    local encounterID, encounterName, difficultyID, groupSize, success = ...
    if (success and self.db.profile.enabled and self.db.profile.displayInstructions) then
        inInstance, instanceType = IsInInstance()
        if instanceType == "raid" and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            RaidLootSeller:ScheduleTimer("BroadcastInstructions", 5)
        end
    end 
end

function RaidLootSeller:BroadcastInstructions()
  RLS_SendBroadcast('RaidLootSeller - Items in the raid may be auctioned off.'
    .. ' If you see an item go up for auction that you want, whisper your bids to ' .. UnitName("player"), false)
end

function RaidLootSeller:WhisperReceivedEvent(event, ...)
      local message, sender = ...
      self:ProcessWhisper(message, sender)
end

function RaidLootSeller:ChatReceivedEvent(event, ...)
    -- only offer rolls shown in raid/party chat if the user is a group leader or has assist in raid
    if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
        local message, sender = ...
        self:ProcessWhisper(message, sender)
    end
end

function RaidLootSeller:ProcessBidMessage(message, sender)
    if not string.find(sender, '-') then
        sender = RLS_GetUnitNameWithRealm(sender)
    end

    local bid = 0

    if currentRollItem == nil then
        return
    end
    
    local _, _, num, suffix = string.find(message, '^(%d+%.?%d*)([k|K|m|M]?)$')
    if num == nil then
        RLS_SendWhisper('Please provide a bid of the form "5000" or "5k"', sender)
        return
    end

    if suffix ~= nil and suffix ~= '' then
        if string.lower(suffix) == 'k' then
            bid = tonumber(num) * 1000
        elseif string.lower(suffix) == 'm' then
            bid = tonumber(num) * 1000000
        end
    else
        bid = tonumber(num)
    end

    if (currentBidder == nil and bid >= currentMinimumBid) or (currentBidder ~= nil and bid > (currentBid + self.db.profile.bidIncrement)) then
        currentBid = bid
        currentBidder = sender
        RLS_SendWhisper('Your bid of ' .. currentBid .. ' has been accepted.', sender)
        RLS_SendBroadcast(RLS_GetNameWithoutRealm(sender) .. ' bid ' .. currentBid .. ' for ' .. currentRollItem, true)
        self:ResetCountDown()
    elseif currentBidder ~= nil then
        RLS_SendWhisper('Current bid is ' .. currentBid .. ' by ' .. currentBidder .. '. Please bid at least ' .. self.db.profile.bidIncrement .. ' higher.', sender)
    else
        RLS_SendWhisper('Minimum bid is ' .. currentMinimumBid .. '. You must bid at least this much.', sender)
    end

end

function RaidLootSeller:ProcessSellMessage(message, sender)
    if not string.find(sender, '-') then
        sender = RLS_GetUnitNameWithRealm(sender)
    end

    -- if the person whispered 'sell [item]', then add the item to the array so we can process it
    local _, _, whisperedItem = string.find(message, '[sell|Sell|SELL][%s]*(|.+|r)')
    if whisperedItem ~= nil then
        whisperedItems[sender] = whisperedItem
    end

    message = string.upper(message)

    if whisperedItem ~= nil or message == SELL_MESSAGE or message == '\'' .. SELL_MESSAGE .. '\'' then
        if whisperedItems[sender] ~= nil then
            local item = whisperedItems[sender]

            whisperedItems[sender] = nil
            self:QueueItem(sender, item)

            -- if we're still rolling for another item, let the person know their item is queued
            if currentRollItem ~= nil then
                RLS_SendWhisper('Thank you! ' .. item .. ' will be auctioned off after current item is done.', sender)
            else 
                RLS_SendWhisper('Thank you! ' .. item .. ' is being auctioned off now.', sender)
                self:AskForRolls()
            end
        end
    end
end

function RaidLootSeller:ProcessWhisper(message, sender) 
    msg = string.lower(message)

    -- process sell requests
    if string.match(msg, 'sell') ~= nil then
        self:ProcessSellMessage(message, sender)
    end

    -- process bids
    if string.match(msg, '^(%d+%.?%d*)([k|K|m|M]?)$') ~= nil then
        self:ProcessBidMessage(message, sender)
    end
end

function RaidLootSeller:QueueItem(sender, item)
    queuedRollOwners[numOfQueuedRollItems] = sender
    queuedRollItems[numOfQueuedRollItems] = item
    numOfQueuedRollItems = numOfQueuedRollItems + 1
end

function RaidLootSeller:AskForRolls()
    if currentRollItem == nil and numOfQueuedRollItems > 0 then
        currentRollOwner = queuedRollOwners[numOfQueuedRollItems - 1]
        currentRollItem = queuedRollItems[numOfQueuedRollItems - 1]
        numOfQueuedRollItems = numOfQueuedRollItems - 1

        -- try and get details about the item up for sale
        local description = ""
        local cost = ""
        
        local fullItemInfo = self:GetFullItemInfo(currentRollItem)
        description = " ("
        if fullItemInfo[FII_REAL_ILVL] ~= nil then
            description = description .. fullItemInfo[FII_REAL_ILVL] .. " "
        end
        if fullItemInfo[FII_IS_RELIC] and fullItemInfo[FII_RELIC_TYPE] ~= nil then
            description = description .. fullItemInfo[FII_RELIC_TYPE] .. " Relic"
        else
            if fullItemInfo[FII_CLASS] == LE_ITEM_CLASS_ARMOR then
                if fullItemInfo[FII_SUB_CLASS] == LE_ITEM_ARMOR_GENERIC or fullItemInfo[FII_ITEM_EQUIP_LOC] == "INVTYPE_CLOAK" then
                    description = description .. _G[fullItemInfo[FII_ITEM_EQUIP_LOC]]
                else
                    description = description .. fullItemInfo[FII_SUB_TYPE] .. " " .. _G[fullItemInfo[FII_ITEM_EQUIP_LOC]]
                end
            else
                description = description .. fullItemInfo[FII_SUB_TYPE]
            end
        end
        description = description .. ")"
        currentMinimumBid = tonumber(self.db.profile.price[fullItemInfo[FII_ITEM_EQUIP_LOC]])

        RLS_SendBroadcast('Bid for ' .. currentRollItem .. description .. ' starting at ' .. currentMinimumBid .. '.', true)
    
        self:ResetCountDown()
    end
end

function RaidLootSeller:ResetCountDown()
    -- cancel any existing timers
    for _, timer in ipairs(bidTimers) do
        RaidLootSeller:CancelTimer(timer)
    end

    table.insert(bidTimers, RaidLootSeller:ScheduleTimer("tenSecondsRemaining", self.db.profile.delay - 10))
    table.insert(bidTimers, RaidLootSeller:ScheduleTimer("fiveSecondsRemaining", self.db.profile.delay - 5))
    table.insert(bidTimers, RaidLootSeller:ScheduleTimer("zeroSecondsRemaining", self.db.profile.delay))
    table.insert(bidTimers, RaidLootSeller:ScheduleTimer("EndRolls", self.db.profile.delay + 1))
end

function RaidLootSeller:tenSecondsRemaining()
    RLS_SendBroadcast('10 seconds remaining to bid for ' .. currentRollItem, true)
end

function RaidLootSeller:fiveSecondsRemaining()
    RLS_SendBroadcast('5 seconds remaining to bid for ' .. currentRollItem, true)
end

function RaidLootSeller:zeroSecondsRemaining()
    RLS_SendBroadcast('Bidding has ended for ' .. currentRollItem, false)
end

function RaidLootSeller:EndRolls()
    local winner = currentBidder and RLS_GetNameWithoutRealm(currentBidder) or nil

    -- notify everyone of the results of the auction
    if winner ~= nil then
        RLS_SendBroadcast(winner .. ' won ' .. currentRollItem .. ' for ' .. currentBid, true)
        -- wisper winner
        RLS_SendWhisper('You won ' .. currentRollItem .. '! Please open trade with ' .. UnitName("player") .. '.', winner)
        -- wisper loot owner
        RLS_SendWhisper(winner .. ' won your ' .. currentRollItem .. '. Please trade it to ' .. UnitName("player"), currentRollOwner)
    else
        RLS_SendBroadcast('Nobody bid on ' .. currentRollItem .. ' from ' .. RLS_GetNameWithoutRealm(currentRollOwner), true)
    end

    self:ClearBids()
    
    -- if there's another roll to do, let's delay a few seconds before starting the next roll
    if (numOfQueuedRollItems > 0) then
        RaidLootSeller:ScheduleTimer("AskForRolls", 10)
    end

end

function RaidLootSeller:ClearBids()
    currentRollOwner = nil
    currentRollItem = nil
    currentRolls = {}
    queuedRollOwners[numOfQueuedRollItems] = nil
    queuedRollItems[numOfQueuedRollItems] = nil
    currentBid = 0
    currentMinimumBid = 0
    currentBidder = nil
end

-- returns the names from the given array, with 'and others' if array size > limit
function RaidLootSeller:GetNames(namelist, limit)
    local names = ''
    if namelist ~= nil then
        if limit == nil then  -- no limit; show all names
            limit = #namelist
        end
        if namelist[1] ~= nil then
            -- sort the array by ilvl first
            local sortedNamelist = namelist
            if #namelist > 1 then
                local copiedNamelist = ShallowCopy(namelist)  -- we will destroy elements in the list while sorting, so copy it
                sortedNamelist = {}
                local lowestILVL
                local lowestIndex
                local ilvl
                local i = 1
                local size = #copiedNamelist
                while i <= size do
                    lowestILVL = 1000000
                    lowestIndex = 1  -- we could be sorting a list without ilvls, in which case just keep the same order
                    for j = 1, #copiedNamelist do
                        if copiedNamelist[j] ~= nil then
                            ilvl = string.match(copiedNamelist[j], '(%d+)')
                            if ilvl ~= nil then
                                ilvl = tonumber(ilvl)
                                if ilvl < lowestILVL then
                                    lowestILVL = ilvl
                                    lowestIndex = j
                                end
                            end
                        end
                    end
                    table.insert(sortedNamelist, table.remove(copiedNamelist, lowestIndex))
                    i = i + 1
                end
            end
        
            names = sortedNamelist[1]
            local maxnames = min(#sortedNamelist, limit)
            for i = 2, maxnames do
                if #sortedNamelist == 2 then
                    names = names .. ' '
                else
                    names = names .. ', '
                end
                if i == #sortedNamelist then -- last person
                    names = names .. 'and '
                end
                names = names .. sortedNamelist[i]
            end
            if #sortedNamelist > limit then
                names = names .. ', and others'
            end
        end
    end
    return names
end

function RaidLootSeller:GetItemFromQueueByPlayer(player)
    for key, value in pairs(queuedRollOwners) do
        if value == player then
            return queuedRollItems[key]
        end
    end
    return nil
end

function RaidLootSeller:GetFullItemInfo(item)
    fullItemInfo = {}
    if item ~= nil then
        fullItemInfo[FII_ITEM] = item
        
        -- determine the basic values from the Blizzard GetItemInfo() API call
        fullItemInfo[FII_NAME],
        fullItemInfo[FII_LINK],
        fullItemInfo[FII_QUALITY],
        fullItemInfo[FII_BASE_ILVL],
        fullItemInfo[FII_REQUIRED_LEVEL],
        fullItemInfo[FII_TYPE],
        fullItemInfo[FII_SUB_TYPE],
        fullItemInfo[FII_MAX_STACK],
        fullItemInfo[FII_ITEM_EQUIP_LOC],
        fullItemInfo[FII_TEXTURE],
        fullItemInfo[FII_VENDOR_PRICE],
        fullItemInfo[FII_CLASS],
        fullItemInfo[FII_SUB_CLASS],
        fullItemInfo[FII_BIND_TYPE],
        fullItemInfo[FII_EXPAC_ID],
        fullItemInfo[FII_ITEM_SET_ID],
        fullItemInfo[FII_IS_CRAFTING_REAGENT]
        = GetItemInfo(item)

        -- determine whether the item is equippable & whether it is a relic
        fullItemInfo[FII_IS_EQUIPPABLE] = IsEquippableItem(item)
        fullItemInfo[FII_IS_RELIC] = fullItemInfo[FII_CLASS] == LE_ITEM_CLASS_GEM and fullItemInfo[FII_SUB_CLASS] == LE_ITEM_ARMOR_RELIC

        -- we only need to determine other values if it's an equippable item or a relic
        if fullItemInfo[FII_IS_EQUIPPABLE] or fullItemInfo[FII_IS_RELIC] then

            -- set up the tooltip to determine values that aren't returned via GetItemInfo()
            local rows = 30
            if fullItemInfo[FII_IS_RELIC] then
                rows = 6  -- if it's a relic, we only need to inspect the first 6 rows
            end
            tooltip = tooltip or RLS_CreateEmptyTooltip(30)
            tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
            tooltip:ClearLines()
            tooltip:SetHyperlink(item)
            local t
            local index

            -- determine the real iLVL
            local realILVL = nil
            t = tooltip.leftside[2]:GetText()
            if t ~= nil then
                realILVL = t:match(RLS_ITEM_LEVEL_PATTERN)
            end

            if realILVL == nil then  -- ilvl can be in the 2nd or 3rd line dependng on the tooltip; if we didn't find it in 2nd, try 3rd
                t = tooltip.leftside[3]:GetText()
                if t ~= nil then
                    realILVL = t:match(RLS_ITEM_LEVEL_PATTERN)
                end
            end
            if realILVL == nil then  -- if we still couldn't find it (shouldn't happen), just use the ilvl we got from GetItemInfo()
                realILVL = fullItemInfo[FII_BASE_ILVL]
            end
            fullItemInfo[FII_REAL_ILVL] = tonumber(realILVL)

            -- if the item is a relic, determine the relic type
            local relicType = nil
            if fullItemInfo[FII_IS_RELIC] then
                index = 1
                while not relicType and tooltip.leftside[index] do
                    t = tooltip.leftside[index]:GetText()
                    if t ~= nil then
                        relicType = t:match(RLS_RELIC_TOOLTIP_TYPE_PATTERN)                
                    end
                    index = index + 1
                end
            end
            fullItemInfo[FII_RELIC_TYPE] = relicType

            -- if the item is restricted to certain classes, determine which ones
            local classes = nil
            index = 1
            while not classes and tooltip.leftside[index] do
                t = tooltip.leftside[index]:GetText()
                if t ~= nil then
                    classes = t:match(RLS_CLASSES_ALLOWED_PATTERN)
                end
                index = index + 1
            end
            if classes ~= nil then
                classes = string.upper(classes)
                classes = string.gsub(classes, " ", "")  -- remove space for DEMON HUNTER, DEATH KNIGHT
            end
            fullItemInfo[FII_CLASSES] = classes

            -- hide the tooltip now that we're done with it (is this really necessary?)
            tooltip:Hide()
        end
  end

    return fullItemInfo
end
