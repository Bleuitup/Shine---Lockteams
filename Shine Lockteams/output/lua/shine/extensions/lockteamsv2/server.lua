local Plugin = {}
Plugin.Version = "2.2"
Plugin.HasConfig = true
Plugin.ConfigName = "LockTeamsV2.json"

Plugin.DefaultConfig = {
    ChatName = "LockTeams v2",
    ChatMsg = "A match is underway and teams are locked in order to preserve balance.",
    AutoLockOnStart = false,
    AutoLockOnStartOnlyWhenAdminOnline = false,
    AdminGroup = "admin_group",

    -- If a player is denied this many team-join attempts within JoinSpamWindow seconds,
    -- they are moved out of the Ready Room and into Spectator.
    JoinSpamAttempts = 5,
    JoinSpamWindow = 5,
    MoveSpamJoinersToSpectator = true,
    JoinSpamSpectatorMsg = "You tried to join too many times too quickly and were moved to Spectator."
}

Plugin.CheckConfig = true
Plugin.CheckConfigTypes = true
Plugin.CheckConfigRecursively = false
Plugin.DefaultState = false
Plugin.NS2Only = false

Shine:RegisterExtension("lockteamsv2", Plugin)

local Shine = Shine

function Plugin:Initialise()
    self:CreateCommands()
    self.Enabled = true
    self.TeamLock = false
    self.JoinAttempts = {}

    return true
end

function Plugin:LockTeams()
    self.TeamLock = true
    Shine:NotifyDualColour(nil, 255, 15, 23, self.Config.ChatName .. ": ", 181, 172, 229, "Teams are now locked.")
end

function Plugin:UnlockTeams()
    self.TeamLock = false
    self.JoinAttempts = {}
    Shine:NotifyDualColour(nil, 66, 176, 244, self.Config.ChatName .. ": ", 181, 172, 229, "Teams are now unlocked.")
end

function Plugin:CreateCommands()
    -- Shine invokes command handlers as Func( Client, ... ) without binding self,
    -- so wrap the plugin methods in closures that capture the plugin instance.
    local LockTeamsCommand = self:BindCommand("sh_lockteamsv2", "lock", function( Client )
        self:LockTeams()
    end, false)
    LockTeamsCommand:Help("Lock both teams and prevent players from joining.")

    local UnlockTeamsCommand = self:BindCommand("sh_unlockteamsv2", "unlock", function( Client )
        self:UnlockTeams()
    end, false)
    UnlockTeamsCommand:Help("Unlock both teams and allow players to join.")
end

function Plugin:AdminIsOnline()
    local GameIDs = Shine.GameIDs

    for Client, ID in GameIDs:Iterate() do
        local UserData = Shine:GetUserData(Client)

        if UserData ~= nil then
            if UserData.Group == self.Config.AdminGroup then
                return true
            end
        end
    end

    return false
end

function Plugin:NotifyPlayer(Player, Message)
    Shine:NotifyDualColour(Player, 255, 212, 0, self.Config.ChatName .. ": ", 181, 172, 229, Message)
end

function Plugin:RecordDeniedJoinAttempt(Player, Window)
    local Client = Server.GetOwner(Player)
    if not Client then
        return 0
    end

    local Now = Shared.GetTime()
    local Attempts = self.JoinAttempts[Client]

    if not Attempts then
        Attempts = {}
        self.JoinAttempts[Client] = Attempts
    end

    for i = #Attempts, 1, -1 do
        if Now - Attempts[i] > Window then
            table.remove(Attempts, i)
        end
    end

    Attempts[#Attempts + 1] = Now

    return #Attempts
end

function Plugin:MovePlayerToSpectator(Player)
    if Player:GetTeamNumber() == kSpectatorIndex then
        return
    end

    local Gamerules = GetGamerules()

    if Gamerules then
        Gamerules:JoinTeam(Player, kSpectatorIndex)
    end
end

function Plugin:JoinTeam(_, Player, NewTeam, Force, ShineForce)
    if (NewTeam == 1 or NewTeam == 2) and self.TeamLock and not Force and not ShineForce then
        local JoinSpamAttempts = self.Config.JoinSpamAttempts or 5
        local JoinSpamWindow = self.Config.JoinSpamWindow or 5
        local MoveSpamJoinersToSpectator = self.Config.MoveSpamJoinersToSpectator
        local JoinSpamSpectatorMsg = self.Config.JoinSpamSpectatorMsg or "You tried to join too many times too quickly and were moved to Spectator."

        if MoveSpamJoinersToSpectator == nil then
            MoveSpamJoinersToSpectator = true
        end

        local Attempts = self:RecordDeniedJoinAttempt(Player, JoinSpamWindow)

        if MoveSpamJoinersToSpectator
            and JoinSpamAttempts > 0
            and JoinSpamWindow > 0
            and Attempts >= JoinSpamAttempts then

            self:NotifyPlayer(Player, JoinSpamSpectatorMsg)
            self:MovePlayerToSpectator(Player)
        else
            self:NotifyPlayer(Player, self.Config.ChatMsg)
        end

        return false
    end
end

function Plugin:SetGameState(Gamerules, State, OldState)
    if State == kGameState.Started and self.Config.AutoLockOnStart then
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

function Plugin:ClientDisconnect(Client)
    if self.JoinAttempts then
        self.JoinAttempts[Client] = nil
    end
end

function Plugin:Cleanup()
    self.BaseClass.Cleanup(self)
    Print"Disabling server plugin..."
end
