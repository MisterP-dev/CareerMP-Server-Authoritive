# Saves

## Where they are

Everything is in `Resources/Server/CareerMP/saves/`. Each player has:

| File | |
|---|---|
| `beammp<id>.json` | The current save. `<id>` is the player's BeamMP account ID. |
| `beammp<id>.bak1.json` ... `.bak5.json` | Older saves, `bak1` is the newest. |
| `beammp<id>.log` | Money log: income, payments between players, refused income, corrections and changes made from the console. Also notes when the player loaded a save that isn't theirs, or when an unsynced local save was found. |

To find out which file belongs to who, look in `Server.log` for a line like this one, it shows up every time someone joins:

```
[CareerMP] ---------- Career of SomePlayer loaded from the server (beammp1234567, $10000)
```

## How saving works

1. When a player joins, the server sends them their save. Their game writes it into a career profile called `careermpbeammp<id>` and loads it.
2. Every time the game saves (the normal career autosave, `/save`, or the server asking every 5 minutes), the game sends the save back. After the first time only the files that changed get sent.
3. The server checks it, fixes the money if it's higher than it should be, stores it and tells the game it worked. If there's no answer after 30 seconds the game tries again, up to 3 times. After that the player gets a message that the save failed.
4. The new file gets written to a temporary file first and read back to make sure it's complete. Only then do the backups move along and the new one takes the place of the old one.

Money is tracked separately. Every time a player's money changes their game reports it, and the server checks it against the limits in the config.

## Restoring a backup

1. Stop the server, or at least make sure the player isn't online.
2. Rename or delete `beammp<id>.json`.
3. Rename the backup you want, for example `beammp<id>.bak2.json`, to `beammp<id>.json`.
4. Start the server. The player gets that save the next time they join.

You don't have to do anything if the newest save is broken, the server loads the newest backup that works by itself and prints a line about it.

## Unsynced saves

If a player's PC has a newer save than the server when they join (for example their game crashed before the save reached the server), the server save is loaded anyway. The save from their PC isn't deleted though: it gets renamed to a profile called `careermpbeammp<id>unsynced<date>`, and the server log says so. If it's worth getting back, an admin can compare it with the server save and decide.

## Loading other saves

While on the server, loading a different profile or an older save from the career menu gets the player kicked (with `kickOnForeignSave` on). From that moment the server ignores everything that player's game sends, so none of it ends up on the server. When they rejoin they get their server save as usual.

## Moving to another server

Copy the whole `saves` folder over. The saves are tied to BeamMP accounts, not to the server.

## Resetting a player

Delete their files while they're offline. They start a new career the next time they join.
