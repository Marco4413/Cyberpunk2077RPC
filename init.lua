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
    name = "CyberpunkRPC",
    version = "1.0",
    gameState = GameStates.MainMenu,
    _isActivityDirty = true,
    elapsedInterval = 0,
    startedAt = 0,
    showUI = false,
    config = { },
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
    print("[ " .. os.date("%x %X") .. " ][ " .. CyberpunkRPC.name .. " ]:", table.concat({ ... }))
end

function CyberpunkRPC:SetEnabled(value)
    self.config.enabled = value
    if (not self.config.enabled) then
        ConsoleLog("Disabled.")
        self:SetActivity("ApplicationId", nil)
        self:SubmitActivity()
        return
    end
    ConsoleLog("Enabled.")
end

function CyberpunkRPC:IsEnabled()
    return self.config.enabled
end

function CyberpunkRPC:GetDefaultConfig()
    return {
        enabled = true,
        rpcFile = "rpc.json",
        submitInterval = 5
    }
end

function CyberpunkRPC:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode(self.config))
    io.close(file)
end

local function CrossCheckTypes(tbl1, tbl2)
    local changed = false
    for k, v in next, tbl1 do
        local t1, t2 = type(tbl1[k]), type(tbl2[k])
        if (t1 ~= t2) then
            tbl2[k] = tbl1[k]
            changed = true
        elseif (t1 == "table") then
            changed = CrossCheckTypes(tbl1[k], tbl2[k]) or changed
        end
    end
    return changed
end

function CyberpunkRPC:LoadConfig()
    local ok = pcall(function ()
        local file = io.open("data/config.json", "r")
        local configText = file:read("*a")
        io.close(file)

        local defaultConfig = CyberpunkRPC:GetDefaultConfig()
        self.config = json.decode(configText)
        if (CrossCheckTypes(defaultConfig, self.config)) then
            self:SaveConfig()
        end
    end)
    if (not ok) then self:SaveConfig(); end
end

function CyberpunkRPC:ResetConfig()
    self.config = self:GetDefaultConfig()
    self:SaveConfig()
end

function CyberpunkRPC:SetActivity(key, value)
    local oldValue = self.activity[key]
    if (oldValue ~= value) then
        if (key == "Buttons" and type(oldValue) == "table" and type(value) == "table") then
            -- If no button was added/removed we can't be sure that they're the same
            if (#value == #oldValue) then
                for i=1, #value do
                    local newButton = value[i]
                    local oldButton = oldValue[i]
                    if (oldButton.Label ~= newButton.Label or oldButton.Url ~= newButton.Url) then
                        self.activity[key] = value
                        self._isActivityDirty = true
                        return true
                    end
                end
                return false
            end
        end

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

function CyberpunkRPC:SubmitActivity(force)
    if (force or self._isActivityDirty) then
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

function CyberpunkRPC.GetGender(player)
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

    ConsoleLog("Mod Initialized!")
    ConsoleLog("Using Application Id: ", CyberpunkRPC.applicationId)
end

local function Event_OnUpdate(dt)
    if (not CyberpunkRPC:IsEnabled()) then return; end

    CyberpunkRPC.elapsedInterval = CyberpunkRPC.elapsedInterval + dt
    if (CyberpunkRPC.elapsedInterval >= CyberpunkRPC.config.submitInterval) then
        CyberpunkRPC.elapsedInterval = 0

        if (CyberpunkRPC.gameState == GameStates.None) then
            CyberpunkRPC:SetActivity("ApplicationId", nil)
            CyberpunkRPC:SubmitActivity()
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
        CyberpunkRPC:SubmitActivity()
    end
end

local function Event_OnShutdown()
    CyberpunkRPC:SetActivity("ApplicationId", nil)
    CyberpunkRPC:SubmitActivity()
end

local function Event_OnDraw()
    if (not CyberpunkRPC.showUI) then return; end

    if (ImGui.Begin(CyberpunkRPC.name)) then
        if (ImGui.Button("Save")) then
            CyberpunkRPC:SaveConfig()
        end
        ImGui.SameLine()
        if (ImGui.Button("Load")) then
            CyberpunkRPC:LoadConfig()
        end
        ImGui.SameLine()
        if (ImGui.Button("Reset")) then
            CyberpunkRPC:ResetConfig()
        end
        ImGui.SameLine()
        if (ImGui.Button("Force Submit")) then
            CyberpunkRPC:SubmitActivity(true)
        end

        ImGui.Separator()
        local newEnabled, changed = ImGui.Checkbox("Enabled", CyberpunkRPC:IsEnabled())
        if (changed) then CyberpunkRPC:SetEnabled(newEnabled); end

        local newInterval, changed = ImGui.InputFloat("Submit Interval", CyberpunkRPC.config.submitInterval)
        if (changed) then CyberpunkRPC.config.submitInterval = math.max(newInterval, 1); end

        if (CyberpunkRPC:IsEnabled()) then
            ImGui.Text("RPC File (Editable if not enabled): " .. CyberpunkRPC.config.rpcFile)
        else
            local newFile, changing = ImGui.InputText("RPC File", CyberpunkRPC.config.rpcFile, 256)
            if (changing) then
                CyberpunkRPC.elapsedInterval = 0
                CyberpunkRPC.config.rpcFile = newFile
            end
        end
        ImGui.Separator()

        -- This may cause issues if not done only on box presses
        local newDirt, changed = ImGui.Checkbox("Is Activity Dirty", CyberpunkRPC._isActivityDirty)
        if (changed) then CyberpunkRPC._isActivityDirty = newDirt; end
    end
    ImGui.End()
end

local function Event_OnOverlayOpen()
    CyberpunkRPC.showUI = true
end

local function Event_OnOverlayClose()
    CyberpunkRPC.showUI = false
end

function CyberpunkRPC:Init()
    self.startedAt = math.floor(os.time() * 1e3)
    self.config = self:GetDefaultConfig()
    self:LoadConfig()
    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return CyberpunkRPC:Init()
