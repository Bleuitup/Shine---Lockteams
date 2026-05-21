local Plugin = {}
Plugin.Version = "1.4"
Plugin.HasConfig = true
Plugin.ConfigName = "LockTeams.json"

Plugin.DefaultConfig = {
    ChatName = "LockTeams",
    ChatMsg = "A match is underway and teams are locked in order to preserve balance.",
    AutoLockOnStart = false,
    AutoLockOnStartOnlyWhenAdminOnline = false,
    AdminGroup = "admin_group"
}

Plugin.CheckConfig = true
Plugin.CheckConfigTypes = true
Plugin.CheckConfigRecursively = false
Plugin.DefaultState = false
Plugin.NS2Only = false
Shine:RegisterExtension("lockteams", Plugin)
local Shine = Shine

function Plugin:Initialise()
    self:CreateCommands()
    self.Enabled = true
    self.TeamLock = false

    return true
end

function Plugin:LockTeams()
    Plugin.TeamLock = true
    Shine:NotifyDualColour(nil, 255, 15, 23, Plugin.Config.ChatName .. ": ", 181, 172, 229, "Teams are now locked.")
end

function Plugin:UnlockTeams()
    Plugin.TeamLock = false
    Shine:NotifyDualColour(nil, 66, 176, 244, Plugin.Config.ChatName .. ": ", 181, 172, 229, "Teams are now unlocked.")
end

function Plugin:CreateCommands()
    local LockTeamsCommand = self:BindCommand("sh_lockteams", "lock", self.LockTeams, false)
    LockTeamsCommand:Help("Lock both teams and prevent players from joining.")
    local UnlockTeamsCommand = self:BindCommand("sh_unlockteams", "unlock", self.UnlockTeams, false)
    UnlockTeamsCommand:Help("Unlock both teams and allow players to join.")
end

function Plugin:AdminIsOnline()
    local GameIDs = Shine.GameIDs

    for Client, ID in GameIDs:Iterate() do
        UserData = Shine:GetUserData(Client)

        if UserData ~= nil then
            if (UserData.Group == self.Config.AdminGroup) then return true end
        end
    end

    return false
end

function Plugin:JoinTeam(_, Player, NewTeam, Force, ShineForce)
    if (NewTeam == 1 or NewTeam == 2) and self.TeamLock and not Force and not ShineForce then
        Shine:NotifyDualColour(nil, 255, 212, 0, Player.name .. ": ", 181, 172, 229, self.Config.ChatMsg)

        return false
    end
end

function Plugin:SetGameState(Gamerules, State, OldState)
    if (State == kGameState.Started and self.Config.AutoLockOnStart) then
        if self.Config.AutoLockOnStartOnlyWhenAdminOnline then
            if self:AdminIsOnline() then
                self:LockTeams()
            end
        else
            self:LockTeams()
        end
    end
end

function Plugin:EndGame()
    self:UnlockTeams()
end

function Plugin:Cleanup()
    self.BaseClass.Cleanup(self)
    Print"Disabling server plugin..."
end