state("Borderlands3") {}

startup {
#region Settings
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_echo", true, "Picking up Claptrap's echo", "start_header");
    settings.Add("start_jackpot", true, "Starting Jackpot DLC", "start_header");
    settings.Add("start_wedding", true, "Starting Wedding DLC", "start_header");
    settings.Add("start_bounty", true, "Starting Bounty DLC", "start_header");
    settings.Add("start_krieg", true, "Starting Krieg DLC", "start_header");
    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_tyreen", true, "Main Campaign ending cutscene", "split_header");
    settings.Add("split_jackpot", true, "Jackpot DLC ending cutscene", "split_header");
    settings.Add("split_wedding", true, "Wedding DLC ending cutscene", "split_header");
    settings.Add("split_bounty", true, "Bounty DLC ending cutscene", "split_header");
    settings.Add("split_krieg", true, "Krieg DLC ending cutscene", "split_header");
    settings.Add("count_sqs", false, "Count SQs in \"SQs:\" counter component (requires reload)");
#endregion

#region Versions
    var ORDERED_VERSIONS = new List<string>() {
        "OAK-PADDIESEL1-39",
        "OAK-PATCHDIESEL-11",
        "OAK-PATCHDIESEL-21",
        "OAK-PATCHDIESEL-45",
        "OAK-PATCHDIESEL-71",
        "OAK-PATCHDIESEL-97",
        "OAK-PATCHDIESEL-99",
        "OAK-PATCHDIESEL0-45",
        "OAK-PATCHDIESEL2-32",
        "OAK-PATCHWIN64-49",
        "OAK-PATCHDIESEL1-102",
        "OAK-PATCHWIN641",
        "OAK-PATCHDIESEL-178",
        "OAK-PATCHWIN64-79",
        "OAK-PATCHDIESEL1-137",
        "OAK-PATCHWIN641-63",
        "OAK-PATCHDIESEL0-103",
        "OAK-PATCHWIN640-59",
        "OAK-PATCHDIESEL-222",
        "OAK-PATCHWIN64-123",
        "OAK-PATCHDIESEL1-191",
        "OAK-PATCHWIN641-118",
        "OAK-PATCHDIESEL0-200",
        "OAK-PATCHWIN640-149",
        "OAK-PATCHDIESEL-226",
        "OAK-PATCHWIN64-127",
        "OAK-PATCHDIESEL0-224",
        "OAK-PATCHWIN640-172",
        "OAK-PATCHDIESEL1-304", // Confirmed
        "OAK-PATCHWIN641-227",  // Confirmed
        "OAK-PATCHDIESEL0-280", // Confirmed
        "OAK-PATCHWIN640-226",  // Confirmed
    };

    // Need to pass this a version reference cause otherwise it'll always use what we had when
    //  defining this
    vars.beforePatch = (Func<string, string, bool>)((version, patch) => {
        var sanitizedVersion = version.StartsWith("Unstable ") ? version.Substring(9) : version;
        var versionIdx = ORDERED_VERSIONS.IndexOf(sanitizedVersion);
        if (versionIdx == -1) {
            // Assume unknown versions are newer
            return false;
        }
        return versionIdx < ORDERED_VERSIONS.IndexOf(patch);
    });
#endregion

    vars.unknownVersionTimeout = DateTime.MaxValue;

    vars.watchers = new MemoryWatcherList();
    vars.hasWatcher = (Func<string, bool>)(name => {
        return ((MemoryWatcherList)vars.watchers).Any(x => x.Name == name);
    });

    vars.delayedSplitTime = TimeSpan.Zero;
    vars.lastGameWorld = null;

    vars.resetOnStart = (EventHandler)((e, o) => {
        vars.delayedSplitTime = TimeSpan.Zero;
        vars.lastGameWorld = null;
    });
    timer.OnStart += vars.resetOnStart;

#region Counter
    vars.incrementCounter = null;
    vars.resetCounter = null;

    // There's no good way to redo this on layout change
    // While we could hackily look for stuff in update or startup, only grabbing it once here makes
    //  for a relatively intuitive explanation for users - it just requires a reload
    try {
        foreach (var component in timer.Layout.Components) {
            // Counter isn't a default component, so we need to use reflection to keep this working
            //  when it's not installed
            var type = component.GetType();
            if (type.Name != "CounterComponent") {
                continue;
            }

            var counterSettings = type.GetProperty("Settings").GetValue(component);
            var textProperty = counterSettings.GetType().GetProperty("CounterText");
            if ((string)textProperty.GetValue(counterSettings) != "SQs:") {
                continue;
            }

            var counter = type.GetProperty("Counter").GetValue(component);
            var counterType = counter.GetType();

            var incrMethod = counterType.GetMethod("Increment");
            var resetMethod = counterType.GetMethod("Reset");

            if (incrMethod == null || resetMethod == null) {
                throw new NullReferenceException();
            }

            print("Found SQ counter component");

            vars.incrementCounter = (Action)(() => {
                incrMethod.Invoke(counter, new object[0]);
            });

            vars.resetCounter = (EventHandler)((e, o) => {
                resetMethod.Invoke(counter, new object[0]);
            });
            timer.OnStart += vars.resetCounter;

            break;
        }
    } catch (NullReferenceException) {}

    if (vars.incrementCounter == null) {
        print("Did not find SQ counter component");
        vars.incrementCounter = (Action)(() => {});
    }
#endregion
}

shutdown {
    // Being safe in case we failed during startup/init
    if (((IDictionary<string, object>)vars).ContainsKey("resetOnStart")) {
        if (vars.resetOnStart != null) {
            timer.OnStart -= vars.resetOnStart;
        }
    }
    if (((IDictionary<string, object>)vars).ContainsKey("resetOnStart")) {
        if (vars.resetCounter != null) {
            timer.OnStart -= vars.resetCounter;
        }
    }
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;
    var anyScanFailed = false;

    vars.watchers.Clear();

    vars.currentMissions = null;
    vars.newMissions = null;

    vars.createMissionCountPointer = null;
    vars.createMissionDataPointer = null;
    vars.currentWorld = null;
    vars.loadFromGNames = null;

#region Version
    var VERSION_PATTERNS = new List<Tuple<int, string[]>>() {
        // Steam
        new Tuple<int, string[]>(16, new string[] {
            "8D 7B 14",             // lea edi,[rbx+14]
            "E8 ????????",          // call Borderlands3.exe+41F5F0
            "48 8B 4C 24 30",       // mov rcx,[rsp+30]
            "4C 8D 05 ????????",    // lea r8,[Borderlands3.exe+4C370A0]    <----
            "B8 3F000000"           // mov eax,0000003F
        }),
        // Epic
        new Tuple<int, string[]>(18, new string[] {
            "48 8D 4C 24 30",       // lea rcx,[rsp+30]
            "E8 ????????",          // call Borderlands3.exe+412D30
            "48 8B 4C 24 30",       // mov rcx,[rsp+30]
            "4C 8D 05 ????????",    // lea r8,[Borderlands3.exe+4E96510]    <----
            "41 B9 15000000",       // mov r9d,00000015
            "B8 3F000000"           // mov eax,0000003F
        })
    };

    version = "Unknown";
    foreach (var pattern in VERSION_PATTERNS) {
        ptr = scanner.Scan(new SigScanTarget(pattern.Item1, pattern.Item2));
        if (ptr != IntPtr.Zero) {
            version = game.ReadString(new IntPtr(game.ReadValue<int>(ptr) + ptr.ToInt64() + 4), 64);
        }
    }
#endregion

#region Epic Process Fix
    /*
    Launching the game on Epic first creates a "launcher" process, which starts the actual game, but
     still sticks around. Both processes are called "Borderlands3", but only the second one is valid
     and has the pointers we need.
    Livesplit will hook the last launched processed - so when you launch it after the game, it works
     fine. However, if it's running before launching the game, it hooks onto the launcher while it's
     still the only process, and cause it doesn't quit we get stuck with it.
    To fix this, we use reflection to set the hooked game back to null (it's private), then exit and
     let livesplit try hook again next tick - eventually it will pick the newer, correct, process.
    We'll do this for 30s max, and assume we actually do have an unknown version then.
    */

    if (version == "Unknown") {
        // Not setting `anyScanFailed` here since unknown is already a failure message
        if (vars.unknownVersionTimeout == DateTime.MaxValue) {
            print("Could not find version pointer!");
        }

        if (vars.unknownVersionTimeout < DateTime.Now) {
            print("Timeout expired; assuming version is actually unknown!");
        } else if (
            // If on Epic
            !Directory.Exists(Path.Combine(
                Path.GetDirectoryName(page.FileName),
                @"..\..\..\Engine\Binaries\ThirdParty\steamworks"
            ))
        ) {
            if (vars.unknownVersionTimeout == DateTime.MaxValue) {
                print("May be due to hooking Epic launcher process instead of the game - retrying");
                vars.unknownVersionTimeout = DateTime.Now.AddSeconds(30);
            }

            var allComponents = timer.Layout.Components;
            // Grab the autosplitter from splits
            if (timer.Run.AutoSplitter != null && timer.Run.AutoSplitter.Component != null) {
                allComponents = allComponents.Append(timer.Run.AutoSplitter.Component);
            }
            foreach (var component in allComponents) {
                var type = component.GetType();
                if (type.Name == "ASLComponent") {
                    // Could also check script path, but renaming the script breaks that, and
                    //  running multiple autosplitters at once is already just asking for problems
                    var script = type.GetProperty("Script").GetValue(component);
                    script.GetType().GetField(
                        "_game",
                        BindingFlags.NonPublic | BindingFlags.Instance
                    ).SetValue(script, null);
                }
            }
            return;
        }
    }

    vars.unknownVersionTimeout = DateTime.MaxValue;
#endregion

#region GNames
    ptr = scanner.Scan(new SigScanTarget(11,
        "E8 ????????",          // call Borderlands3.exe+3DB68AC
        "48 ?? ??",             // mov rax,rbx
        "48 89 1D ????????",    // mov [Borderlands3.exe+69426C8],rbx   <----
        "48 8B 5C 24 ??",       // mov rbx,[rsp+20]
        "48 83 C4 28",          // add rsp,28
        "C3",                   // ret
        "?? DB",                // xor ebx,ebx
        "48 89 1D ????????",    // mov [Borderlands3.exe+69426C8],rbx
        "?? ??",                // mov eax,ebx
        "48 8B 5C 24 ??",       // mov rbx,[rsp+20]
        "48 83 C4 ??",          // add rsp,28
        "C3"                    // ret
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GNames pointer!");
        anyScanFailed = true;
    } else {
        var GNames = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - page.BaseAddress.ToInt64() + 4
        );

        vars.loadFromGNames = (Func<int, string>)((idx) => {
            if (idx == 0) {
                // Technically this is wrong, index 0 is valid but is normally "None"
                // Practically, if we have 0 we probably have a bad pointer
                return null;
            }
            var namePtr = new DeepPointer(GNames, (idx / 0x4000) * 8, (idx % 0x4000) * 8, 0x10);
            return namePtr.DerefString(game, 64);
        });
    }
#endregion

    // See this for info on the next two
    // https://gist.github.com/apple1417/111a6d7f3a4b786d4752e3b458617e26

#region World Name
    ptr = scanner.Scan(new SigScanTarget(7,
        "4C 8D 0C 40",          // lea r9,[rax+rax*2]
        "48 8B 05 ????????",    // mov rax,[Borderlands3.exe+6175420] <----
        "4A 8D 0C C8"           // lea rcx,[rax+r9*8]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find current world pointer!");
        anyScanFailed = true;
    } else {
        var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x0, 0x18
        )){ Name = "world_name" });
    }
#endregion

#region Loading
    var ALL_LOADING_PATTERNS = new List<Tuple<string, int>>() {
        new Tuple<string, int>("D0010000", 0x9DC), // Before OAK-PATCHDIESEL0-280
        new Tuple<string, int>("F0010000", 0xA7C)
    };

    // Can just try all patterns cause the scan will fail on bad ones
    foreach (var pattern in ALL_LOADING_PATTERNS) {
        ptr = scanner.Scan(new SigScanTarget(-119,
            "C7 44 24 28 0C000010",         // mov [rsp+28],1000000C
            "C7 44 24 20" + pattern.Item1   // mov [rsp+20],000001F0
        ));
        if (ptr != IntPtr.Zero) {
            var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                game.ReadValue<int>(ptr) + relPos, 0xF8, pattern.Item2
            )){ Name = "is_loading" });
            break;
        }
    }
    if (!vars.hasWatcher("is_loading")) {
        print("Could not find loading pointer!");
    }
#endregion

#region Missions
    ptr = scanner.Scan(new SigScanTarget(31,
        "88 1D ????????",       // mov [Borderlands3.exe+6A5A794],bl { (0) }
        "E8 ????????",          // call Borderlands3.exe+3DB17A4
        "48 8D 0D ????????",    // lea rcx,[Borderlands3.exe+6A5A798] { (-2147481615) }
        "E8 ????????",          // call Borderlands3.exe+3DB1974
        "48 8B 5C 24 20",       // mov rbx,[rsp+20]
        "48 8D 05 ????????",    // lea rax,[Borderlands3.exe+6A5A6A0] { (0) }   <----
        "48 83 C4 28",          // add rsp,28 { 40 }
        "C3"                    // ret
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find local player pointer!");
        anyScanFailed = true;
    } else {
        var localPlayer = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - page.BaseAddress.ToInt64() + 0xD4
        );
        var missionComponentOffset = vars.beforePatch(version, "OAK-PATCHDIESEL0-280")
                                     ? 0xC48
                                     : 0xC60;
        // Playthroughs is the only constant pointer, the rest depend on playthough and the order
        //  you grabbed missions in
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            localPlayer, 0x30, missionComponentOffset, 0x1E0
        )){ Name = "playthrough" });

        vars.createMissionCountPointer = (Func<DeepPointer>)(() => {
            // In the case where we have an invalid playthrough index (-1), use playthrough 0 so the
            //  pointer doesn't go out of bounds
            // Practically, this only happens if when first loading the mission count, we'll always
            // get a playthrough update before ever using the pointer, but good to be safe
            var playthrough = Math.Max(0, vars.watchers["playthrough"].Current);
            return new DeepPointer(
                localPlayer,
                0x30,
                missionComponentOffset,
                0x188,
                0x18 * playthrough + 0x8
            );
        });

        vars.createMissionDataPointer = (Func<int, int, DeepPointer>)((offset1, offset2) => {
            return new DeepPointer(
                localPlayer,
                0x30,
                missionComponentOffset,
                0x188,
                0x18 * vars.watchers["playthrough"].Current,
                offset1,
                offset2
            );
        });
    }
#endregion

    if (version != "Unknown" && anyScanFailed) {
        version = "Unstable " + version;
    }
}

exit {
    vars.unknownVersionTimeout = DateTime.MaxValue;
    timer.IsGameTimePaused = true;
}

update {
    vars.watchers.UpdateAll(game);

#region World
    if (vars.hasWatcher("world_name") && vars.loadFromGNames != null) {
        vars.currentWorld = vars.loadFromGNames(vars.watchers["world_name"].Current);

        if (vars.watchers["world_name"].Changed) {
            print(
                "Map changed from "
                + vars.loadFromGNames(vars.watchers["world_name"].Old)
                + " to "
                + vars.currentWorld
            );

            if (settings["count_sqs"] && vars.currentWorld == "MenuMap_P") {
                vars.incrementCounter();
            }
        }
    } else {
        vars.currentWorld = null;
    }
#endregion

#region Loading
    if (vars.hasWatcher("is_loading") && vars.watchers["is_loading"].Changed) {
        print(
            "Loading changed from "
            + vars.watchers["is_loading"].Old.ToString("X")
            + " to "
            + vars.watchers["is_loading"].Current.ToString("X")
        );
    }
#endregion

#region Missions
    if (vars.hasWatcher("playthrough")) {
        if (vars.newMissions != null) {
            vars.newMissions.Clear();
        }

        var missionsChanged = false;
        if (vars.hasWatcher("mission_count")) {
            missionsChanged = vars.watchers["mission_count"].Changed;
        }

        // If playthrough changes we need to update the mission counter pointer
        if (
            !vars.hasWatcher("mission_count")
            || (vars.watchers["playthrough"].Changed && vars.watchers["playthrough"].Current >= 0)
        ) {
            ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == "mission_count");
            vars.watchers.Add(new MemoryWatcher<int>(
                vars.createMissionCountPointer()
            ){ Name = "mission_count" });

            vars.watchers["mission_count"].Update(game);
            // The inital update doesn't set Changed, hence why we need this extra value
            missionsChanged = true;
        }

        // If the missions pointer/count changes we might have new missions
        if (missionsChanged) {
            print("Missions changed");

            var CUTSCENE_MISSIONS = new Dictionary<string, string>() {
                { "Mission_Ep23_TyreenFinalBoss_C", "split_tyreen" },
                { "Mission_DLC1_Ep07_TheHeist_C", "split_jackpot" },
                { "EP06_DLC2_C", "split_wedding" },
                { "Mission_Ep05_Crater_C", "split_bounty" },
                { "ALI_EP05_C", "split_krieg" }
            };

            foreach (var name in CUTSCENE_MISSIONS.Values) {
                ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == name);
            }
            ((MemoryWatcherList)vars.watchers).RemoveAll(
                 x => x.Name == "Mission_Ep01_ChildrenOfTheVault_C"
            );

            var oldMissions = vars.currentMissions;
            vars.currentMissions = new List<string>();

            // Just incase this ever becomes an invalid pointer
            var missionCount = Math.Min(1000, vars.watchers["mission_count"].Current);
            for (var idx = 0; idx < missionCount; idx++) {
                var missionName = vars.loadFromGNames(
                    vars.createMissionDataPointer(0x30 * idx, 0x18).Deref<int>(game)
                );
                if (missionName == null) {
                    continue;
                }
                vars.currentMissions.Add(missionName);

                if (missionName == "Mission_Ep01_ChildrenOfTheVault_C") {
                    // Watch the 5th objective (index 4/offset 0x10) specifically
                    vars.watchers.Add(new MemoryWatcher<int>(
                        vars.createMissionDataPointer(0x30 * idx + 0x10, 0x10)
                    ){ Name = "start_echo" });
                    print("Found starting echo objective");
                } else if (CUTSCENE_MISSIONS.ContainsKey(missionName)) {
                    var setting_name = CUTSCENE_MISSIONS[missionName];
                    // Watch the active objective set name
                    vars.watchers.Add(new MemoryWatcher<int>(
                        vars.createMissionDataPointer(0x30 * idx + 0x20, 0x18)
                    ){ Name = setting_name });
                    print("Found " + setting_name + " objective set");
                }
            }

            vars.newMissions = ((List<string>)vars.currentMissions).Where(
                x => (
                    // Don't fill in anything when first loading missions
                    oldMissions != null && vars.watchers["mission_count"].Old > 0
                    && !oldMissions.Contains(x)
                )
            ).ToList();
        }
    }
#endregion
}

start {
    if (
        settings["start_echo"] && vars.hasWatcher("start_echo")
        // Make sure not to fire when first loading in on a character
        && vars.hasWatcher("playthrough") && vars.watchers["playthrough"].Old != -1
        && vars.watchers["start_echo"].Changed && vars.watchers["start_echo"].Current == 1
        // If we don't have a world pointer ignore this, otherwise only start in Covenant Pass
        && (vars.currentWorld == null || vars.currentWorld == "Recruitment_P")
    ) {
        print("Starting due to collecting echo.");
        return true;
    }

    if (vars.newMissions != null) {
        var MISSION_DATA = new Dictionary<string, string>() {
            { "Mission_DLC1_Ep01_MeetTimothy_C", "start_jackpot" },
            { "EP01_DLC2_C", "start_wedding" },
            { "Mission_Ep01_WestlandWelcome_C", "start_bounty" },
            { "ALI_EP01_C", "start_krieg" },
        };

        foreach (var missionName in vars.newMissions) {
            if (MISSION_DATA.ContainsKey(missionName) && settings[MISSION_DATA[missionName]]) {
                print("Starting due to picking up mission " + missionName.ToString());
                return true;
            }
        }
    }

    return false;
}

isLoading {
    if (
        (vars.hasWatcher("is_loading") && vars.watchers["is_loading"].Current != 0)
        || vars.currentWorld == "MenuMap_P"
    ) {
        // If you start on the main menu sometimes a single tick is counted before pausing, fix it
        if (timer.CurrentAttemptDuration.TotalSeconds < 0.1) {
            timer.SetGameTime(TimeSpan.Zero);
        }
        return true;
    }

    return false;
}

split {
#region Level Transitions
    if (
        settings["split_levels"]
        && vars.currentWorld != null && vars.currentWorld != "MenuMap_P"
        && vars.currentWorld != vars.lastGameWorld
    ) {
        var last = vars.lastGameWorld;
        vars.lastGameWorld = vars.currentWorld;
        // Don't split on the first load into the game
        if (last != null) {
            return true;
        }
    }
#endregion

#region Ending Cutscenes
    if (vars.hasWatcher("playthrough") && vars.watchers["playthrough"].Old != -1) {
        var CUTSCENE_DATA = new List<Tuple<string, string, TimeSpan>>() {
            new Tuple<string, string, TimeSpan>(
                "split_tyreen", "Set_TyreenDeadCine_ObjectiveSet", TimeSpan.FromSeconds(2)
            ),
            new Tuple<string, string, TimeSpan>(
                "split_jackpot", "Set_FinalCinematic_ObjectiveSet", TimeSpan.FromSeconds(1)
            ),
            new Tuple<string, string, TimeSpan>(
                "split_wedding", "Set_FinalCredits_ObjectiveSet", TimeSpan.FromSeconds(1)
            ),
            new Tuple<string, string, TimeSpan>(
                "split_bounty", "SET_EndCredits_ObjectiveSet", TimeSpan.FromSeconds(0.1)
            ),
            new Tuple<string, string, TimeSpan>(
                "split_krieg", "SET_OutroCIN_ObjectiveSet", TimeSpan.FromSeconds(1)
            )
        };

        foreach (var data in CUTSCENE_DATA) {
            var setting_name = data.Item1;
            if (!vars.hasWatcher(setting_name) || !settings[setting_name]) {
                continue;
            }

            var objectiveSet = data.Item2;
            var delay = data.Item3;
            var watcher = vars.watchers[setting_name];

            if (watcher.Changed && vars.loadFromGNames(watcher.Current) == objectiveSet) {
                vars.delayedSplitTime = timer.CurrentTime.GameTime + delay;
                // We have bigger problems if you manage to activate two of these at once
                break;
            }
        }
    }
#endregion

    if (
        vars.delayedSplitTime != TimeSpan.Zero
        && vars.delayedSplitTime < timer.CurrentTime.GameTime
    ) {
        vars.delayedSplitTime = TimeSpan.Zero;
        return true;
    }

    return false;
}
