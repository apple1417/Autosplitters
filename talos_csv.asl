state("Talos") {
    float xPos: 0x12BBBC0, 0, 0x3C;
    float yPos: 0x12BBBC0, 0, 0x40;
    float zPos: 0x12BBBC0, 0, 0x44;
    float xSpeed: 0x12BBBC0, 0, 0x70;
    float ySpeed: 0x12BBBC0, 0, 0x74;
    float zSpeed: 0x12BBBC0, 0, 0x78;
}

init {
    vars.logFilePath = Directory.GetCurrentDirectory() + "\\talos_movement.csv";
    System.IO.File.WriteAllText(vars.logFilePath, "Time,X Pos,Y Pos,Z Pos,X Speed,Y Speed,Z Speed\n");
}

split {
    System.IO.File.AppendAllText(vars.logFilePath,
        timer.CurrentTime.RealTime.ToString() + ","
        + current.xPos.ToString() + ","
        + current.yPos.ToString() + ","
        + current.zPos.ToString() + ","
        + current.xSpeed.ToString() + ","
        + current.ySpeed.ToString() + ","
        + current.zSpeed.ToString() + "\n"
    );
}
