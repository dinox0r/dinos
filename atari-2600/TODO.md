# TODO
======

[ ] Stars and moon layer
    [ ] Write a set x position macro for a single sprite (Px)
        (cp/paste/update the current `SET_STITCHED_SPRITE_X_POS`)
    [ ] Move the set x position macro into a subroutine
        so it can be called twice (why a macro first and then
        a subroutine? To copy/paste edit in the same file)
    [ ] Draw the stars sprites

[ ] Merge a few zero bytes of the ptero sprite together to
    save some ROM

[ ] In both `SET_SPRITE_X_POS` and `SET_STITCHED_SPRITE_X_POS`
    check case 4 and strobe 1 CPU cycle earlier, and do
    `jmp end_case_4` instead of a `nop`, `sta HMOVE` and 
    then `jmp end_case_4`. This might shave a few ROM bytes.

