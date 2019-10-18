/*
  Serious Engine 1 has public source code, as Revolution is based on that code it helps a lot
  Some parts of the game also ship with symbols, which helps even more
  https://github.com/Croteam-official/Serious-Engine
*/

state("SeriousSam") {}

startup {
    settings.Add("Split on finishing level", true);
    settings.Add("Split on collecting secrets (host only)", false);
}

init {
    var exe = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();
    
    var exeScanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);
    var engineScanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.foundPointers = false;
    vars.allPointers = new List<MemoryWatcher>();

    var ptr = IntPtr.Zero;
    ptr = exeScanner.Scan(new SigScanTarget(1,
        /*
          This matches part of a conditional in Menu.StartMenus() as follows:
            `pgmCurrentMenu == &_pGUIM->gmMainMenu`
          As it happens this is the exact check we want to replicate to check resets, so we can
           extract both addresses at once
        */
        "A1 ????????",              // mov eax,[SeriousSam.exe+8AC58]       <--- pgmCurrentMenu
        "83 C4 04",                 // add esp,04 { 4 }
        "3D ????????"               // cmp eax,SeriousSam.exe+952D0         <--- &_pGUIM->gmMainMenu
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find menu pointers!");
        return false;
    }
    vars.currentMenu = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress
    ));
    // Only need the address here, don't care about the contents
    vars.mainMenu = game.ReadValue<int>(ptr + 8);
    vars.allPointers.Add(vars.currentMenu);

    ptr = engineScanner.Scan(new SigScanTarget(5,
        /*
          Finding CSoundLibrary._bMuted through Engine.SoundLibrary::Mute
          While it sounds iffy, you can search through to source to find out that in practice this
           only ever mutes loading screens, if you set your volume to 0 it will still be false.
        */
        "FF 77 40",                 // push [edi+40]
        "C7 05 ???????? 01000000"   // mov [Engine._pSound+1C],00000001     <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to CSoundLibrary._bMuted!");
        return false;
    }
    vars.isMuted = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress
    ));
    vars.allPointers.Add(vars.isMuted);

    ptr = engineScanner.Scan(new SigScanTarget(3,
        // Finding Engine._pNetwork through Engine.CSteam::UpdateSteamLobbyData
        "8B F1",                // mov esi,ecx
        "A1 ????????",          // mov eax,[Engine._pNetwork]               <---
        "85 C0"                 // test eax,eax
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to Engine._pNetwork!");
        return false;
    }
    /*
      All these can use the same base address - see the following CE struct:
      https://gist.github.com/apple1417/cb95c9dac1bf2f00b5d2afff02d094fb
    */
    vars.gameFinished = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
        0x20, 0xDC
    ));
    vars.playerFlags =  new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
        0x20, 0x4, 0x4, 0x3DC
    ));
    vars.secretCount = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)exe.BaseAddress,
        0x20, 0x4, 0x4, 0x2BB0
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
        return settings["Split on finishing level"];;
    }

    // TODO: Player 1 uses +4 +4, Player 2 uses +4 +8C, Player 3 uses +4 +114, etc, 0x88 increments
    if (vars.secretCount.Current > vars.secretCount.Old) {
        return settings["Split on collecting secrets (host only)"];
    }
}

reset {
    // Reset if you switch to the main menu - won't catch reloading a save but ehh
    if (vars.currentMenu.Current == vars.mainMenu && vars.currentMenu.Old != vars.mainMenu) {
        return true;
    }
}

isLoading {
    return vars.isMuted.Current == 1;
}