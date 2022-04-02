state("Wonderlands") {}

startup {
#region Settings
    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_levels_dont_end", true, "Unless doing so would end the run", "split_levels");
#endregion

    timer.IsGameTimePaused = true;

    vars.watchers = new MemoryWatcherList();
    vars.hasWatcher = (Func<string, bool>)(name => {
        return ((MemoryWatcherList)vars.watchers).Any(x => x.Name == name);
    });

    vars.lastGameWorld = null;

    vars.LOADING_WORLDS = new List<string>() {
        "PreviewSceneWorld",
        "Loader"
    };
}

onStart {
    vars.lastGameWorld = null;
}

init {
    var exe = modules.First();

    var scanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    vars.watchers.Clear();

    vars.loadFromGNames = null;

    vars.currentWorld = null;

#region UE Constants
    // UObject
    const int NAME_OFFSET = 0x18;

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
}

exit {
    timer.IsGameTimePaused = true;
}

update {
    vars.watchers.UpdateAll(game);

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

    return false;
}
