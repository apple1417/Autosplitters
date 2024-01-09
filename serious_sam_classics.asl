/*
  Serious Engine 1 has public source code, and some parts of the game ship with symbols, both of
   which help a lot when working on this.
  https://github.com/Croteam-official/Serious-Engine

  Despite this, the three games, and the gog versions, all use slightly different code (all
   different from the source too), which does mean some of the pointer offsets and sigscans need to
   change between them, but once we've found the pointers everything works the same
*/

state("DedicatedServer") {}
state("DedicatedServer_Custom") {}
state("DedicatedServerGameSpy") {}
state("SeriousSam") {}
state("SeriousSam_Custom") {}
state("SeriousSamGamespy") {}

startup {
    settings.Add("start_no_auto", false, "Don't guess start trigger");
    settings.Add("start_level", false, "Start on level load", "start_no_auto");
    settings.Add("start_netricsa", false, "Start on exiting Netricsa", "start_no_auto");
    settings.Add("split_level", true, "Split on finishing level");
    settings.Add("split_secret", false, "Split on collecting secrets (host only)");
}

init {
    vars.foundPointers = false;
    vars.isDedicated = game.ProcessName.StartsWith("DedicatedServer");

    var exe = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();

    var exeScanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var engineScanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.allPointers = new List<MemoryWatcher>();
    var ptr = IntPtr.Zero;

    /*
      Try extract the version information to work out the game
      TFE and TSE use a major and minor version that's just a define, Rev uses a string
    */
    ptr = engineScanner.Scan(new SigScanTarget(6,
        "E8 ????????",                  // call Engine.CON_GetBufferSize+480
        "6A ??",                        // push 07                          <--- Minor Version
        "68 ????????",                  // push 00002710                    <--- Major Version
        "6A 04",                        // push 04
        "68 ????????"                   // push Engine._ulEngineBuildMinor+118
    ));
    if (ptr != IntPtr.Zero) {
        byte minor = game.ReadValue<byte>(ptr);
        int major = game.ReadValue<int>(IntPtr.Add(ptr, 2));

        if (major == 10000 && minor == 5) {
            version = "TFE";
        } else if (major == 10000 && minor == 7) {
            version = "TSE";
        } else {
            print("Unknown version: " + major.ToString() + "." + minor.ToString());
            version = "Unknown";
            return false;
        }
    } else {
        // If we didn't find the last sigscan then assume it's revolution, and double check
        ptr = engineScanner.Scan(new SigScanTarget(2,
            "FF 35 ????????",           // push [Engine._SE_VER_STRING]
            "8D 85 30FFFFFF"            // lea eax,[ebp-000000D0]
        ));
        if (ptr == IntPtr.Zero) {
            // Try old version pointer
            ptr = engineScanner.Scan(new SigScanTarget(2,
                "8B 15 ????????",           // mov edx,[Engine._SE_VER_STRING] { (60E53D0C) }
                "8B 00",                    // mov eax,[eax]
                "51",                       // push ecx
                "52"                        // push edx
            ));
        }

        if (ptr == IntPtr.Zero) {
            print("Could not find pointers to determine version!");
            version = "Error";
            return false;
        }

        string versionStr = game.ReadString(
            new IntPtr(game.ReadValue<int>(new IntPtr(game.ReadValue<int>(ptr)))),
            16
        );

        if (versionStr == "AP_3381") {
            version = "Revolution";
        } else {
            print("Unknown version " + versionStr);
            version = "Unknown";
            return false;
        }
    }

    if (version == "Error" || version == "Unknown") {
        return false;
    }

    var baseGame = version;
    var isSteamVersion = true;
    var isClassicsPatch = false;

    if (vars.isDedicated) {
        version = "Dedicated " + version;
    }
    // The steam TFE/TSE versions ship with some 64-bit exes that GOG doesn't have (and renames the
    //  32-bit ones), which we can use to tell them apart.
    if (!File.Exists(Path.GetDirectoryName(exe.FileName) + "\\SeriousModeler32.exe")) {
        version += " GOG";
        isSteamVersion = false;
    }
    if (exe.ModuleName.EndsWith("Gamespy.exe")) {
        version += " GameSpy";
        isSteamVersion = false;
    }
    if (exe.ModuleName.EndsWith("_Custom.exe")) {
        version += " Classics Patch";
        isSteamVersion = false;
        isClassicsPatch = true;
    }

    // Find all the pointers we need

    /*
      Find _pGame.gm_csComputerState through DoGame() in SeriousSam.cpp
      This actually has multiple different matches, but they'll all give us the right pointer
    */
    if (baseGame == "Revolution") {
        ptr = exeScanner.Scan(new SigScanTarget(14,
            "83 C4 04",                 // add esp,04
            "83 3D ???????? 00",        // cmp dword ptr [SeriousSam.exe+8AC54],00
            "74 ??",                    // je SeriousSam.exe+5D173
            "8B 0D ????????",           // mov ecx,[SeriousSam.exe+9BA20]   <--- _pGame
            "8B 01"                     // mov eax,[ecx]
        ));
    } else if (isClassicsPatch) {
        ptr = exeScanner.Scan(new SigScanTarget(2,
            "8B 15 ????????",       // mov edx, [SeriousSam_Custom.exe+41080]   <--- _pGame
            "8B 0A",                // mov ecx, [edx]
            "8B 01",                // mov eax, [ecx]
            "FF 50 ??",             // call dword ptr [eax+60]
            "89 1D ????????"        // mov [SeriousSam_Custom.exe+54784], ebx
        ));
    } else if (isSteamVersion) {
        ptr = exeScanner.Scan(new SigScanTarget(13,
            "83 C4 04",             // add esp,04
            "83 3D ???????? 00",    // cmp dword ptr [SeriousSam.exe+9896C],00
            "74 ??",                // je SeriousSam.exe+346FC
            "A1 ????????",          // mov eax,[SeriousSam.exe+98D4C]   <--- _pGame
            "8B 10"                 // mov edx,[eax]
        ));
    } else {
        ptr = exeScanner.Scan(new SigScanTarget(17,
            "83 c4 04",             // add esp,0x4
            "39 1d ????????",       // cmp DWORD PTR ds:0x442bf4,ebx
            "0f 84 ????????",       // je 0x4d85
            "8b 0d ????????",       // mov ecx,DWORD PTR ds:0x442fc4    <--- _pGame
            "8b 11"                 // mov edx,DWORD PTR [ecx]
        ));
    }
    if (ptr == IntPtr.Zero && !vars.isDedicated) {
        print("Could not find pointer to _pGame.gm_csComputerState!");
        version = "Error";
        return false;
    } else if (isClassicsPatch) {
        vars.computerState = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
            0x0, 0x8
        ));
        vars.allPointers.Add(vars.computerState);
    } else {
        vars.computerState = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
            (baseGame == "Revolution") ? 0xC : 0x8
        ));
        vars.allPointers.Add(vars.computerState);
    }

    /*
      This matches part of a conditional in the static method StartMenus() in Menu.cpp as follows:
        `pgmCurrentMenu == &_pGUIM->gmMainMenu`
      As it happens this is the exact check we want to replicate to check resets, so we can
       extract both addresses at once
      We only care about the main menu address, not actually it's contents, so we just save that
    */
    if (baseGame == "Revolution") {
        ptr = exeScanner.Scan(new SigScanTarget(1,
            "A1 ????????",              // mov eax,[SeriousSam.exe+8AC58]   <--- pgmCurrentMenu
            "83 C4 04",                 // add esp,04
            "3D ????????"               // cmp eax,SeriousSam.exe+952D0     <--- &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 8);
    } else if (isClassicsPatch) {
        ptr = exeScanner.Scan(new SigScanTarget(7,
            "8B 15 ????????",           // mov edx, [SeriousSam_Custom.exe+547D0]   <--- _pGUIM
            "A1 ????????",              // mov eax, [SeriousSam_Custom.exe+547B0]   <--- pgmCurrentMenu
            "8B 35 ????????",           // mov esi, [SeriousSam_Custom.exe+54784]
            "83 C4 04",                 // add esp, 04
            "8D 8A ????????"            // lea ecx, [edx+00000200]                  <--- &x->gmMainMenu
        ));
        var _pGUIM = game.ReadPointer(ptr - 5);
        var offset = game.ReadValue<int>(ptr + 15);
        vars.mainMenu = game.ReadValue<int>(_pGUIM) + offset;
    } else if (isSteamVersion) {
        ptr = exeScanner.Scan(new SigScanTarget(5,
            // Technically this matches something in engine too, but we're using the exe scanner :)
            "83 C4 04",                 // add esp,04
            "81 3D ???????? ????????"   // cmp [SeriousSam.exe+989A4],SeriousSam.exe+94490
                                        //         pgmCurrentMenu      &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 4);
    } else {
        ptr = exeScanner.Scan(new SigScanTarget(1,
            "a1 ????????",              // mov eax, ds:0x442c2c             <--- pgmCurrentMenu
            "8b 0d ????????",           // mov ecx, DWORD PTR ds:0x442bf4
            "83 c4 04",                 // add esp, 0x4
            "3d ????????"               // cmp eax, 0x43e718                <--- &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 14);
    }
    if (ptr == IntPtr.Zero && !vars.isDedicated) {
        print("Could not find menu pointers!");
        version = "Error";
        return false;
    } else {
        vars.currentMenu = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) - (int)exe.BaseAddress
        ));
        vars.allPointers.Add(vars.currentMenu);
    }

    /*
      Finding CSoundLibrary._bMuted through Engine.SoundLibrary::Mute
      While it sounds iffy, you can search through to source to find out that in practice this only
       ever mutes loading screens, if you set your volume to 0 it will still be false.
    */
    if (baseGame == "Revolution") {
        ptr = engineScanner.Scan(new SigScanTarget(5,
            "FF 77 40",                 // push [edi+40]
            "C7 05 ???????? 01000000"   // mov [Engine._pSound+1C],00000001
            // push edi
        ));
        if (ptr == IntPtr.Zero) {
            // Try old version pointer
            ptr = engineScanner.Scan(new SigScanTarget(9,
                "C7 45 FC 00000000",        // mov [ebp-04],00000000
                "C7 05 ???????? 01000000",  // mov [Engine._pSound+1C],00000001
                "E8 ????????",              // call Engine.CSoundData::Read_t+13E0
                "83 C4 08"                  // add esp,08
            ));
        }
    } else {
        ptr = engineScanner.Scan(new SigScanTarget(2,
            // call Engine.CTSingleLock::CTSingleLock
            "C7 05 ???????? 01000000",  // mov [Engine._pSound+1C],00000001
            "8B 46 1C"                  // mov eax,[esi+1C]
        ));
    }
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to CSoundLibrary._bMuted!");
        version = "Error";
        return false;
    }
    vars.isMuted = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress
    ));
    vars.allPointers.Add(vars.isMuted);

    /*
      Finding Engine._pNetwork through Engine.CSoundLibrary::MixSounds
      In Revolution this has another match in Engine.CWorld::CreateEntity, but it just changes the
       function call, it still gets us the right pointer
    */
    ptr = engineScanner.Scan(new SigScanTarget(2,
        "8B 0D ????????",           // mov ecx,[Engine._pNetwork]
        "83 C4 08",                 // add esp,08
        "E8 ????????",              // call Engine.CNetworkLibrary::IsPaused
        "85 C0"                     // test eax,eax
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to Engine._pNetwork!");
        version = "Error";
        return false;
    }
    var _pNetwork = game.ReadValue<int>(ptr) - (int)exe.BaseAddress;

    /*
      All these can use the same base address - see one of the following CE structs
      TFE/TSE: https://gist.github.com/apple1417/b4eac1f58b7e96e8f03f724f3f9de603
      Revolution: https://gist.github.com/apple1417/cb95c9dac1bf2f00b5d2afff02d094fb
    */
    vars.gameFinished = new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, 0x20, (baseGame == "Revolution") ? 0xDC : 0xB0
    ));
    vars.playerFlags =  new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, 0x20, 0x4, 0x4, (baseGame == "Revolution") ? 0x3DC : 0x380
    ));
    vars.isSinglePlayer =  new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, (baseGame == "Revolution") ? 0x9D8 : 0x97C
    ));

    var secretOffset = 0;
    switch (baseGame) {
        case "TFE":
            secretOffset = 0x1274;
            break;
        case "TSE":
            secretOffset = 0x25B8;
            break;
        case "Revolution":
            secretOffset = 0x2BB0;
            break;
        default:
            print("Invalid version");
            return false;
    }
    vars.secretCount = new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, 0x20, 0x4, 0x4, secretOffset
    ));
    vars.allPointers.Add(vars.gameFinished);
    vars.allPointers.Add(vars.playerFlags);
    vars.allPointers.Add(vars.isSinglePlayer);
    vars.allPointers.Add(vars.secretCount);

    vars.foundPointers = true;
}

update {
    if (!vars.foundPointers) return false;

    foreach (var ptr in vars.allPointers) {
        ptr.Update(game);
    }
}

start {
    bool useLevel = false;
    bool useNetricsa = false;
    if (settings["start_no_auto"]) {
        useLevel = settings["start_level"];
        useNetricsa = settings["start_netricsa"] && !vars.isDedicated;
    } else {
        // If in coop use level transitions, otherwise use netricsa
        if (vars.isSinglePlayer.Current == 0) {
            useLevel = true;
        } else {
            useNetricsa = true;
        }
    }

    if (useLevel) {
        /*
          This pointer is undefined until the game starts, so it'll return 0
          It is set to 0 by default so even then it won't quite return, but as soon as the player
           entity is initialized it's set to 1
          Conveniently, with wait for all players on, this doesn't happen until everyone's connected
        */
        return vars.playerFlags.Current != 0 && vars.playerFlags.Old == 0;
    } else if (useNetricsa) {
        // This pointer however is always active, check if it goes from CS_TURNINGOFF to CS_OFF
        return vars.computerState.Current == 0 && vars.computerState.Old == 3;
    }
}

split {
    // Checking PLF_CHANGINGLEVEL - won't trigger on loading saves
    if ((vars.playerFlags.Current & 0x40 ) != 0 && (vars.playerFlags.Old & 0x40) == 0) {
        return settings["split_level"];
    }
    // Workaround for the last level in a campaign, which just ends on the stats screen.
    if (vars.gameFinished.Current == 1 && vars.gameFinished.Old == 0) {
        return settings["split_level"];
    }

    // TODO: Player 1 uses +4 +4, Player 2 uses +4 +8C, Player 3 uses +4 +114, etc, 0x88 increments
    if (vars.secretCount.Current > vars.secretCount.Old) {
        return settings["split_secret"];
    }
}

reset {
    if (vars.isDedicated) {
        return false;
    }
    // Reset if you switch to the main menu - won't catch reloading a save but ehh
    return vars.currentMenu.Current == vars.mainMenu && vars.currentMenu.Old != vars.mainMenu;
}

isLoading {
    return vars.isMuted.Current == 1;
}
