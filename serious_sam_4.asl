state("Sam4") {}

startup {
    settings.Add("no_cheats", true, "Don't start the run if cheats are active");
    settings.Add("level_transitions", true, "Split on level transitions");
    settings.Add("start_everywhere", false, "Start the run in any world");
    settings.Add("il_mode", false, "IL Mode (Experimental)");

    vars.reader = null;
}

init {
    vars.currentWorld = "";
    vars.isLoadingMain = null;
    vars.isLoadingSecondary = null;
    vars.igt = null;
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
        print("Could not find main loading pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        vars.isLoadingMain = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x10, 0x208
        ));
    }

    ptr = scanner.Scan(new SigScanTarget(20,
        "48 8B D8",             // mov rbx,rax
        "48 85 C0",             // test rax,rax
        "74 3F",                // je Sam4.exe+8864C4
        "4C 8B 00",             // mov r8,[rax]
        "48 8B C8",             // mov rcx,rax
        "41 FF 10",             // call qword ptr [r8]
        "48 8B 15 ????????"     // mov rdx,[Sam4.exe+22606F0] { (085E8A40) }       <----
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find secondary loading pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        vars.isLoadingSecondary = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x50
        ));
    }

    ptr = scanner.Scan(new SigScanTarget(11,
        "FF 90 68020000",       // call qword ptr [rax+00000268]
        "EB 41",                // jmp Sam4.exe+3AD30
        "48 8B 0D ????????"     // mov rcx,[Sam4.exe+2244138]       <----
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find igt pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        vars.igt = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x10, 0x238, 0x1d8, 0x170, 0x10
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

    if (vars.isLoadingMain != null) {
        vars.isLoadingMain.Update(game);
    }
    if (vars.isLoadingSecondary != null) {
        vars.isLoadingSecondary.Update(game);
    }
    if (vars.igt != null) {
        vars.igt.Update(game);
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
            timer.IsGameTimePaused = true;
            return true;
        }
    }
}

isLoading {
    if (settings["il_mode"]) {
        return true;
    }
    return (vars.isLoadingMain != null && vars.isLoadingMain.Current != 0)
            || (vars.isLoadingSecondary != null && vars.isLoadingSecondary.Current != 0);
}

gameTime {
    if (settings["il_mode"] && vars.igt != null) {
        return new TimeSpan(0, 0, vars.igt.Current);
    }
}

split {
    if (vars.line == null || settings["il_mode"]) {
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
