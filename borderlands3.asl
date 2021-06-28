state("Borderlands3") {}

startup {
    settings.Add("start_echo", true, "Start the run when picking up Claptrap's echo");
    settings.Add("start_sancturary", false, "Start the run when entering Sanctuary");
    settings.Add("split_levels", false, "Split on level transitions");
    settings.Add("split_tyreen", true, "Split on Main Campaign ending cutscene");
    settings.Add("split_jackpot", true, "Split on Jackpot DLC ending cutscene");
    settings.Add("split_wedding", true, "Split on Wedding DLC ending cutscene");
    settings.Add("split_bounty", true, "Split on Bounty DLC ending cutscene");
    settings.Add("split_krieg", true, "Split on Krieg DLC ending cutscene");
    settings.Add("count_sqs", false, "Count SQs in \"SQs:\" counter component");

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

    vars.beforePatch = (Func<string, string, bool>)((version, patch) => {
        var sanitizedVersion = version.StartsWith("Unstable ") ? version.Substring(9) : version;
        var versionIdx = ORDERED_VERSIONS.IndexOf(sanitizedVersion);
        if (versionIdx == -1) {
            // Assume unknown versions are newer
            return false;
        }
        return versionIdx < ORDERED_VERSIONS.IndexOf(patch);
    });

    vars.loadFromGNames = null;

    vars.localPlayer = null;

    vars.worldPtr = null;
    vars.isLoading = null;
    vars.playthrough = null;
    vars.missionCount = null;
    vars.startingEchoObjective = null;

    vars.currentWorld = null;
    vars.oldWorld = null;

    vars.lastGameWorld = null;

    vars.missionComponentOffset = 0xC48;
    vars.justLoadedMissions = false;
    vars.delayedSplitTime = TimeSpan.Zero;
    vars.cutsceneWatchers = new Dictionary<string, MemoryWatcher<int>>();

    timer.OnStart += (e, o) => { vars.delayedSplitTime = TimeSpan.Zero; };

    vars.incrementCounter = null;

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

            timer.OnStart += (e, o) => {
                resetMethod.Invoke(counter, new object[0]);
            };

            break;
        }
    } catch (NullReferenceException) {}

    if (vars.incrementCounter == null) {
        print("Did not find SQ counter component");
        vars.incrementCounter = (Action)(() => {});
    }
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    vars.currentWorld = null;
    vars.oldWorld = null;

    vars.lastGameWorld = null;

    ptr = scanner.Scan(new SigScanTarget(8,
        "48 8B 4C 24 30",       // mov rcx,[rsp+30]
        "4C 8D 05 ????????",    // lea r8,[Borderlands3.exe+4C370A0]    <----
        "B8 3F000000"           // mov eax,0000003F
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find version pointer!");
        version = "Unknown";
    } else {
        version = game.ReadString(new IntPtr(game.ReadValue<int>(ptr) + ptr.ToInt64() + 4), 64);
    }

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
        vars.loadFromGNames = null;
    } else {
        var GNames = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - page.BaseAddress.ToInt64() + 4
        );

        vars.loadFromGNames = (Func<int, string>)((idx) => {
            var namePtr = new DeepPointer(GNames, (idx / 0x4000) * 8, (idx % 0x4000) * 8, 0x10);
            return namePtr.DerefString(game, 64);
        });
    }

    // See this for info on the next two
    // https://gist.github.com/apple1417/111a6d7f3a4b786d4752e3b458617e26

    ptr = scanner.Scan(new SigScanTarget(7,
        "4C 8D 0C 40",          // lea r9,[rax+rax*2]
        "48 8B 05 ????????",    // mov rax,[Borderlands3.exe+6175420] <----
        "4A 8D 0C C8"           // lea rcx,[rax+r9*8]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find current world pointer!");
        vars.worldPtr = null;
    } else {
        var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
        vars.worldPtr = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x0, 0x18
        ));
    }

    Tuple<string, int> loadingPattern;
    if (vars.beforePatch(version, "OAK-PATCHDIESEL0-280")) {
        loadingPattern = new Tuple<string, int>("D0010000", 0x9DC);
    } else {
        loadingPattern = new Tuple<string, int>("F0010000", 0xA7C);
    }

    ptr = scanner.Scan(new SigScanTarget(-119,
        "C7 44 24 28 0C000010",         // mov [rsp+28],1000000C
        "C7 44 24 20" + loadingPattern.Item1   // mov [rsp+20],000001F0
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading pointer!");
        vars.isLoading = null;
    } else {
        var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
        vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0xF8, loadingPattern.Item2
        ));
    }

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
        vars.localPlayer = null;
        vars.playthrough = null;
    } else {
        vars.localPlayer = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - page.BaseAddress.ToInt64() + 0xD4
        );
        if (vars.beforePatch(version, "OAK-PATCHDIESEL0-280")) {
            vars.missionComponentOffset = 0xC48;
        } else {
            vars.missionComponentOffset = 0xC60;
        }
        // Playthroughs is the only constant pointer, the rest depend on playthough and the order
        //  you grabbed missions in
        vars.playthrough = new MemoryWatcher<int>(new DeepPointer(
            vars.localPlayer, 0x30, vars.missionComponentOffset, 0x1E0
        ));
        vars.justLoadedMissions = true;
    }
    // These get set in update
    vars.missionCount = null;
    vars.startingEchoObjective = null;

    if (
        version != "Unknown" && (
            vars.loadFromGNames == null
            || vars.worldPtr == null
            || vars.isLoading == null
            || vars.playthrough == null
        )
    ) {
        version = "Unstable " + version;
    }
}

exit {
    timer.IsGameTimePaused = true;
}

update {
    if (vars.worldPtr != null && vars.loadFromGNames != null) {
        var changed = vars.worldPtr.Update(game);
        vars.oldWorld = vars.worldPtr.Old == 0
                        ? null
                        : vars.loadFromGNames(vars.worldPtr.Old);
        vars.currentWorld = vars.worldPtr.Current == 0
                            ? null
                            : vars.loadFromGNames(vars.worldPtr.Current);

        if (changed) {
            print(
                "Map changed from "
                + vars.oldWorld.ToString()
                + " to "
                + vars.currentWorld.ToString()
            );

            if (settings["count_sqs"] && vars.currentWorld == "MenuMap_P") {
                vars.incrementCounter();
            }
        }
    } else {
        vars.oldWorld = null;
        vars.currentWorld = null;
    }


    if (vars.isLoading != null) {
        var changed = vars.isLoading.Update(game);
        if (changed) {
            print(
                "Loading changed from "
                + vars.isLoading.Old.ToString("X")
                + " to "
                + vars.isLoading.Current.ToString("X")
            );
        }
    }

    if (vars.justLoadedMissions) {
        vars.justLoadedMissions = false;
    }
    if (vars.playthrough != null) {
        var playthroughChanged = vars.playthrough.Update(game);
        var missionsChanged = false;

        // If playthrough changes we need to update the mission counter pointer
        if (vars.missionCount == null || (playthroughChanged && vars.playthrough.Current >= 0)) {
            var playthrough = vars.playthrough.Current >= 0 ? vars.playthrough.Current : 0;
            vars.missionCount = new MemoryWatcher<int>(new DeepPointer(
                vars.localPlayer, 0x30, vars.missionComponentOffset, 0x188, 0x18 * playthrough + 0x8
            ));
            missionsChanged = true;
        }

        missionsChanged |= vars.missionCount.Update(game);

        // If the missions pointer/count changes we might have new missions
        if (missionsChanged) {
            print("Missions changed");
            vars.startingEchoObjective = null;
            vars.cutsceneWatchers.Clear();

            var CUTSCENE_MISSIONS = new Dictionary<string, string>() {
                { "Mission_Ep23_TyreenFinalBoss_C", "split_tyreen" },
                { "Mission_DLC1_Ep07_TheHeist_C", "split_jackpot" },
                { "EP06_DLC2_C", "split_wedding" },
                { "Mission_Ep05_Crater_C", "split_bounty" },
                { "ALI_EP05_C", "split_krieg" }
            };

            for (var idx = 0; idx < vars.missionCount.Current; idx++) {
                var missionName = vars.loadFromGNames(
                    new DeepPointer(
                        vars.localPlayer,
                        0x30, vars.missionComponentOffset, 0x188,
                        0x18 * vars.playthrough.Current,
                        0x30 * idx,
                        0x18
                    ).Deref<int>(game)
                );

                if (missionName == "Mission_Ep01_ChildrenOfTheVault_C") {
                    vars.startingEchoObjective = new MemoryWatcher<int>(
                        new DeepPointer(
                            vars.localPlayer,
                            0x30, vars.missionComponentOffset, 0x188,
                            0x18 * vars.playthrough.Current,
                            // Watch the 5th objective (index 4/offset 0x10) specifically
                            0x30 * idx + 0x10,
                            0x10
                        )
                    );
                    print("Found starting echo objective");
                } else if (CUTSCENE_MISSIONS.ContainsKey(missionName)) {
                    vars.cutsceneWatchers[CUTSCENE_MISSIONS[missionName]] = new MemoryWatcher<int>(
                        new DeepPointer(
                            vars.localPlayer,
                            0x30, vars.missionComponentOffset, 0x188,
                            0x18 * vars.playthrough.Current,
                            // Watch the active objective set name
                            0x30 * idx + 0x20,
                            0x18
                        )
                    );
                    print("Found " + CUTSCENE_MISSIONS[missionName] + " objective set");
                }
            }

            // Making new watchers means new != old, so we need a var to ignore it for one tick
            vars.justLoadedMissions = true;
        }

        if (vars.startingEchoObjective != null) {
            vars.startingEchoObjective.Update(game);
        }
        foreach (var watcher in vars.cutsceneWatchers.Values) {
            watcher.Update(game);
        }
    }
}

start {
    if (
        !vars.justLoadedMissions
        && settings["start_echo"]
        && vars.startingEchoObjective != null
        && vars.startingEchoObjective.Current == 1 && vars.startingEchoObjective.Old == 0
    ) {
        return true;
    }

    if (settings["start_sancturary"] && vars.currentWorld == "Sanctuary3_P") {
        return true;
    }

    return false;
}

isLoading {
    if (vars.isLoading.Current != 0 || vars.currentWorld == "MenuMap_P") {
        // If you start on the main menu sometimes a single tick is counted before pausing, fix it
        if (timer.CurrentAttemptDuration.TotalSeconds < 0.1) {
            timer.SetGameTime(TimeSpan.Zero);
        }
        return true;
    }

    return false;
}

split {
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

    if (!vars.justLoadedMissions) {
        var CUTSCENE_DATA = new Dictionary<string, Tuple<string, TimeSpan>>() {
            { "split_tyreen", new Tuple<string, TimeSpan>(
                "Set_TyreenDeadCine_ObjectiveSet", TimeSpan.FromSeconds(2)
            )},
            { "split_jackpot", new Tuple<string, TimeSpan>(
                "Set_FinalCinematic_ObjectiveSet", TimeSpan.FromSeconds(1)
            )},
            { "split_wedding", new Tuple<string, TimeSpan>(
                "Set_FinalCredits_ObjectiveSet", TimeSpan.FromSeconds(1)
            )},
            { "split_bounty", new Tuple<string, TimeSpan>(
                "SET_EndCredits_ObjectiveSet", TimeSpan.FromSeconds(0.1)
            )},
            { "split_krieg", new Tuple<string, TimeSpan>(
                "SET_OutroCIN_ObjectiveSet", TimeSpan.FromSeconds(1)
            )}
        };

        foreach (var item in vars.cutsceneWatchers) {
            var name = item.Key;
            var watcher = item.Value;
            var objectiveSet = CUTSCENE_DATA[name].Item1;
            var delay = CUTSCENE_DATA[name].Item2;

            if (
                settings[name]
                && watcher.Current != watcher.Old
                && vars.loadFromGNames(watcher.Current) == objectiveSet
            ) {
                vars.delayedSplitTime = timer.CurrentTime.GameTime + delay;
                continue;
            }
        }
    }

    if (vars.delayedSplitTime != TimeSpan.Zero && vars.delayedSplitTime < timer.CurrentTime.GameTime) {
        vars.delayedSplitTime = TimeSpan.Zero;
        return true;
    }

    return false;
}
