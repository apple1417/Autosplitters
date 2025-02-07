state("Sam3") {}
state("Sam2017") {}
state("Sam4") {}
state("SamSM") {}

startup {
    settings.Add("no_cheats", true, "Don't start the run if cheats are active");
    settings.Add("split_levels", true, "Split on level transitions");
    settings.Add("split_raahloom", true, "Split on defeating Raahloom (Standard BFE only)");
    settings.Add("start_everywhere", false, "Start the run in any world");

    vars.current_world = "<unknown>";
    vars.reader = null;

    vars.watchers = new MemoryWatcherList();

    // Returns a watcher's current value, or 0 if it doesn't exist.
    vars.get_current = (Func<string, object>)(name => {
        var watcher = ((MemoryWatcherList)vars.watchers).FirstOrDefault(x => x.Name == name);
        if (watcher == null) {
            return 0;
        }
        var cur_val = watcher.Current;
        if (cur_val == null) {
            return 0;
        }
        return cur_val;
    });

    vars.RE_CHANGING = new System.Text.RegularExpressions.Regex(@"^Changing over to (.*?)$");
    vars.RE_STARTED = new System.Text.RegularExpressions.Regex(@"^Started simulation on '(.*?)'");

    vars.VALID_STARTING_WORLDS = new List<string>() {
        "Content/SeriousSamHD/Levels/00_Egypt/0_01_Hatshepsut.wld",
        "Content/SeriousSamHD/Levels/Z0_DemoKarnak/KarnakDemo.wld",
        "Content/SeriousSamHD_TSE/Levels/01_TSE/1_01_Palenque.wld",
        "Content/SeriousSamHD_TSE/Levels/04_LegendOfTheBeast/4_01_CityEnter.wld",
        "Content/SeriousSamHD_TSE/Levels/Z1_DemoPalenque/PalenqueDemo.wld",
        "Content/SeriousSam3/Levels/01_BFE/01_CairoSquare/01_CairoSquare.wld",
        "Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld",
        "Content/SeriousSam4/Levels/01_PB/00_Prolepsis.wld",
        "Content/SeriousSamSM/Levels/01_SM/01_Refinery.wld",
    };
}

init {
    vars.current_world = "<unknown>";
    vars.watchers.Clear();

    var exe = modules.First();
    var scanner = new SignatureScanner(game, exe.BaseAddress, exe.ModuleMemorySize);

    var dir_name = Path.GetDirectoryName(exe.FileName);
    var log_path = Path.GetFullPath(
        game.Is64Bit() ? Path.Combine(dir_name, "..", "..", "Log", game.ProcessName + ".log")
                       : Path.Combine(dir_name, "..", "Log", game.ProcessName + ".log")
    );
    print("Using log path: '" + log_path + "'");
    vars.reader = new StreamReader(new FileStream(
        log_path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite
    ));
    vars.reader.ReadToEnd();

    var read_offset = (Func<IntPtr, int>)(ptr => {
        if (game.Is64Bit()) {
            var rel_pos = (int)(ptr.ToInt64() - exe.BaseAddress.ToInt64() + 4);
            return game.ReadValue<int>(ptr) + rel_pos;
        } else {
            return game.ReadValue<int>(ptr) - (int)exe.BaseAddress;
        }
    });

#region Loading Pointer
    /*
    This pointer is 1 when actually loading and 0 at all other times - including when waiting on the
     continue screen.
    */
    {
        var base_ptr = IntPtr.Zero;
        var offset_0_ptr = IntPtr.Zero;
        var offset_1_ptr = IntPtr.Zero;
        if (game.Is64Bit()) {
            base_ptr = scanner.Scan(new SigScanTarget(3,
                "48 8B 0D ????????",        // mov rcx,[Sam4.exe+2244138]           <----
                "48 8B 11",                 // mov rdx,[rcx]
                "FF 92 B0000000"            // call qword ptr [rdx+000000B0]
            ));
            offset_0_ptr = scanner.Scan(new SigScanTarget(7,
                "48 83 EC 28",              // sub rsp,28
                "48 8B 49 ??",              // mov rcx,[rcx+10]                     <----
                "48 85 C9",                 // test rcx,rcx
                "74 17"                     // je Sam2017.exe+652B4
            ));
            offset_1_ptr = scanner.Scan(new SigScanTarget(7,
                "48 83 EC 30",              // sub rsp,30
                "48 83 B9 ????0000 00",     // cmp qword ptr [rcx+000001F8],00      <----
                "41 8B F9"                  // mov edi,r9d
            ));
        } else {
            base_ptr = scanner.Scan(new SigScanTarget(4,
                "83 C4 ??",                 // add esp,04
                "FF D0",                    // call eax
                "8B 0D ????????",           // mov ecx,[Sam3.exe+BA93F0]            <----
                "8B 11",                    // mov edx,[ecx]
                "8B 42 ??"                  // mov eax,[edx+5C]
            ));
            offset_0_ptr = scanner.Scan(new SigScanTarget(2,
                "8B 49 ??",                 // mov ecx,[ecx+08]                     <----
                "83 EC 08",                 // sub esp,08
                "85 C9",                    // test ecx,ecx
                "74 16"                     // je Talos.exe+63AEE3
            ));
            offset_1_ptr = scanner.Scan(new SigScanTarget(12,
                "C7 86 ????0000 01000000",  // mov [esi+00000180],00000001
                "C7 86 ????0000 00000000",  // mov [esi+000001C4],00000000          <----
                "89 BE ????0000"            // mov [esi+000001D4],edi
            ));
        }

        if (base_ptr == IntPtr.Zero || offset_0_ptr == IntPtr.Zero || offset_1_ptr == IntPtr.Zero) {
            print("Could not find loading pointer!");
        } else {
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                read_offset(base_ptr),
                game.ReadValue<byte>(offset_0_ptr),
                game.ReadValue<short>(offset_1_ptr)
            )){ Name = "is_loading" });
        }
    }
#endregion

#region Continue Screen Pointer
    /*
    This pointer is 1 throughout the entire "first load" into the level, with the special UI. It
    includes the continue screen. It stays at 0 for any mid level loads (e.g. qs/ql).
    */
    {
        var base_ptr = IntPtr.Zero;
        var offset_0_ptr = IntPtr.Zero;
        if (game.Is64Bit()) {
            base_ptr = scanner.Scan(new SigScanTarget(3,
                "48 8B 15 ????????",        // mov rdx,[Sam2017.exe+1DA0FF0]        <----
                "48 8B C8",                 // mov rcx,rax
                "E8 ????????",              // call Sam2017.exe+DC3740
                "85 C0",                    // test eax,eax
                "74 0A",                    // je Sam2017.exe+7C0E38
                "C7 87 ??010000 01000000"   // mov [rdi+00000154],00000001
            ));
            offset_0_ptr = scanner.Scan(new SigScanTarget(4,
                "74 0B",                    // je Sam2017.exe+DADA52
                "FF 43 ??",                 // inc [rbx+50]                         <----
                "FF 43 ??"                  // inc [rbx+58]
            ));
        } else {
            if (game.ProcessName == "Sam3") {
                base_ptr = scanner.Scan(new SigScanTarget(14,
                    "8B 4F ??",             // mov ecx,[edi+6C]
                    "E8 ????????",          // call Sam3.exe+5E3070
                    "85 C0",                // test eax,eax
                    "74 ??",                // je Sam3.exe+354B13
                    "8B 0D ????????"        // mov ecx,[Sam3.exe+BAF8BC]            <----
                ));
            } else {
                base_ptr = scanner.Scan(new SigScanTarget(2,
                    "8B 15 ????????",       // mov edx,[SamHD_TSE.exe+9B32B4]       <----
                    "52",                   // push edx
                    "8B 10",                // mov edx,[eax]
                    "8B C8",                // mov ecx,eax
                    "8B 02",                // mov eax,[edx]
                    "FF D0",                // call eax
                    "50",                   // push eax
                    "E8 ????????",          // call SamHD_TSE.exe+605100
                    "83 C4 08",             // add esp,08
                    "85 C0",                // test eax,eax
                    "0F85 ????????"         // jne SamHD_TSE.exe+2BAC60
                ));
            }
            offset_0_ptr = scanner.Scan(new SigScanTarget(2,
                "01 ?? ??",                 // add [ebx+34],esi                     <----
                "01 ?? ??",                 // add [ebx+3C],esi
                "EB ??",                    // jmp SamHD_TSE.exe+5DDCDE
                "A1 ????????"               // mov eax,[SamHD_TSE.exe+9EA6B8]
            ));
        }

        if (base_ptr == IntPtr.Zero || offset_0_ptr == IntPtr.Zero) {
            print("Could not find continue screen pointer!");
        } else {
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                read_offset(base_ptr),
                game.ReadValue<byte>(offset_0_ptr)
            )){ Name = "is_continue" });
        }
    }
#endregion

#region Cheats Pointer
    /*
    This pointer just holds the direct cheats value - you can set cheats to any int, it'll be
     exactly that, super easy to find.
    */
    {
        var base_ptr = IntPtr.Zero;
        if (game.Is64Bit()) {
            base_ptr = scanner.Scan(new SigScanTarget(6,
                "45 33 E4",                 // xor r12d,r12d
                "44 39 25 ????????",        // cmp [Sam4.exe+2246D20],r12d          <----
                "75 24",                    // jne Sam4.exe+203123
                "48 8D 4E 28"               // lea rcx,[rsi+28]
            ));
        } else {
            base_ptr = scanner.Scan(new SigScanTarget(5,
                "85 C0",                    // test eax,eax
                "75 ??",                    // jne SamHD_TSE.exe+5A471
                "A1 ????????",              // mov eax,[SamHD_TSE.exe+9B2B6C]       <----
                "83 F8 02"                  // cmp eax,02
            ));
        }

        if (base_ptr == IntPtr.Zero) {
            print("Could not find cheats pointer!");
        } else {
            vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(
                read_offset(base_ptr)
            )){ Name = "cheats" });
        }
    }
#endregion
}

exit {
    timer.IsGameTimePaused = true;
    vars.reader.Close();
    vars.reader = null;
}

update {
    if (vars.reader != null) {
        while (true) {
            vars.line = vars.reader.ReadLine();
            if (vars.line == null) {
                break;
            }
            if (vars.line.Length <= 16) {
                continue;
            }
            vars.line = vars.line.Substring(16);

            // Graphics API errors spam the log far quicker than livesplit updates
            if (
                vars.line.StartsWith("Direct3D9: API error!")
                || vars.line.StartsWith("Direct3D11: API error!")
                || vars.line.StartsWith("OpenGL: API error!")
            ) {
                continue;
            }

            break;
        }
    }

    vars.watchers.UpdateAll(game);
}

start {
    if (vars.line == null) {
        return false;
    }

    var match = vars.RE_STARTED.Match(vars.line);
    if (match.Success) {
        var world = match.Groups[1].Value;

        if (settings["no_cheats"] && vars.get_current("cheats") != 0) {
            print("Not starting the run because of cheats");
        } else if (!vars.VALID_STARTING_WORLDS.Contains(world) && !settings["start_everywhere"]) {
            print("Not starting run due to entering wrong world");
        } else {
            print("Started a new run");

            vars.current_world = world;
            timer.IsGameTimePaused = true;
            return true;
        }
    }
}

isLoading {
    return vars.get_current("is_loading") != 0 || vars.get_current("is_continue") != 0;
}

onStart {
    // Ensure the timer is 0 if we start during a load
    if (vars.get_current("is_loading") != 0 || vars.get_current("is_continue") != 0) {
        timer.IsGameTimePaused = true;
        timer.SetGameTime(timer.Run.Offset);
    }
}

split {
    if (vars.line == null) {
        return false;
    }

    // Level Transitions
    var match = vars.RE_CHANGING.Match(vars.line);
    if (match.Success) {
        var world = match.Groups[1].Value;

        // So qs+ql doesn't trigger it
        if (world != vars.current_world) {
            print("Changed worlds from " + vars.current_world + " to " + world);
            vars.current_world = world;

            if (settings["split_levels"]) {
                return true;
            }
        }
    }

    // In standard BFE there's literally just a scripting error when you kill rahloom
    // Fixed in fusion unfortuantly
    if (
        vars.current_world == "Content/SeriousSam3/Levels/02_DLC/03_TempleOfSethirkopshef/03_TempleOfSethirkopshef.wld"
        && vars.line.StartsWith("Lua error: [Script entity id = 4132 (Script_Boss)]:25")
        && settings["split_raahloom"]
    ) {
        return true;
    }
}
