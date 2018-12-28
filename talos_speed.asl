state("Talos") {
    float x: 0x12BBBC0, 0, 0x70;
    float y: 0x12BBBC0, 0, 0x74;
    float z: 0x12BBBC0, 0, 0x78;
}

startup {
    vars.tcsX = null;
    vars.tcsY = null;
    vars.tcsZ = null;
    vars.tcsHoriz = null;
    vars.tcsTotal = null;
}

init {
    var index = 0;
    foreach (LiveSplit.UI.Components.IComponent component in timer.Layout.Components) {
        if (component.GetType().Name == "TextComponent") {
            vars.tc = component;
            if (index == 0) {
                vars.tcsX = vars.tc.Settings;
            } else if (index == 1) {
                vars.tcsY = vars.tc.Settings;
            } else if (index == 2) {
                vars.tcsZ = vars.tc.Settings;
            } else if (index == 3) {
                vars.tcsHoriz = vars.tc.Settings;
            } else if (index == 4) {
                vars.tcsTotal = vars.tc.Settings;

                vars.tcsX.Text1 = "X";
                vars.tcsY.Text1 = "Y";
                vars.tcsZ.Text1 = "Z";
                vars.tcsHoriz.Text1 = "Horizontal";
                vars.tcsTotal.Text1 = "Total";

                vars.tcsX.Text2 = current.x.ToString("F3");
                vars.tcsY.Text2 = current.y.ToString("F3");
                vars.tcsZ.Text2 = current.z.ToString("F3");
                vars.tcsHoriz.Text2 = Math.Sqrt(current.x*current.x + current.z*current.z).ToString("F3");
                vars.tcsTotal.Text2 = Math.Sqrt(current.x*current.x + current.y*current.y + current.z*current.z).ToString("F3");

                break;
            }
            index++;
        }
    }
}

update {
    if (current.x != old.x
        || current.y != old.y
        || current.z != old.z) {

        vars.tcsX.Text2 = current.x.ToString("F3");
        vars.tcsY.Text2 = current.y.ToString("F3");
        vars.tcsZ.Text2 = current.z.ToString("F3");
        vars.tcsHoriz.Text2 = Math.Sqrt(current.x*current.x + current.z*current.z).ToString("F3");
        vars.tcsTotal.Text2 = Math.Sqrt(current.x*current.x + current.y*current.y + current.z*current.z).ToString("F3");
    }
}
