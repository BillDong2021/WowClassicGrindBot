local Load = select(2, ...)
local DataToColor = unpack(Load)
local Range = DataToColor.Libs.RangeCheck

-- Discover player's direction in radians (360 degrees = 2π radians)
function DataToColor:GetPlayerFacing()
    return GetPlayerFacing() or 0
end

-- Use Astrolabe function to get current player position
function DataToColor:GetCurrentPlayerPosition()
    local map = C_Map.GetBestMapForUnit(DataToColor.C.unitPlayer)
    if map ~= nil then
        local position = C_Map.GetPlayerMapPosition(map, DataToColor.C.unitPlayer)
        if position ~= nil then
            return position:GetXY()
        end
    end
end

-- Base 2 converter for up to 24 boolean values to a single pixel square.
function DataToColor:Base2Converter()
    -- 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384
    return
    DataToColor:MakeIndexBase2(DataToColor:targetCombatStatus(), 0) +
    DataToColor:MakeIndexBase2(DataToColor:GetEnemyStatus(), 1) +
    DataToColor:MakeIndexBase2(DataToColor:deadOrAlive(), 2) +
    DataToColor:MakeIndexBase2(DataToColor:checkTalentPoints(), 3) +
    DataToColor:MakeIndexBase2(DataToColor:isTradeRange(), 4) +
    DataToColor:MakeIndexBase2(DataToColor:targetHostile(), 5) +
    DataToColor:MakeIndexBase2(DataToColor:IsPetVisible(), 6) +
    DataToColor:MakeIndexBase2(DataToColor:mainhandEnchantActive(), 7) +
    DataToColor:MakeIndexBase2(DataToColor:offhandEnchantActive(), 8) +
    DataToColor:MakeIndexBase2(DataToColor:GetInventoryBroken(), 9) +
    DataToColor:MakeIndexBase2(DataToColor:IsPlayerFlying(), 10) +
    DataToColor:MakeIndexBase2(DataToColor:IsPlayerSwimming(), 11) +
    DataToColor:MakeIndexBase2(DataToColor:petHappy(), 12) +
    DataToColor:MakeIndexBase2(DataToColor:hasAmmo(), 13) +
    DataToColor:MakeIndexBase2(DataToColor:playerCombatStatus(), 14) +
    DataToColor:MakeIndexBase2(DataToColor:IsTargetOfTargetPlayer(), 15) +
    DataToColor:MakeIndexBase2(DataToColor:IsAutoRepeatSpellOn(DataToColor.C.Spell.AutoShotId), 16) +
    DataToColor:MakeIndexBase2(DataToColor:hasTarget(), 17) +
    DataToColor:MakeIndexBase2(DataToColor:IsPlayerMounted(), 18) +
    DataToColor:MakeIndexBase2(DataToColor:IsAutoRepeatSpellOn(DataToColor.C.Spell.ShootId), 19) +
    DataToColor:MakeIndexBase2(DataToColor:IsCurrentSpell(DataToColor.C.Spell.AttackId), 20) +
    DataToColor:MakeIndexBase2(DataToColor:targetIsNormal(), 21)+
    DataToColor:MakeIndexBase2(DataToColor:IsTagged(), 22) +
    DataToColor:MakeIndexBase2(DataToColor:IsPlayerFalling(), 23)
end

function DataToColor:Base2Converter2()
    return
    DataToColor:MakeIndexBase2(DataToColor:IsPlayerDrowning(), 0) +
    DataToColor:MakeIndexBase2(DataToColor.corpseInRange, 1)
end

function DataToColor:Base2CustomTrigger(t)
    local v = 0
    for i=0, 23 do
        v = v + DataToColor:MakeIndexBase2(t[i], i)
    end
    return v
end

function DataToColor:Set(trigger, input)
    if input == true then input = 1 end
    local v = tonumber(input) or 0
    if v > 0 then v = 1 end
    if trigger >= 0 and trigger <= 23 then
        DataToColor.customTrigger1[trigger] = v
    end
end

function DataToColor:getAuraMaskForClass(func, unitId, table)
    local num = 0
    for k, v in pairs(table) do
        for i = 1, 10 do
            local name, texture = func(unitId, i)
            if name == nil then
                break
            end
            if v[texture] or string.find(name, v[1]) then
                --DataToColor:Print(name.." -> "..v[1]);
                num = num + DataToColor:MakeIndexBase2(1, k)
                break
            end
        end
    end
    return num
end

function DataToColor:getAuraCount(func, unitId)
    local num = 0
    for i = 1, 10 do
        local name = func(unitId, i)
        if name == nil then
            break
        end
        num = num + 1
    end
    return num
end

-- Grabs current targets name
function DataToColor:GetTargetName(partition)
    if UnitExists(DataToColor.C.unitTarget) then
        local target = GetUnitName(DataToColor.C.unitTarget)
        target = DataToColor:StringToASCIIHex(target)
        if partition < 3 then
            return tonumber(string.sub(target, 0, 6))
        else if target > 999999 then
                return tonumber(string.sub(target, 7, 12))
            end
        end
    end
    return 0
end

function DataToColor:CastingInfoSpellId(unitId)

    local UnitCastingInfo = { DataToColor.UnitCastingInfo(unitId) }
    local startTime = UnitCastingInfo[5]
    local spellID = UnitCastingInfo[#UnitCastingInfo]

    if spellID ~= nil then
        if unitId == DataToColor.C.unitPlayer and startTime ~= DataToColor.lastCastStartTime then
            DataToColor.lastCastStartTime = startTime
            DataToColor.CastNum = DataToColor.CastNum + 1
        end
        return spellID
    end

    local UnitChannelInfo = { DataToColor.UnitChannelInfo(unitId) }
    startTime = UnitChannelInfo[4]
    spellID = UnitChannelInfo[#UnitChannelInfo]

    if spellID ~= nil then
        if unitId == DataToColor.C.unitPlayer and startTime ~= DataToColor.lastCastStartTime then
            DataToColor.lastCastStartTime = startTime
            DataToColor.CastNum = DataToColor.CastNum + 1
        end
        return spellID
    end
    return 0
end

--


function DataToColor:getUnitXP(unit)
    return UnitXP(unit)
end

function DataToColor:getUnitXPMax(unit)
    return UnitXPMax(unit)
end

-- Finds maximum amount of health player can have
function DataToColor:getHealthMax(unit)
    return UnitHealthMax(unit)
end
-- Finds axact amount of health player current has
function DataToColor:getHealthCurrent(unit)
    return UnitHealth(unit)
end

-- Finds maximum amount of mana a character can store
function DataToColor:getPowerTypeMax(unit, type)
    return UnitPowerMax(unit, type)
end

-- Finds exact amount of mana player is storing
function DataToColor:getPowerTypeCurrent(unit, type)
    return UnitPower(unit, type)
end

-- Finds player current level
function DataToColor:getPlayerLevel()
    return UnitLevel(DataToColor.C.unitPlayer)
end

function DataToColor:getTargetLevel()
    return UnitLevel(DataToColor.C.unitTarget)
end

-- Finds the total amount of money.
function DataToColor:getMoneyTotal()
    return GetMoney()
end

function DataToColor:targetHostile()
    local hostile = UnitReaction(DataToColor.C.unitPlayer, DataToColor.C.unitTarget)
    if hostile ~= nil and hostile <= 4 then
        return 1
    end
    return 0
end

local ammoSlot = GetInventorySlotInfo("AmmoSlot")
function DataToColor:hasAmmo()
    local ammoCount = GetInventoryItemCount(DataToColor.C.unitPlayer, ammoSlot)
    if ammoCount > 0 then
        return 1
    end
    return 0
end

function DataToColor:getRange()
    if UnitExists(DataToColor.C.unitTarget) then
        local min, max = Range:GetRange(DataToColor.C.unitTarget)
        if max == nil then
            max = 99
        end
        return min * 100000 + max * 100
    end
    return 0
end

function DataToColor:isTradeRange()
    if UnitExists(DataToColor.C.unitTarget) then
        if CheckInteractDistance(DataToColor.C.unitTarget, 2) then
            return 1
        end
    end
    return 0
end

function DataToColor:targetNpcId()
    local _, _, _, _, _, npcID, guid = strsplit('-', UnitGUID(DataToColor.C.unitTarget) or '')
    if npcID ~= nil then
        return tonumber(npcID)
    end
    return 0
end

function DataToColor:getGuid(src)
    -- todo take
    -- care of Player-4731-02AAD4FF
    -- Creature-0-4488-530-222-19350-000005C0D70
    -- Pet-0-4448-530-222-22123-15004E200E
    local _, _, _, _, _, npcID, spawnUID = strsplit('-', UnitGUID(src) or '')
    if npcID ~= nil then
        return DataToColor:uniqueGuid(npcID, spawnUID)
    end
    return 0
end

function DataToColor:getGuidFromUUID(uuid)
    local _, _, _, _, _, npcID, spawnUID = strsplit('-', uuid or '')
    return DataToColor:uniqueGuid(npcID, spawnUID)
end

function DataToColor:uniqueGuid(npcId, spawn)
    local spawnEpochOffset = bit.band(tonumber(string.sub(spawn, 5), 16), 0x7fffff)
    local spawnIndex = bit.band(tonumber(string.sub(spawn, 1, 5), 16), 0xffff8)

    local dd = date("*t", spawnEpochOffset)
    local num = 
    DataToColor:sum24(
        dd.day +
        dd.hour +
        dd.min +
        dd.sec +
        npcId +
        spawnIndex
    )
    return tonumber(num, 16)
end

local offsetEnumPowerType = 2
function DataToColor:actionbarCost(slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == DataToColor.C.ActionType.Macro then
        id = GetMacroSpell(id)
    end
    if id and actionType == DataToColor.C.ActionType.Spell or actionType == DataToColor.C.ActionType.Macro then
        local costTable = GetSpellPowerCost(id)
        if costTable ~= nil then
            for _, costInfo in pairs(costTable) do
                --print(slot, actionType, costInfo.type, costInfo.cost, GetSpellLink(id))
                return DataToColor.C.MAX_POWER_TYPE * (costInfo.type + offsetEnumPowerType) + DataToColor.C.MAX_ACTION_IDX * slot + costInfo.cost
            end
        end
    end
    return DataToColor.C.MAX_POWER_TYPE * offsetEnumPowerType + DataToColor.C.MAX_ACTION_IDX * slot + 0
end

function DataToColor:equipSlotItemId(slot)
    local equip
    if GetInventoryItemLink(DataToColor.C.unitPlayer, slot) == nil then
        equip = 0
    else _, _, equip = string.find(GetInventoryItemLink(DataToColor.C.unitPlayer, slot), DataToColor.C.ItemPattern)
        equip = string.gsub(equip, 'm:', '')
    end
    return tonumber(equip or 0)
end
-- -- Function to tell if a spell is on cooldown and if the specified slot has a spell assigned to it
-- -- Slot ID information can be found on WoW Wiki. Slots we are using: 1-12 (main action bar), Bottom Right Action Bar maybe(49-60), and  Bottom Left (61-72)

function DataToColor:areSpellsInRange()
    local inRange = 0
    for i = 1, table.getn(DataToColor.S.spellInRangeList), 1 do
        local isInRange = IsSpellInRange(GetSpellInfo(DataToColor.S.spellInRangeList[i]), DataToColor.C.unitTarget)
        if isInRange==1 then
            inRange = inRange + (2 ^ (i - 1))
        end
    end
    return inRange
end

function DataToColor:isActionUseable(min,max)
    local isUsableBits = 0
    local isUsable, notEnough
    for i = min, max do
        local start, duration, enabled = GetActionCooldown(i)
        isUsable, notEnough = IsUsableAction(i)

        if start == 0 and isUsable == true and notEnough == false and GetActionTexture(i) ~= 134400 then -- red question mark texture
            isUsableBits = isUsableBits + (2 ^ (i - min))
        end

        local elapsed = (start + duration - GetTime())
        if enabled == 1 and start ~= 0 and duration > 1.5 then -- exclude GCD - according to internet everything counts as GCD below 1.5
            if not DataToColor.struct:exists(DataToColor.actionBarCooldownQueue, i) then
                -- add
                DataToColor.struct:push(DataToColor.actionBarCooldownQueue, i, elapsed)
            end
        elseif elapsed <= 0 and DataToColor.struct:exists(DataToColor.actionBarCooldownQueue, i) then
            -- update to show expired
            DataToColor.struct:push(DataToColor.actionBarCooldownQueue, i, 0)
        end
    end
    return isUsableBits
end

function DataToColor:isCurrentAction(min,max)
    local isUsableBits = 0
    for i = min, max do
        if IsCurrentAction(i) then
            isUsableBits = isUsableBits + (2 ^ (i - min))
        end
    end
    return isUsableBits
end

-- Function to tell how many bag slots we have in each bag
function DataToColor:bagSlots(bag)
    return GetContainerNumSlots(bag)
end

-- Finds passed in string to return profession level
function DataToColor:GetProfessionLevel(skill)
    local numskills = GetNumSkillLines()
    for c = 1, numskills do
        local skillname, _, _, skillrank = GetSkillLineInfo(c)
        if(skillname == skill) then
            return tonumber(skillrank)
        end
    end
    return 0
end

-- Returns zone name
function DataToColor:GetZoneName(partition)
    local zone = DataToColor:StringToASCIIHex(GetZoneText())
    if zone and tonumber(string.sub(zone, 7, 12)) ~= nil then
        -- Returns first 3 characters of zone
        if partition < 3 then
            return tonumber(string.sub(zone, 0, 6))
            -- Returns characters 4-6 of zone
        elseif partition >= 3 then
            return tonumber(string.sub(zone, 7, 12))
        end
    end
    -- Fail safe to prevent nil
    return 1
end

function DataToColor:GetBestMap()
    return C_Map.GetBestMapForUnit(DataToColor.C.unitPlayer) or 0
end 

-- Game time on a 24 hour clock
function DataToColor:GameTime()
    local hours, minutes = GetGameTime()
    hours = (hours * 100) + minutes
    return hours
end

function DataToColor:GetGossipIcons()
    -- Checks if we have options available
    local option = GetGossipOptions()
    -- Checks if we have an active quest in the gossip window
    local activeQuest = GetGossipActiveQuests()
    -- Checks if we have a quest that we can pickup
    local availableQuest = GetGossipAvailableQuests()
    local gossipCode
    -- Code 0 if no gossip options are available
    if option == nil and activeQuest == nil and availableQuest == nil then
        gossipCode = 0
        -- Code 1 if only non quest gossip options are available
    elseif option ~= nil and activeQuest == nil and availableQuest == nil then
        gossipCode = 1
        -- Code 2 if only quest gossip options are available
    elseif option == nil and (activeQuest ~= nil or availableQuest) ~= nil then
        gossipCode = 2
        -- Code 3 if both non quest gossip options are available
    elseif option ~= nil and (activeQuest ~= nil or availableQuest) ~= nil then
        gossipCode = 3
        -- -- Error catcher
    else
        gossipCode = 0
    end
    return gossipCode
end

--return the x and y of corpse and resurrect the player if he is on his corpse
--the x and y is 0 if not dead
--runs the RetrieveCorpse() function to ressurrect
function DataToColor:CorpsePosition()
    if UnitIsGhost(DataToColor.C.unitPlayer) then
        local map = C_Map.GetBestMapForUnit(DataToColor.C.unitPlayer)
        if C_DeathInfo.GetCorpseMapPosition(map) ~= nil then
            return C_DeathInfo.GetCorpseMapPosition(map):GetXY()
        end
    end

    return 0, 0
end

function DataToColor:ComboPoints()
    return GetComboPoints(DataToColor.C.unitPlayer, DataToColor.C.unitTarget) or 0
end

function DataToColor:getMeleeAttackSpeed(unit)
    local mainHand, offHand = UnitAttackSpeed(unit)
    if not mainHand then
        mainHand = 0
    end

    if not offHand then
        offHand = 0
    end
    return 10000 * math.floor(mainHand * 100) + math.floor(offHand * 100)
end

-----------------------------------------------------------------
-- Boolean functions --------------------------------------------
-- Only put functions here that are part of a boolean sequence --
-- Sew BELOW for examples ---------------------------------------
-----------------------------------------------------------------

function DataToColor:hasTarget()
    return UnitExists(DataToColor.C.unitTarget) and 1 or 0
end

function DataToColor:mainhandEnchantActive() 
    local hasMainHandEnchant = GetWeaponEnchantInfo()
    return hasMainHandEnchant and 1 or 0
end

function DataToColor:offhandEnchantActive() 
    local _, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    return hasOffHandEnchant and 1 or 0
end

-- Finds if player or target is in combat
function DataToColor:targetCombatStatus()
    return UnitAffectingCombat(DataToColor.C.unitTarget) and 1 or 0
end

-- Checks if target is dead. Returns 1 if target is dead, nil otherwise (converts to 0)
function DataToColor:GetEnemyStatus()
    return UnitIsDead(DataToColor.C.unitTarget) and 1 or 0
end

function DataToColor:targetIsNormal()
    local classification = UnitClassification(DataToColor.C.unitTarget)
    if classification == DataToColor.C.unitNormal then
        if (UnitIsPlayer(DataToColor.C.unitTarget)) then
            return 0
        end

        if UnitName(DataToColor.C.unitPet) == UnitName(DataToColor.C.unitTarget) then
            return 0
        end

        return 1
        -- if target is not in combat, return 1 for bitmask
    else
        return 0
    end
end

-- Checks if we are currently alive or are a ghost/dead.
function DataToColor:deadOrAlive()
    return UnitIsDeadOrGhost(DataToColor.C.unitPlayer) and 1 or 0
end

-- Checks the number of talent points we have available to spend
function DataToColor:checkTalentPoints()
    if UnitCharacterPoints(DataToColor.C.unitPlayer) > 0 then
        return 1
    end
    return 0
end

function DataToColor:shapeshiftForm()
    local index = GetShapeshiftForm(false)
    if index == nil or index == 0 then
        return 0
    end

    local _, _, _, spellId = GetShapeshiftFormInfo(index)
    local form = DataToColor.S.playerAuraMap[spellId]
    if form ~= nil then
        return form
    end
    return index
end

function DataToColor:playerCombatStatus()
    return UnitAffectingCombat(DataToColor.C.unitPlayer) and 1 or 0
end

-- Returns the slot in which we have a fully degraded item
function DataToColor:GetInventoryBroken()
    for i = 1, 18 do
        if GetInventoryItemBroken(DataToColor.C.unitPlayer, i) then
            return 1
        end
    end
    return 0
end
-- Checks if we are on a taxi
function DataToColor:IsPlayerFlying()
    return UnitOnTaxi(DataToColor.C.unitPlayer) and 1 or 0
end

function DataToColor:IsPlayerSwimming()
    return IsSwimming() and 1 or 0
end

function DataToColor:IsPlayerFalling()
    return IsFalling() and 1 or 0
end

function DataToColor:IsPlayerDrowning()
    local id = GetMirrorTimerInfo(2) -- 2 BREATH
    if id == DataToColor.C.MIRRORTIMER.BREATH then
        return 1
    end
    return 0
end

function DataToColor:IsPlayerMounted()
    return IsMounted() and 1 or 0
end

function DataToColor:IsTargetOfTargetPlayerAsNumber()
    if not(UnitName(DataToColor.C.unitTargetTarget)) then return 2 end -- target has no target
    if DataToColor.C.CHARACTER_NAME == UnitName(DataToColor.C.unitTarget) then return 0 end -- targeting self
    if UnitName(DataToColor.C.unitPet) == UnitName(DataToColor.C.unitTargetTarget) then return 4 end -- targetting my pet
    if DataToColor.C.CHARACTER_NAME == UnitName(DataToColor.C.unitTargetTarget) then return 1 end -- targetting me
    if UnitName(DataToColor.C.unitPet) == UnitName(DataToColor.C.unitTarget) and UnitName(DataToColor.C.unitTargetTarget) ~= nil then return 5 end
    return 3
end

-- Returns true if target of our target is us
function DataToColor:IsTargetOfTargetPlayer()
    local x = DataToColor:IsTargetOfTargetPlayerAsNumber()
    if x==1 or x==4 then return 1 else return 0 end
end

function DataToColor:IsTagged()
    return UnitIsTapDenied(DataToColor.C.unitTarget) and 1 or 0
end

function DataToColor:IsAutoRepeatActionOn(actionSlot)
    return IsAutoRepeatAction(actionSlot) and 1 or 0
end

function DataToColor:IsAutoRepeatSpellOn(spell)
    return IsAutoRepeatSpell(spell) and 1 or 0
end

function DataToColor:IsCurrentSpell(spell)
    return IsCurrentSpell(spell) and 1 or 0
end

function DataToColor:IsCurrentActionOn(actionSlot)
    return IsCurrentAction(actionSlot) and 1 or 0
end

function DataToColor:IsPetVisible()
    if UnitIsVisible(DataToColor.C.unitPet) and not UnitIsDead(DataToColor.C.unitPet) then
        return 1
    end
    return 0
end

function DataToColor:petHappy()
    local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
    -- (1 = unhappy, 2 = content, 3 = happy)
    if happiness ~= nil and happiness == 3 then
        return 1
    end
    return 0
end

-- Returns 0 if target is unskinnable or if we have no target.
function DataToColor:isUnskinnable()
    local creatureType = UnitCreatureType(DataToColor.C.unitTarget)
    -- Demons COULD be included in this list, but there are some skinnable demon dogs.
    if creatureType == DataToColor.C.Humanoid or creatureType == DataToColor.C.Elemental or creatureType == DataToColor.C.Mechanical or creatureType == DataToColor.C.Totem then
        return 1
    else if creatureType ~= nil then
            return 0
        end
    end
    return 1
end