# Configuration

The config is created the first time the server starts, in `Resources/Server/CareerMP/config/config.json`. New settings get added to it automatically when you update. You can edit the file while the server is off, or change things live with `CareerMP SetConfig <section> <key> <value>` in the server console.

## server

| Setting | Default | |
|---|---|---|
| `requireAccount` | `true` | Only players logged in to BeamMP can join. Leave this on. If it's off, guests get a save based on their name, and anyone using the same name gets that save. |
| `startingMoney` | `10000` | Money for a new career. |
| `incomeLimitSingle` | `250000` | Most money a single reward can give (missions, deliveries and so on). Anything over it is refused. |
| `incomeLimitPerHour` | `1000000` | Most money a player can earn per hour, not counting sales. |
| `saleLimitSingle` | `5000000` | Most money a single sale can give, like selling a car. |
| `saleLimitPerHour` | `10000000` | Most money from sales per hour. |
| `blockCheatIncome` | `true` | Refuses money added with the game's debug/cheat functions. |
| `kickOnMoneyViolation` | `false` | Kicks the player when income gets refused. When it's off the money is just taken back. |
| `kickOnForeignSave` | `true` | Kicks the player when they load another profile or an older save from the career menu. When it's off they can stay, but nothing they do gets saved anymore. |
| `maxSaveSizeMB` | `32` | Bigger saves are refused. Normal saves are around 2 MB. |
| `backupCount` | `5` | How many older copies of each save are kept. 1 is the minimum. |
| `autoSaveMinutes` | `5` | The server asks a player's game to save when it hasn't saved for this long. `0` turns it off. |
| `saveCommandCooldown` | `30` | Seconds a player has to wait between two `/save`. |
| `allowTransactions` | `true` | Lets players pay each other from the player list. |
| `shortWindowMax` | `1000` | Payment limit: how much a player can send within `shortWindowSeconds`. |
| `shortWindowSeconds` | `30` | |
| `longWindowMax` | `10000` | Payment limit: how much a player can send within `longWindowSeconds`. |
| `longWindowSeconds` | `300` | |
| `sessionSendingMax` | `100000` | Most a player can send to others in one session. |
| `sessionReceiveMax` | `200000` | Most a player can receive from others in one session. |
| `autoUpdate` | `false` | Checks this repo for a new version when the server starts and downloads it. |
| `autoExit` | `true` | Closes the server after an auto update, for servers with a restart script. |

The hourly limits are counted per account, so reconnecting doesn't reset them.

## client

These get sent to every player.

| Setting | Default | |
|---|---|---|
| `sharedTraffic` | `true` | One player hosts the traffic for everyone. `false` means everyone spawns their own like in the original CareerMP. |
| `roadTrafficEnabled` | `true` | |
| `roadTrafficAmount` | `10` | Driving traffic cars. With shared traffic that's the total, otherwise it's per player. |
| `extraTrafficEnabled` | `false` | |
| `extraTrafficAmount` | `0` | Extra traffic cars that get spawned but don't all drive at the same time. The game swaps them in so traffic looks more varied. |
| `parkedTrafficEnabled` | `true` | |
| `parkedTrafficAmount` | `10` | Parked cars. |
| `trafficSimpleVehicles` | `true` | Uses the simple traffic models, which are much lighter. |
| `trafficSmartSelections` | `true` | BeamNG's own pick of which cars spawn in traffic. |
| `trafficAllowMods` | `false` | Lets mod vehicles show up in traffic. |
| `localUnicycleGhost` | `false` | When you walk, other things go through you. |
| `remoteUnicycleGhost` | `true` | Other players that are walking can't be hit. |
| `remoteVehicleGhost` | `false` | Other players' cars have no collision. |
| `worldEditorEnabled` | `false` | Lets players open the world editor. |
| `consoleEnabled` | `false` | Lets players open the Lua console. |
| `simplifyRemoteVehicles` | `false` | |
| `spawnVehicleIgnitionLevel` | `0` | |
| `skipOtherPlayersVehicles` | `false` | |
| `serverSaveName` | `""` | Not used in this version, saves are named after the BeamMP account. |
| `serverSaveSuffix` | `""` | Not used in this version. |
| `serverSaveNameEnabled` | `false` | Not used in this version. |

The traffic and gameplay settings are set in the player's game while they're on the server and put back to their own when they leave.
