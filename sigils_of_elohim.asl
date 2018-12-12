state("Sigils") {
    bool inPuzzle       : 0x00a0576c, 0x684;
    int puzzleIndex     : 0x00a1d1d0, 0xc, 0x24, 0x14, 0x10, 0x48;
    float displayedTime : 0x00a1d1d0, 0xc, 0x24, 0x14, 0x10, 0x54;
    double globalTime   : 0x00a1d1f4, 0x58;
}

init {
    vars.displayState = 0;
    vars.doubleSplit = 0;
}

start {
    if (current.inPuzzle && !old.inPuzzle) {
        vars.displayState = 0;
        vars.doubleSplit = 0;
        return true;
    }
}

isLoading {
    return current.globalTime == old.globalTime;
}

exit {
    timer.IsGameTimePaused = true;
}

update {
    /*
      Try to use the displayed timer to work when you solve a puzzle
      We do this here so that it isn't interrupted by double split protection
      
      Initally the timer will just be frozen
      Once you get down to one piece left it will start updating
      When you solve the puzzle it will freeze again
      Occasionally we'll catch it between updates so it will have the save value 2 frames in a row,
       meaning we look for 4 in a row to be sure it's frozen
    */
    switch ((int) vars.displayState) {
        // Frozen in new puzzle
        case 0: {
            if (current.displayedTime != old.displayedTime) {
                vars.displayState = 1;
            }
            break;
        } 
        // Timer updated last frame, but not this one
        case 1: {
            if (current.displayedTime == old.displayedTime) {
                vars.displayState = 2;
            }
            break;
        }
        // Timer hasn't updated for a few frames
        case 2: case 3:{
            if (current.displayedTime == old.displayedTime) {
                vars.displayState++;
            // Incase it just got stuck
            } else { 
                vars.displayState = 1;
            }
            break;
        }
        // Cases 4 and 5 are handled in split
    }
}

split {
    // Otherwise we'll split when you go into the main menu to switch puzzles
    if (!current.inPuzzle) {
        vars.doubleSplit = 0;
        return false;
    }
    
    // This gives some leniency on timing between various vars updating
    if (vars.doubleSplit < 30) {
        vars.doubleSplit++;
        return false;
    }
    
    if (vars.displayState == 4) {
        if (current.puzzleIndex % 8 == 7) {
            vars.displayState = 5;
            vars.doubleSplit = 0;
            return true;
        }
        vars.displayState = 0;
    }
    
    if (old.puzzleIndex != current.puzzleIndex) {
        if (vars.displayState != 5) {
            vars.displayState = 0;
            vars.doubleSplit = 0;
            return true;
        }
        vars.displayState = 0;
    }
}
