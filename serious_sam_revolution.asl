/*
  Serious Engine 1 has public source code, as Revolution is based on that code it helps a lot
  If you're lucky (like I was) your version of the game will also ship with symbols
  https://github.com/Croteam-official/Serious-Engine
*/

state("SeriousSam") {}

startup {
    settings.Add("Don't start the run if cheats are active", true);
    settings.Add("Split on loading screens", true);
}

init {
    var page = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();
    
    var scanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.foundPointers = false;

    var ptr = IntPtr.Zero;
    ptr = scanner.Scan(new SigScanTarget(5,
        /*
         This is CSoundLibrary._bMuted, finding it from the function SoundLibrary::Mute()
         In practice they only ever call it to mute for loading screens, if you set your volume to
          0 it will still be false
        */
        "FF 77 40",                 // push [edi+40]
        "C7 05 ???????? 01000000"   // mov [Engine._pSound+1C],00000001 { 0 }       <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find isLoading pointer!");
        return false;
    }
    vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));
    
    ptr = scanner.Scan(new SigScanTarget(4,
        /*
          This is CCommunicationInterface.cci_bClientInitialized, finding it from
           CSessionState::MakeSynchronisationCheck()
        */
        "8B D9",                // mov ebx,ecx
        "83 3D ???????? 00",    // cmp dword ptr [Engine._cmiComm+C],00 { 0 }       <---
        "0F84 ????????"         // je Engine.CSessionState::MakeSynchronisationCheck+142
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find isInGame pointer!");
        return false;
    }
    vars.isInGame = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    ptr = scanner.Scan(new SigScanTarget(2,
        /*
          This is Engine.cht_bEnable, finding it from CNetworkLibrary::GetNetworkTimeFactor()
          Suprisingly few places actually directly reference it
        */
        "83 3D ???????? 00",    // cmp dword ptr [Engine.cht_bEnable],00 { 0 }      <---
        "74 07",                // je Engine.CNetworkLibrary::GetNetworkTimeFactor+10
        "D9 81 ????????"        // fld dword ptr [ecx+0000134C]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find cheats pointer!");
        return false;
    }
    vars.cheats = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    vars.foundPointers = true;
}

update {
    if (vars.foundPointers == false) return false;

    vars.isLoading.Update(game);
    vars.isInGame.Update(game);
    vars.cheats.Update(game);
}

start {
    if (vars.isInGame.Current == 1 &&  vars.isInGame.Old == 0) {
        if (settings["Don't start the run if cheats are active"] && vars.cheats.Current != 0) {
            return false;
        }
        
        vars.justStarted = true;
        return true;
    }
}

exit {
    timer.IsGameTimePaused = true;
}

split {
    if (vars.isLoading.Current == 0 && vars.isLoading.Old == 1) {
        // This prevents splitting right after you load for the first time
        if (vars.justStarted) {
            vars.justStarted = false;
            return false;
        }
        
        return settings["Split on loading screens"];
    }
}

reset {
    return vars.isInGame.Current == 0 &&  vars.isInGame.Old == 1;
}

isLoading {
    return vars.isLoading.Current == 1;
}