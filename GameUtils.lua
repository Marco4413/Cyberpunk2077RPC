local GameUtils = { }

---@param player PlayerPuppet|nil
---@return string|nil
function GameUtils.GetLifePath(player)
    if (player == nil) then return nil; end
    local systems = Game.GetScriptableSystemsContainer()
    local devSystem = systems:Get("PlayerDevelopmentSystem")
    local devData = devSystem:GetDevelopmentData(player)
    return devData ~= nil and devData:GetLifePath().value or nil
end

---@param player PlayerPuppet|nil
function GameUtils.GetLevel(player)
    if (player == nil) then return { level = -1, streetCred = -1 }; end
    local statsSystem = Game.GetStatsSystem()
    local playerEntityId = player:GetEntityID()
    local level = statsSystem:GetStatValue(playerEntityId, "Level")
    local streetCred = statsSystem:GetStatValue(playerEntityId, "StreetCred")
    return { level = level or -1, streetCred = streetCred or -1 }
end

---@param player PlayerPuppet|nil
function GameUtils.GetHealthArmor(player)
    if (player == nil) then return { health = -1, maxHealth = -1, armor = -1 }; end
    local playerEntityId = player:GetEntityID()
    local statsPoolSystem = Game.GetStatPoolsSystem()
    local health = math.floor(statsPoolSystem:GetStatPoolValue(
        playerEntityId, gamedataStatPoolType.Health, false) + .5)
    local statsSystem = Game.GetStatsSystem()
    local maxHealth = math.floor(statsSystem:GetStatValue(playerEntityId, "Health") + .5)
    local armor = math.floor(statsSystem:GetStatValue(playerEntityId, "Armor") + .5)
    return { health = health or -1, maxHealth = maxHealth or -1, armor = armor or -1 }
end

---@param weapon gameweaponObject|nil
function GameUtils.GetWeaponName(weapon)
    if (weapon == nil) then return nil; end
    local weaponRecord = weapon:GetWeaponRecord()
    if (weaponRecord == nil) then return nil; end
    return Game.GetLocalizedTextByKey(weaponRecord:DisplayName())
end

function GameUtils.GetActiveQuest()
    local res = { name = "Roaming.", objective = nil }
    local journal = Game.GetJournalManager()

    -- Game Dump:
    -- gameJournalQuestObjective[ id:02_meet_hanako, entries:Array[ handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle)], description:LocKey#9874, counter:0, optional:false, locationPrefabRef:, itemID:, districtID: ]
    local questObjective = journal:GetTrackedEntry()
    if (questObjective == nil or questObjective.GetDescription == nil) then return res; end

    local descriptionLocKey = questObjective:GetDescription()
    if (descriptionLocKey ~= nil) then
        res.objective = Game.GetLocalizedText(descriptionLocKey)
    end

    -- Game Dump:
    -- gameJournalQuestPhase[ id:q115, entries:Array[ handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle)], locationPrefabRef: ]
    local questPhase = journal:GetParentEntry(questObjective)
    if (questPhase == nil) then return res; end

    -- Game Dump:
    -- gameJournalQuest[ id:02_sickness, entries:Array[ handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle) handle:gameJournalEntry(RT_Handle)], title:LocKey#9860, type:MainQuest, recommendedLevelID:, districtID: ]
    local quest = journal:GetParentEntry(questPhase)
    if (quest == nil or quest.GetTitle == nil) then return res; end

    local titleLocKey = quest:GetTitle(journal)
    if (titleLocKey ~= nil) then
        res.name = Game.GetLocalizedText(titleLocKey)
    end

    return res
end

---@param player PlayerPuppet|nil
function GameUtils.GetGender(player)
    if (player == nil) then return nil; end
    local genderName = player:GetResolvedGenderName()
    return genderName and genderName.value or nil
end

return GameUtils
