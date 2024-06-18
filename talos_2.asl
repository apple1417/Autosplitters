state("Talos2-Win64-Shipping") {}

startup {
    settings.Add("start_header", true, "Start the run on ...");
    settings.Add("start_skip_first_cutscene", true, "Skipping the first cutscene", "start_header");
    settings.Add("start_any_level", false, "Loading into any level", "start_header");
    settings.Add("start_no_cheating", true, "Unless cheats are enabled", "start_header");

    settings.Add("split_header", true, "Split on ...");
    settings.Add("split_levels", true, "Level transitions", "split_header");
    settings.Add("split_lasers", false, "Activating towers", "split_header");
    settings.Add("split_puzzles", false, "Solving puzzles", "split_header");
    settings.Add("split_stars", false, "Collecting stars", "split_header");
    settings.Add("split_labs", false, "Visting labs", "split_header");
    settings.Add("split_vtol", false, "VTOL flights", "split_header");
    settings.Add("split_achievements", false, "Achievement triggers", "split_header");
    settings.Add("split_fast_travel", false, "Unlocking DLC Fast Travels", "split_header");
    settings.Add("split_mega_east", false, "Megastructure East lasers", "split_header");
    settings.Add("split_mega_north", false, "Megastructure North lasers", "split_header");
    settings.Add("split_mega_south", false, "Megastructure South pins", "split_header");
    settings.Add("split_cube", false, "Isle of the Blessed Hexahedron", "split_header");
    settings.Add("split_final_cutscene", true, "Triggering the final cutscene", "split_header");

    settings.Add("reset_header", true, "Reset on ...");
    settings.Add("reset_skip_first_cutscene", false, "Skipping the first cutscene", "reset_header");
    settings.Add("reset_main_menu", true, "Returning to the Main Menu", "reset_header");

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
        "Pyramid_Transition_E",
        "N1_WP",
        "N2_WP",
        "N3_WP",
        "Pyramid_Transition_N",
        "S1_WP",
        "S2_WP",
        "S3_WP",
        "Pyramid_Transition_S",
        "W1_WP",
        "W2_WP",
        "W3_WP",
        "Pyramid_Interior_W",
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
            "DLC2.LighthouseGreen:Activated",
            "DLC2.LighthouseRed:Activated",
            "DLC2.LighthouseBlue:Activated",
        }),
        new Tuple<string, HashSet<string>>("split_puzzles", new HashSet<string>() {
            "OriginalSim:Puzzle0", "OriginalSim:Puzzle1", "OriginalSim:Puzzle2", "OriginalSim:Puzzle3",
            "OriginalSim:Puzzle4", "OriginalSim:Puzzle5", "OriginalSim:Puzzle6", "OriginalSim:Puzzle7",
            "OriginalSim:Puzzle8", "OriginalSim:Puzzle9", "OriginalSim:Puzzle10", "OriginalSim:Puzzle11",
            "E1:Puzzle0", "E1:Puzzle1", "E1:Puzzle2", "E1:Puzzle3", "E1:Puzzle4", "E1:Puzzle5",
            "E1:Puzzle6", "E1:Puzzle7", "E1:Puzzle8", "E1:Puzzle9", "E1:Puzzle10",
            "E2:Puzzle0", "E2:Puzzle1", "E2:Puzzle2", "E2:Puzzle3", "E2:Puzzle4", "E2:Puzzle5",
            "E2:Puzzle6", "E2:Puzzle7", "E2:Puzzle8", "E2:Puzzle9", "E2:Puzzle10",
            "E3:Puzzle0", "E3:Puzzle1", "E3:Puzzle2", "E3:Puzzle3", "E3:Puzzle4", "E3:Puzzle5",
            "E3:Puzzle6", "E3:Puzzle7", "E3:Puzzle8", "E3:Puzzle9", "E3:Puzzle10",
            "N1:Puzzle0", "N1:Puzzle1", "N1:Puzzle2", "N1:Puzzle3", "N1:Puzzle4", "N1:Puzzle5",
            "N1:Puzzle6", "N1:Puzzle7", "N1:Puzzle8", "N1:Puzzle9", "N1:Puzzle10",
            "N2:Puzzle0", "N2:Puzzle1", "N2:Puzzle2", "N2:Puzzle3", "N2:Puzzle4", "N2:Puzzle5",
            "N2:Puzzle6", "N2:Puzzle7", "N2:Puzzle8", "N2:Puzzle9", "N2:Puzzle10",
            "N3:Puzzle0", "N3:Puzzle1", "N3:Puzzle2", "N3:Puzzle3", "N3:Puzzle4", "N3:Puzzle5",
            "N3:Puzzle6", "N3:Puzzle7", "N3:Puzzle8", "N3:Puzzle9", "N3:Puzzle10",
            "S1:Puzzle0", "S1:Puzzle1", "S1:Puzzle2", "S1:Puzzle3", "S1:Puzzle4", "S1:Puzzle5",
            "S1:Puzzle6", "S1:Puzzle7", "S1:Puzzle8", "S1:Puzzle9", "S1:Puzzle10",
            "S2:Puzzle0", "S2:Puzzle1", "S2:Puzzle2", "S2:Puzzle3", "S2:Puzzle4", "S2:Puzzle5",
            "S2:Puzzle6", "S2:Puzzle7", "S2:Puzzle8", "S2:Puzzle9", "S2:Puzzle10",
            "S3:Puzzle0", "S3:Puzzle1", "S3:Puzzle2", "S3:Puzzle3", "S3:Puzzle4", "S3:Puzzle5",
            "S3:Puzzle6", "S3:Puzzle7", "S3:Puzzle8", "S3:Puzzle9", "S3:Puzzle10",
            "W1:Puzzle0", "W1:Puzzle1", "W1:Puzzle2", "W1:Puzzle3", "W1:Puzzle4", "W1:Puzzle5",
            "W1:Puzzle6", "W1:Puzzle7", "W1:Puzzle8", "W1:Puzzle9", "W1:Puzzle10",
            "W2:Puzzle0", "W2:Puzzle1", "W2:Puzzle2", "W2:Puzzle3", "W2:Puzzle4", "W2:Puzzle5",
            "W2:Puzzle6", "W2:Puzzle7", "W2:Puzzle8", "W2:Puzzle9", "W2:Puzzle10",
            "W3:Puzzle0", "W3:Puzzle1", "W3:Puzzle2", "W3:Puzzle3", "W3:Puzzle4", "W3:Puzzle5",
            "W3:Puzzle6", "W3:Puzzle7", "W3:Puzzle8", "W3:Puzzle9", "W3:Puzzle10",
            "DLC1:Puzzle0", "DLC1:Puzzle1", "DLC1:Puzzle2", "DLC1:Puzzle3", "DLC1:Puzzle4",
            "DLC1:Puzzle5", "DLC1:Puzzle6", "DLC1:Puzzle7", "DLC1:Puzzle8", "DLC1:Puzzle9",
            "DLC1:Puzzle10", "DLC1:Puzzle11", "DLC1:Puzzle12", "DLC1:Puzzle13", "DLC1:Puzzle14",
            "DLC1:Puzzle15", "DLC1:Puzzle16", "DLC1:Puzzle17", "DLC1:Puzzle18", "DLC1:Puzzle19",
            "DLC2:Puzzle0", "DLC2:Puzzle1", "DLC2:Puzzle2", "DLC2:Puzzle3", "DLC2:Puzzle4",
            "DLC2:Puzzle5", "DLC2:Puzzle6", "DLC2:Puzzle7", "DLC2:Puzzle8", "DLC2:Puzzle9",
            "DLC2:Puzzle10", "DLC2:Puzzle11", "DLC2:Puzzle12", "DLC2:Puzzle13", "DLC2:Puzzle14",
            "DLC2:Puzzle15", "DLC2:Puzzle16", "DLC2:Puzzle17", "DLC2:Puzzle18", "DLC2:Puzzle19",
            "DLC2:Puzzle20", "DLC2:Puzzle21", "DLC2:Puzzle22", "DLC2:Puzzle23", "DLC2:Puzzle24",
            "DLC2:Puzzle25", "DLC2:Puzzle26", "DLC2:Puzzle27", "DLC2:Puzzle28", "DLC2:Puzzle29",
            "DLC3:Puzzle0", "DLC3:Puzzle1", "DLC3:Puzzle2", "DLC3:Puzzle3", "DLC3:Puzzle4",
            "DLC3:Puzzle5", "DLC3:Puzzle6", "DLC3:Puzzle7", "DLC3:Puzzle8", "DLC3:Puzzle9",
            "DLC3:Puzzle10", "DLC3:Puzzle11", "DLC3:Puzzle12", "DLC3:Puzzle13", "DLC3:Puzzle14",
            "DLC3:Puzzle15", "DLC3:Puzzle16", "DLC3:Puzzle17", "DLC3:Puzzle18", "DLC3:Puzzle19",
            "DLC3:Puzzle20", "DLC3:Puzzle21", "DLC3:Puzzle22", "DLC3:Puzzle23",
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
            "PandoraStarPicked_DLC2_GreenCluster", "SphinxStarPicked_DLC2_GreenCluster",
            "PandoraStarPicked_DLC2_RedCluster", "PrometheusStarPicked_DLC2_RedCluster",
            "PrometheusStarPicked_DLC2_BlueCluster", "SphinxStarPicked_DLC2_RedCluster",
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
            "FlightCompleted:11",
        }),
        new Tuple<string, HashSet<string>>("split_mega_east", new HashSet<string>() {
            "General.ME:PuzzleSolved:0",
            "General.ME:PuzzleSolved:1",
            "General.ME:PuzzleSolved:2",
        }),
        new Tuple<string, HashSet<string>>("split_mega_north", new HashSet<string>() {
            "MN:PuzzleSolvedRed",
            "MN:PuzzleSolvedGreen",
            "MN:PuzzleSolvedBlue",
        }),
        new Tuple<string, HashSet<string>>("split_mega_south", new HashSet<string>() {
            "MS:PrometheusChainPin0",
            "MS:PrometheusChainPin1",
            "MS:PrometheusChainPin2",
            "MS:PrometheusChainPin3",
            "MS:PrometheusChainPin4",
            "MS:PrometheusStatueSolved",
        }),
        new Tuple<string, HashSet<string>>("split_fast_travel", new HashSet<string>() {
            "DLC2.FastTravelUnlocked:East",
            "DLC2.FastTravelUnlocked:Landsite",
            "DLC2.FastTravelUnlocked:LighthouseBlue",
            "DLC2.FastTravelUnlocked:LighthouseGreen",
            "DLC2.FastTravelUnlocked:LighthouseRed",
            "DLC2.FastTravelUnlocked:North",
            "DLC2.FastTravelUnlocked:West",
            "DLC3.FastTravelUnlocked:IslandStart",
            "DLC3.FastTravelUnlocked:L1",
            "DLC3.FastTravelUnlocked:L2",
            "DLC3.FastTravelUnlocked:L3",
            "DLC3.FastTravelUnlocked:L4",
            "DLC3.FastTravelUnlocked:M2",
            "DLC3.FastTravelUnlocked:M3",
            "DLC3.FastTravelUnlocked:M4",
            "DLC3.FastTravelUnlocked:R1",
            "DLC3.FastTravelUnlocked:R2",
            "DLC3.FastTravelUnlocked:R3",
            "DLC3.FastTravelUnlocked:R4",
        }),
        new Tuple<string, HashSet<string>>("split_cube", new HashSet<string>() {
            "DLC2.CubeSolved",
        }),
    };

    vars.PLAYER_STATE_NAMES = new List<string>() {
        "Unrestricted",
        "Interacting",
        "InDialogue",
        "VisionTransition",
        "InVision",
        "InPDA",
        "Dead",
        "ShuttingDown",
        "Loading",
        "ResettingGameplay",
        "InVehicle",
        "Cutscene",
        "FirstPersonCutsequence",
        "InElevatorBeam",
        "OnLadder",
        "InWater",
        "Underwater",
        "InOldTerminal",
        "Scanning",
        "Dreaming",
        "NoMovement",
        "Teleporting",
        "InElevator",
        "TetroBridge",
        "PhotoMode",
        "InArranger",
        "InGravityBeam",
        "Benchmarking",
        "OnEnergyBridge",
        "InGravitySwitch",
    };

    // To catch a DLC start we always look for a pair of log messages
    // Main game only needs one, but we can just about fit it into the same structure
    // First line to match (or null for none), second line to match, level
    vars.START_LOG_LINE_DATA = new List<Tuple<System.Text.RegularExpressions.Regex, string, string>>() {
        new Tuple<System.Text.RegularExpressions.Regex, string, string>(
            null,
            "LogLevelSequence: Starting new camera cut: 'None'",
            "OriginalSim_WP"
        ),
        new Tuple<System.Text.RegularExpressions.Regex, string, string>(
            // I trust the hash in the player start to stay the same, but not the FName index, hence
            // using regexes
            new System.Text.RegularExpressions.Regex(
                @"^LogTemp: Object WBP_SkipCutsceneCUI_C_\d+ is not a valid context to retrieve"
                + @" world settings. Using object BP_TalosPlayerStart_C_UAID_50EBF65C1DD049E901"
            ),
            "LogLevelSequence: Starting new camera cut: 'None'",
            "DLC1"
        ),
        new Tuple<System.Text.RegularExpressions.Regex, string, string>(
            new System.Text.RegularExpressions.Regex(
                @"^LogTemp: Object WBP_SkipCutsceneCUI_C_\d+ is not a valid context to retrieve"
                + @" world settings. Using object BP_TalosPlayerStart_C_UAID_50EBF65C1DD010E201"
            ),
            "LogBlueprintUserMessages: [BP_TalosWorldSettings_C] Saving game @BP_TalosPlayerStart_C_UAID_50EBF65C1DD0BDE101",
            "DLC2"
        ),
        new Tuple<System.Text.RegularExpressions.Regex, string, string>(
            new System.Text.RegularExpressions.Regex(
                @"^LogTemp: Object WBP_SkipCutsceneCUI_C_\d+ is not a valid context to retrieve"
                + @" world settings. Using object BP_TalosPlayerStart_C_UAID_50EBF65C1DD050E901"
            ),
            "LogBlueprintUserMessages: [BP_TalosWorldSettings_C] Saving game @BP_TalosPlayerStart_C_UAID_D843AE1E0C3B35DC01",
            "DLC3"
        ),
    };
    vars.inProgressStartLinePairs = new List<bool>() {true, false, false, false};

    vars.TimerModel = new TimerModel(){ CurrentState = timer };
    vars.reader = null;

    // Sometimes things reference this before init and spam errors?
    vars.isLoading = (Func<bool>)(() => false);
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
        ));
    }

    vars.gWorldFName.Update(game);
    vars.currentGWorld = vars.FNameToString(vars.gWorldFName.Current);
#endregion

#region Save data
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

        vars.cheatManager = new MemoryWatcher<long>(new DeepPointer(
            baseAddr, 0xFC0, 0x38, 0x0, 0x30, 0x420
        ));

        ptr = scanner.Scan(new SigScanTarget(3,
            "0FB6 97 ????????",         // movzx edx, byte ptr [rdi+000008E8]                   <---
            "48 8B CB",                 // mov rcx, rbx
            "40 88 B7 ????????",        // mov [rdi+000008E8], sil
            "E8 ????????",              // call Talos2-Win64-Shipping.exe+25C6060
            "0FB6 97 ????????"          // movzx edx, byte ptr [rdi+000008E8]
        ));
        if (ptr == IntPtr.Zero) {
            print("Could not find PlayerState offset!");
            version = "ERROR";
            return;
        }
        vars.playerState = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0xFC0, 0x38, 0x0, 0x30, game.ReadValue<int>(ptr)
        ));

        ptr = scanner.Scan(new SigScanTarget(3,
            "48 8B ?? ????????",        // mov rcx, [rdi+000001D0]                              <---
            "48 85 C9",                 // test rcx, rcx
            "74 ??",                    // je Talos2-Win64-Shipping.exe+25EE729
            "E8 ????????",              // call Talos2-Win64-Shipping.exe+25E45F0
            "48 63 ?? ????????",        // movsxd rax, dword ptr [rbx+000005D0]
            "8D 70 FF"                  // lea esi, [rax-01]
        ));
        if (ptr == IntPtr.Zero) {
            print("Could not find SaveGame offset!");
            version = "ERROR";
            return;
        }
        var saveGameOffset = game.ReadValue<int>(ptr);

        vars.lastPlayedWorld = new StringWatcher(new DeepPointer(
            baseAddr, 0xFC0, saveGameOffset, 0x28, 0x0, 0x48, 0x0
        ), ReadStringType.UTF16, 64);

        vars.boolVariablesPtr = new DeepPointer(
            baseAddr, 0xFC0, saveGameOffset, 0x28, 0x0, 0xC8, 0x0
        );
        vars.boolVariableCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0xFC0, saveGameOffset, 0x28, 0x0, 0xD0
        ));

        vars.utopiaPuzzleCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0xFC0, saveGameOffset, 0x28, 0x0, 0x208
        ));

        vars.achievementCount = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0xFC0, saveGameOffset, 0x60
        ));
    }

    // If we're attaching as the game launches, the pointer will still be invalid
    // Temporarily switch to set zero or null, so that this still clears the inital update flag
    // This ensures we get a changed event once the pointer is actually filled
    vars.lastPlayedWorld.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
    vars.lastPlayedWorld.Update(game);
    vars.lastPlayedWorld.FailAction = MemoryWatcher.ReadFailAction.DontUpdate;

    vars.lastSplittableWorld = vars.VALID_LEVELS_TO_SPLIT_ON.Contains(vars.lastPlayedWorld.Current)
                            ? vars.lastPlayedWorld.Current
                            : null;

#endregion

#region Loading
    ptr = scanner.Scan(new SigScanTarget(18,
        "41 BE 01000000",               // mov r14d, 00000001
        "F0 44 0FC1 35 ????????",       // lock xadd [Talos2-Win64-Shipping.AK::SoundEngine::g_PlayingID], r14d
        "4C 8B 3D ????????"             // mov r15, [Talos2-Win64-Shipping.g_pRegistryMgr+10]   <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading ui offset pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        // This pointer is set to -96f when in a blocking load, and 0 otherwise - assume it's some
        // UI offset. Has worked across multiple people with different resolutions + other settings.
        // Unfortuantly, it does NOT work for "soft loads", where something didn't finish loading in
        // time and it pauses and blurs the screen while waiting on it to catch up

        // Darkid has validated these offsets, though they aren't UObjects or anything we can tell
        // the exact meaning of
        vars.loadingUiOffset = new MemoryWatcher<float>(new DeepPointer(
            baseAddr, 0x98, 0x30, 0xB0, 0x18, 0x8
        )) {
            FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull
        };
    }

    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8D 0D ????????",            // lea rcx, [Talos2-Win64-Shipping.exe+8A87158]         <---
        "E8 ????????",                  // call Talos2-Win64-Shipping.exe+B77000
        "48 8B 05 ????????",            // mov rax, [Talos2-Win64-Shipping.exe+8A87158]         <---
        "48 89 34 ??",                  // mov [rax+rbx*8], rsi
        "0FB6 45 ??"                    // movzx eax, byte ptr [rbp+67]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find streaming setting level pointer!");
        version = "ERROR";
        return;
    } else {
        var baseAddr = IntPtr.Add(ptr, game.ReadValue<int>(ptr) + 4);

        // This points at ULevelHolderSubsystem::CurrentStreamingSettingsLevel
        // 0 = L0_PrioritizeGameplay
        // 1 = L1_GameplayTransition
        // 2 = L2_SleepTransition
        // 3 = L3_CapsuleTransition
        // 4 = L4_NotInteractive

        // Levels 3 and 4 are only set during loading screens (it stays at 0 during capsule dialog)
        // Unfortuantly, while it's perfect for soft loads, during "hard loads" (i.e. RCs), it
        // triggers a bit late, hence needing both flags

        // None of these offsets point at UObjects (except the last), and they haven't been directly
        // validated, but they all appear to work

        // I don't know what exactly this object is, nothing points to UObjects, and they haven't
        // been validated
        // At offset 0x8, there's a TMap of subsystem classes to their instances
        // We look through all the instances until we find the `LevelHolderSubsystem`
        vars.subSystemList = new MemoryWatcher<long>(new DeepPointer(
            baseAddr, 0x20, 0x8
        ));
        vars.numSubSystems = new MemoryWatcher<int>(new DeepPointer(
            baseAddr, 0x20, 0x10
        ));

        bool firstRun = true;
        vars.findStreamingSettingsLevel = (Action)(() => {
            if (firstRun)
            {
                firstRun = false;
            }
            else if (!vars.subSystemList.Changed && !vars.numSubSystems.Changed)
            {
                return /*dummy*/;
            }

            // Little bit of safety in case this becomes an invalid pointer
            var numSubSystems = Math.Min(100, vars.numSubSystems.Current);
            for (var idx = 0; idx < numSubSystems; idx++) {
                var name = game.ReadValue<int>(
                    game.ReadPointer(new IntPtr(vars.subSystemList.Current + 0x18 * idx + 0x8)) + 0x18
                );
                if (vars.FNameToString((ulong)name) == "LevelHolderSubsystem") {
                    // Have not validated this last offset either
                    vars.streamingSettingsLevel = new MemoryWatcher<int>(new DeepPointer(
                        baseAddr, 0x20, 0x8, 0x18 * idx + 0x8, 0x160
                    ));
                }
            }
        });

        vars.subSystemList.Update(game);
        vars.numSubSystems.Update(game);
        vars.findStreamingSettingsLevel();
    }

    vars.isLoading = (Func<bool>)(() => vars.streamingSettingsLevel.Current >= 3
                                        || Math.Abs(vars.loadingUiOffset.Current - -96f) < 0.0001);
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
    vars.playerState.Update(game);
    vars.lastPlayedWorld.Update(game);
    vars.boolVariableCount.Update(game);
    vars.utopiaPuzzleCount.Update(game);
    vars.achievementCount.Update(game);
    vars.loadingUiOffset.Update(game);
    vars.subSystemList.Update(game);
    vars.numSubSystems.Update(game);

    vars.findStreamingSettingsLevel();
    vars.streamingSettingsLevel.Update(game);

    if (vars.gWorldFName.Changed) {
        var newWorld = vars.FNameToString(vars.gWorldFName.Current);
        print("GWorld changed from '" + vars.currentGWorld + "' to '" + newWorld + "'");

        if (settings["reset_main_menu"]
            && newWorld == "MainMenu2"
            && timer.CurrentPhase != TimerPhase.Ended) {
            print("Resetting due to returning to main menu.");
            vars.TimerModel.Reset();
        }

        if (settings["start_any_level"]
            && vars.currentGWorld == "MainMenu2"
            && (newWorld == "Holder"
                // The DLCs don't use the holder world system
                || newWorld == "DLC1" || newWorld == "DLC2" || newWorld == "DLC3")
        ) {
            if (vars.cheatManager.Current == 0 || !settings["start_no_cheating"]) {
                print("Starting due to level load");
                vars.TimerModel.Start();
            } else {
                print("Not starting due to cheats");
            }
        }

        vars.currentGWorld = newWorld;
    }

    if (vars.playerState.Changed) {
        var oldState = vars.playerState.Old < vars.PLAYER_STATE_NAMES.Count
                        ? vars.PLAYER_STATE_NAMES[vars.playerState.Old]
                        : ("Unknown State " + vars.playerState.Old.ToString("X"));
        var newState = vars.playerState.Current < vars.PLAYER_STATE_NAMES.Count
                        ? vars.PLAYER_STATE_NAMES[vars.playerState.Current]
                        : ("Unknown State " + vars.playerState.Current.ToString("X"));
        print("Player state changed from " + oldState + " to " + newState);

        if (settings["split_final_cutscene"]
            && vars.lastPlayedWorld.Current == "AthenaTemple"
            && newState == "Cutscene"
        ) {
            print("Splitting for athena cutscene start");
            vars.TimerModel.Split();
        }
    }

    if (vars.lastPlayedWorld.Changed) {
        print("LastPlayedWorld changed from '" + vars.lastPlayedWorld.Old + "' to '" + vars.lastPlayedWorld.Current + "'");

        if (vars.VALID_LEVELS_TO_SPLIT_ON.Contains(vars.lastPlayedWorld.Current)) {
            if (settings["split_levels"]
                && vars.lastSplittableWorld != vars.lastPlayedWorld.Current
                // Don't split if this is the first transition of the run
                && vars.lastSplittableWorld != null
                // Blacklist the birthlab -> city transition
                && !(vars.lastSplittableWorld == "RobotCity_BirthLab_v02"
                    && vars.lastPlayedWorld.Current == "RobotCity_WP")
                // Blacklist the athena temple -> pyramid reset when you finish the run
                && !(vars.lastSplittableWorld == "Pyramid_Interior_W"
                    && vars.lastPlayedWorld.Current == "Pyramid_WP"
                    && vars.lastPlayedWorld.Old == "AthenaTemple")
            ) {
                print("Splitting for level transition.");
                vars.TimerModel.Split();
            }

            vars.lastSplittableWorld = vars.lastPlayedWorld.Current;
        }
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

                if (variable == "General.GameCompleted"
                    && settings["split_final_cutscene"]
                    && (vars.lastPlayedWorld.Current == "DLC1"
                       || vars.lastPlayedWorld.Current == "DLC2"
                       || vars.lastPlayedWorld.Current == "DLC3")) {
                    print("Splitting for DLC completion");
                    vars.TimerModel.Split();
                    hasAlreadySplit = true;
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

    if (vars.utopiaPuzzleCount.Changed) {
        print(
            "Utopia puzzle count changed from "
            + vars.utopiaPuzzleCount.Old.ToString()
            + " to "
            + vars.utopiaPuzzleCount.Current.ToString()
        );

        if (settings["split_puzzles"] && vars.utopiaPuzzleCount.Current > vars.utopiaPuzzleCount.Old) {
            vars.TimerModel.Split();
        }
    }

    if (vars.achievementCount.Changed) {
        print(
            "Achievement count changed from "
            + vars.achievementCount.Old.ToString()
            + " to "
            + vars.achievementCount.Current.ToString()
        );

        if (settings["split_achievements"] && vars.achievementCount.Current > vars.achievementCount.Old) {
            vars.TimerModel.Split();
        }
    }

    if (vars.loadingUiOffset.Changed) {
        print(
            "Loading flag changed from "
            + vars.loadingUiOffset.Old.ToString()
            + " to "
            + vars.loadingUiOffset.Current.ToString()
        );
    }

    if (vars.streamingSettingsLevel.Changed) {
        print(
            "Streaming setting level changed from "
            + vars.streamingSettingsLevel.Old.ToString()
            + " to "
            + vars.streamingSettingsLevel.Current.ToString()
        );
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

        for (var idx = 0; idx < vars.START_LOG_LINE_DATA.Count; idx++) {
            var firstLine = vars.START_LOG_LINE_DATA[idx].Item1;
            var secondLine = vars.START_LOG_LINE_DATA[idx].Item2;
            var level = vars.START_LOG_LINE_DATA[idx].Item3;

            if (firstLine != null && firstLine.Match(line).Success) {
                vars.inProgressStartLinePairs[idx] = true;
                continue;
            } else if (
                vars.inProgressStartLinePairs[idx]
                && line.StartsWith(secondLine)
                && vars.lastPlayedWorld.Current == level
            ) {
                // Only clear if we actually have a line pair
                if (firstLine != null) {
                    vars.inProgressStartLinePairs[idx] = false;
                }

                if (settings["reset_skip_first_cutscene"] && timer.CurrentPhase != TimerPhase.Ended ) {
                    print("Resetting for " + level + " cutscene restart");
                    vars.TimerModel.Reset();
                }

                if (vars.cheatManager.Current == 0 || !settings["start_no_cheating"]) {
                    if (settings["start_skip_first_cutscene"]) {
                        print("Starting run due to " + level + " cutscene end");
                        vars.TimerModel.Start();
                    }
                } else {
                    print("Not starting due to cheats");
                }

                continue;
            } else if (firstLine != null) {
                vars.inProgressStartLinePairs[idx] = false;
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
        timer.SetGameTime(TimeSpan.Zero);
    }
}

// Dummies to add the options back
start { return false; }
split { return false; }
reset { return false; }
