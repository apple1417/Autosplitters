state("Sam4") {}

startup {
    settings.Add("no_cheats", true, "Don't start the run if cheats are active");
    settings.Add("level_transitions", true, "Split on level transitions");
    settings.Add("start_everywhere", false, "Start the run in any world");

    vars.reader = null;
}

init {
    vars.currentWorld = "";
    vars.onContinueScreen = false;
    vars.isLoading = null;
    vars.cheats = null;

    var page = modules.First();

    var logPath = Path.GetFullPath(Path.Combine(
        Path.GetDirectoryName(page.FileName), "..", "..", "Log", "Sam4.log")
    );
    print("Using log path: '" + logPath + "'");
    vars.reader = new StreamReader(new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
    vars.reader.ReadToEnd();

    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 0D ????????",    // mov rcx,[Sam4.exe+2244138]       <----
        "48 8B 11",             // mov rdx,[rcx]
        "FF 92 B0000000"        // call qword ptr [rdx+000000B0]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find loading pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x10, 0x208
        ));
    }

    ptr = scanner.Scan(new SigScanTarget(6,
        "45 33 E4",             // xor r12d,r12d
        "44 39 25 ????????",    // cmp [Sam4.exe+2246D20],r12d      <----
        "75 24",                // jne Sam4.exe+203123
        "48 8D 4E 28"           // lea rcx,[rsi+28]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find cheats pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        vars.cheats = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos
        ));
    }
}

exit {
    timer.IsGameTimePaused = true;
    vars.reader.Close();
    vars.reader = null;
}


update {
    if (vars.reader != null) {
        do {
            vars.line = vars.reader.ReadLine();
        } while (vars.line != null && vars.line.Length <= 16);
        if (vars.line != null) {
            vars.line = vars.line.Substring(16).Trim();
        }
    }

    if (vars.cheats != null) {
        vars.cheats.Update(game);
    }
}

start {
    if (vars.line == null) return false;

    var match = new System.Text.RegularExpressions.Regex(@"^Started simulation on '(.*?)'").Match(vars.line);
    if (match.Success) {
        string world = match.Groups[1].Value;
        
        // Cheats
        if (settings["no_cheats"] && vars.cheats != null && vars.cheats.Current != 0) {
            print("Not starting the run because of cheats");
            return false;
        // Wrong starting world
        } else if (world != "Content/SeriousSam4/Levels/01_PB/00_Prolepsis.wld"
                   && !settings["start_everywhere"]) {
            print("Not starting run due to entering wrong world");
        // Actually start run
        } else {
            print("Started a new run");

            vars.currentWorld = world;
            vars.onContinueScreen = true;
            timer.IsGameTimePaused = true;
            return true;
        }
    }
}

isLoading {
    if (vars.line != null) {
        if (vars.onContinueScreen && vars.line.EndsWith("sound channels reinitialized.")) {
            vars.onContinueScreen = false;
        }

        if (vars.line.StartsWith("Started loading world")
            && !vars.line.Contains("Content/SeriousSam4/Levels/Menu/")) {

            print("Continue screen trigger: " + vars.line);
            vars.onContinueScreen = true;
        }
    }
    return vars.onContinueScreen || (vars.isLoading != null && vars.isLoading.Current != 0);
}

split {
    if (vars.line == null) {
        return false;
    }

    // Level Transitions
    if (vars.line.StartsWith("Changing over to ")) {
        var world = vars.line.Substring(17);
        // So qs+ql doesn't trigger it
        if (world == vars.currentWorld) {
          return false;
        }
        print("Changed worlds from " + vars.currentWorld + " to " + world);
        vars.currentWorld = world;
        return settings["level_transitions"];
    }
}
