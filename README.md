### Autosplitters
Livesplit autosplitters for various games.
These don't all necessarily do autosplitting or load removal, livesplit is just a nice tool to quickly do some memory reading with.

##### serious_sam_3_bfe.asl
- Starts upon loading any level
- Removes loading screens, including "Continue" screen when the map has loaded
- Splits for world transitions
- Ending splits for defeating the final boss in both the main and dlc campaigns
- Uses sig scans and log messages, so should work for all versions

##### serious_sam_revolution.asl
- Starts upon loading any level (specifically network client being initialized)
- Removes loading screens
- Splits on loading screens
- Uses sig scans, so should work for all versions

##### sigils_of_elohim.asl
- Starts upon entering any puzzle
- Splits upon solving puzzles
- Syncs in game timers

##### talos_csv.asl
- Saves your position, speed, and distances traveled last frame (delta) to a csv file while the timer is running
- Made for version 326589, 32-bit unmodded, probably breaks everywhere else

##### talos_principle.asl
- Fork of Talos Principle autosplitter available [here](https://github.com/jbzdarkid/Autosplitters/blob/master/LiveSplit.TheTalosPrinciple.asl), has mostly the same features
- Removes loads when changing graphics options
- Uses sig scans, so should work for all versions

##### talos_qrs.asl
- For Talos Principle All Achievements runs
- Splits when total QR count changes, will stop when maximum reached
- Updates first text component in layout to show current QR count
- Uses sig scans, so should work for all versions

##### talos_speed.asl
- Overwrites your first 5 text components with your player speed
- Made for version 326589, 32-bit unmodded, probably breaks everywhere else
