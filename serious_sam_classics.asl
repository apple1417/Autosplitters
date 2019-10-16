/*
  Serious Engine 1 has public source code, which helps verify this a lot:
  https://github.com/Croteam-official/Serious-Engine
*/

state("SeriousSam") {}

startup {
    settings.Add("Split on loading screens", false);
}

init {
    var page = modules.First();
    var engine = modules.Where(m => m.ModuleName == "Engine.dll").First();
    
    var scanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
    vars.foundPointers = false;

    var ptr = IntPtr.Zero;
    ptr = scanner.Scan(new SigScanTarget(2,
        /*
         This is CSoundLibrary._bMuted, finding it from the function SoundLibrary::Mute()
         In practice they only ever call it to mute for loading screens, if you set your volume to
          0 it will still be false
        */
        "C7 05 ???????? 01000000",  // mov [Engine._pSound+1C],00000001 { (0),1 }   <---
        "8B 46 1C"                  // mov eax,[esi+1C]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find isLoading pointer!");
        return false;
    }
    vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    vars.foundPointers = true;
}

update {
    if (vars.foundPointers == false) return false;

    vars.isLoading.Update(game);
}

exit {
    timer.IsGameTimePaused = true;
}

split {
    if (vars.isLoading.Current == 1 && vars.isLoading.Old == 0) {
        return settings["Split on loading screens"];
    }
}

isLoading {
    return vars.isLoading.Current == 1;
}