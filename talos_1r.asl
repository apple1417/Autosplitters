state("Talos1-Win64-Shipping") {}

startup {
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_skip_first_cutscene", true, "Skipping the first cutscene", "start_header");
    settings.Add("start_any_level", false, "Loading into any level", "start_header");
    settings.Add("start_no_cheating", true, "Unless cheats are enabled", "start_header");

    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_hub", true, "Entering Nexus/Hubs", "split_header");
    settings.Add("undo_return_level", true, "Undo on re-entering same world you just left", "split_hub");
    settings.Add("split_levels", false, "Any level transition", "split_header");
    settings.Add("split_arrangers", true, "Solving arrangers", "split_header");
    settings.Add("split_sigils", false, "Collecting sigils/Gehenna bots", "split_header");
    settings.Add("split_final_terminal", true, "Final terminal inputs", "split_header");

    settings.Add("reset_header", true, "Reset on ...");
    settings.Add("reset_main_menu", true, "Returning to the Main Menu", "reset_header");

    vars.RE_LOGLINE = new System.Text.RegularExpressions.Regex(@"^\[.+?\]\[.+?\](.+)$");
    vars.RE_USER_TERMINAL = new System.Text.RegularExpressions.Regex(@"^LogTerminalProcessor: USER: (.+)$");

    vars.HUB_WORLDS = new HashSet<string>() { "Nexus", "DLC_01_Hub", "Bonus_1_Hub" };

    // Since all the cutscenes are hundreds of thousands of units away, start the run when the
    // camera jumps a significant distance in one tick, to the player start coords
    vars.START_CAMERA_JUMP_DATA = new Dictionary<string, Tuple<double, double[]>>() {
        {
            "Cloud_1_01", new Tuple<double, double[]>(
                500000,
                new double[3] { 5585, -2520, 203 }
            )
        }, {
            // Unsurpringly, Gehenna starts in the exact same place
            "DLC_01_Intro", new Tuple<double, double[]>(
                500000,
                new double[3] { 5585, -2520, 203 }
            )
        }, {
            // The ITB cutscene have multiple different scenes at different coords, but they're all
            // this far away
            "Bonus_1_Hub", new Tuple<double, double[]>(
                2500000,
                new double[3] { -896, 8217, 1548 }
            )
        }
    };
    vars.Vect3DDistance = new Func<double[], double[], double>((double[] A, double[] B) => {
        double dx = A[0] - B[0];
        double dy = A[1] - B[1];
        double dz = A[2] - B[2];
        return Math.Sqrt(dx*dx + dy*dy + dz*dz);
    });

    vars.TRANSCENDENCE_ETERNALIZE_ENDING_STRINGS = new HashSet<string>() {
        "/eternalize", // English, French, Japanese, Simplified Chinese, Traditional Chinese
        "/eternare", // Italian
        "/eternizar", // Spanish, Portuguese
        "/prenesi u vječnost", // Croatian
        "/uwiecznienie", // Polish
        "/verewigen", // German
        "/увековечить", // Russian
        "/영생 부여", // Korean

        "/prijeđi", // Croatian
        "/transcend", // English, French, Japanese, Simplified Chinese, Traditional Chinese
        "/transcendencja", // Polish
        "/transcender", // Portuguese
        "/transcendere", // Italian
        "/transzendieren", // German
        "/trascender", // Spanish
        "/переступить", // Russian
        "/초월", // Korean
    };
    vars.GEHENNA_ENDING_STRINGS = new HashSet<string>() {
        "Good luck everyone", // English
        "各位祝你們好運", // Traditional Chinese
        "Bonne chance à tous", // French
        "Viel Glück", // German
        "Suerte a todos.", // Spanish
        "Всем удачи", // Russian
        "Buona fortuna a tutti", // Italian
        "Powodzenia wszystkim", // Polish
        "Hodně štěstí všem", // Czech
        "İyi şanslar millet", // Turkish

        "Remember me", // English
        "不要忘了我", // Traditional Chinese
        "Ne m'oubliez pas", // French
        "Denkt an mich", // German
        "Recuérdame.", // Spanish
        "Помните меня", // Russian
        "Ricordatemi", // Italian
        "Pamiętajcie o mnie", // Polish
        "Pamatujte si na mě", // Czech
        "Beni unutmayın", // Turkish

        "Forgive me", // English
        "原諒我", // Traditional Chinese
        "Pardonnez-moi", // French
        "Vergebt mir", // German
        "Perdóname.", // Spanish
        "Простите меня", // Russian
        "Perdonatemi", // Italian
        "Wybaczcie mi", // Polish
        "Odpusťte mi", // Czech
        "Beni affedin", // Turkish
    };
    vars.ITB_ENDING_STRINGS = new HashSet<string>() {
        "/upload", // English
    };

    vars.TimerModel = new TimerModel(){ CurrentState = timer };
    vars.reader = null;

    // Sometimes things reference this before init and spam errors?
    vars.isLoading = (Func<bool>)(() => false);
}

init {
    var exe = modules.First();
    var scanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var ptr = IntPtr.Zero;

#region GNames
    ptr = scanner.Scan(new SigScanTarget(3,
        "4C 8D 05 ????????",            // lea r8, [Talos1-Win64-Shipping.exe+9BF6240]          <---
        "EB ??",                        // jmp Talos1-Win64-Shipping.exe+12252ED
        "48 8D 0D ????????",            // lea rcx, [Talos1-Win64-Shipping.exe+9BF6240]
        "E8 ????????",                  // call Talos1-Win64-Shipping.exe+1226BB0
        "4C 8B C0",                     // mov r8, rax
        "C6 05 ???????? 01",            // mov byte ptr [Talos1-Win64-Shipping.exe+9BC9EDA], 01
        "8B ??",                        // mov edx, ebx
        "0FB7 C3",                      // movzx eax, bx
        "89 44 24 24"                   // mov [rsp+24], eax
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GNames pointer!");
        version = "ERROR";
        return;
    } else {
        var fNamePool = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        // Pre-cache 0, incase we get given an invalid pointer to read before GNames is initalized
        var gnamesCache = new Dictionary<ulong, string>() {{0, "None"}};
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

#region GWorld
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 05 ????????",            // mov rax, [Talos1-Win64-Shipping.exe+9E326C8]         <---
        "48 85 C0",                     // test rax, rax
        "75 ??",                        // jne Talos1-Win64-Shipping.exe+2E9F27A
        "80 3D ???????? 02"             // cmp byte ptr [Talos1-Win64-Shipping.exe+9E1B028], 02
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GWorld pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        vars.gWorldFName = new MemoryWatcher<ulong>(new DeepPointer(
            baseAddr, 0x18
        ));
    }

    vars.gWorldFName.Update(game);
    vars.currentGWorld = vars.FNameToString(vars.gWorldFName.Current);
    vars.lastNonHubWorld = "dummy";
#endregion

#region GEngine
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 0D ????????",            // mov rcx, [Talos2-Win64-Shipping.exe+88C2680]         <---
        "48 89 BC 24 ????????",         // mov [rsp+000000A0], rdi
        "48 85 C9",                     // test rcx, rcx
        "0F84 ????????"                 // je Talos2-Win64-Shipping.exe+5193317
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GEngine pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        // Can't create a memory watcher to a double[3], will handle it manually
        vars.oldCameraPos = new double[3];
        vars.cameraPosStartPtr = new DeepPointer(
            baseAddr, 0x10A8, 0x38, 0x0, 0x30, 0x370, 0x1C8, 0xF0
        );

        vars.cheatManager = new MemoryWatcher<long>(new DeepPointer(
            baseAddr, 0x10A8, 0x38, 0x0, 0x30, 0x420
        ));

        vars.solvedArrangersCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0x10A8, 0x1D8, 0x28, 0x0, 0x88
        ));
        vars.collectedTetroCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0x10A8, 0x1D8, 0x28, 0x0, 0x2E0
        ));
    }
#endregion

#region Loading
    ptr = scanner.Scan(new SigScanTarget(2,
        "8B 05 ????????",       // mov eax, [Talos1-Win64-Shipping.exe+9C92B54]   <---
        "89 43 ??",             // mov [rbx+64], eax
        "F3 0F10 0D ????????"   // movss xmm1, [Talos1-Win64-Shipping.exe+9974788]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find sync load count pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);
        vars.syncLoadCount = new MemoryWatcher<int>(new DeepPointer(baseAddr));
    }

    // When the syncload count first climbs, we're in the first half of the load. It reaches zero
    // before the load is completely finished however.
    // When loading into any normal level, the rewind manager fires a log line, it clears this flag
    // to set the end. When loading into the main menu, we clear it early, and only use the sync
    // load - whatever extra processing is being done doesn't seem to happen for menu.
    vars.midLoad = false;

    vars.isLoading = (Func<bool>)(() => {
        if (vars.syncLoadCount.Current > 0) {
            if (vars.syncLoadCount.Old == 0) {
                vars.midLoad = true;
            }
            return true;
        }
        return vars.midLoad;
    });
#endregion

    var logPath = (
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        + "\\Talos1\\Saved\\Logs\\Talos1.log"
    );
    var stream = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    stream.Seek(0, SeekOrigin.End);
    vars.reader = new StreamReader(stream);
}

exit {
    if (vars.reader != null) {
        vars.reader.Close();
    }
    vars.reader = null;

    timer.IsGameTimePaused = true;
}

update {
    if (version == "ERROR") {
        return;
    }

    vars.gWorldFName.Update(game);
    vars.cheatManager.Update(game);
    vars.syncLoadCount.Update(game);
    vars.solvedArrangersCount.Update(game);
    vars.collectedTetroCount.Update(game);

    if (vars.gWorldFName.Changed && vars.gWorldFName.Current != 0) {
        var newWorld = vars.FNameToString(vars.gWorldFName.Current);
        print("GWorld changed from '" + vars.currentGWorld + "' to '" + newWorld + "'");

        if (vars.currentGWorld != newWorld) {
            if (newWorld == "MainMenu2") {
                // Clear the load immediately when we're swapping to main menu, always use the sync load
                print("Clearing load due to loading main menu");
                vars.midLoad = false;

                if (settings["reset_main_menu"] && timer.CurrentPhase != TimerPhase.Ended) {
                    print("Resetting due to returning to main menu");
                    vars.TimerModel.Reset();
                }
            }

            bool alreadySplitLevel = false;
            if (settings["split_levels"]) {
                print("Splitting for level transition");
                vars.TimerModel.Split();
                alreadySplitLevel = true;
            }

            if (vars.HUB_WORLDS.Contains(newWorld)) {
                if (settings["split_hub"] && !alreadySplitLevel) {
                    print("Splitting for return to hub");
                    vars.TimerModel.Split();
                }

                vars.lastNonHubWorld = vars.currentGWorld;
            }

            if (
                settings["split_hub"]
                && settings["undo_return_level"]
                && newWorld == vars.lastNonHubWorld
                && vars.HUB_WORLDS.Contains(vars.currentGWorld)
            ) {
                print("Undoing split due to returning to last level");
                vars.TimerModel.UndoSplit();

                // With split on every level transition also on, having gone back will have caused
                // an extra split, undo both
                if (settings["split_levels"]) {
                    vars.TimerModel.UndoSplit();
                }
            }

            if (
                timer.CurrentPhase == TimerPhase.NotRunning
                && settings["start_any_level"]
                && vars.currentGWorld == "MainMenu2"
            ) {
                if (vars.cheatManager.Current == 0 || !settings["start_no_cheating"]) {
                    print("Starting due to level load");
                    vars.TimerModel.Start();
                } else {
                    print("Not starting due to cheats");
                }
            }
        }

        vars.currentGWorld = newWorld;
    }

    if (vars.syncLoadCount.Changed) {
        print(
            "Sync load count changed from "
            + vars.syncLoadCount.Old.ToString()
            + " to "
            + vars.syncLoadCount.Current.ToString()
        );
    }

    if (vars.solvedArrangersCount.Changed) {
        print(
            "Solved arranger count changed from "
            + vars.solvedArrangersCount.Old.ToString()
            + " to "
            + vars.solvedArrangersCount.Current.ToString()
        );

        if (
            settings["split_arrangers"]
            // For now, going with only splitting once if this jumps more
            && vars.solvedArrangersCount.Current > vars.solvedArrangersCount.Old
        ) {
            print("..splitting");
            vars.TimerModel.Split();
        }
    }

    if (vars.collectedTetroCount.Changed) {
        print(
            "Collected tetro count changed from "
            + vars.collectedTetroCount.Old.ToString()
            + " to "
            + vars.collectedTetroCount.Current.ToString()
        );

        if (
            settings["split_sigils"]
            && vars.collectedTetroCount.Current > vars.collectedTetroCount.Old
        ) {
            print("..splitting");
            vars.TimerModel.Split();
        }
    }

    if (
        timer.CurrentPhase == TimerPhase.NotRunning
        && settings["start_skip_first_cutscene"]
        && vars.START_CAMERA_JUMP_DATA.ContainsKey(vars.currentGWorld)
    ) {
        var newCameraPosBytes = vars.cameraPosStartPtr.DerefBytes(game, 24);
        if (newCameraPosBytes != null)
        {
            var cameraJumpData = vars.START_CAMERA_JUMP_DATA[vars.currentGWorld];

            var newCameraPos = new double[3] {
                BitConverter.ToDouble(newCameraPosBytes, 0),
                BitConverter.ToDouble(newCameraPosBytes, 8),
                BitConverter.ToDouble(newCameraPosBytes, 16),
            };

            if (
                // If we've jumped a far enough distance this tick
                vars.Vect3DDistance(vars.oldCameraPos, newCameraPos) > cameraJumpData.Item1
                // And we're now very close to the start coords
                && vars.Vect3DDistance(newCameraPos, cameraJumpData.Item2) < 100
            ) {
                // Assume the cutscene finished, start the run
                if (vars.cheatManager.Current == 0 || !settings["start_no_cheating"]) {
                    if (settings["start_skip_first_cutscene"]) {
                        print("Starting run due to cutscene camera jump");
                        vars.TimerModel.Start();
                    }
                } else {
                    print("Not starting due to cheats");
                }
            }

            vars.oldCameraPos = newCameraPos;
        }
    }

    while (vars.reader != null) {
        // The log file is rotated, but if we're running as the game launches, we might still catch
        // the last one. When the game truncates it, this means we're left reading from an offset
        // far beyond the end of the file.
        // Detect this and reset the stream pos
        if (vars.reader.BaseStream.Position > vars.reader.BaseStream.Length) {
            print("Resetting log stream pos due to truncate");
            vars.reader.DiscardBufferedData();
            vars.reader.BaseStream.Position = 0;
        }

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

        // On loading into any level, we immediately get a LogRewind line, use it to end the load
        if (line.StartsWith("LogRewind") && vars.midLoad) {
            print("Clearing load due to log line: " + line);
            vars.midLoad = false;
        }

        if (settings["split_final_terminal"]) {
            match = vars.RE_USER_TERMINAL.Match(line);
            if (match.Success) {
                var userInput = match.Groups[1].Value;

                if (vars.currentGWorld == "Islands_03") {
                    // Any terminal input in the messenger island is good enough, there isn't one
                    // normally. Collected what all the translated strings are would also be a pain.
                    print("Splitting for messenger ending");
                    vars.TimerModel.Split();
                } else if (
                    vars.currentGWorld == "Nexus"
                    && vars.TRANSCENDENCE_ETERNALIZE_ENDING_STRINGS.Contains(userInput)
                ) {
                    print("Splitting for transcendence/eternalize ending");
                    vars.TimerModel.Split();
                } else if (
                    vars.currentGWorld == "DLC_01_Hub"
                    && vars.GEHENNA_ENDING_STRINGS.Contains(userInput)
                ) {
                    print("Splitting for gehenna ending");
                    vars.TimerModel.Split();
                } else if (
                    vars.currentGWorld == "Bonus_1_Hub"
                    && vars.ITB_ENDING_STRINGS.Contains(userInput)
                ) {
                    print("Splitting for ITB ending");
                    vars.TimerModel.Split();
                }
            }
        }
    }
}

isLoading {
    return vars.isLoading();
}

onStart {
    if (vars.isLoading()) {
        timer.IsGameTimePaused = true;
        timer.SetGameTime(timer.Run.Offset);
    }
}

// Dummies to add the options back
start {;}
split {;}
reset {;}
