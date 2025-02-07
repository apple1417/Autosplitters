state("Wonderlands") {}

startup {
#region Settings
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_enter_snoring", true, "Loading into Snoring Valley", "start_header");
    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_levels_dont_end", true, "Unless doing so would end the run", "split_levels");
    settings.Add("split_dragon_lord", true, "Killing the Dragon Lord", "split_header");
#endregion

    timer.IsGameTimePaused = true;

    vars.epicProcessTimeout = DateTime.MaxValue;
    vars.cts = new CancellationTokenSource();

    vars.watchers = new MemoryWatcherList();
    vars.hasWatcher = (Func<string, bool>)(name => {
        return ((MemoryWatcherList)vars.watchers).Any(x => x.Name == name);
    });

    vars.delayedSplitTime = TimeSpan.Zero;
    vars.lastGameWorld = null;

    vars.LOADING_WORLDS = new List<string>() {
        "PreviewSceneWorld",
        "Loader"
    };
}

shutdown {
    vars.cts.Cancel();
}

onStart {
    vars.delayedSplitTime = TimeSpan.Zero;
    vars.lastGameWorld = null;
}

init {
    var exe = modules.First();

#region Epic Process Fix
    /*
    Launching the game on Epic first creates a "launcher" process, which starts the actual game, but
     still sticks around. Both processes are called "Wonderlands", but only the second one is valid
     and has the pointers we need.
    Livesplit will hook the last launched processed - so when you launch it after the game, it works
     fine. However, if it's running before launching the game, it hooks onto the launcher while it's
     still the only process, and cause it doesn't quit we get stuck with it.
    To fix this, we use reflection to set the hooked game back to null (it's private), then exit and
     let livesplit try hook again next tick - eventually it will pick the newer, correct, process.
    We'll do this for 30s max, and assume we're actually the game then.

    Launcher process is `<wl>\Wonderlands.exe`
    Actual game is `<wl>\OakGame\Binaries\Win64\Wonderlands.exe`
    */
    if (File.Exists(Path.Combine(
        Path.GetDirectoryName(exe.FileName),
        "OakGame", "Binaries", "Win64", "Wonderlands.exe"
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
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 89 05 ????????",    // mov [Wonderlands.exe+66C2BE8],rax { (1B334CAE0) }    <---
        "0F28 D7"               // movaps xmm2,xmm7
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find current world pointer!");
        version = "ERROR";
        return;
    } else {
        var relPos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, NAME_OFFSET
        )){ Name = "world_name" });
    }
#endregion

#region Loading
    ptr = scanner.Scan(new SigScanTarget(12,
        "80 3D ???????? 00",    // cmp byte ptr [Wonderlands.exe+6677957],00 { (0),0 }
        "75 15",                // jne Wonderlands.exe+205BFA0
        "48 8B 0D ????????",    // mov rcx,[Wonderlands.exe+668DC10] { (050DCA00) }     <----
        "33 D2"                 // xor edx,edx
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading pointer!");
        version = "ERROR";
        return;
    } else {
        var relPos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0xD0
        )){ Name = "is_loading" });
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

            ((MemoryWatcherList)vars.watchers).RemoveAll(
                x => x.Name == "start_enter_snoring" || x.Name == "split_dragon_lord"
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

                if (missionName == "Mission_Plot00_C") {
                    var settingName = "start_enter_snoring";

                    // Watch the 1st objective specifically
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
                            offsets["ObjectivesProgress_ElementSize"] * (1 - 1)
                        )
                    ){ Name = settingName });

                    print("Found " + settingName + " objective");
                } else if (missionName == "Mission_Plot10_C"){
                    var settingName = "split_dragon_lord";

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
    timer.IsGameTimePaused = true;
}

update {
    vars.watchers.UpdateAll(game);

    if (vars.doMissionUpdate != null) {
        vars.doMissionUpdate();
    }

#region World
    if (vars.hasWatcher("world_name") && vars.loadFromGNames != null) {
        var oldWorld = vars.currentWorld;
        vars.currentWorld = vars.loadFromGNames(vars.watchers["world_name"].Current);

        if (
            vars.watchers["world_name"].Changed
            && !vars.LOADING_WORLDS.Contains(oldWorld)
            && !vars.LOADING_WORLDS.Contains(vars.currentWorld)
        ) {
            print("Map changed from " + oldWorld + " to " + vars.currentWorld);
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
        settings["start_enter_snoring"] && vars.hasWatcher("start_enter_snoring")
        // Make sure not to fire when first loading in on a character
        && vars.hasWatcher("playthrough") && vars.watchers["playthrough"].Old != -1
        // If the objective changed to active
        && vars.watchers["start_enter_snoring"].Changed
        && vars.watchers["start_enter_snoring"].Current == 1
        // If we don't have a world pointer ignore this, otherwise only start in Snoring Valley
        && (vars.currentWorld == null || vars.currentWorld == "Tutorial_P")
    ) {
        print("Starting due to entering Snoring Valley echo.");
        return true;
    }
}

isLoading {
    if (
        (vars.hasWatcher("is_loading") && vars.watchers["is_loading"].Current != 0)
        || vars.currentWorld == "MenuMap_P"
    ) {
        // If you start on the main menu sometimes a single tick is counted before pausing, fix it
        if (timer.CurrentAttemptDuration.TotalSeconds < 0.1) {
            timer.SetGameTime(timer.Run.Offset);
        }
        return true;
    }

    return false;
}

split {
#region Level Transitions
    if (
        settings["split_levels"]
        && vars.currentWorld != null
        && vars.currentWorld != "MenuMap_P" && !vars.LOADING_WORLDS.Contains(vars.currentWorld)
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
    if (
        // Make sure not to fire when first loading in on a character
        vars.hasWatcher("playthrough") && vars.watchers["playthrough"].Old != -1
        && vars.hasWatcher("split_dragon_lord") && settings["split_dragon_lord"]
        // If we don't have a world pointer ignore this, otherwise only end in the Fearamid
        && (vars.currentWorld == null || vars.currentWorld == "PyramidBoss_P")
    ) {
        var objectiveSet = "Set_RessurectionCutscene_ObjectiveSet";
        var watcher = vars.watchers["split_dragon_lord"];

        if (watcher.Changed && vars.loadFromGNames(watcher.Current) == objectiveSet) {
            // 0.920 found mostly though experimentation, seems to line up most of the time at 60fps
            // BL3 uses nice round numbers, why'd they have to mess it up for this
            vars.delayedSplitTime = timer.CurrentTime.GameTime + TimeSpan.FromSeconds(0.920);
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
