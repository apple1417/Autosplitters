state("Talos2-Win64-Shipping") {}

startup {
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_skip_bootup", true, "Skipping the first cutscene in bootup", "start_header");
    settings.Add("start_any_level", false, "Loading into any level", "start_header");

    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", false, "Level transitions", "split_header");
    settings.Add("split_lasers", false, "Activating lasers", "split_header");
    settings.Add("split_puzzles", false, "Solving puzzles", "split_header");
    settings.Add("split_stars", false, "Collecting stars", "split_header");
    settings.Add("split_labs", false, "Visting labs", "split_header");
    settings.Add("split_vtol", false, "VTOL flights", "split_header");

    vars.RE_LOGLINE = new System.Text.RegularExpressions.Regex(@"^\[.+?\]\[.+?\](.+)$");
    vars.RE_ASYNC_TIME_LIMIT = new System.Text.RegularExpressions.Regex(@"s.AsyncLoadingTimeLimit = ""(\d+(.\d+)?)""");

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

    vars.BOOL_VAR_SPLITS = new List<Tuple<string, HashSet<string>>>() {
        new Tuple<string, HashSet<string>>("split_lasers", new HashSet<string>() {
            "E1:TowerActive",
            "E2:TowerActive",
            "E3:TowerActive",
            "N1:TowerActive",
            "N2:TowerActive",
            "N3:TowerActive",
            "S1:TowerActive",
            "S2:TowerActive",
            "S3:TowerActive",
            "W1:TowerActive",
            "W2:TowerActive",
            "W3:TowerActive",
        }),
        new Tuple<string, HashSet<string>>("split_puzzles", new HashSet<string>() {
            "E1:Puzzle0", "E1:Puzzle1", "E1:Puzzle2", "E1:Puzzle3", "E1:Puzzle4", "E1:Puzzle5", "E1:Puzzle6", "E1:Puzzle7", "E1:Puzzle8", "E1:Puzzle9", "E1:Puzzle10",
            "E2:Puzzle0", "E2:Puzzle1", "E2:Puzzle2", "E2:Puzzle3", "E2:Puzzle4", "E2:Puzzle5", "E2:Puzzle6", "E2:Puzzle7", "E2:Puzzle8", "E2:Puzzle9", "E2:Puzzle10",
            "E3:Puzzle0", "E3:Puzzle1", "E3:Puzzle2", "E3:Puzzle3", "E3:Puzzle4", "E3:Puzzle5", "E3:Puzzle6", "E3:Puzzle7", "E3:Puzzle8", "E3:Puzzle9", "E3:Puzzle10",
            "N1:Puzzle0", "N1:Puzzle1", "N1:Puzzle2", "N1:Puzzle3", "N1:Puzzle4", "N1:Puzzle5", "N1:Puzzle6", "N1:Puzzle7", "N1:Puzzle8", "N1:Puzzle9", "N1:Puzzle10",
            "N2:Puzzle0", "N2:Puzzle1", "N2:Puzzle2", "N2:Puzzle3", "N2:Puzzle4", "N2:Puzzle5", "N2:Puzzle6", "N2:Puzzle7", "N2:Puzzle8", "N2:Puzzle9", "N2:Puzzle10",
            "N3:Puzzle0", "N3:Puzzle1", "N3:Puzzle2", "N3:Puzzle3", "N3:Puzzle4", "N3:Puzzle5", "N3:Puzzle6", "N3:Puzzle7", "N3:Puzzle8", "N3:Puzzle9", "N3:Puzzle10",
            "S1:Puzzle0", "S1:Puzzle1", "S1:Puzzle2", "S1:Puzzle3", "S1:Puzzle4", "S1:Puzzle5", "S1:Puzzle6", "S1:Puzzle7", "S1:Puzzle8", "S1:Puzzle9", "S1:Puzzle10",
            "S2:Puzzle0", "S2:Puzzle1", "S2:Puzzle2", "S2:Puzzle3", "S2:Puzzle4", "S2:Puzzle5", "S2:Puzzle6", "S2:Puzzle7", "S2:Puzzle8", "S2:Puzzle9", "S2:Puzzle10",
            "S3:Puzzle0", "S3:Puzzle1", "S3:Puzzle2", "S3:Puzzle3", "S3:Puzzle4", "S3:Puzzle5", "S3:Puzzle6", "S3:Puzzle7", "S3:Puzzle8", "S3:Puzzle9", "S3:Puzzle10",
            "W1:Puzzle0", "W1:Puzzle1", "W1:Puzzle2", "W1:Puzzle3", "W1:Puzzle4", "W1:Puzzle5", "W1:Puzzle6", "W1:Puzzle7", "W1:Puzzle8", "W1:Puzzle9", "W1:Puzzle10",
            "W2:Puzzle0", "W2:Puzzle1", "W2:Puzzle2", "W2:Puzzle3", "W2:Puzzle4", "W2:Puzzle5", "W2:Puzzle6", "W2:Puzzle7", "W2:Puzzle8", "W2:Puzzle9", "W2:Puzzle10",
            "W3:Puzzle0", "W3:Puzzle1", "W3:Puzzle2", "W3:Puzzle3", "W3:Puzzle4", "W3:Puzzle5", "W3:Puzzle6", "W3:Puzzle7", "W3:Puzzle8", "W3:Puzzle9", "W3:Puzzle10",
        }),
        new Tuple<string, HashSet<string>>("split_stars", new HashSet<string>() {
            "PandoraStarPicked_E1",    "PrometheusStarPicked_E1",
            "PandoraStarPicked_E2",    "SphinxStarPicked_E2",
            "PandoraStarPicked_E3",    "SphinxStarPicked_E3",
            "PrometheusStarPicked_N1", "SphinxStarPicked_N1",
            "PrometheusStarPicked_N2", "SphinxStarPicked_N2",
            "PandoraStarPicked_N3",    "PrometheusStarPicked_N3",
            "PandoraStarPicked_S1",    "SphinxStarPicked_S1",
            "PandoraStarPicked_S2",    "PrometheusStarPicked_S2",
            "PandoraStarPicked_S3",    "SphinxStarPicked_S3",
            "PrometheusStarPicked_W1", "SphinxStarPicked_W1",
            "PandoraStarPicked_W2",    "PrometheusStarPicked_W2",
            "PrometheusStarPicked_W3", "SphinxStarPicked_W3",
        }),
        new Tuple<string, HashSet<string>>("split_labs", new HashSet<string>() {
            "E1.LostLab.Completed",
            "E2.LostLab.Completed",
            "E3.LostLab.Completed",
            "N1.LostLab.Completed",
            "N2.LostLab.Completed",
            "N3.LostLab.Completed",
            "S1.LostLab.Completed",
            "S2.LostLab.Completed",
            "S3.LostLab.Completed",
            "W1.LostLab.Completed",
            "W2.LostLab.Completed",
            "W3.LostLab.Completed",
        }),
        new Tuple<string, HashSet<string>>("split_vtol", new HashSet<string>() {
            "FlightCompleted:1b",
            "FlightCompleted:2",
            "FlightCompleted:3",
            "FlightCompleted:4",
            "FlightCompleted:5b",
            "FlightCompleted:6b",
            "FlightCompleted:7",
            "FlightCompleted:8",
            "FlightCompleted:9",
            "FlightCompleted:10b",
        }),
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

#region Save data
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 0D ????????",        // mov rcx, [Talos2-Win64-Shipping.exe+88C2680]                 <---
        "48 89 BC 24 ????????",     // mov [rsp+000000A0], rdi
        "48 85 C9",                 // test rcx, rcx
        "0F84 ????????"             // je Talos2-Win64-Shipping.exe+5193317
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GEngine pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        vars.boolVariablesPtr = new DeepPointer(
            baseAddr, 0xFC0, 0x1C0, 0x28, 0x0, 0xC8, 0x0
        );
        vars.boolVariableCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0xFC0, 0x1C0, 0x28, 0x0, 0xD0
        ));
    }
#endregion

    var logPath = (
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        + "\\Talos2\\Saved\\Logs\\Talos2.log"
    );
    var stream = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    stream.Seek(0, SeekOrigin.End);
    vars.reader = new StreamReader(stream);

    vars.isLoading = false;
}

exit {
    vars.reader.Close();
    vars.reader = null;
}

update {
    vars.gWorldFName.Update(game);
    vars.innerWorldFName.Update(game);
    vars.boolVariableCount.Update(game);

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

                print("Splitting for level transition.");
                vars.TimerModel.Split();
            }

            vars.lastValidWorld = newWorld;
        }

        // World will change to none while in a load, so start on any change away from it
        if (settings["start_any_level"] && vars.currentInnerWorld == "None") {
            print("Starting due to level load");
            vars.TimerModel.Start();
        }

        vars.currentInnerWorld = newWorld;
    }

    if (vars.boolVariableCount.Changed) {
        print(
            "Bool variable count changed from "
            + vars.boolVariableCount.Old.ToString()
            + " to "
            + vars.boolVariableCount.Current.ToString()
        );

        if (vars.boolVariableCount.Current > vars.boolVariableCount.Old) {
            var FSTRING_SIZE = 0x10;

            // Read the entire new block of variables in one go
            var variableBlock = IntPtr.Zero;
            vars.boolVariablesPtr.DerefOffsets(game, out variableBlock);

            IntPtr blockStartAddr = variableBlock + (vars.boolVariableCount.Old * FSTRING_SIZE);
            int blockSize = (vars.boolVariableCount.Current - vars.boolVariableCount.Old) * FSTRING_SIZE;
            var blockData = game.ReadBytes(blockStartAddr, blockSize);

            // Parse out the string from the new block
            var hasAlreadySplit = false;
            for (int i = 0; i < blockSize; i+= FSTRING_SIZE) {
                IntPtr varAddr = new IntPtr(BitConverter.ToInt64(blockData, i));
                int varSize = BitConverter.ToInt32(blockData, i + 8);

                var variable = game.ReadString(varAddr, ReadStringType.UTF16, (varSize - 1) * 2);
                print("  Added: '" + variable + "'");

                // Check if to split on it
                if (hasAlreadySplit) {
                    continue;
                }

                foreach (var entry in vars.BOOL_VAR_SPLITS) {
                    var settingName = entry.Item1;
                    var varsToSplitOn = entry.Item2;

                    if (settings[settingName] && varsToSplitOn.Contains(variable)) {
                        vars.TimerModel.Split();
                        hasAlreadySplit = true;
                        break; // Since we know nothing's in two categories at once
                    }
                }
            }
        }
    }

    while (vars.reader != null) {
        var line = vars.reader.ReadLine();
        if (line == null) {
            break;
        }
        var match = vars.RE_LOGLINE.Match(line);
        if (!match.Success) {
            continue;
        }
        line = match.Groups[1].Value;

        // Handle all log parsing in one place

        if (settings["start_skip_bootup"]
            // Not going to trust the FName index to be constant, but the hash within the name should be
            && line.StartsWith("LogLevelSequence: Starting new camera cut: 'CameraActor_UAID_00FFDAACEB7F9A9001_")
            && vars.currentInnerWorld == "OriginalSim_WP") {
            print("Starting run due to bootup cutscene end");
            vars.TimerModel.Start();
            continue;
        }

        // This line is printed at the very start of a load, breakpointed the exact call that prints
        // to confirm, so we can be confident in it
        // Problem is, it only happens on RCs and going main menu <-> game, not between levels
        if (line.StartsWith("LogLoad: LoadMap: ")) {
            print("Map loaded, starting load");
            vars.isLoading = true;
            continue;
        }

        // Which leads us to this hacky trigger: seems they change the async load time limit during
        // a load
        var asyncMatch = vars.RE_ASYNC_TIME_LIMIT.Match(line);
        if (asyncMatch.Success) {
            // Seen values of 10.0, 15.0 when starting loading, and 0.5 on stop - round to a
            // threshold of 1
            var timeout = Convert.ToDouble(asyncMatch.Groups[1].Value);
            if (timeout > 1.0) {
                print("Increased async loading time limit");
                // Not convinced this is a good starting load trigger, so leaving it out for now
            } else {
                print("Decreased decreased async loading time limit, stopping load");
                vars.isLoading = false;
            }
            continue;
        }

        // This one's a fallback: we'll rarely hit it, but when we do we're definitely in a load,
        // better late than never
        if (line.StartsWith("LogStreaming: Warning: IsTimeLimitExceeded: ProcessAsyncLoadingFromGameThread")) {
            print("Exceeded async load time limit, starting load");
            vars.isLoading = true;
            continue;
        }
    }
}

isLoading {
    return vars.isLoading;
}

// Dummies to add the options back
start { return false; }
split { return false; }