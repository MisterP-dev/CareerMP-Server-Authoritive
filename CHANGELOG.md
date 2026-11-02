# Changelog

## 0.1.0

First version, based on CareerMP 0.0.37.

### BeamNG 0.40 port
- Rebuilt `careerMP.lua`, `computer.lua` and `playerDriving.lua` on top of the 0.40 versions of those files
- Removed the old overrides of insurance, inventory, tuning, painting, part shopping, walking and the drag display, the 0.40 versions work as they are
- Updated for the renamed BeamMP events and UI apps
- Fixed the player list app not loading
- Other players' cars don't get removed anymore when your career loads
- Bigger computer zones in the garages
- Drag race light sync turned off

### Server saves
- Career saves are stored on the server per BeamMP account and sent to the player on join
- Only changed files get sent after the first save, sent in small parts so the game doesn't freeze
- The server confirms every save, the game sends it again if there's no answer
- 5 backups per player, broken saves fall back to the newest working backup
- Newer saves found on the player's PC are kept as a separate profile instead of being deleted
- `/save` chat command and an autosave request every 5 minutes
- Guests can't join, and the same account can't join twice
- Loading another profile or an older save from the career menu gets the player kicked (`kickOnForeignSave`)

### Money
- Server keeps track of every player's money and corrects saves with too much
- Limits for single rewards, sales and income per hour
- Money from debug/cheat functions is blocked
- Payments between players are checked against the server's money
- Money log per player
- `CareerMP Money` console command

### Traffic
- Shared traffic, one player hosts it for everyone (`sharedTraffic`)
- No nametags on traffic cars
- Traffic going through speed cameras and red lights isn't reported as the host anymore

### Other
- Auto update now checks this repo instead of the original one
