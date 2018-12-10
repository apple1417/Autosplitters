state("Sigils") {
    bool inPuzzle       : 0x00a0576c, 0x684;
    float lastSolveTime : 0x00a1d1d0, 0xc, 0x24, 0x14, 0x10, 0x50;
}

init {
    vars.doubleSplit = 0;
}

start {
    if (current.inPuzzle && !old.inPuzzle) {
        vars.doubleSplit = 0;
        return true;
    }
}

split {
    if (vars.doubleSplit < 30) {
        vars.doubleSplit++;
        return false;
    }

    if (current.lastSolveTime != old.lastSolveTime) {
        vars.doubleSplit = 0;
        return true;
    }
}
