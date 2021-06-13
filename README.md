### Autosplitters
Livesplit autosplitters for various games.
Most of these use sigscans meaning they should work across multiple versions of their game.

These don't all necessarily do autosplitting or load removal however, livesplit is just a nice tool to quickly do some memory reading with.

##### serious_sam_3_bfe.asl
- Starts upon loading the starting levels
- Removes loading screens, including the continue screen when the map has loaded
- Splits for world transitions
- Ending splits for defeating the final boss in both the main and dlc campaigns

##### serious_sam_4_bfe.asl
- Starts upon loading the first level
- Removes loading screens, including the continue screen when the map has loaded
- Splits for world transitions

##### serious_sam_classics.asl
Works for Serious Sam TFE, TSE, and Revolution
- Starts upon loading any level OR exiting Netricsa, either chosen automatically based on version or by setting
- Removes loading screens
- Splits on loading screens and collecting secrets
- Resets on return to main menu
- Uses sig scans so should keep working for Revolution updates

##### sigils_of_elohim.asl
- Starts upon entering any puzzle
- Splits upon solving puzzles
- Syncs in game timers
- Made for current steam version, there probably won't be updates anyway

##### talos_csv.asl
- Saves your position, speed, and distances traveled last frame (delta) to a csv file while the timer is running
- Made for version 326589, 32-bit unmodded, probably breaks everywhere else

##### talos_principle.asl
- Fork of Talos Principle autosplitter available [here](https://github.com/jbzdarkid/Autosplitters/blob/master/LiveSplit.TheTalosPrinciple.asl), has mostly the same features
- Removes loads when changing graphics options

##### talos_qrs.asl
- For Talos Principle All Achievements runs
- Splits when total QR count changes, will stop when maximum reached
- Updates first text component in layout to show current QR count

##### talos_speed.asl
- Overwrites your first 5 text components with your player speed
- Only works on 326/32/unmodded and 440/64/modded - couldn't be bothered to write up sigscans :)
