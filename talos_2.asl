state("Talos2-Win64-Shipping") {}

startup {
    settings.Add("start_skip_bootup", true, "Start the run on skipping the first cutscene in bootup.");
    settings.Add("split_levels", true, "Split on level transitions");

    vars.VALID_LEVELS_TO_SPLIT_ON = new HashSet<string>() {
        "OriginalSim_WP",
        "RobotCity_BirthLab_v02", // Note: we blacklist the birthlab -> city transition later
        "RobotCity_WP",           // Need birthlab to split on exiting bootup/mega 4
        "Pyramid_WP",
        "E1_WP",
        "E2_WP",
        "E3_WP",
        "Pyramid_Entrance_E",
        "N1_WP",
        "N2_WP",
        "N3_WP",
        "Pyramid_Entrance_N",
        "S1_WP",
        "S2_WP",
        "S3_WP",
        "Pyramid_Entrance_S",
        "W1_WP",
        "W2_WP",
        "W3_WP",
        "Pyramid_Entrance_W",
    };

    vars.TimerModel = new TimerModel(){ CurrentState = timer };
}

init {
    var exe = modules.First();
    var scanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var ptr = IntPtr.Zero;

#region Unreal Constants
    var UOBJECT_NAME_OFFSET = 0x18;
#endregion

#region GNames
    ptr = scanner.Scan(new SigScanTarget(3,
        "4C 8D 05 ????????",            // lea r8, [Talos2-Win64-Shipping.exe+86C4600]          <---
        "EB ??",                        // jmp Talos2-Win64-Shipping.exe+2B6A7A6
        "48 8D 0D ????????",            // lea rcx, [Talos2-Win64-Shipping.exe+86C4600]
        "E8 ????????",                  // call Talos2-Win64-Shipping.exe+2B666F0
        "4C 8B C0",                     // mov r8, rax
        "C6 05 ???????? 01",            // mov byte ptr [Talos2-Win64-Shipping.exe+86A0A79], 01
        "8B D6"                         // mov edx, esi
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GNames pointer!");
        version = "ERROR";
        return;
    } else {
        var fNamePool = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        var gnamesCache = new Dictionary<ulong, string>();
        vars.FNameToString = (Func<ulong, string>)((fName) => {
            var number       = (fName & 0xFFFFFFFF00000000) >> 0x20;
            var nameLookup   = (fName & 0x00000000FFFFFFFF) >> 0x00;

            string name;
            if (gnamesCache.ContainsKey(nameLookup)) {
                name = gnamesCache[nameLookup];
            } else {
                var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
                var nameIdx  = (fName & 0x000000000000FFFF) >> 0x00;

                var chunk = game.ReadPointer(fNamePool + 0x10 + (int)chunkIdx * 0x8);
                var nameEntry = chunk + (int)nameIdx * 0x2;

                var length = game.ReadValue<short>(nameEntry) >> 6;
                name = game.ReadString(nameEntry + 0x2, length);

                gnamesCache[nameLookup] = name;
            }

            return number == 0 ? name : name + "_" + (number - 1);
        });
    }
#endregion

#region Worlds
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 39 3D ????????",            // cmp [Talos2-Win64-Shipping.exe+88C5E00], rdi         <---
        "75 07",                        // jne Talos2-Win64-Shipping.exe+518C65D
        "48 89 1D ????????",            // mov [Talos2-Win64-Shipping.exe+88C5E00], rbx
        "E8 ????????"                   // call Talos2-Win64-Shipping.exe+51052C0
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GWorld pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);
        vars.gWorldFName = new MemoryWatcher<ulong>(new DeepPointer(
            baseAddr, UOBJECT_NAME_OFFSET
        )){
            FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull
        };
        vars.innerWorldFName = new MemoryWatcher<ulong>(new DeepPointer(
            baseAddr, 0x180, 0x8, 0x20, UOBJECT_NAME_OFFSET
        )){
            FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull
        };
    }

    vars.gWorldFName.Update(game);
    vars.innerWorldFName.Update(game);
    vars.currentGWorld = vars.FNameToString(vars.gWorldFName.Current);
    vars.currentInnerWorld = vars.FNameToString(vars.innerWorldFName.Current);
    print("Inital GWorld: '" + vars.currentGWorld + "'");
    print("Inital inner world: '" + vars.currentInnerWorld + "'");

    vars.lastValidWorld = vars.VALID_LEVELS_TO_SPLIT_ON.Contains(vars.currentInnerWorld)
                            ? vars.currentInnerWorld
                            : null;
#endregion

    var logPath = (
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        + "\\Talos2\\Saved\\Logs\\Talos2.log"
    );
    var stream = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    stream.Seek(0, SeekOrigin.End);
    vars.reader = new StreamReader(stream);
}

exit {
    vars.reader.Close();
    vars.reader = null;
}

update {
    vars.gWorldFName.Update(game);
    vars.innerWorldFName.Update(game);

    if (vars.gWorldFName.Changed) {
        var newWorld = vars.FNameToString(vars.gWorldFName.Current);
        print("GWorld changed from '" + vars.currentGWorld + "' to '" + newWorld + "'");
        vars.currentGWorld = newWorld;
    }

    if (vars.innerWorldFName.Changed) {
        var newWorld = vars.FNameToString(vars.innerWorldFName.Current);
        print("Inner world changed from '" + vars.currentInnerWorld + "' to '" + newWorld + "'");

        // Easier to handle level change splitting here - we need to keep updating last valid world
        // even outside of a run.
        if (vars.VALID_LEVELS_TO_SPLIT_ON.Contains(newWorld)) {
            if (settings.SplitEnabled && settings["split_levels"]
                && vars.lastValidWorld != newWorld
                // Don't split if this is the first transition of the run
                && vars.lastValidWorld != null
                // Blacklist the birthlab -> city transition
                && !(vars.lastValidWorld == "RobotCity_BirthLab_v02" && newWorld == "RobotCity_WP")) {

                vars.TimerModel.Split();
            }

            vars.lastValidWorld = newWorld;
        }

        vars.currentInnerWorld = newWorld;
    }

    while (vars.reader != null) {
        var line = vars.reader.ReadLine();
        if (line == null) {
            break;
        }

        // Handle all log parsing in one place

        if (settings.StartEnabled && settings["start_skip_bootup"]
            && line.EndsWith("LogLevelSequence: Starting new camera cut: 'CameraActor_UAID_00FFDAACEB7F9A9001_1470756327'")
            && vars.currentInnerWorld == "OriginalSim_WP") {
            vars.TimerModel.Start();
        }
    }
}

// Dummies to add the options back
start { return false; }
split { return false; }
