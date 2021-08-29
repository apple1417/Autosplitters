state("BorderlandsPreSequel") {}

startup {
    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_vault_key", true, "Interacting with the vault key", "split_header");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_levels_dont_end", true, "Unless doing so would end the run", "split_levels");
    settings.Add("pause_prerendered", false, "Pause for prerendered cutscenes, adding the time back afterwards.");

    vars.watchers = new MemoryWatcherList();

    vars.loadFromGNames = null;
    vars.doMissionUpdate = null;

    vars.blinkCheckTime = DateTime.MaxValue;
    vars.prerenderedStartTime = null;
    vars.lastGameWorld = null;

    vars.resetOnStart = (EventHandler)((e, o) => {
        vars.blinkCheckTime =  DateTime.MaxValue;
        vars.prerenderedStartTime = null;
        vars.lastGameWorld = null;
    });
    timer.OnStart += vars.resetOnStart;
}

shutdown {
    // Being safe in case we failed during startup/init
    if (((IDictionary<string, object>)vars).ContainsKey("resetOnStart")) {
        if (vars.resetOnStart != null) {
            timer.OnStart -= vars.resetOnStart;
        }
    }
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    version = "Error";
    vars.currentWorld = null;

#region Blink
    var blink = modules.Where(
        m => m.ModuleName == "binkw32.dll" || m.ModuleName == "bink2w32.dll"
    ).FirstOrDefault();

    vars.addBlinkPointer = (Action<ProcessModuleWow64Safe>)(blinkModule => {
        if (blinkModule.ModuleName == "binkw32.dll") {
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                blinkModule.BaseAddress + 0x3FDF8
            )){ Name = "prerendered_movie" });
        } else {
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                blinkModule.BaseAddress + 0x4611C
            )){ Name = "prerendered_movie" });
        }
    });

    if (blink == null) {
        print("Couldn't find blink dll for prerendered cutscene pointer!");
        print("Livesplit may have hooked the game too fast, retrying in 10s.");

        vars.blinkCheckTime = DateTime.Now + TimeSpan.FromSeconds(10);
    } else {
        vars.addBlinkPointer(blink);
    }
#endregion

#region Loading
    ptr = scanner.Scan(new SigScanTarget(9,
        "33 C0",            // xor eax,eax
        "8D 8D E0FEFFFF",   // lea ecx,[ebp-00000120]
        "A3 ????????"       // mov [BorderlandsPreSequel.exe+1C6C0D0],eax   <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading pointer 1!");
        return false;
    }
    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    )){ Name = "is_loading_1" });


    ptr = scanner.Scan(new SigScanTarget(2,
        "39 ?? ????????",   // cmp [BorderlandsPreSequel.exe+1B763F8],edi   <---
        "0F85 ????????",    // jne BorderlandsPreSequel.exe+939B67
        "D9E8"              // fld1
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading pointer 2!");
        return false;
    }
    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    )){ Name = "is_loading_2" });
#endregion

#region XP
    ptr = scanner.Scan(new SigScanTarget(2,
        "69 F6 94040000",   // imul esi,esi,00000494
        "81 C6 ????????",   // add esi,BorderlandsPreSequel.exe+1C80A58 <---
        "8B F8"             // mov edi,eax
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find xp pointer!");
        return false;
    }
    // This is actually two ints, level followed by points
    // We only want to check when both are 0 though, so can read as a single long
    vars.watchers.Add(new MemoryWatcher<long>(new DeepPointer(
        // The value's stuck inside a struct a bit
        // The struct is copied to a PlayerSaveGame object at a few points
        game.ReadValue<int>(ptr) - (int)page.BaseAddress + 0xC
    )){ Name = "xp" });
#endregion

#region Cinematic Mode
    ptr = scanner.Scan(new SigScanTarget(6,
        "83 E1 01",         // and ecx,01
        "5F",               // pop edi
        "89 0D ????????"    // mov [BorderlandsPreSequel.exe+1C740C4],ecx   <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find cinematic mode pointer!");
        return false;
    }
    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
        // This is a simpler pointer whose value is just copied from:
        // Engine.GamePlayers[0].Actor.WorldInfo.GRI.MissionTracker.bCinematicMode
        // engine, 0x47C, 0x0, 0x40, 0xE0, 0x330, 0x374, 0x358 (bit 1)
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    )){ Name = "cinematic_mode" });
#endregion

#region GNames
    ptr = scanner.Scan(new SigScanTarget(1,
        "A1 ????????",  // mov eax,[BorderlandsPreSequel.exe+1C05724]   <---
        "8B 0C B0",     // mov ecx,[eax+esi*4]
        "68 00100000",  // push 00001000
        "6A 00"         // push 00
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GNames pointer!");
        return false;
    }
    var GNames = game.ReadValue<int>(ptr) - (int)page.BaseAddress;
    vars.loadFromGNames = (Func<int, string>)(idx => {
        if (idx == 0) {
            // Technically this is wrong, index 0 is valid but is normally "None"
            // Practically, if we have 0 we probably have a bad pointer
            return null;
        }
        return new DeepPointer(GNames, idx * 4, 0x10).DerefString(game, 64);
    });
#endregion

#region Engine
    ptr = scanner.Scan(new SigScanTarget(6,
        "0F2F C2",      // comiss xmm0,xmm2
        "77 ??",        // ja BorderlandsPreSequel.exe+66C2B0
        "A1 ????????"   // mov eax,[BorderlandsPreSequel.exe+156F2E8]   <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find game engine pointer!");
        return false;
    }
    var engine = game.ReadValue<int>(ptr) - (int)page.BaseAddress;

    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
        // Engine.GamePlayers[0].Actor.WorldInfo.StreamingLevels[1].Outer.Outer.Name._index
        engine, 0x47C, 0x0, 0x40, 0xE0, 0x2D4, 0x4, 0x28, 0x28, 0x2C
    )){ Name = "world" });
#endregion

#region Missions
    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
        // Engine.GamePlayers[0].Actor.WorldInfo.GRI.CurrentPlaythroughIndex
        engine, 0x47C, 0x0, 0x40, 0xE0, 0x330, 0x360
    )){ Name = "playthrough" });
    vars.watchers["playthrough"].Update(game);

    var firstLoad = true;

    vars.doMissionUpdate = (Action<bool>)(force => {
        // On the title screen we read 0 missions (i.e. when restarting the game), update on first
        //  load into the game
        if (firstLoad && vars.watchers["world"].Changed) {
            print("Forcing mission change due to first load");
            firstLoad = false;
            force = true;
        }

        var missionsChanged = false;
        if (vars.watchers["playthrough"].Changed || force) {
            missionsChanged = true;

            ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == "mission_count");
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                // Engine.GamePlayers[0].Actor.MissionPlaythroughs[playthrough].MissionList._size
                engine,
                0x47C,
                0x0,
                0x40,
                0x1344,
                0x54 * vars.watchers["playthrough"].Current + 0x4
            )){ Name = "mission_count" });
            vars.watchers["mission_count"].Update(game);
        }
        missionsChanged |= vars.watchers["mission_count"].Changed;

        // If the missions pointer/count changes we might have new missions
        if (missionsChanged) {
            ((MemoryWatcherList)vars.watchers).RemoveAll(x => x.Name == "vault_key");

            // Just incase this ever becomes an invalid pointer
            var missionCount = Math.Min(1000, vars.watchers["mission_count"].Current);
            print("Missions changed - current count " + missionCount.ToString());
            for (var idx = 0; idx < missionCount; idx++) {
                var name = vars.loadFromGNames(new DeepPointer(
                    // Engine.GamePlayers[0].Actor.MissionPlaythroughData[playthrough].MissionList[idx].MissionDefinition.Name._index
                    engine,
                    0x47C,
                    0x0,
                    0x40,
                    0x1344,
                    0x54 * vars.watchers["playthrough"].Current,
                    0x2C * idx,
                    0x2C
                ).Deref<int>(game));

                if (name == "M_DahlDigsite") {
                    print("Found Beginning of the End at index " + idx.ToString());
                    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                        // Engine.GamePlayers[0].Actor.MissionPlaythroughData[playthrough].MissionList[idx].ObjectivesProgress[14]
                        engine,
                        0x47C,
                        0x0,
                        0x40,
                        0x1344,
                        0x54 * vars.watchers["playthrough"].Current,
                        0x2C * idx + 0x8,
                        0x38
                    )){ Name = "vault_key" });
                }
            }
        }
    });

    vars.doMissionUpdate(true);
#endregion

    version = "";
}

update {
    if (version == "Error") {
        return false;
    }

    if (vars.blinkCheckTime < DateTime.Now) {
        vars.blinkCheckTime = DateTime.MaxValue;

        var blink = modules.Where(
            m => m.ModuleName == "binkw32.dll" || m.ModuleName == "bink2w32.dll"
        ).FirstOrDefault();

        if (blink == null) {
            print("Still couldn't find blink dll for prerendered cutscene pointer!");
            version = "Error";
        } else {
            print("Found blink dll");
            vars.addBlinkPointer(blink);
        }
    }

    vars.watchers.UpdateAll(game);
    vars.doMissionUpdate(false);

    if (vars.watchers["world"].Changed || vars.currentWorld == null) {
        var oldWorld = vars.currentWorld;
        vars.currentWorld = vars.loadFromGNames(vars.watchers["world"].Current);

        if (oldWorld != null && vars.currentWorld != null) {
            print("Map changed from " + oldWorld + " to " + vars.currentWorld);
        }
    }
}

start {
    return (
        vars.watchers["xp"].Current == 0
        && vars.watchers["cinematic_mode"].Current == 0
        && vars.watchers["cinematic_mode"].Old == 1
        && vars.currentWorld == "MoonShotIntro_P"
    );
}

isLoading {
    var prerendered = (MemoryWatcher<int>)((MemoryWatcherList)vars.watchers).Where(
        x => x.Name == "prerendered_movie"
    ).FirstOrDefault();
    return (
        vars.watchers["is_loading_1"].Current == 1
        || (
            vars.watchers["is_loading_2"].Current == 0
            && prerendered != null && prerendered.Current == 0
        )
        || vars.currentWorld == "menumap"
        || (
            settings["pause_prerendered"]
            && prerendered != null && prerendered.Current == 1
        )
    );
}

gameTime {
    if (!settings["pause_prerendered"]) {
        return null;
    }

    var prerendered = (MemoryWatcher<int>)((MemoryWatcherList)vars.watchers).Where(
        x => x.Name == "prerendered_movie"
    ).FirstOrDefault();
    if (prerendered == null) {
        return null;
    }

    if (prerendered.Current == 1 && prerendered.Old == 0) {
        vars.prerenderedStartTime = timer.CurrentTime.RealTime.Value.TotalMilliseconds;
    }
    if (prerendered.Current == 0 && prerendered.Old == 1 && vars.prerenderedStartTime != null) {
        var prerenderedTime = timer.CurrentTime.RealTime.Value.TotalMilliseconds - vars.prerenderedStartTime;
        return timer.CurrentTime.GameTime.Value.Add(TimeSpan.FromMilliseconds(prerenderedTime));
    }

    return null;
}

split {
    if (
        settings["split_levels"]
        && vars.currentWorld != null && vars.currentWorld != "menumap"
        && vars.currentWorld != vars.lastGameWorld
        && !(
            timer.CurrentSplitIndex == timer.Run.Count - 1
            && settings["split_levels_dont_end"]
        )
    ) {
        var last = vars.lastGameWorld;
        vars.lastGameWorld = vars.currentWorld;
        // Don't split on the first load into the game
        if (last != null) {
            print("Splitting for level transition");
            return true;
        }
    }

    if (settings["split_vault_key"]) {
        var keyWatcher = (MemoryWatcher<int>)((MemoryWatcherList)vars.watchers).Where(
            x => x.Name == "vault_key"
        ).FirstOrDefault();

        if (
            keyWatcher != null
            && keyWatcher.Current == 1 && keyWatcher.Changed
            && vars.currentWorld == "InnerCore_p"
        ) {
            print("Splitting for vault key");
            return true;
        }
    }
}

exit {
    timer.IsGameTimePaused = true;
}
