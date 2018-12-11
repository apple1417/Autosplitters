state("Sigils") {
    /*
      True when you're in a puzzle, or on the reward screen after solving one
      False pretty much everywhere else, including clicking on a reward without solving a puzzle
    */
    bool inPuzzle       : 0x00a0576c, 0x684;
    /*
      The index of the puzzle you were last in, or 10092 if you just restarted.
      0-indexed starting at Blue 1, goes in normal reading direction
    */
    int puzzleIndex     : 0x00a1d1d0, 0xc, 0x24, 0x14, 0x10, 0x48;
    /*
      Holds the float version of the last time the timer displayed, or 0 after a restart
      Only updates when the timer is being displayed, when there's one piece left
    */
    float displayedTime : 0x00a1d1d0, 0xC, 0x24, 0x14, 0x10, 0x54;
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

split {
    // If you leave a puzzle and enter one with a different it would normally split
    if (!current.inPuzzle) {
        vars.doubleSplit = 0;
        return false;
    }
    // This gives some leniency on timing between various vars updating
    if (vars.doubleSplit < 30) {
        vars.doubleSplit++;
        return false;
    }

    // If puzzle indexes change we can probably split
    if (current.puzzleIndex != old.puzzleIndex) {
        // If we're coming from a reward screen we'll already have split
        if (vars.displayState == 3) {
            vars.displayState = 0;
            return false;
        }
        
        vars.doubleSplit = 0;
        print("index change");
        return true;
    }
    
    /*
      When you solve a reward puzzle the index doesn't update until you enter the next one
      We want to split on the solve though, so we have to deal with the displayed timer
      The timer will be static when we enter the split, then when there's one piece left it will
       start updating
      After it starts updating it will stop when you solve it
      Unfortuantly sometimes it get stuck for a frame so it'll need to be the same value for two for
       us to be sure
      After that we just need to prevent splits when the index changes, cause we'll already have
       split for the puzzle
      
      Unfortuantly you can't tell between the timer stopping because you finished or because you
       picked up one of the pieces again, it will split anyway
      This should be rare, even if you don't know what you're doing, and it won't split a second
       time when you solve it anyway, so it's probably fine to leave as-is
    */
    if (current.puzzleIndex % 8 == 7) {
        switch ((int) vars.displayState) {
            // Before timer starts updating
            case 0: {
                if (current.displayedTime != old.displayedTime) {
                    vars.displayState = 1;
                }
                break;
            }
            // Timer updated last frame
            case 1: {
                if (current.displayedTime == old.displayedTime) {
                    vars.displayState = 2;
                }
                break;
            }
            // Timer was the same last frame
            case 2: {
                if (current.displayedTime == old.displayedTime) {
                    vars.displayState = 3;
                    vars.doubleSplit = 0;
                    return true;
                // Incase it got stuck
                } else {
                    vars.displayState = 1;
                }
                break;
            }
        }
    }
}
