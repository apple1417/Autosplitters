/* Sig scans
----------------x64
Talos.exe+C5EF3 - 83 F8 05              - cmp eax,05
Talos.exe+C5EF6 - 0F85 D0000000         - jne Talos.exe+C5FCC
Talos.exe+C5EFC - 48 83 3D CC226D01 00  - cmp qword ptr [Talos.exe+17981D0],00
Talos.exe+C5F04 - 0F84 4C050000         - je Talos.exe+C6456
Talos.exe+C5F0A - 48 83 3D B6226D01 00  - cmp qword ptr [Talos.exe+17981C8],00
----------------x86
Talos.exe+83DE9 - 83 F8 05              - cmp eax,05
Talos.exe+83DEC - 0F85 EB000000         - jne Talos.exe+83EDD
Talos.exe+83DF2 - 83 3D E8406501 00     - cmp dword ptr [Talos.exe+12540E8],00
Talos.exe+83DF9 - 0F84 3F060000         - je Talos.exe+8443E
Talos.exe+83DFF - 83 3D E4406501 00     - cmp dword ptr [Talos.exe+12540E4],00
*/

state("Talos") {}

startup {
    vars.tcs = null;
}

init {
    var page = modules.First();
    var scanner = new SignatureScanner(game, page.BaseAddress, page.ModuleMemorySize);
    var ptr = IntPtr.Zero;
    vars.QRs = null;
    if (game.Is64Bit()) {
        ptr = scanner.Scan(new SigScanTarget(12, 
        "83 F8 05",                  // cmp eax,05
        "0F 85 ????????",            // jne Talos.exe+83EDD
        "48 83 3D ???????? 00",      // cmp qword ptr [Talos.exe+17981D0],00
        "0F 84 ????????",            // je Talos.exe+8443E
        "48 83 3D ???????? 00"));    // cmp dword ptr [Talos.exe+12540E4],00
        if (ptr == IntPtr.Zero) {
          print("=======Could not find QRs=========");
          return false; 
        }
        int relativePosition = (int)((long)ptr - (long)page.BaseAddress) + 5;
        vars.QRs = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) + relativePosition, 0xc0, 0x10, 0x2d0));
    } else {
        ptr = scanner.Scan(new SigScanTarget(11, 
        "83 F8 05",             // cmp eax,05
        "0F 85 ????????",       // jne Talos.exe+83EDD
        "83 3D ???????? 00",    // cmp dword ptr [Talos.exe+12540E8],00
        "0F 84 ????????",       // je Talos.exe+8443E
        "83 3D ???????? 00"));  // cmp dword ptr [Talos.exe+12540E4],00
        if (ptr == IntPtr.Zero) {
          print("=======Could not find QRs=========");
          return false; 
        }
        vars.QRs = new MemoryWatcher<int>(new DeepPointer(
            game.ReadValue<int>(ptr) - (int)page.BaseAddress, 0x7c, 0x10, 0x268));
    }
    if (vars.QRs == null) return false;
    
    vars.QRs.Update(game);
    foreach (LiveSplit.UI.Components.IComponent component in timer.Layout.Components) {
        if (component.GetType().Name == "TextComponent") { 
            vars.tc = component;
            vars.tcs = vars.tc.Settings;
            vars.tcs.Text2 = vars.QRs.Current.ToString() + "/83";
            break;
        }
    }
}

update {
    if (vars.QRs == null) return false;
    vars.QRs.Update(game);
    if (vars.QRs.Current != vars.QRs.Old && vars.tcs != null) {
        vars.tcs.Text2 = vars.QRs.Current.ToString() + "/83";
    }
}


split {
    if (vars.QRs.Current != vars.QRs.Old) {
        return true;
    }
}