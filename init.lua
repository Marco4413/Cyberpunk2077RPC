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
local Handlers = require "Handlers"

---@class GameStates
local GameStates = {
    None = 0,
    MainMenu = 1,
    DeathMenu = 2,
    PauseMenu = 3,
    Playing = 4,
    Loading = 5
}

---@class CyberpunkRPC
local CyberpunkRPC = {
    name = "CyberpunkRPC",
    version = "1.1",
    website = "https://github.com/Marco4413/Cyberpunk2077RPC",
    ---@type PlayerPupper Only available in Activity Handlers
    player = nil,
    gameState = GameStates.MainMenu,
    _isActivityDirty = true,
    elapsedInterval = 0,
    startedAt = 0,
    showUI = false,
    ---@type Config
    config = { },
    applicationId = "1025361016802005022",
    ---@type Activity
    activity = { },
    GameStates = GameStates,
    _handlers = { },
    GameUtils = require "GameUtils"
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

---@alias ActivityHandler fun(rpc:CyberpunkRPC, activity:Activity):boolean|nil

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
    ---@class Config
    return {
        enabled = true,
        rpcFile = "rpc.json",
        submitInterval = 5,
        showWebsiteButton = false,
        showDrivingActivity = false,
        showCombatActivity = false
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

---@param handler ActivityHandler
function CyberpunkRPC:AddActivityHandler(handler)
    table.insert(self._handlers, handler)
    return handler
end

---@param handler ActivityHandler
function CyberpunkRPC:RemoveActivityHandler(handler)
    for i=#self._handlers, 1, -1 do
        if (self._handlers[i] == handler) then
            table.remove(self._handlers, i)
            break
        end
    end
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
            State = nil,
            Buttons = CyberpunkRPC.config.showWebsiteButton and {
                { Label = CyberpunkRPC.name .. " Website", Url = CyberpunkRPC.website }
            } or nil
        }

        CyberpunkRPC.player = Game.GetPlayer()
        for i=#CyberpunkRPC._handlers, 1, -1 do
            if (CyberpunkRPC._handlers[i](CyberpunkRPC, activity)) then
                break
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
        
        local newValue, changed = ImGui.Checkbox("Show Website Button", CyberpunkRPC.config.showWebsiteButton)
        if (changed) then CyberpunkRPC.config.showWebsiteButton = newValue; end

        local newValue, changed = ImGui.DragFloat("Submit Interval", CyberpunkRPC.config.submitInterval, 0.01, 1, 3600, "%.2f")
        if (changed) then CyberpunkRPC.config.submitInterval = math.max(newValue, 1); end

        if (CyberpunkRPC:IsEnabled()) then
            ImGui.Text("RPC File (Editable if not enabled): " .. CyberpunkRPC.config.rpcFile)
        else
            local newValue, changing = ImGui.InputText("RPC File", CyberpunkRPC.config.rpcFile, 256)
            if (changing) then
                CyberpunkRPC.elapsedInterval = 0
                CyberpunkRPC.config.rpcFile = newValue
            end
        end
        
        local newValue, changed = ImGui.Checkbox("Show Driving Activity", CyberpunkRPC.config.showDrivingActivity)
        if (changed) then CyberpunkRPC.config.showDrivingActivity = newValue; end
        
        local newValue, changed = ImGui.Checkbox("Show Combat Activity", CyberpunkRPC.config.showCombatActivity)
        if (changed) then CyberpunkRPC.config.showCombatActivity = newValue; end
        ImGui.Separator()

        -- This may cause issues if not done only on box presses
        local newValue, changed = ImGui.Checkbox("Is Activity Dirty", CyberpunkRPC._isActivityDirty)
        if (changed) then CyberpunkRPC._isActivityDirty = newValue; end
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

    Handlers:RegisterHandlers(CyberpunkRPC)

    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return CyberpunkRPC:Init()
