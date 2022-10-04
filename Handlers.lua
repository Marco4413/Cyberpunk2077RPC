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

local GameUtils = require "GameUtils"

local Handlers = { }

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.Loading(self, activity)
    if (self.gameState == self.GameStates.Loading) then
        activity.Details = "Loading..."
        return true
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.MainMenu(self, activity)
    if (self.gameState == self.GameStates.MainMenu) then
        activity.Details = "Watching the Main Menu."
        return true
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.PauseMenu(self, activity)
    if (self.gameState == self.GameStates.PauseMenu and self.player ~= nil) then
        local level = GameUtils.GetLevel(self.player)
        local lifepath = GameUtils.GetLifePath(self.player)

        activity.Details = "Game Paused."
        activity.LargeImageKey = GameUtils.GetGender(self.player):lower()
        activity.LargeImageText = table.concat({
            "Level: ", level.level, "; ",
            "Street Cred: ", level.streetCred
        })
        activity.SmallImageKey = lifepath:lower()
        activity.SmallImageText = lifepath
        activity.State = nil
        return true
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.DeathMenu(self, activity)
    if (self.gameState == self.GameStates.DeathMenu) then
        activity.LargeImageKey = "deathmenu"
        activity.Details = "Admiring the Death Menu."
        activity.State = "No Armor?"
        return true
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.Combat(self, activity)
    if (not self.config.showCombatActivity) then return; end
    if (self.gameState == self.GameStates.Playing and self.player ~= nil and Game.GetPlayer():IsInCombat()) then
        local level = GameUtils.GetLevel(self.player)
        local lifepath = GameUtils.GetLifePath(self.player)
        local healthArmor = GameUtils.GetHealthArmor(self.player)
        local weaponName = GameUtils.GetWeaponName(Game.GetPlayer():GetActiveWeapon())
        
        activity.Details = "Fighting with " .. healthArmor.health .. "/" .. healthArmor.maxHealth .. "HP"
        activity.LargeImageKey = GameUtils.GetGender(self.player):lower()
        activity.LargeImageText = table.concat({
            "Level: ", level.level, "; ",
            "Street Cred: ", level.streetCred
        })
        activity.SmallImageKey = lifepath:lower()
        activity.SmallImageText = lifepath
        activity.State = weaponName and ("Using " .. weaponName) or "No weapon equipped."
        return true
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.Driving(self, activity)
    if (not self.config.showDrivingActivity) then return; end
    if (self.gameState == self.GameStates.Playing and self.player ~= nil) then
        local vehicle = Game.GetMountedVehicle(self.player)
        if (vehicle ~= nil and vehicle:IsPlayerDriver()) then
            local level = GameUtils.GetLevel(self.player)
            local lifepath = GameUtils.GetLifePath(self.player)
            local vehicleName = vehicle:GetDisplayName()
            local vehicleSpeed = math.floor(vehicle:GetCurrentSpeed() * 3.6 + .5)
            
            activity.Details = "Driving " .. vehicleName .. "."
            activity.LargeImageKey = GameUtils.GetGender(self.player):lower()
            activity.LargeImageText = table.concat({
                "Level: ", level.level, "; ",
                "Street Cred: ", level.streetCred
            })
            activity.SmallImageKey = lifepath:lower()
            activity.SmallImageText = lifepath

            if (vehicleSpeed > 0) then
                activity.State = "Cruising at " .. vehicleSpeed .. "km/h"
            elseif (vehicleSpeed < 0) then
                activity.State = "Going backwards at " .. -vehicleSpeed .. "km/h"
            else
                activity.State = "Currently parked."
            end
            return true
        end
    end
end

---@param self CyberpunkRPC
---@param activity Activity
function Handlers.Playing(self, activity)
    if (self.gameState == self.GameStates.Playing and self.player ~= nil) then
        local questInfo = GameUtils.GetActiveQuest()
        local level = GameUtils.GetLevel(self.player)
        local lifepath = GameUtils.GetLifePath(self.player)

        activity.Details = questInfo.name
        activity.LargeImageKey = GameUtils.GetGender(self.player):lower()
        activity.LargeImageText = table.concat({
            "Level: ", level.level, "; ",
            "Street Cred: ", level.streetCred
        })
        activity.SmallImageKey = lifepath:lower()
        activity.SmallImageText = lifepath
        activity.State = questInfo.objective
        return true
    end
end

---@param mod CyberpunkRPC
function Handlers:RegisterHandlers(mod)
    mod:AddActivityHandler(self.Playing)
    mod:AddActivityHandler(self.Combat)
    mod:AddActivityHandler(self.Driving)
    mod:AddActivityHandler(self.DeathMenu)
    mod:AddActivityHandler(self.PauseMenu)
    mod:AddActivityHandler(self.MainMenu)
    mod:AddActivityHandler(self.Loading)
end

return Handlers
