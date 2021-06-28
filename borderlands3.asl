state("Borderlands3") {}

startup {
#region Settings
    settings.Add("start_echo", true, "Start the run when picking up Claptrap's echo");
    settings.Add("start_sancturary", false, "Start the run when entering Sanctuary");
    settings.Add("split_levels", false, "Split on level transitions");
    settings.Add("split_tyreen", true, "Split on Main Campaign ending cutscene");
    settings.Add("split_jackpot", true, "Split on Jackpot DLC ending cutscene");
    settings.Add("split_wedding", true, "Split on Wedding DLC ending cutscene");
    settings.Add("split_bounty", true, "Split on Bounty DLC ending cutscene");
    settings.Add("split_krieg", true, "Split on Krieg DLC ending cutscene");
    settings.Add("count_sqs", false, "Count SQs in \"SQs:\" counter component");
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
        "OAK-PATCHDIESEL1-304",
        "OAK-PATCHWIN641-227",
        "OAK-PATCHDIESEL0-280",
        "OAK-PATCHWIN640-226",
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

    // There's no good way to redo this on layout change so we'll just give in and put it in startup
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
    timer.OnStart -= vars.resetOnStart;
    if (vars.resetCounter != null) {
        timer.OnStart -= vars.resetCounter;
    }
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;
    var anyScanFailed = false;

    vars.watchers.Clear();
    vars.loadFromGNames = null;

    vars.currentWorld = null;
    vars.localPlayer = null;
    vars.missionComponentOffset = null;

#region Version
    ptr = scanner.Scan(new SigScanTarget(8,
        "48 8B 4C 24 30",       // mov rcx,[rsp+30]
        "4C 8D 05 ????????",    // lea r8,[Borderlands3.exe+4C370A0]    <----
        "B8 3F000000"           // mov eax,0000003F
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find version pointer!");
        version = "Unknown";
        // Not setting `anyScanFailed` here since unknown is already a failure message
    } else {
        version = game.ReadString(new IntPtr(game.ReadValue<int>(ptr) + ptr.ToInt64() + 4), 64);
    }
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
        vars.localPlayer = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - page.BaseAddress.ToInt64() + 0xD4
        );
        vars.missionComponentOffset = vars.beforePatch(version, "OAK-PATCHDIESEL0-280")
                                      ? 0xC48
                                      : 0xC60;
        // Playthroughs is the only constant pointer, the rest depend on playthough and the order
        //  you grabbed missions in
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            vars.localPlayer, 0x30, vars.missionComponentOffset, 0x1E0
        )){ Name = "playthrough" });
    }
#endregion

    if (version != "Unknown" && anyScanFailed) {
        version = "Unstable " + version;
    }
}

exit {
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
        // Getting here implies `vars.localPlayer` and `vars.missionComponentOffset` are not null

        var missionsChanged = false;
        if (vars.hasWatcher("mission_count")) {
            missionsChanged = vars.watchers["mission_count"].Changed;
        }

        // If playthrough changes we need to update the mission counter pointer
        if (
            !vars.hasWatcher("mission_count")
            || (vars.watchers["playthrough"].Changed && vars.watchers["playthrough"].Current >= 0)
        ) {
            // In the case where we have an invalid playthrough index (-1) when first loading the
            //  mission count, use playthrough 0 so the pointer doesn't go out of bounds
            // Practically, we'll get a playthrough update before ever using the pointer, but good
            //  to be sage
            var playthrough = Math.Max(0, vars.watchers["playthrough"].Current);

            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                vars.localPlayer, 0x30, vars.missionComponentOffset, 0x188, 0x18 * playthrough + 0x8
            )){ Name = "mission_count" });
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

            // Just incase this ever becomes an invalid pointer
            var missionCount = Math.Min(1000, vars.watchers["mission_count"].Current);
            for (var idx = 0; idx < missionCount; idx++) {
                var missionName = vars.loadFromGNames(
                    new DeepPointer(
                        vars.localPlayer,
                        0x30, vars.missionComponentOffset, 0x188,
                        0x18 * vars.watchers["playthrough"].Current,
                        0x30 * idx,
                        0x18
                    ).Deref<int>(game)
                );
                if (missionName == null) {
                    continue;
                }

                if (missionName == "Mission_Ep01_ChildrenOfTheVault_C") {
                    vars.watchers.Add(new MemoryWatcher<int>(
                        new DeepPointer(
                            vars.localPlayer,
                            0x30, vars.missionComponentOffset, 0x188,
                            0x18 * vars.watchers["playthrough"].Current,
                            // Watch the 5th objective (index 4/offset 0x10) specifically
                            0x30 * idx + 0x10,
                            0x10
                        )
                    ){ Name = "start_echo" });
                    print("Found starting echo objective");
                } else if (CUTSCENE_MISSIONS.ContainsKey(missionName)) {
                    var setting_name = CUTSCENE_MISSIONS[missionName];
                    vars.watchers.Add(new MemoryWatcher<int>(
                        new DeepPointer(
                            vars.localPlayer,
                            0x30, vars.missionComponentOffset, 0x188,
                            0x18 * vars.watchers["playthrough"].Current,
                            // Watch the active objective set name
                            0x30 * idx + 0x20,
                            0x18
                        )
                    ){ Name = setting_name });
                    print("Found " + setting_name + " objective set");
                }
            }
        }
    }
#endregion
}

start {
    if (
        settings["start_echo"] && vars.hasWatcher("start_echo")
        && vars.watchers["start_echo"].Changed && vars.watchers["start_echo"].Current == 1
    ) {
        print("Starting due to collecting echo.");
        return true;
    }

    if (settings["start_sancturary"] && vars.currentWorld == "Sanctuary3_P") {
        print("Starting due to entering Sancturary.");
        return true;
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

    foreach (var item in CUTSCENE_DATA) {
        var setting_name = item.Item1;
        if (!vars.hasWatcher(setting_name) || !settings[setting_name]) {
            continue;
        }

        var objectiveSet = item.Item2;
        var delay = item.Item3;
        var watcher = vars.watchers[setting_name];

        if (watcher.Changed && vars.loadFromGNames(watcher.Current) == objectiveSet) {
            vars.delayedSplitTime = timer.CurrentTime.GameTime + delay;
            // We have bigger problems if you manage to activate two of these at once
            break;
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
