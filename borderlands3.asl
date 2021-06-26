state("Borderlands3") {}

startup {
    settings.Add("split_levels", false, "Split on level transitions");
    settings.Add("start_sancturary", false, "Start the run when entering Sanctuary (for DLCs)");
    settings.Add("count_sqs", false, "Count SQs in \"SQs:\" counter component");

    vars.loadFromGNames = null;

    vars.worldPtr = null;
    vars.isLoading = null;

    vars.currentWorld = null;
    vars.oldWorld = null;

    vars.lastGameWorld = null;

    vars.incrementCounter = null;

    try {
        foreach (var component in timer.Layout.Components) {
            // Counter isn't a default component, so we need to use reflection to keep this working
            //  when it's not installed
            var type = component.GetType();
            if (type.Name != "CounterComponent") {
                continue;
            }

            var counterSettings = type.GetProperty("Settings").GetValue(component);
            var textProperty = counterSettings.GetType().GetProperty("CounterText");
            if ((string)textProperty.GetValue(counterSettings) != "SQs:") {
                continue;
            }

            var counter = type.GetProperty("Counter").GetValue(component);
            var counterType = counter.GetType();

            var incrMethod = counterType.GetMethod("Increment");
            var resetMethod = counterType.GetMethod("Reset");

            if (incrMethod == null || resetMethod == null) {
                throw new NullReferenceException();
            }

            print("Found SQ counter component");

            vars.incrementCounter = (Action)(() => {
                incrMethod.Invoke(counter, new object[0]);
            });

            timer.OnStart += (e, o) => {
                resetMethod.Invoke(counter, new object[0]);
            };

            break;
        }
    } catch (NullReferenceException) {}

    if (vars.incrementCounter == null) {
        print("Did not find SQ counter component");
        vars.incrementCounter = (Action)(() => {});
    }
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;

    vars.currentWorld = null;
    vars.oldWorld = null;

    vars.lastGameWorld = null;

    ptr = scanner.Scan(new SigScanTarget(8,
        "48 8B 4C 24 30",       // mov rcx,[rsp+30]
        "4C 8D 05 ????????",    // lea r8,[Borderlands3.exe+4C370A0]    <----
        "B8 3F000000"           // mov eax,0000003F
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find version pointer!");
        version = "Unknown";
    } else {
        version = game.ReadString(new IntPtr(game.ReadValue<int>(ptr) + ptr.ToInt64() + 4), 64);
    }

    ptr = scanner.Scan(new SigScanTarget(11,
        "E8 ????????",          // call Borderlands3.exe+3DB68AC
        "48 ?? ??",             // mov rax,rbx
        "48 89 1D ????????",    // mov [Borderlands3.exe+69426C8],rbx   <----
        "48 8B 5C 24 ??",       // mov rbx,[rsp+20]
        "48 83 C4 28",          // add rsp,28
        "C3",                   // ret
        "?? DB",                // xor ebx,ebx
        "48 89 1D ????????",    // mov [Borderlands3.exe+69426C8],rbx
        "?? ??",                // mov eax,ebx
        "48 8B 5C 24 ??",       // mov rbx,[rsp+20]
        "48 83 C4 ??",          // add rsp,28
        "C3"                    // ret
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find GNames pointer!");
    } else {
        var relPos = (int)((long)ptr - (long)page.BaseAddress) + 4;
        var GNames = game.ReadValue<int>(ptr) + relPos;

        vars.loadFromGNames = (Func<int, string>)((idx) => {
            var namePtr = new DeepPointer(GNames, (idx / 0x4000) * 8, (idx % 0x4000) * 8, 0x10);
            return namePtr.DerefString(game, 64);
        });
    }

    // See https://gist.github.com/apple1417/111a6d7f3a4b786d4752e3b458617e26 for info on these

    ptr = scanner.Scan(new SigScanTarget(7,
        "4C 8D 0C 40",          // lea r9,[rax+rax*2]
        "48 8B 05 ????????",    // mov rax,[Borderlands3.exe+6175420] <----
        "4A 8D 0C C8"           // lea rcx,[rax+r9*8]
    ));
    if (ptr == IntPtr.Zero) {
        print("Could not find current world pointer!");
    } else {
        var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
        vars.worldPtr = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relPos, 0x0, 0x18
        ));
    }

    var ALL_LOADING_PATTERNS = new List<Tuple<string, int>>() {
        new Tuple<string, int>("D0010000", 0x9DC),
        new Tuple<string, int>("F0010000", 0xA7C)
    };

    foreach (var pattern in ALL_LOADING_PATTERNS) {
        ptr = scanner.Scan(new SigScanTarget(-119,
            "C7 44 24 28 0C000010",         // mov [rsp+28],1000000C
            "C7 44 24 20" + pattern.Item1   // mov [rsp+20],000001F0
        ));
        if (ptr == IntPtr.Zero) {
            continue;
        } else {
            var relPos = (int)(ptr.ToInt64() - page.BaseAddress.ToInt64() + 4);
            vars.isLoading = new MemoryWatcher<int>(new DeepPointer(
                game.ReadValue<int>(ptr) + relPos, 0xF8, pattern.Item2
            ));
            break;
        }
    }
    if (vars.isLoading == null) {
        print("Could not find loading pointer!");
    }

    if (
        version != "Unknown" && (
            vars.loadFromGNames == null
            || vars.worldPtr == null
            || vars.isLoading == null
        )
    ) {
        version = "Unstable " + version;
    }
}

exit {
    timer.IsGameTimePaused = true;
}

update {
    if (vars.worldPtr != null && vars.loadFromGNames != null) {
        var changed = vars.worldPtr.Update(game);
        vars.oldWorld = vars.worldPtr.Old == 0
                        ? null
                        : vars.loadFromGNames(vars.worldPtr.Old);
        vars.currentWorld = vars.worldPtr.Current == 0
                            ? null
                            : vars.loadFromGNames(vars.worldPtr.Current);

        if (changed) {
            print(
                "Map changed from "
                + vars.oldWorld.ToString()
                + " to "
                + vars.currentWorld.ToString()
            );

            if (settings["count_sqs"] && vars.currentWorld == "MenuMap_P") {
                vars.incrementCounter();
            }
        }
    } else {
        vars.oldWorld = null;
        vars.currentWorld = null;
    }


    if (vars.isLoading != null) {
        var changed = vars.isLoading.Update(game);
        if (changed) {
            print(
                "Loading changed from "
                + vars.isLoading.Old.ToString("X")
                + " to "
                + vars.isLoading.Current.ToString("X")
            );
        }
    }
}

start {
    if (settings["start_sancturary"] && vars.currentWorld == "Sanctuary3_P") {
        return true;
    }
    return false;
}

isLoading {
    if (vars.isLoading.Current != 0 || vars.currentWorld == "MenuMap_P") {
        // If you start on the main menu sometimes a single tick is counted before pausing, fix it
        if (timer.CurrentAttemptDuration.TotalSeconds < 0.1) {
            timer.SetGameTime(TimeSpan.Zero);
        }
        return true;
    }
    return false;
}

split {
    if (
        settings["split_levels"]
        && vars.currentWorld != null && vars.currentWorld != "MenuMap_P"
        && vars.currentWorld != vars.lastGameWorld
    ) {
        var last = vars.lastGameWorld;
        vars.lastGameWorld = vars.currentWorld;
        // Don't split on the first load into the game
        if (last != null) {
            return true;
        }
    }
    return false;
}
