/*
  Serious Engine 1 has public source code, as Revolution is based on that code it helps a lot
  If you're lucky (like I was) your version of the game will also ship with symbols
  https://github.com/Croteam-official/Serious-Engine
*/

state("SeriousSam") {}

startup {
    settings.Add("Split on loading screens", true);
    settings.Add("Split on collecting secrets (host only)", false);
}

init {
    var page = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();
    
    var scanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.foundPointers = false;
    vars.justStarted = false;

    var ptr = IntPtr.Zero;
    ptr = scanner.Scan(new SigScanTarget(5,
        /*
         This is CSoundLibrary._bMuted, finding it from the function Engine.SoundLibrary::Mute
         In practice they only ever call it to mute for loading screens, if you set your volume to
          0 it will still be false
        */
        "FF 77 40",                 // push [edi+40]
        "C7 05 ???????? 01000000"   // mov [Engine._pSound+1C],00000001 { 0 }       <---
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to CSoundLibrary._bMuted!");
        return false;
    }
    vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    ptr = scanner.Scan(new SigScanTarget(4,
        /*
          This is CCommunicationInterface.cci_bInitialized, finding it from
           Engine.CSessionState::MakeSynchronisationCheck
        */
        "8B D9",                // mov ebx,ecx
        "83 3D ???????? 00",    // cmp dword ptr [Engine._cmiComm+C],00 { 0 }       <---
        "0F84 ????????"         // je Engine.CSessionState::MakeSynchronisationCheck+142
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to CCommunicationInterface.cci_bInitialized!");
        return false;
    }
    vars.isInGame = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    ptr = scanner.Scan(new SigScanTarget(3,
        /*
          Finding Engine._pNetwork through Engine.CSteam::UpdateSteamLobbyData
          This obviously isn't a function in the source
        */
        "8B F1",                // mov esi,ecx
        "A1 ????????",          // mov eax,[Engine._pNetwork] { (02E799A0) }        <---
        "85 C0"                 // test eax,eax
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find pointer to Engine._pNetwork!");
        return false;
    }
    // See https://gist.github.com/apple1417/cb95c9dac1bf2f00b5d2afff02d094fb
    vars.secretCount = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress,
        0x20, 0x4, 0x4, 0x2BB0
    ));

    vars.foundPointers = true;
}

update {
    if (vars.foundPointers == false) return false;

    vars.isLoading.Update(game);
    vars.isInGame.Update(game);
    vars.secretCount.Update(game);
}

start {
    if (vars.isInGame.Current == 1 &&  vars.isInGame.Old == 0) {
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
    
    if (vars.secretCount.Current > vars.secretCount.Old) {
        return settings["Split on collecting secrets (host only)"];
    }
}

reset {
    return vars.isInGame.Current == 0 &&  vars.isInGame.Old == 1;
}

isLoading {
    return vars.isLoading.Current == 1;
}