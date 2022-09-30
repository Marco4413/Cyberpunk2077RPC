--[[
Copyright (c) 2022 [Marco4413](https://github.com/Marco4413/CyberpunkRPC)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local GameUI = require "libs/cetkit/GameUI"

local GameStates = {
    None = 0,
    MainMenu = 1,
    DeathMenu = 2,
    PauseMenu = 3,
    Playing = 4,
    Loading = 5
}

CyberpunkRPC = {
    version = "1.0",
    gameState = GameStates.MainMenu,
    _isActivityDirty = true,
    elapsedInterval = 0,
    startedAt = 0,
    config = {
        rpcFile = "rpc.json",
        submitInterval = 5
    },
    applicationId = "1025361016802005022",
    activity = { },
    enums = { GameStates = GameStates }
}

---@class Activity
---@field ApplicationId string
---@field Details string
---@field StartTimestamp number
---@field EndTimestamp number
---@field LargeImageKey string
---@field LargeImageText string
---@field SmallImageKey string
---@field SmallImageText string
---@field State string
---@field PartySize number
---@field PartyMax number

local function ConsoleLog(...)
    print("[ " .. os.date("%x %X") .. " ][ CyberpunkRPC ]:", table.concat({ ... }))
end

function CyberpunkRPC:SetActivity(key, value)
    local oldValue = self.activity[key]
    if (oldValue ~= value) then
        self._isActivityDirty = true
        self.activity[key] = value
        return true
    end
    return false
end

---@param activity Activity
function CyberpunkRPC:SetFullActivity(activity)
    local changed = false
    for k, v in next, self.activity do
        changed = self:SetActivity(k, activity[k]) or changed
    end
    for k, v in next, activity do
        changed = self:SetActivity(k, v) or changed
    end
    return changed
end

function CyberpunkRPC:SubmitActivity()
    if (self._isActivityDirty) then
        -- Used to ensure that an object gets serialized instead of an array
        self.activity.json = true
        ConsoleLog("Activity needs updating (", json.encode(self.activity), ")")
        local file = io.open(self.config.rpcFile, "w")
        file:write(json.encode(self.activity))
        io.close(file)
        self.activity.json = nil
        self._isActivityDirty = false
        return true
    end
    return false
end

function CyberpunkRPC:SetState(newState)
    self.gameState = newState
end

function CyberpunkRPC.GetLifePath(player)
    if (player == nil) then return nil; end
    local systems = Game.GetScriptableSystemsContainer()
    local devSystem = systems:Get("PlayerDevelopmentSystem")
    local devData = devSystem:GetDevelopmentData(player)
    return devData ~= nil and devData:GetLifePath().value or nil
end

function CyberpunkRPC.GetLevel(player)
    if (player == nil) then return { level = -1, streetCred = -1 }; end
    local statsSystem = Game.GetStatsSystem()
    local playerEntityId = player:GetEntityID()
    local level = statsSystem:GetStatValue(playerEntityId, "Level")
    local streetCred = statsSystem:GetStatValue(playerEntityId, "StreetCred")
    return { level = level or -1, streetCred = streetCred or -1 }
end

function CyberpunkRPC.GetQuest()
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

function CyberpunkRPC:GetGender(player)
    if (player == nil) then return nil; end
    local genderName = player:GetResolvedGenderName()
    return genderName and genderName.value or nil
end

local function Event_OnInit()
    GameUI.OnSessionStart(function (state)
        CyberpunkRPC:SetState(GameStates.Playing)
    end)

    GameUI.OnLoadingStart(function (state)
        CyberpunkRPC:SetState(GameStates.Loading)
    end)

    GameUI.OnMenuOpen(function (state)
        if (state.menu == "MainMenu") then
            CyberpunkRPC:SetState(GameStates.MainMenu)
        elseif (state.menu == "DeathMenu") then
            CyberpunkRPC:SetState(GameStates.DeathMenu)
        elseif (state.menu == "PauseMenu") then
            CyberpunkRPC:SetState(GameStates.PauseMenu)
        end
    end)

    GameUI.OnMenuClose(function (state)
        if (state.lastMenu ~= "MainMenu" and state.lastMenu ~= "DeathMenu") then
            CyberpunkRPC:SetState(GameStates.Playing)
        end
    end)

    ConsoleLog(GameUI.GetMenu())
    ConsoleLog("Mod Initialized!")
    ConsoleLog("Using Application Id: ", CyberpunkRPC.applicationId)
end

local function Event_OnUpdate(dt)
    CyberpunkRPC.elapsedInterval = CyberpunkRPC.elapsedInterval + dt
    if (CyberpunkRPC.elapsedInterval >= CyberpunkRPC.config.submitInterval) then
        CyberpunkRPC.elapsedInterval = 0
        CyberpunkRPC:SubmitActivity()

        if (CyberpunkRPC.gameState == GameStates.None) then
            CyberpunkRPC:SetActivity("ApplicationId", nil)
            return
        end

        ---@type Activity
        local activity = {
            ApplicationId = CyberpunkRPC.applicationId,
            StartTimestamp = CyberpunkRPC.startedAt,
            Details = nil,
            LargeImageKey = "default",
            LargeImageText = "Cyberpunk 2077",
            SmallImageKey = nil,
            SmallImageText = nil,
            State = nil
        }

        if (CyberpunkRPC.gameState == GameStates.Loading) then
            activity.Details = "Loading..."
        elseif (CyberpunkRPC.gameState == GameStates.MainMenu) then
            activity.Details = "Watching the Main Menu."
        elseif (CyberpunkRPC.gameState == GameStates.PauseMenu) then
            local player = Game.GetPlayer()
            if (player ~= nil) then
                local level = CyberpunkRPC.GetLevel(player)
                local lifepath = CyberpunkRPC.GetLifePath(player)
                activity.Details = "Game Paused."
                activity.LargeImageKey = CyberpunkRPC.GetGender(player):lower()
                activity.LargeImageText = table.concat({
                    "Level: ", level.level, "; ",
                    "Street Cred: ", level.streetCred
                })
                activity.SmallImageKey = lifepath:lower()
                activity.SmallImageText = lifepath
                activity.State = nil
            end
        elseif (CyberpunkRPC.gameState == GameStates.DeathMenu) then
            activity.Details = "Admiring the Death Menu."
            activity.State = "No Armor?"
        elseif (CyberpunkRPC.gameState == GameStates.Playing) then
            local player = Game.GetPlayer()
            if (player ~= nil) then
                local questInfo = CyberpunkRPC.GetQuest()
                local level = CyberpunkRPC.GetLevel(player)
                local lifepath = CyberpunkRPC.GetLifePath(player)
                activity.Details = questInfo.name
                activity.LargeImageKey = CyberpunkRPC.GetGender(player):lower()
                activity.LargeImageText = table.concat({
                    "Level: ", level.level, "; ",
                    "Street Cred: ", level.streetCred
                })
                activity.SmallImageKey = lifepath:lower()
                activity.SmallImageText = lifepath
                activity.State = questInfo.objective
            end
        end

        CyberpunkRPC:SetFullActivity(activity)
    end
end

local function Event_OnShutdown()
    CyberpunkRPC:SetActivity("ApplicationId", nil)
    CyberpunkRPC:SubmitActivity()
end

function CyberpunkRPC:Init()
    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    self.startedAt = math.floor(os.time() * 1e3)
    return self
end

return CyberpunkRPC:Init()