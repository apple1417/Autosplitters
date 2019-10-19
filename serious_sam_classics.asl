/*
  Serious Engine 1 has public source code, and some parts of the game ship with symbols, both of
   which help a lot when working on this.
  https://github.com/Croteam-official/Serious-Engine
  
  Despite this, the three games all use slightly different code (all different from the source too),
   which does mean some of the pointer offsets need to change between them, but once we've found
   them everything works the same
*/

state("SeriousSam") {}

startup {
    settings.Add("Split on finishing level", true);
    settings.Add("Split on collecting secrets (host only)", false);
}

init {
    vars.foundPointers = false;
    
    var exe = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();
    
    // TODO: This won't survive an update
    if (exe.ModuleMemorySize == 610304) {
        version = "TFE";
    } else if (exe.ModuleMemorySize == 843776) {
        version = "TSE";
    } else if (exe.ModuleMemorySize == 1032192) {
        version = "Revolution";
    } else {
        version = "Unknown";
        return false;
    }
    
    var exeScanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var engineScanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.allPointers = new List<MemoryWatcher>();
    var ptr = IntPtr.Zero;
    
    /*
      This matches part of a conditional in Menu.StartMenus() as follows:
        `pgmCurrentMenu == &_pGUIM->gmMainMenu`
      As it happens this is the exact check we want to replicate to check resets, so we can
       extract both addresses at once
    */
    if (version == "Revolution") {
        ptr = exeScanner.Scan(new SigScanTarget(1,
            "A1 ????????",              // mov eax,[SeriousSam.exe+8AC58]   <--- pgmCurrentMenu
            "83 C4 04",                 // add esp,04
            "3D ????????"               // cmp eax,SeriousSam.exe+952D0     <--- &_pGUIM->gmMainMenu
        ));
    } else {
        ptr = exeScanner.Scan(new SigScanTarget(5,
            // Technically this matches something in engine too, but we're using the exe scanner :)
            "83 C4 04",                 // add esp,04
            "81 3D ???????? ????????"   // cmp [SeriousSam.exe+989A4],SeriousSam.exe+94490
                                        //         pgmCurrentMenu      &_pGUIM->gmMainMenu
        ));
    }
    if (ptr == IntPtr.Zero) {
        print("Could not find menu pointers!");
        return false;
    }
    vars.currentMenu = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress
    ));
    // Only need the address here, don't care about the contents
    vars.mainMenu = game.ReadValue<int>(ptr + ((version == "Revolution") ? 8 : 4));
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
    
    var secretOffset = 0;
    switch (version) {
        case "TFE": secretOffset = 0x1274; break;
        case "TSE": secretOffset = 0x25B8; break;
        case "Revolution": secretOffset = 0x2BB0; break;
        default: print("Invalid version"); return false;
    }
    vars.secretCount = new MemoryWatcher<int>(new DeepPointer(
        _pNetwork, 0x20, 0x4, 0x4, secretOffset
    ));
    vars.allPointers.Add(vars.gameFinished);
    vars.allPointers.Add(vars.playerFlags);
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
    /*
      This pointer is undefined until the game starts, so it'll return 0
      It is set to 0 by default so even then it won't quite return, but as soon as the player entity
       is initialized it's set to 1, and that'll happen soon enough that it's fine for this
    */
    return vars.playerFlags.Current != 0 &&  vars.playerFlags.Old == 0;
}

split {
    // Checking PLF_CHANGINGLEVEL - won't trigger on loading saves
    if ((vars.playerFlags.Current & 0x40 ) != 0 && (vars.playerFlags.Old & 0x40) == 0) {
        return settings["Split on finishing level"];
    }
    // Workaround for the last level in a campaign, which just ends on the stats screen.
    if (vars.gameFinished.Current == 1 && vars.gameFinished.Old == 0) {
        return settings["Split on finishing level"];
    }

    // TODO: Player 1 uses +4 +4, Player 2 uses +4 +8C, Player 3 uses +4 +114, etc, 0x88 increments
    if (vars.secretCount.Current > vars.secretCount.Old) {
        return settings["Split on collecting secrets (host only)"];
    }
}

reset {
    // Reset if you switch to the main menu - won't catch reloading a save but ehh
    return vars.currentMenu.Current == vars.mainMenu && vars.currentMenu.Old != vars.mainMenu;
}

isLoading {
    return vars.isMuted.Current == 1;
}