# CareerMP-Server-Authoritive

A fork of [CareerMP](https://github.com/StanleyDudek/CareerMP) by StanleyDudek, ported to BeamNG.drive 0.40 and changed so that the server keeps everyone's career save instead of the players.

In the original CareerMP your career is saved on your own PC. That's handy if you want to take a save offline, but it also means anyone can open their save files and give themselves money or cars. In this version the server stores the save, sends it to you when you join and gets it back every time your game saves. Editing the files on your PC does nothing because they get replaced the next time you join.

All credit for the base mod goes to StanleyDudek (Dudekahedron). This wouldn't exist without CareerMP.

## What's different from CareerMP

- Works on BeamNG.drive 0.40.1. The original glitches on join there because a lot of the career code changed in 0.40.
- Career saves are stored on the server, one per BeamMP account. That's everything in the save folder: your cars with their parts, paint and where they were left, money, XP, parts inventory, deliveries, insurance, milestones and so on.
- Guests can't join since the save is tied to the BeamMP account, and the same account can't be on the server twice.
- The server keeps track of each player's money. If a save comes in with more money than the server expects it gets corrected. There are limits on single rewards, sales and income per hour, and money from the game's debug/cheat functions is blocked.
- Paying other players is checked against the money the server has for you.
- `/save` in chat saves your career on the server, and the server asks everyone's game to save every 5 minutes.
- The server keeps 5 backups of every save. If the newest file is broken it loads the next one.
- Loading a different profile or an older save from the career menu gets you kicked, so you can't bring in cars or money from a local save.
- Shared traffic: one player's game runs the traffic and everyone sees the same cars, instead of everyone spawning their own.
- Traffic driving through speed cameras or red light cameras doesn't get announced as a player anymore.
- Drag race light sync is turned off for now, the drag strip code changed too much in 0.40.

## Requirements

Tested with:

- BeamNG.drive 0.40.1
- BeamMP Server 3.9.3

West Coast, USA only, same as the original.

Every player needs a BeamMP account.

## Installing

1. Remove any old CareerMP from your server first (`Resources/Client/CareerMP.zip` and `Resources/Server/CareerMP/careerMP.lua`). You can keep the config folder.
2. Download this repo (Code > Download ZIP) and copy `Resources/Client/CareerMP.zip` and `Resources/Server/CareerMP/` into the same places in your BeamMP server folder.
3. In `ServerConfig.toml` set `MaxCars = 100` or more and `Map = "/levels/west_coast_usa/info.json"`.
4. Start the server once. It creates `Resources/Server/CareerMP/config/config.json` and the `saves` folder.
5. Change whatever you want in the config (see [docs/configuration.md](docs/configuration.md)) and restart the server.

`Resources/Client/CareerMP/` in this repo is the unpacked content of `CareerMP.zip`, so the code can be read on GitHub. The server only needs the zip.

**Restart the server every time you update the files.** The server only loads the mod when it starts, so until then players keep getting the old version.

### Coming from the original CareerMP

Local saves are not moved to the server. Everyone starts a new career the first time they join. Their old saves stay on their PC and still work in single player.

## Commands

In chat:

| Command | |
|---|---|
| `/save` | Saves your career on the server. Works every 30 seconds, not during missions or the tutorial. Other players don't see it in chat. |

In the server console (`CMP` works as a shorter prefix):

| Command | |
|---|---|
| `CareerMP Help` | Lists the commands |
| `CareerMP GetConfig [section] [key]` | Shows the config, a section or a single value |
| `CareerMP SetConfig <section> <key> <value>` | Changes a setting and saves it, e.g. `CareerMP SetConfig server backupCount 3` |
| `CareerMP Money <player> [amount]` | Shows or sets the money of a player that is online |
| `CareerMP Update` | Checks this repo for a newer version and downloads it |

## Saves

Saves are in `Resources/Server/CareerMP/saves/`, one file per BeamMP account, plus backups and a log of each player's money. How it all works, how to restore a backup and how to move saves to another server is in [docs/saves.md](docs/saves.md).

## Traffic

The BeamMP server can't drive cars, it only passes data between the players' games. So one player's game has to run the traffic. The first player to join becomes the traffic host and stays it until they leave, then the next player takes over and their game spawns new traffic. Everyone else sees the host's traffic as normal multiplayer cars, without nametags.

The host's game has a bit more to do: AI for 20 cars with the default settings, and sending their positions to everyone. Police chases only happen for the host because the police cars are AI on their PC.

If you'd rather have everyone spawn their own traffic like in the original CareerMP, set `sharedTraffic` to `false`.

## Known issues

- The career itself still runs in the player's game. Someone who edits the mod's Lua can still cheat money up to the limits or change their cars. The server only checks money, not XP or anything else.
- Leaving career to freeroam in the middle of a session isn't blocked.
- Drag race lights aren't synced.
- Not tested much with more than 3 players yet.

If something breaks, open an issue and add your `Server.log` and the player's `beamng.log` (found in `%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\`).

## Credits

- [StanleyDudek](https://github.com/StanleyDudek) for CareerMP: [original repo](https://github.com/StanleyDudek/CareerMP), [Dudek's Sandbox discord](https://discord.gg/caU5adg)
- Bouboule, and Lion and Luuk from BeamPaint, who are thanked in the original for the http request examples
- BeamNG and the BeamMP team
