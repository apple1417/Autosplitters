// Credit to darkid who wrote the Talos Principle Autosplitter, this is heavily based off of that
// https://github.com/jbzdarkid/Autosplitters/blob/master/LiveSplit.TheTalosPrinciple.asl

state("Sam3") {
    // Would prefer to use a sigscan but can't find a good one
    int ughZanHealth : 0xBF4DD8, 0xCC, 0x48, 0x450;
}

startup {
    settings.Add("Don't start the run if cheats are active", true);
    settings.Add("Split on level transitions", true);
    settings.Add("Split on defeating Ugh Zan (Experimental)", true);
    settings.Add("Split on defeating Raahloom", true);
    settings.Add("Start the run in any world", false);
    
    // Setup autosplitter log file
    vars.logFilePath = Directory.GetCurrentDirectory() + "\\autosplitter_ss3.log";
    vars.log = (Action<string>)((string logLine) => {
        print(logLine);
        string time = System.DateTime.Now.ToString("yyyy-MM-dd hh:mm:ss.fff");
        System.IO.File.AppendAllText(vars.logFilePath, time + ": " + logLine + "\r\n");
    });
    try {
        vars.log("Autosplitter loaded");
    } catch (System.IO.FileNotFoundException e) {
        System.IO.File.Create(vars.logFilePath);
        vars.log("Autosplitter loaded, log file created");
    }
}

init {
    var page = modules.First();
    var gameDir = Path.GetDirectoryName(page.FileName);
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    vars.foundPointers = false;
    vars.currentWorld = "";
    vars.onContinueScreen = false;
    vars.ughZanFightStage = 0;

    var ptr = IntPtr.Zero;
    ptr = scanner.Scan(new SigScanTarget(3,
        "03 C3",            // add eax,ebx
        "A3 ????????",      // mov [Sam3.exe+B9F1A0],eax { [00000000] }        <----
        "89 74 82 FC",      // mov [edx+eax*4-04],esi
        "83 3D ???????? 00" // cmp dword ptr [Sam3.exe+C0852C],00 { 0 }
    ));
    if (ptr == IntPtr.Zero) {
        vars.log("Could not find loading pointer!");
        return false;
    }
    vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    ptr = scanner.Scan(new SigScanTarget(5,
        "85 C0",       // test eax,eax
        "75 08",       // jne Sam3.exe+707DE
        "A1 ????????", // mov eax,[Sam3.exe+BAE900] { [00000003] }        <----
        "5E",          // pop esi
        "5D"           // pop ebp
    ));
    if (ptr == IntPtr.Zero) {
        vars.log("Could not find cheats pointer!");
        return false;
    }
    vars.cheats = new MemoryWatcher<int>(new DeepPointer(
        game.ReadValue<int>(ptr) - (int)page.BaseAddress
    ));

    vars.foundPointers = true;


    string logPath = gameDir.TrimEnd("\\Bin".ToCharArray()) + "\\Log\\" + game.ProcessName + ".log";
    vars.log("Using log path: '" + logPath + "'");
    
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

start {
    if (vars.line == null) return false;
    
    System.Text.RegularExpressions.Regex regex = new System.Text.RegularExpressions.Regex(@"^Started simulation on '(.*?)'");
    System.Text.RegularExpressions.Match match = regex.Match(vars.line);
    if (match.Success) {
        string world = match.Groups[1].Value;
        
        // Cheats
        if (settings["Don't start the run if cheats are active"] && vars.cheats.Current != 0) {
            vars.log("Not starting the run because of cheat flags: " + vars.cheats.Current);
            return false;
        // Wrong starting world
        } else if (world != "Content/SeriousSam3/Levels/01_BFE/01_CairoSquare/01_CairoSquare.wld"
                   && world != "Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld"
                   && !settings["Start the run in any world"]) {
            vars.log("Not starting run due to entering wrong world");
        // Actually start run
        } else {
            vars.log("Started a new run");
            vars.currentWorld = world;
            vars.onContinueScreen = true;
            vars.ughZanFightStage = 0;
            timer.IsGameTimePaused = true;
            return true;
        }
    }
}

update {
    if (vars.foundPointers == null) return false;

    vars.isLoading.Update(game);
    vars.cheats.Update(game);

    do {
        vars.line = vars.reader.ReadLine();
        if (vars.line == null) break;
        if (vars.line.Length <= 16) continue;
        vars.line = vars.line.Substring(16); // Removes the date and log level from the line
    // If graphics API errors happen they'll spam the log far quicker than livesplit will update
    } while (vars.line.StartsWith("Direct3D9: API error!")
             || vars.line.StartsWith("Direct3D11: API error!")
             || vars.line.StartsWith("OpenGL: API error!"));
}

isLoading
{
    if (vars.line != null) {
        if (vars.onContinueScreen &&
            vars.line.StartsWith("resFreeUnused")) {
            vars.onContinueScreen = false;
        }
        /*
          Netricsa is technically it's own level that can trigger this
          Quickloading or dying doesn't show the continue screen, and apparently wasn't always
           getting turned off again, so no reason to check
          This does mean continue screen from loading a screen on a different save won't be
           counted out, but if you're doing that the small timeloss is the least of your worries
        */
        if (!vars.line.Contains("NetricsaLevel.wld")
            && !vars.line.Contains("/SeriousSam3/SavedGames/")
            && vars.line.StartsWith("Started loading world")) {
                
            vars.log("Continue screen trigger: " + vars.line);
            vars.onContinueScreen = true;
        }
    }
    return vars.isLoading.Current != 0 || vars.onContinueScreen;
}

split {
    /*
      Ugh Zan
      The issue with Ugh Zan is that, while there is a line when the cutscene starts, it both
       requires autosaves to be on, and we have no good way of telling if it's the right autosave
      Instead we have to use a pointer
      Unfortuantly the best pointer I can find, to his health, sucks, it's reused for all sorts of
       things and it occasionally drops to 0 for multiple frames in a row during the fight
    */
    if (settings["Split on defeating Ugh Zan (Experimental)"]
        && vars.currentWorld == "Content/SeriousSam3/Levels/01_BFE/12_HatshepsutTemple/12_HatshepsutTemple.wld") {
        if (vars.ughZanFightStage == 0
            // Here's hoping it never randomly jumps to these values outside the fight
            && (current.ughZanHealth == 5000 || current.ughZanHealth == 7500 || current.ughZanHealth == 10000)) {
            
            vars.ughZanFightStage = 1;
            vars.log("Started Ugh Zan Fight");
        }
        
        // Count how many frames in a row health has been at 0
        if (vars.ughZanFightStage > 0) {
            if (current.ughZanHealth != 0) {
                vars.ughZanFightStage = 1;
            /*
              If health has been at 0 for long enough we can assume he's dead
              I've never seen more than 4 frames of fake 0s in a row before, add one to be safe,
               meaning we need to wait until the stage is 6
              Cause livesplit is 60hz this also happens to be exactly 0.1s late if that ever matters
            */
            } else if (vars.ughZanFightStage == 6) {
                vars.log("Assuming Ugh Zan dead, splitting");
                vars.ughZanFightStage = 0;
                return true;
            } else  {
                vars.log("Ugh Zan 0 HP for " +  vars.ughZanFightStage.ToString() + " frames");
                vars.ughZanFightStage++;
            }
        }
    }

    // The rest of this will break if we don't have a log line
    if (vars.line == null) return false;

    // Level Transitions
    if (vars.line.StartsWith("Changing over to ")) {
        var mapName = vars.line.Substring(17);
        // So qs+ql doesn't trigger it
        if (mapName == vars.currentWorld) {
          return false;
        }
        vars.log("Changed worlds from " + vars.currentWorld + " to " + mapName);
        vars.currentWorld = mapName;
        return settings["Split on level transitions"];
    }

    /*
      Raahloom
      There's literally just a scripting error when you kill him
    */
    if (vars.currentWorld == "Content/SeriousSam3/Levels/02_DLC/03_TempleOfSethirkopshef/03_TempleOfSethirkopshef.wld" &&
        vars.line.StartsWith("Lua error: [Script entity id = 4132 (Script_Boss)]:25")) {
        return settings["Split on defeating Raahloom"];
    }
}