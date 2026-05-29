# LockTeams v2 — Publishing & Changes

This document explains how to publish **`lockteams-v2/`** as a new Natural Selection 2
Steam Workshop mod, and details exactly what was changed from the original
**[Shine] Lock Teams** mod (workshop id `1479440378`).

---

## 1. What this mod is

A server-side [Shine](https://github.com/Person8880/Shine) plugin that lets admins
lock/unlock the marine and alien teams mid-match. v2 is a renamed, independent copy
of the original with one behavioural fix (see [Changes](#3-changes-from-the-original)).

```
lockteams-v2/
├── modinfo.json                                     # display name + workshop description
├── .modinfo                                         # mod display name
└── lua/
    └── shine/
        └── extensions/
            └── lockteamsv2/
                └── server.lua                       # the plugin code
```

> The plugin is **server-side only** — there is no `client.lua` / `shared.lua`.

---

## 2. How to publish it as a new Workshop mod

NS2 mods are built and published with the **Launch Pad** tool that ships with the game.
The `modinfo.json` in this folder is the engine's *cache* format and is **not** the
publishing format — Launch Pad generates its own metadata and a brand-new workshop id.

### 2.1 Prerequisites
- Natural Selection 2 installed via Steam.
- You are logged into the Steam account that will own the mod.
- Launch Pad lives at:
  `…/steamapps/common/Natural Selection 2/LaunchPad32.exe` (or `LaunchPad.exe`).
  On this machine the game is under
  `~/.steam/debian-installation/steamapps/common/Natural Selection 2/`.

### 2.2 Create the mod project
1. Open **Launch Pad** and choose **New Mod** (this creates a `*.modproj` and a
   `source/` folder somewhere of your choosing, e.g. `~/ns2mods/LockTeamsV2/`).
2. Set the **mod name** to `[Shine] Lock Teams v2`.
3. Copy the **`lua/`** tree from `lockteams-v2/` into the project's `source/`
   folder so you end up with:
   ```
   source/lua/shine/extensions/lockteamsv2/server.lua
   ```
4. (Optional) Copy `.modinfo` / the description text from `modinfo.json` into the
   project so the Workshop listing matches.

### 2.3 Build & publish
1. In Launch Pad, **Build** the mod — this compiles `source/` into `output/`.
2. Click **Publish to Workshop**.
   - On first publish Steam assigns a **new workshop id** (a new hex *mod id*),
     so it will not overwrite the original author's mod (`582E77FA`).
   - Add a title, description, preview image, and visibility, then confirm.
3. Steam uploads the mod. The new id appears in Launch Pad and on the Workshop page.

### 2.4 Use it on a server
1. Subscribe the server to the new workshop id (add it to the server's mod list /
   `-mods` launch argument, by the hex id Launch Pad reports).
2. Enable the plugin in your Shine config. The extension is registered as
   **`lockteamsv2`**, so in `config://shine/BaseConfig.json` (or wherever you keep it):
   ```json
   "ActiveExtensions": {
       "lockteamsv2": true
   }
   ```
3. Grant your admins permission for the v2 commands in the Shine user/group config:
   `sh_lockteamsv2` and `sh_unlockteamsv2`.
4. The plugin writes its config to **`LockTeamsV2.json`** on first run.
5. (Optional) Bind the commands in-game for fast use:
   ```
   bind F2 sh_lockteamsv2
   bind F3 sh_unlockteamsv2
   ```

---

## 3. Changes from the original

Three kinds of changes were made: a **functional fix** (the message target), a
**new feature** (auto-move join spammers to Spectator), and a set of **renames** so the
mod is a fully distinct plugin that cannot collide with the original.

Line numbers below refer to the **original** `server.lua`
(`lockteams/lua/shine/extensions/lockteams/server.lua`).

### 3.1 Functional fix — message only to the joining player

When teams are locked and a player tries to join, the original broadcast the "teams are
locked" message to **everyone** (first argument `nil` = all clients). v2 sends it only
to the player attempting to join.

**Original — line 63:**
```lua
        Shine:NotifyDualColour(nil, 255, 212, 0, Player.name .. ": ", 181, 172, 229, self.Config.ChatMsg)
```

**v2 — the message is sent through a `NotifyPlayer` helper that targets the `Player`:**
```lua
function Plugin:NotifyPlayer(Player, Message)
    Shine:NotifyDualColour(Player, 255, 212, 0, self.Config.ChatName .. ": ", 181, 172, 229, Message)
end
```
…called from `JoinTeam` as `self:NotifyPlayer(Player, self.Config.ChatMsg)`.

> Note: the lock/unlock **confirmation** messages in `LockTeams()` and `UnlockTeams()`
> still use `nil` on purpose — those are intentional server-wide admin announcements and
> were left unchanged.

### 3.2 New feature — auto-move join spammers to Spectator

Merged from a previous **v1.5** of the original mod. When teams are locked, repeated
denied join attempts are tracked per-client; once a player exceeds the threshold they are
moved out of the Ready Room into Spectator instead of just being notified.

New config keys (`DefaultConfig`), written to `LockTeamsV2.json`:

| Key | Default | Meaning |
|-----|---------|---------|
| `JoinSpamAttempts` | `5` | Denied attempts before a player is moved to Spectator |
| `JoinSpamWindow` | `5` | Sliding window in seconds for counting attempts |
| `MoveSpamJoinersToSpectator` | `true` | Master on/off for the feature |
| `JoinSpamSpectatorMsg` | `"You tried to join too many times…"` | Message shown to the moved player |

Supporting code added:
- `self.JoinAttempts = {}` initialised in `Initialise()` and **reset** in `UnlockTeams()`.
- `Plugin:RecordDeniedJoinAttempt(Player, Window)` — records the attempt time (via
  `Server.GetOwner(Player)` + `Shared.GetTime()`), prunes entries older than the window,
  and returns the current count.
- `Plugin:MovePlayerToSpectator(Player)` — calls `GetGamerules():JoinTeam(Player, kSpectatorIndex)`.
- `Plugin:ClientDisconnect(Client)` — clears that client's recorded attempts.
- `Plugin:JoinTeam(...)` now records each denied attempt and, when the threshold is hit,
  notifies + moves the player to Spectator; otherwise it shows the normal locked message.

> Setting `MoveSpamJoinersToSpectator` to `false`, or `JoinSpamAttempts`/`JoinSpamWindow`
> to `0`, disables the auto-move and restores plain notify-only behaviour.

### 3.3 Renames (distinct-plugin identity)

| What | Original line | Original value | v2 value |
|------|--------------:|----------------|----------|
| Plugin version | 2 | `Plugin.Version = "1.4"` | `Plugin.Version = "2.1"` |
| Config file name | 4 | `Plugin.ConfigName = "LockTeams.json"` | `Plugin.ConfigName = "LockTeamsV2.json"` |
| In-chat name | 7 | `ChatName = "LockTeams",` | `ChatName = "LockTeams v2",` |
| Shine extension id | 19 | `Shine:RegisterExtension("lockteams", Plugin)` | `Shine:RegisterExtension("lockteamsv2", Plugin)` |
| Lock command | 41 | `self:BindCommand("sh_lockteams", "lock", …)` | `self:BindCommand("sh_lockteamsv2", "lock", …)` |
| Unlock command | 43 | `self:BindCommand("sh_unlockteams", "unlock", …)` | `self:BindCommand("sh_unlockteamsv2", "unlock", …)` |

Folder / metadata renames that accompany the code changes:

| What | Original | v2 |
|------|----------|----|
| Extension folder | `lua/shine/extensions/lockteams/` | `lua/shine/extensions/lockteamsv2/` |
| Mod display name (`.modinfo`, `modinfo.json`) | `[Shine] Lock Teams` | `[Shine] Lock Teams v2` |

The `!lock` / `!unlock` chat aliases (2nd argument to `BindCommand`) were **kept the
same** — they are short user aliases, not "lockteams" identifiers.

---

## 4. Credit

Based on the original **[Shine] Lock Teams** mod by Tik, wherever he might be.
