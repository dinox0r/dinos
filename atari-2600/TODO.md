# TODO
======

[x] Stars and moon layer
    [-] ~Write a set x position macro for a single sprite (Px)
        (cp/paste/update the current `SET_STITCHED_SPRITE_X_POS`)~
        discarded. Using the routine from AtariAge forum
    [-] ~Move the set x position macro into a subroutine
        so it can be called twice (why a macro first and then
        a subroutine? To copy/paste edit in the same file)~
        discarded. Doing 2 consecutive sta RESP0,x leaves too
        much gap (what was I even thinking, it's too obvious)
    [x] Draw the stars sprites
    [x] Add the 2 scanlines I took from play area to the sky kernel

[ ] Merge a few zero bytes of the ptero sprite together to
    save some ROM

[x] In both `SET_SPRITE_X_POS` and `SET_STITCHED_SPRITE_X_POS`
    check case 4 and strobe 1 CPU cycle earlier, and do
    `jmp end_case_4` instead of a `nop`, `sta HMOVE` and 
    then `jmp end_case_4`. This might shave a few ROM bytes.

[ ] Try the idea of using 2 sprites for obstacles and then once
    the leftmost one is out of screen swap to 1 sprite and set
    the x position to the one of the rightmost obstacle in the 
    2 sprite formation (might require some extra ROM)

[ ] Check if the case 4 of the SET POS macro could be removed
    using just more HMOVE

[ ] Move to 8K ROM format?
[x] Add log messages measuring the size of each section

## Features

[ ] Day/night cycle
[ ] Gravel
[ ] Score (EPIC)
[ ] Splash screen
[ ] Game over text (how?)
[ ] More cacti sprites
[ ] 2 clusters of cacti (idea)

