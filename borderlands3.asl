state("Borderlands3") {}

startup {
#region Settings
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_echo", true, "Picking up Claptrap's echo", "start_header");
    settings.Add("start_jackpot", true, "Starting Jackpot DLC", "start_header");
    settings.Add("start_wedding", true, "Starting Wedding DLC", "start_header");
    settings.Add("start_bounty", true, "Starting Bounty DLC", "start_header");
    settings.Add("start_krieg", true, "Starting Krieg DLC", "start_header");
    settings.Add("start_arms_race", true, "Starting Arms Race DLC", "start_header");
    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_levels_dont_end", true, "Unless doing so would end the run", "split_levels");
    settings.Add("split_tyreen", true, "Main Campaign ending cutscene", "split_header");
    settings.Add("split_jackpot", true, "Jackpot DLC ending cutscene", "split_header");
    settings.Add("split_wedding", true, "Wedding DLC ending cutscene", "split_header");
    settings.Add("split_bounty", true, "Bounty DLC ending cutscene", "split_header");
    settings.Add("split_krieg", true, "Krieg DLC ending cutscene", "split_header");
    settings.Add("use_char_time", false, "Track character time, instead of loadless.");
    settings.Add("count_sqs", false, "Count SQs in \"SQs:\" counter component (requires reload)");
#endregion

    timer.IsGameTimePaused = true;

    vars.epicProcessTimeout = DateTime.MaxValue;
    vars.cts = new CancellationTokenSource();

    vars.watchers = new MemoryWatcherList();
    vars.hasWatcher = (Func<string, bool>)(name => {
        return ((MemoryWatcherList)vars.watchers).Any(x => x.Name == name);
    });

    vars.newMissions = new List<string>();

    vars.delayedSplitTime = TimeSpan.Zero;
    vars.lastGameWorld = null;

#region Mission Data
    vars.SPLIT_MISSION_DATA = new List<Tuple<string, string, string, TimeSpan>>() {
        // Setting, Mission, ObjectiveSet, Delay
        new Tuple<string, string, string, TimeSpan>(
            "split_tyreen", "Mission_Ep23_TyreenFinalBoss_C", "Set_TyreenDeadCine_ObjectiveSet",
            TimeSpan.FromSeconds(2)
        ),
        new Tuple<string, string, string, TimeSpan>(
            "split_jackpot", "Mission_DLC1_Ep07_TheHeist_C", "Set_FinalCinematic_ObjectiveSet",
            TimeSpan.FromSeconds(1)
        ),
        new Tuple<string, string, string, TimeSpan>(
            "split_wedding", "EP06_DLC2_C", "Set_FinalCredits_ObjectiveSet",
            TimeSpan.FromSeconds(1)
        ),
        new Tuple<string, string, string, TimeSpan>(
            "split_bounty", "Mission_Ep05_Crater_C", "SET_EndCredits_ObjectiveSet",
            TimeSpan.FromSeconds(0.1)
        ),
        new Tuple<string, string, string, TimeSpan>(
            "split_krieg", "ALI_EP05_C", "SET_OutroCIN_ObjectiveSet",
            TimeSpan.FromSeconds(1)
        )
    };

    vars.START_MISSION_DATA = new Dictionary<string, string>() {
        // Mission: Setting
        // Mission as key is more convenient for where we use this
        { "Mission_DLC1_Ep01_MeetTimothy_C", "start_jackpot" },
        { "EP01_DLC2_C", "start_wedding" },
        { "Mission_Ep01_WestlandWelcome_C", "start_bounty" },
        { "ALI_EP01_C", "start_krieg" },
        { "Mission_GearUp_Intro_C", "start_arms_race" }
    };
#endregion

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

            vars.resetCounter = (Action)(() => {
                resetMethod.Invoke(counter, new object[0]);
            });

            break;
        }
    } catch (NullReferenceException) {}

    if (vars.incrementCounter == null) {
        print("Did not find SQ counter component");
        vars.incrementCounter = (Action)(() => {});
        vars.resetCounter = vars.incrementCounter;
    }
#endregion
}

shutdown {
    vars.cts.Cancel();
}

onStart {
    vars.delayedSplitTime = TimeSpan.Zero;
    vars.lastGameWorld = null;

    vars.resetCounter();
}

init {
    var exe = modules.First();

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
    We'll do this for 30s max, and assume we're actually the game then.

    Launcher process is `<bl3>\Borderlands3.exe`
    Actual game is `<bl3>\OakGame\Binaries\Win64\Borderlands3.exe`
    */
    if (File.Exists(Path.Combine(
        Path.GetDirectoryName(exe.FileName),
        "OakGame", "Binaries", "Win64", "Borderlands3.exe"
    ))) {
        if (vars.epicProcessTimeout < DateTime.Now) {
            print("Timeout expired; assuming this is actually the game process.");
        } else {
            if (vars.epicProcessTimeout == DateTime.MaxValue) {
                print("Seem to have hooked the epic launcher process - retrying");
                vars.epicProcessTimeout = DateTime.Now.AddSeconds(30);
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
    } else {
        vars.epicProcessTimeout = DateTime.MaxValue;
    }
#endregion

    var scanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    vars.newMissions.Clear();
    vars.watchers.Clear();

    vars.doMissionUpdate = null;
    vars.loadFromGNames = null;

    vars.currentWorld = null;

#region UE Constants
    // UObject
    const int CLASS_OFFSET = 0x10;
    const int NAME_OFFSET = 0x18;

    // UField
    const int NEXT_OFFSET = 0x28;

    // UStruct
    const int SUPERFIELD_OFFSET = 0x30;
    const int CHILDREN_OFFSET = 0x38;

    // UProperty
    const int ELEMENT_SIZE_OFFSET = 0x34;
    const int OFFSET_INTERNAL_OFFSET = 0x44;

    // UObjectProperty
    const int PROPERTY_CLASS_OFFSET = 0x70;

    // UClassProperty
    const int INNER_PROPERTY_OFFSET = 0x70;

    // UStructProperty
    const int PROPERTY_STRUCT_OFFSET = 0x70;

    // FArray
    const int ARRAY_DATA_OFFSET = 0x0;
    const int ARRAY_COUNT_OFFSET = 0x8;

    // GNames
    const int GNAMES_CHUNK_SIZE = 0x4000;
    const int GNAMES_NAME_OFFSET = 0x10;
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
        version = "ERROR";
        return;
    } else {
        var GNames = (int)(
            game.ReadValue<int>(ptr) + ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4
        );

        var GNamesCache = new Dictionary<int, string>() {
            // Technically this is wrong, index 0 is valid but is normally "None"
            // Practically, if we have 0 we probably have a bad pointer
            { 0, null }
        };

        vars.loadFromGNames = (Func<int, string>)((idx) => {
            if (GNamesCache.ContainsKey(idx)) {
                return GNamesCache[idx];
            }
            var name = new DeepPointer(
                GNames,
                (idx / GNAMES_CHUNK_SIZE) * 8,
                (idx % GNAMES_CHUNK_SIZE) * 8,
                GNAMES_NAME_OFFSET
            ).DerefString(game, 64);

            GNamesCache[idx] = name;
            return name;
        });
    }
#endregion

#region World Name
    ptr = scanner.Scan(new SigScanTarget(7,
        "4C 8D 0C 40",          // lea r9,[rax+rax*2]
        "48 8B 05 ????????",    // mov rax,[Borderlands3.exe+6175420] <----
        "4A 8D 0C C8"           // lea rcx,[rax+r9*8]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find current world pointer!");
        version = "ERROR";
        return;
    } else {
        var relPos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x0, NAME_OFFSET
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
            var relPos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                game.ReadValue<int>(ptr) + relPos, 0xF8, pattern.Item2
            )){ Name = "is_loading" });
            break;
        }
    }
    if (!vars.hasWatcher("is_loading")) {
        print("Could not find loading pointer!");
        version = "ERROR";
    }
#endregion

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
        version = "ERROR";
    } else {
        var relPos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
        var localPlayer = (game.ReadValue<int>(ptr) + relPos) + (0x8 * 0x1A);

        var offsets = new Dictionary<string, int>();
        var finishedOffsetSearch = false;

#region Mission Updates
        // For some reason `Action` won't accept empty returns :/
        vars.doMissionUpdate = (Func<object>)(() => {
            vars.newMissions.Clear();

            // If we haven't found all offsets yet, we won't be able to do any more
            if (!finishedOffsetSearch || !vars.hasWatcher("playthrough")) {
                return;
            }

            // If we have an invalid playthrough index, use playthrough 0 so the pointer doesn't
            //  go out of bounds
            // When there's no cached value it's set to -1, we do run into this
            var playthrough = vars.watchers["playthrough"].Current == 1 ? 1 : 0;

            // If playthrough changes we need to update the mission counter pointer
            if (
                !vars.hasWatcher("mission_count") || (
                    vars.watchers["playthrough"].Changed
                    && vars.watchers["playthrough"].Current != -1
                )
            ) {
                /*
                Not using `Remove()` because MemoryWatcherList is not a dict, it's a weird list,
                 where extracting something is O(n) anyway, and throws if it doesn't exist.
                */
                ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == "mission_count");

                var missionCountWatcher = new MemoryWatcher<int>(
                    new DeepPointer(
                        localPlayer,
                        offsets["PlayerController"],
                        offsets["PlayerMissionComponent"],
                        offsets["MissionPlaythroughs"],
                        (
                            offsets["MissionPlaythroughs_ElementSize"] * playthrough
                            + offsets["MissionList"] + ARRAY_COUNT_OFFSET
                        )
                    )
                ){ Name = "mission_count" };

                // The inital update doesn't trigger change events, so manually set it to something
                //  invalid and update again to force it
                missionCountWatcher.Update(game);
                missionCountWatcher.Current = -1;
                missionCountWatcher.Update(game);

                vars.watchers.Add(missionCountWatcher);
            }

            // If the missions pointer/count changes we might have new missions
            if (!vars.watchers["mission_count"].Changed) {
                return;
            }
            print("Missions changed");

            foreach (var data in vars.SPLIT_MISSION_DATA) {
                //                                                              .Setting
                ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == data.Item1);
            }
            ((MemoryWatcherList)vars.watchers).RemoveAll(
                x => x.Name == "Mission_Ep01_ChildrenOfTheVault_C"
            );

            IntPtr missionList;
            new DeepPointer(
                localPlayer,
                offsets["PlayerController"],
                offsets["PlayerMissionComponent"],
                offsets["MissionPlaythroughs"],
                (
                    offsets["MissionPlaythroughs_ElementSize"] * playthrough
                    + offsets["MissionList"] + ARRAY_DATA_OFFSET
                ),
                0 // Dummy so we don't need to call ReadPointer an extra time
            ).DerefOffsets(game, out missionList);

            // Just incase this ever becomes an invalid pointer
            var missionCount = Math.Min(1000, vars.watchers["mission_count"].Current);
            for (var idx = 0; idx < missionCount; idx++) {
                var thisMission = missionList + offsets["MissionList_ElementSize"] * idx;

                var missionName = vars.loadFromGNames(
                    game.ReadValue<int>(
                        game.ReadPointer(thisMission + offsets["MissionClass"])
                        + NAME_OFFSET
                    )
                );
                if (missionName == null) {
                    continue;
                }

                /*
                Dectect new missions - we assume anything with the first objective incomplete is.

                This isn't perfect, but it's relatively simple and works for what we need it to.
                 If we tried tracking what missions we had last update, we'd also need to track what
                 character you've got selected, which also has side cases like deleting your char
                 and making a new one with the same save game id, it just gets messy.

                Picking up a mission or loading into an ungeared save will have the first objective
                 incomplete, so will get picked up by this, while it won't pick up loading into a
                 save where you've already finished the dlc for the first time.
                The only side case is loading a save where you picked up one of the missions we
                 auto start on for the first time, but didn't complete anything.
                There's no real way to tell the difference between this and loading an ungeared save
                 though, and you can always just switch the setting off if it becomes a problem.
                */
                var firstObjective = game.ReadValue<int>(
                    game.ReadPointer(
                        thisMission + offsets["ObjectivesProgress"] + ARRAY_DATA_OFFSET
                    ) + offsets["ObjectivesProgress_ElementSize"] * 0
                );
                if (firstObjective != 0) {
                    continue;
                }

                print("Picked up new mission " + missionName);
                vars.newMissions.Add(missionName);

                if (missionName == "Mission_Ep01_ChildrenOfTheVault_C") {
                    // Watch the 5th objective specifically
                    vars.watchers.Add(new MemoryWatcher<int>(
                        new DeepPointer(
                            localPlayer,
                            offsets["PlayerController"],
                            offsets["PlayerMissionComponent"],
                            offsets["MissionPlaythroughs"],
                            (
                                offsets["MissionPlaythroughs_ElementSize"] * playthrough
                                + offsets["MissionList"] + ARRAY_DATA_OFFSET
                            ),
                            (
                                offsets["MissionList_ElementSize"] * idx
                                + offsets["ObjectivesProgress"] + ARRAY_DATA_OFFSET
                            ),
                            offsets["ObjectivesProgress_ElementSize"] * (5 - 1)
                        )
                    ){ Name = "start_echo" });

                    print("Found starting echo objective");
                } else {
                    // bleh
                    var data = (
                        (List<Tuple<string, string, string, TimeSpan>>)vars.SPLIT_MISSION_DATA
                    //                     .Mission
                    ).FirstOrDefault(x => x.Item2 == missionName);

                    if (data != null) {
                        //                    .Setting
                        var settingName = data.Item1;

                        // Watch the active objective set name
                        vars.watchers.Add(new MemoryWatcher<int>(
                            new DeepPointer(
                                localPlayer,
                                offsets["PlayerController"],
                                offsets["PlayerMissionComponent"],
                                offsets["MissionPlaythroughs"],
                                (
                                    offsets["MissionPlaythroughs_ElementSize"] * playthrough
                                    + offsets["MissionList"] + ARRAY_DATA_OFFSET
                                ),
                                (
                                    offsets["MissionList_ElementSize"] * idx
                                    + offsets["ActiveObjectiveSet"]
                                ),
                                NAME_OFFSET
                            )
                        ){ Name = settingName });
                        print("Found " + settingName + " objective set");
                    }
                }
            }
            return;
        });
#endregion

#region Offset Searching
        vars.cts = new CancellationTokenSource();
        System.Threading.Tasks.Task.Run((Func<System.Threading.Tasks.Task<object>>)(async () => {
            try {
                var findPropertyOffset = (Func<IntPtr, string, IntPtr>)((cls, name) => {
                    for (
                        ;
                        cls != IntPtr.Zero;
                        cls = game.ReadPointer(cls + SUPERFIELD_OFFSET)
                    ) {
                        // Don't want to check too much, only here is probably a good middle ground
                        vars.cts.Token.ThrowIfCancellationRequested();

                        for (
                            IntPtr prop = game.ReadPointer(cls + CHILDREN_OFFSET);
                            prop != IntPtr.Zero;
                            prop = game.ReadPointer(prop + NEXT_OFFSET)
                        ) {
                            var propName = vars.loadFromGNames(
                                game.ReadValue<int>(prop + NAME_OFFSET)
                            );
                            if (propName == name) {
                                var offset = game.ReadValue<int>(prop + OFFSET_INTERNAL_OFFSET);
                                print(
                                    "Found property '"
                                    + name
                                    + "' at offset 0x"
                                    + offset.ToString("X")
                                );

                                offsets[name] = offset;
                                return prop;
                            }
                        }
                    }

                    print("Couldn't find property '" + name + "'!");
                    return IntPtr.Zero;
                });

                var waitForPointer = (Func<DeepPointer, System.Threading.Tasks.Task<IntPtr>>)(
                    async (deepPtr) => {
                        IntPtr dest;
                        while (true) {
                            // Avoid a weird ToC/ToU that no one else seems to run into
                            try {
                                if (deepPtr.DerefOffsets(game, out dest)) {
                                    return game.ReadPointer(dest);
                                }
                            } catch (ArgumentException) { continue; }

                            await System.Threading.Tasks.Task.Delay(
                                500, vars.cts.Token
                            ).ConfigureAwait(true);
                            vars.cts.Token.ThrowIfCancellationRequested();
                        }
                    }
                );

                // This isn't populated right on game launch, need to wait a little
                print("Waiting for local player class");
                var localPlayerClass = await waitForPointer(new DeepPointer(
                    localPlayer,
                    CLASS_OFFSET
                ));

                var pcProperty = findPropertyOffset(localPlayerClass, "PlayerController");
                if (pcProperty == IntPtr.Zero) {
                    return;
                }

                /*
                Unfortuantly, the `PropertyClass` field on the `PlayerController` property points to
                 the base `PlayerController` class, when we need a field on `OakPlayerController`
                 (which every instance actually put into this slot will be a subclass of).
                */

                print("Waiting for player controller class");
                var pcClass = await waitForPointer(new DeepPointer(
                    localPlayer,
                    offsets["PlayerController"],
                    CLASS_OFFSET
                ));

                print("Found player controller class, continuing to other offsets");

                // We can miss these two, doesn't really matter
                findPropertyOffset(pcClass, "TimePlayedSeconds");
                findPropertyOffset(pcClass, "TimePlayedSecondsLoadedFromSaveGame");

                // Going to assume that if we can find the property, it's fields are valid

                var missionComponentProperty = findPropertyOffset(
                    pcClass, "PlayerMissionComponent"
                );
                if (missionComponentProperty == IntPtr.Zero) {
                    return;
                }
                var missionComponentClass = game.ReadPointer(
                    missionComponentProperty + PROPERTY_CLASS_OFFSET
                );

                if (
                    findPropertyOffset(
                        missionComponentClass, "CachedPlaythroughIndex"
                    ) == IntPtr.Zero
                ) {
                    return;
                };

                var playthroughsProperty = findPropertyOffset(
                    missionComponentClass, "MissionPlaythroughs"
                );
                if (playthroughsProperty == IntPtr.Zero) {
                    return;
                }
                var playthroughsInnerProperty = game.ReadPointer(
                    playthroughsProperty + INNER_PROPERTY_OFFSET
                );
                offsets["MissionPlaythroughs_ElementSize"] = game.ReadValue<int>(
                    playthroughsInnerProperty + ELEMENT_SIZE_OFFSET
                );

                var missionListProperty = findPropertyOffset(
                    game.ReadPointer(playthroughsInnerProperty + PROPERTY_STRUCT_OFFSET),
                    "MissionList"
                );
                if (missionListProperty == IntPtr.Zero) {
                    return;
                }
                var missionListInnerProperty = game.ReadPointer(
                    missionListProperty + INNER_PROPERTY_OFFSET
                );
                offsets["MissionList_ElementSize"] = game.ReadValue<int>(
                    missionListInnerProperty + ELEMENT_SIZE_OFFSET
                );

                var missionEntryStruct = game.ReadPointer(
                    missionListInnerProperty + PROPERTY_STRUCT_OFFSET
                );

                if (findPropertyOffset(missionEntryStruct, "MissionClass") == IntPtr.Zero) {
                    return;
                }
                if (findPropertyOffset(missionEntryStruct, "ActiveObjectiveSet") == IntPtr.Zero) {
                    return;
                }

                var objectivesProgressProperty = findPropertyOffset(
                    missionEntryStruct, "ObjectivesProgress"
                );
                if (objectivesProgressProperty == IntPtr.Zero) {
                    return;
                }
                var objectivesProgressInnerProperty = game.ReadPointer(
                    objectivesProgressProperty + INNER_PROPERTY_OFFSET
                );

                offsets["ObjectivesProgress_ElementSize"] = game.ReadValue<int>(
                    objectivesProgressInnerProperty + ELEMENT_SIZE_OFFSET
                );

                vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                    localPlayer,
                    offsets["PlayerController"],
                    offsets["PlayerMissionComponent"],
                    offsets["CachedPlaythroughIndex"]
                )){ Name = "playthrough" });

                vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                    localPlayer,
                    offsets["PlayerController"],
                    offsets["TimePlayedSeconds"]
                )){ Name = "char_time" });

                vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                    localPlayer,
                    offsets["PlayerController"],
                    offsets["TimePlayedSecondsLoadedFromSaveGame"]
                )){ Name = "char_time_save" });

                finishedOffsetSearch = true;
                print("Found all offsets");

            } catch (Exception ex) {
                print("Exception in Task: " + ex.ToString());
            }
            return;
        }), vars.cts.Token);
#endregion
    }
}

exit {
    vars.cts.Cancel();
    vars.unknownVersionTimeout = DateTime.MaxValue;
    timer.IsGameTimePaused = true;
}

update {
    vars.watchers.UpdateAll(game);

    if (vars.doMissionUpdate != null) {
        vars.doMissionUpdate();
    }

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

    // Similarly, if we know the world, only start in Sanctuary
    if (vars.currentWorld == null || vars.currentWorld == "Sanctuary3_P") {
        foreach (var data in vars.START_MISSION_DATA) {
            if (settings[data.Value] && vars.newMissions.Contains(data.Key)) {
                print("Starting due to picking up mission " + data.Key.ToString());
                return true;
            }
        }
    }

    return false;
}

isLoading {
    if (settings["use_char_time"]) {
        return true;
    }

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

gameTime {
    if (!settings["use_char_time"]) {
        return null;
    }

    var totalTime = 0;
    if (vars.hasWatcher("char_time")) {
        totalTime += vars.watchers["char_time"].Current;
    }
    if (vars.hasWatcher("char_time_save")) {
        totalTime += vars.watchers["char_time_save"].Current;
    }
    return totalTime <= 0 ? (TimeSpan?)null : TimeSpan.FromSeconds(totalTime);
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
        if (
            // Don't split on the first load into the game
            last != null
            // Don't split if we're on the last split and the setting is enabled
            && !(
                timer.CurrentSplitIndex == timer.Run.Count - 1
                && settings["split_levels_dont_end"]
            )
        ) {
            return true;
        }
    }
#endregion

#region Ending Cutscenes
    if (vars.hasWatcher("playthrough") && vars.watchers["playthrough"].Old != -1) {
        foreach (var data in vars.SPLIT_MISSION_DATA) {
            var setting = data.Item1;
            if (!vars.hasWatcher(setting) || !settings[setting]) {
                continue;
            }

            var objectiveSet = data.Item3;
            var delay = data.Item4;
            var watcher = vars.watchers[setting];

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
