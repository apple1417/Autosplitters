/*
  Serious Engine 1 has public source code, and some parts of the game ship with symbols, both of
   which help a lot when working on this.
  https://github.com/Croteam-official/Serious-Engine

  Despite this, the three games, and the gog versions, all use slightly different code (all
   different from the source too), which does mean some of the pointer offsets and sigscans need to
   change between them, but once we've found the pointers everything works the same
*/

state("SeriousSam") {}

startup {
    settings.Add("start_no_auto", false, "Don't guess start trigger");
    settings.Add("start_level", false, "Start on level load", "start_no_auto");
    settings.Add("start_netricsa", false, "Start on exiting Netricsa", "start_no_auto");
    settings.Add("split_level", true, "Split on finishing level");
    settings.Add("split_secret", false, "Split on collecting secrets (host only)");
}

init {
    vars.foundPointers = false;

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

        /*
          The steam version ships with some 64-bit exes that GOG doesn't have (and renames the
           32-bit ones), which we can use to tell them apart.
          There are also some memory differences but they're hard to find when I only have the steam
           version.
        */
        if (!File.Exists(Path.GetDirectoryName(exe.FileName) + "\\SeriousModeler32.exe")) {
            version += "-GOG";
        }
    } else {
        // If we didn't find the last sigscan then assume it's revolution, and double check
        ptr = engineScanner.Scan(new SigScanTarget(2,
            "FF 35 ????????",           // push [Engine._SE_VER_STRING]
            "8D 85 30FFFFFF"            // lea eax,[ebp-000000D0]
        ));
        if (ptr == IntPtr.Zero) {
            print("Could not find pointers to determine version!");
            version = "Error";
            return false;
        }

        IntPtr versionPtr = new IntPtr(game.ReadValue<int>(new IntPtr(game.ReadValue<int>(ptr))));
        // Technically this is a string, but we'll just check the first few bytes ("AP_3") as an int
        int firstValue = game.ReadValue<int>(versionPtr);
        // ReadValue seems to flip this
        if (firstValue == 0x335F5041) {
            version = "Revolution";
        } else {
            print("Unknown version, starts with " + firstValue.ToString("X"));
            version = "Unknown";
            return false;
        }
    }

    // Find all the pointers we need

    /*
      Find _pGame.gm_csComputerState through DoGame() in SeriousSam.cpp
      This actually has multiple different matches, but they'll all give us the right pointer
    */
    if (version == "TFE" || version == "TSE") {
        ptr = exeScanner.Scan(new SigScanTarget(13,
            "83 C4 04",                 // add esp,04
            "83 3D ???????? 00",        // cmp dword ptr [SeriousSam.exe+9896C],00
            "74 ??",                    // je SeriousSam.exe+346FC
            "A1 ????????",              // mov eax,[SeriousSam.exe+98D4C]   <--- _pGame
            "8B 10"                     // mov edx,[eax]
        ));
    // TODO: TSE GOG is untested
    } else if (version == "TFE-GOG" || version == "TSE-GOG") {
        ptr = exeScanner.Scan(new SigScanTarget(17,
            "83 c4 04",                 // add esp,0x4
            "39 1d ????????",           // cmp DWORD PTR ds:0x442bf4,ebx
            "0f 84 ????????",           // je 0x4d85
            "8b 0d ????????",           // mov ecx,DWORD PTR ds:0x442fc4    <--- _pGame
            "8b 11"                     // mov edx,DWORD PTR [ecx]
        ));
    } else if (version == "Revolution") {
        ptr = exeScanner.Scan(new SigScanTarget(14,
            "83 C4 04",                 // add esp,04
            "83 3D ???????? 00",        // cmp dword ptr [SeriousSam.exe+8AC54],00
            "74 ??",                    // je SeriousSam.exe+5D173
            "8B 0D ????????",           // mov ecx,[SeriousSam.exe+9BA20]   <--- _pGame
            "8B 01"                     // mov eax,[ecx]
        ));
    }
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to _pGame.gm_csComputerState!");
        version = "Error";
        return false;
    }
    vars.computerState = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
        (version == "Revolution") ? 0xC : 0x8
    ));

    vars.allPointers.Add(vars.computerState);

    /*
      This matches part of a conditional in the static method StartMenus() in Menu.cpp as follows:
        `pgmCurrentMenu == &_pGUIM->gmMainMenu`
      As it happens this is the exact check we want to replicate to check resets, so we can
       extract both addresses at once
      We only care about the main menu address, not actually it's contents, so we just save that
    */
    if (version == "Revolution") {
        ptr = exeScanner.Scan(new SigScanTarget(1,
            "A1 ????????",              // mov eax,[SeriousSam.exe+8AC58]   <--- pgmCurrentMenu
            "83 C4 04",                 // add esp,04
            "3D ????????"               // cmp eax,SeriousSam.exe+952D0     <--- &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 8);
    } else if (version == "TFE" || version == "TSE") {
        ptr = exeScanner.Scan(new SigScanTarget(5,
            // Technically this matches something in engine too, but we're using the exe scanner :)
            "83 C4 04",                 // add esp,04
            "81 3D ???????? ????????"   // cmp [SeriousSam.exe+989A4],SeriousSam.exe+94490
                                        //         pgmCurrentMenu      &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 4);
    // TODO: TSE GOG is untested
    } else if (version == "TFE-GOG" || version == "TSE-GOG") {
        ptr = exeScanner.Scan(new SigScanTarget(1,
            "a1 ????????",              // mov eax, ds:0x442c2c             <--- pgmCurrentMenu
            "8b 0d ????????",           // mov ecx, DWORD PTR ds:0x442bf4
            "83 c4 04",                 // add esp, 0x4
            "3d ????????"               // cmp eax, 0x43e718                <--- &_pGUIM->gmMainMenu
        ));
        vars.mainMenu = game.ReadValue<int>(ptr + 14);
    }
    if (ptr == IntPtr.Zero) {
        print("Could not find menu pointers!");
        version = "Error";
        return false;
    }
    vars.currentMenu = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress
    ));

    vars.allPointers.Add(vars.currentMenu);

    /*
      Finding CSoundLibrary._bMuted through Engine.SoundLibrary::Mute
      While it sounds iffy, you can search through to source to find out that in practice this only
       ever mutes loading screens, if you set your volume to 0 it will still be false.
    */
    if (version == "Revolution") {
        ptr = engineScanner.Scan(new SigScanTarget(5,
            "FF 77 40",                 // push [edi+40]
            "C7 05 ???????? 01000000"   // mov [Engine._pSound+1C],00000001
            // push edi
        ));
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
        _pNetwork, 0x20, (version == "Revolution") ? 0xDC : 0xB0
    ));
    vars.playerFlags =  new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, 0x20, 0x4, 0x4, (version == "Revolution") ? 0x3DC : 0x380
    ));
    // TODO: Untested on GOG versions, I'd be suprised if it fails though
    vars.isSinglePlayer =  new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, (version == "Revolution") ? 0x9D8 : 0x97C
    ));

    var secretOffset = 0;
    switch (version) {
        case "TFE":
        case "TFE-GOG": secretOffset = 0x1274; break;
        case "TSE":
        case "TSE-GOG": secretOffset = 0x25B8; break;
        case "Revolution": secretOffset = 0x2BB0; break;
        default: print("Invalid version"); return false;
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
        useNetricsa = settings["start_netricsa"];
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
    // Reset if you switch to the main menu - won't catch reloading a save but ehh
    return vars.currentMenu.Current == vars.mainMenu && vars.currentMenu.Old != vars.mainMenu;
}

isLoading {
    return vars.isMuted.Current == 1;
}
