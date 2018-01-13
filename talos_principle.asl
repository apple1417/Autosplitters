/* Sig scans for isLoading
-------------------- x64 (1)
  Talos.exe+C3C04 - E8 97D78500       - call Talos.exe+9213A0
  Talos.exe+C3C09 - 48 8B C8        - mov rcx,rax
  Talos.exe+C3C0C - 48 8B 10        - mov rdx,[rax]
  Talos.exe+C3C0F - FF 92 88000000    - call qword ptr [rdx+00000088]
  Talos.exe+C3C15 - 44 8B E0        - mov r12d,eax
  Talos.exe+C3C18 - 48 8B 0D B1456D01   - mov rcx,[Talos.exe+17981D0] { [14ABBF70] }
  Talos.exe+C3C1F - 48 8B 11        - mov rdx,[rcx]
  Talos.exe+C3C22 - FF 92 B0000000    - call qword ptr [rdx+000000B0]
  Talos.exe+C3C28 - E8 438FB500       - call Talos.exe+C1CB70
-------------------- x86 (1)
  Talos.exe+81CBC - 8B C8         - mov ecx,eax
  Talos.exe+81CBE - 8B 10         - mov edx,[eax]
  Talos.exe+81CC0 - 8B 42 44        - mov eax,[edx+44]
  Talos.exe+81CC3 - FF D0         - call eax
  Talos.exe+81CC5 - 89 45 F0        - mov [ebp-10],eax
  Talos.exe+81CC8 - 8B 0D E8406501    - mov ecx,[Talos.exe+12540E8] { [0A4E4C60] }
  Talos.exe+81CCE - 8B 11         - mov edx,[ecx]
  Talos.exe+81CD0 - FF 52 58        - call dword ptr [edx+58]
  Talos.exe+81CD3 - E8 C8B2A400       - call Talos.exe+ACCFA0
  
  
Sig scans for cheatFlags
-------------------- x64
Talos.exe+54A5BC - 45 33 E4              - xor r12d,r12d
Talos.exe+54A5BF - 4D 8B E8              - mov r13,r8
Talos.exe+54A5C2 - 48 8B EA              - mov rbp,rdx
Talos.exe+54A5C5 - 44 89 A4 24 80000000  - mov [rsp+00000080],r12d
Talos.exe+54A5CD - 44 39 25 9C902701     - cmp [Talos.exe+17C3670],r12d { [00000003] }              <-------
Talos.exe+54A5D4 - 48 8B F9              - mov rdi,rcx
Talos.exe+54A5D7 - 7E 57                 - jle Talos.exe+54A630
Talos.exe+54A5D9 - 44 39 61 48           - cmp [rcx+48],r12d
Talos.exe+54A5DD - 75 51                 - jne Talos.exe+54A630
-------------------- x86
Talos.exe+4AE3C0 - 55                    - push ebp
Talos.exe+4AE3C1 - 8B EC                 - mov ebp,esp
Talos.exe+4AE3C3 - 83 EC 14              - sub esp,14 { 20 }
Talos.exe+4AE3C6 - 83 3D 483F6701 00     - cmp dword ptr [Talos.exe+1273F48],00 { [00000003] }      <-------
Talos.exe+4AE3CD - 53                    - push ebx
Talos.exe+4AE3CE - 56                    - push esi
Talos.exe+4AE3CF - 8B D9                 - mov ebx,ecx
Talos.exe+4AE3D1 - C7 45 FC 00000000     - mov [ebp-04],00000000 { 0 }
Talos.exe+4AE3D8 - 7E 49                 - jle Talos.exe+4AE423
  
  
Sig scans for graphicsChange
-------------------- x64
Talos.exe+E81174 - 4C 8D 4C 24 68        - lea r9,[rsp+68]
Talos.exe+E81179 - 4C 89 4C 24 20        - mov [rsp+20],r9
Talos.exe+E8117E - 45 33 C9              - xor r9d,r9d
Talos.exe+E81181 - FF 50 60              - call qword ptr [rax+60]
Talos.exe+E81184 - FF 05 1EE59500        - inc [Talos.exe+17DF6A8] { [00000000] }                   <-------
Talos.exe+E8118A - EB 1A                 - jmp Talos.exe+E811A6
Talos.exe+E8118C - 4C 8B 11              - mov r10,[rcx]
Talos.exe+E8118F - 48 8D 44 24 68        - lea rax,[rsp+68]
Talos.exe+E81194 - 45 33 C9              - xor r9d,r9d
-------------------- x86
Talos.exe+CB5BD8 - 8B 08                 - mov ecx,[eax]
Talos.exe+CB5BDA - 50                    - push eax
Talos.exe+CB5BDB - 75 0B                 - jne Talos.exe+CB5BE8
Talos.exe+CB5BDD - FF 51 30              - call dword ptr [ecx+30]
Talos.exe+CB5BE0 - FF 05 C09A6801        - inc [Talos.exe+1289AC0] { [00000000] }                   <-------
Talos.exe+CB5BE6 - EB 09                 - jmp Talos.exe+CB5BF1
Talos.exe+CB5BE8 - FF 51 3C              - call dword ptr [ecx+3C]
Talos.exe+CB5BEB - FF 05 C49A6801        - inc [Talos.exe+1289AC4] { [00000000] }
Talos.exe+CB5BF1 - 8B 7D 08              - mov edi,[ebp+08]
*/

state("Talos", "x86") {
  int isLoading: 0x12540E8, 0x08, 0x1C8;
}
state("Talos", "x64") {
  int isLoading: 0x17981D0, 0x10, 0x208;
}

startup {
  // Commonly used, defaults to true
  settings.Add("Don't start the run if cheats are active", true);
  settings.Add("Split on return to Nexus or DLC Hub", true);
  settings.Add("Split on tetromino tower doors", true);
  settings.Add("Split on item unlocks", true);
  settings.Add("Split on star collection in the Nexus", true);

  // Less commonly used, but still sees some use
  settings.Add("Split on tetromino collection or DLC robot collection", false);
  settings.Add("Split on star collection", false);
  settings.Add("Split on tetromino world doors", false);
  settings.Add("Split on exiting any terminal", false);

  // Rarely used
  settings.Add("Split on tetromino star doors", false); // (mostly) unused by the community
  settings.Add("Split on Community% ending", false); // Community% completion -- mostly unused
  settings.Add("Split when exiting Floor 5", false);
  settings.Add("Don't split on tetromino collection in A6", false);
  settings.Add("Don't split on tetromino collection in B4", false);
  settings.Add("Start the run in any world", false);
}

init {
  var gameDir = Path.GetDirectoryName(modules.First().FileName);
  var logPath = "";
  
  var page = modules.First();
  var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
  var ptr = IntPtr.Zero;
  vars.cheatFlags = null;
  vars.graphicsChange = null;
  
  if (game.Is64Bit()) {
    version = "x64";
    logPath = gameDir.TrimEnd("\\Bin\\x64".ToCharArray()) + "\\Log\\Talos.log";
    
    ptr = scanner.Scan(new SigScanTarget(3,
    "44 39 25 ????????", // cmp [Talos.exe+17C3670],r12d { [00000003] }
    "48 8B F9"           // mov rdi,rcx
    ));
    int relativePosition = (int)((long)ptr - (long)page.BaseAddress) + 4;
    if (ptr == IntPtr.Zero) {
      print("=======Could not find cheatFlags=========");
      return false; 
    }
    vars.cheatFlags = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) + relativePosition));
    
    ptr = scanner.Scan(new SigScanTarget(2,
    "FF 05 ????????", // inc [Talos.exe+17DF6A8]
    "EB 1A",          // jmp Talos.exe+E811A6
    "4C 8B 11"        // mov r10,[rcx]
    ));
    int relativePosition2 = (int)((long)ptr - (long)page.BaseAddress) + 4;
    if (ptr == IntPtr.Zero) {
      print("=======Could not find graphicsChange=========");
      return false; 
    }
    vars.graphicsChange = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) + relativePosition2));
    
  } else {
    version = "x86";
    logPath = gameDir.TrimEnd("\\Bin".ToCharArray()) + "\\Log\\Talos.log";
    
    ptr = scanner.Scan(new SigScanTarget(2,
    "83 3D ???????? 00", // cmp dword ptr [Talos.exe+1273F48],00 { [00000003] }
    "53",                // push ebx
    "56",                // push esi
    "8B D9",             // mov ebx,ecx
    "C7 45 FC 00000000"  // mov [ebp-04],00000000 { 0 }
    ));
    if (ptr == IntPtr.Zero) {
      print("=======Could not find cheatFlags=========");
      return false; 
    }
    vars.cheatFlags = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress));
    
    ptr = scanner.Scan(new SigScanTarget(2,
    "FF 05 ????????", // inc [Talos.exe+1289AC0] { [00000000] }
    "EB 09",          // jmp Talos.exe+CB5BF1
    "FF 51 3C"        // call dword ptr [ecx+3C]
    ));
    if (ptr == IntPtr.Zero) {
      print("=======Could not find graphicsChange=========");
      return false; 
    }
    vars.graphicsChange = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress));
  }
  try { // Wipe the log file to clear out messages from last time
    FileStream fs = new FileStream(logPath, FileMode.Open, FileAccess.Write, FileShare.ReadWrite);
    fs.SetLength(0);
    fs.Close();
  } catch {} // May fail if file doesn't exist.
  vars.reader = new StreamReader(new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)); 

}

exit {
  timer.IsGameTimePaused = true;
}

update {
  if (vars.cheatFlags == null) return false;
  vars.cheatFlags.Update(game);
  if (vars.graphicsChange == null) return false;
  vars.graphicsChange.Update(game);
  
  vars.line = vars.reader.ReadLine();
  if (vars.line == null) {
    if (vars.graphicsChange.Old == 0) {
      return false;
    }
  } else {
    vars.line = vars.line.Substring(16); // Removes the date and log level from the line
  }
}

start {
  if (vars.line == null) return false;
  if (settings["Don't start the run if cheats are active"] &&
    vars.cheatFlags.Current != 0) {
    print("Not starting the run because of cheat flags: "+vars.cheatFlags.Current);
    return false;
  }
  // Only start for A1 / Gehenna Intro, since restore backup / continue should mostly be on other worlds.
  if (vars.line.StartsWith("Started simulation on 'Content/Talos/Levels/Cloud_1_01.wld'") ||
    vars.line.StartsWith("Started simulation on 'Content/Talos/Levels/DLC_01_Intro.wld'")) {
    print("Started a new run from a normal starting world.");
    vars.currentWorld = "[Initial World]"; // Not parsing this because it's hard
    vars.lastSigil = "";
    vars.lastLines = 0;
    vars.adminEnding = false;
    vars.introCutscene = true;
    timer.IsGameTimePaused = true;
    return true;
  }
  
  if (settings["Start the run in any world"] &&
    vars.line.StartsWith("Started simulation on '")) {
    print("Started a new run from a non-normal starting world.");
    vars.currentWorld = "[Initial World]"; // Not parsing this because it's hard
    vars.lastSigil = "";
    vars.lastLines = 0;
    vars.adminEnding = false;
    vars.introCutscene = false; // Don't wait for an intro cutscene for custom starts
    timer.IsGameTimePaused = true;
    return true;
  }
}

reset {
  if (vars.line == null) return false;
  if (vars.line == "Saving talos progress upon game stop.") {
    print("Stopped run because the game was exited.");
    return true; // Unique line printed only when you stop the game
  }
}

isLoading {
  //if (vars.line == null) return false;
  if (vars.introCutscene && vars.line == "Save Talos Progress: delayed request") {
    print("Intro cutscene was skipped or ended normally, starting timer.");
    vars.introCutscene = false;
  }
  // Pause the timer during the intro cutscene or when the pointer says so
  return vars.introCutscene || current.isLoading != 0 || vars.graphicsChange.Current != 0;
}

split {
  if (vars.line == null) return false;
  if (vars.line.StartsWith("Changing over to")) { // Map changes
    var mapName = vars.line.Substring(17);
    if (mapName == vars.currentWorld) {
      return false; // Ensure 'restart checkpoint' doesn't trigger map change
    }
    print("Changed worlds from "+vars.currentWorld+" to "+mapName);
    vars.currentWorld = mapName;
    if (settings["Split on return to Nexus or DLC Hub"] &&
      (mapName == "Content/Talos/Levels/Nexus.wld" ||
       mapName == "Content/Talos/Levels/DLC_01_Hub.wld")) {
      return true;
    }
    if (mapName == "Content/Talos/Levels/Cloud_3_08.wld") {
      vars.cStarSigils = 0;
    }
  }
  if (vars.line.StartsWith("Picked:")) { // Sigil/Robot and star collection
    var sigil = vars.line.Substring(8);
    if (sigil == vars.lastSigil) {
      return false; // DLC Double-split prevention
    } else {
      vars.lastSigil = sigil;
    }
    print("Collected sigil " + sigil + " in world " + vars.currentWorld);
    if (vars.currentWorld == "Content/Talos/Levels/Cloud_3_08.wld") {
      vars.cStarSigils++;
      print("Collected " + vars.cStarSigils + " in C*");
      if (vars.cStarSigils == 3 && settings["Split on Community% ending"]) {
        return true;
      }
    }
    if (sigil.StartsWith("**")) {
      if (settings["Split on star collection"]) {
        return true;
      } else {
        if (vars.currentWorld == "Content/Talos/Levels/Nexus.wld") {
          return settings["Split on star collection in the Nexus"];
        }
      }
    } else {
      if (settings["Don't split on tetromino collection in A6"] &&
        vars.currentWorld == "Content/Talos/Levels/Cloud_1_06.wld") {
        print("Not splitting for a collection in A6, per setting.");
        return false;
      }
      if (settings["Don't split on tetromino collection in B4"] &&
        vars.currentWorld == "Content/Talos/Levels/Cloud_2_04.wld") {
        print("Not splitting for a collection in B4, per setting.");
        return false;
      }
      return settings["Split on tetromino collection or DLC robot collection"];
    }
  }

  // Arranger puzzles
  if (vars.line.StartsWith("Puzzle \"") && vars.line.Contains("\" solved")) {
    var puzzle = vars.line.Substring(8);
    print("Solved puzzle: " + puzzle);
    if (puzzle.StartsWith("Mechanic")) {
      return settings["Split on item unlocks"];
    }
    if (puzzle.StartsWith("Door")) {
      return settings["Split on tetromino world doors"];
    }
    if (puzzle.StartsWith("SecretDoor")) {
      return settings["Split on tetromino star doors"];
    }
    if (puzzle.StartsWith("Nexus")) {
      return settings["Split on tetromino tower doors"];
    }
    if (puzzle.StartsWith("DLC_01_Secret")) {
      return settings["(DLC) Split on puzzle doors"];
    }
    if (puzzle.StartsWith("DLC_01_Hub")) {
      vars.adminEnding = true; // Admin puzzle door solved, so the Admin is saved.
      return settings["(DLC) Split on puzzle doors"];
    }
  }

  // Miscellaneous
  if (vars.line == "Save Talos Progress: exited terminal") {
    print("User exited terminal");
    return settings["Split on exiting any terminal"];
  }
  if (vars.currentWorld == "Content/Talos/Levels/Islands_03.wld") {
    if (vars.line.StartsWith("USER:")) { // Line differs in languages, not the prefix
      print("Game completed via Messenger ending.");
      return true;
    }
  }
  if (vars.currentWorld == "Content/Talos/Levels/Nexus.wld") {
    if (vars.line == "Elohim speaks: Elohim-063_Nexus_Ascent_01") {
      print("User exits floor 5 and starts ascending the tower");
      return settings["Split when exiting Floor 5"];
    }
    if (vars.line == "USER: /transcend") {
      print("Game completed via Transcendence ending.");
      return true;
    }
    if (vars.line == "USER: /eternalize") {
      print("Game completed via Eternalize ending.");
      return true;
    }
  }
  if (vars.currentWorld == "Content/Talos/Levels/DLC_01_Hub.wld") {
    if (vars.line == "Save Talos Progress: entered terminal") {
      vars.lastLines = 0;
    }
    if (vars.line.StartsWith("USER:")) {
      vars.lastLines++;
      if (vars.adminEnding) {
        // If admin is saved, it takes 5 lines to end the game
        return (vars.lastLines == 5);
      } else {
        // In all other endings, game ends on the 4th dialogue
        return (vars.lastLines == 4);
      }
    }
  }
}