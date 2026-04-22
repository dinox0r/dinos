  ; =============================================================================
  ; DEBUG_SUB_KERNEL
  ; =============================================================================
  ;
  ; Paints N scanlines using BACKGROUND_COLOUR, used to mark placeholder regions
  ; on screen during development.
  ;
  ; ⚠ NOTE: Parameter {1} (.BGCOLOR) is declared but unused — BACKGROUND_COLOUR
  ;         is always read from RAM instead.
  ;
  ; Parameters:
  ;   {1} -- background colour (declared but unused)
  ;   {2} -- number of scanlines to paint
  ;
  ; Cycles: varies
  ; =============================================================================
  MACRO DEBUG_SUB_KERNEL
.BGCOLOR SET {1}
.KERNEL_LINES SET {2}
    lda BACKGROUND_COLOUR
    sta COLUBK
    ldx #.KERNEL_LINES
.loop:
    dex
    sta WSYNC
    sta HMOVE
    bne .loop
  ENDM

  ; =============================================================================
  ; INCLUDE_AND_LOG_SIZE
  ; =============================================================================
  ;
  ; Includes a source file and logs its ROM start address, end address, and byte
  ; count to the assembler output. Build-time utility — generates no runtime code.
  ;
  ; Parameters:
  ;   {1} -- path to the source file to include
  ; =============================================================================
  MACRO INCLUDE_AND_LOG_SIZE
  ECHO "---------------------------------------------------------"
ROM_START SET *
  ECHO {1}, "code starts at:", ROM_START, "(", [ROM_START]d, ")"
  INCLUDE {1}
.ROM_END SET *
  ECHO {1}, "code ends at:", .ROM_END, "(", [.ROM_END]d, ")"
.SIZE SET (.ROM_END - ROM_START)
  ECHO "Total:", [.SIZE]d, "bytes"
  ENDM

  ; =============================================================================
  ; LOAD_ADDRESS_TO_PTR
  ; =============================================================================
  ;
  ; Loads a 16-bit ROM address into two consecutive zero-page bytes for use as
  ; an indirect pointer.
  ;
  ; Parameters:
  ;   {1} -- ROM address to load
  ;   {2} -- zero-page destination (low byte; high byte written to {2}+1)
  ;
  ; Cycles: 12
  ; =============================================================================
  MACRO LOAD_ADDRESS_TO_PTR
.ADDRESS SET {1}
.POINTER SET {2}
    lda #<.ADDRESS    ; 3 (3)
    sta .POINTER      ; 3 (6)
    lda #>.ADDRESS    ; 3 (9)
    sta .POINTER+1    ; 3 (12)
  ENDM

  ; =============================================================================
  ; INSERT_NOPS
  ; =============================================================================
  ;
  ; Inserts N NOP instructions inline for cycle-accurate timing padding.
  ; Each NOP costs 2 cycles and 1 ROM byte.
  ;
  ; Parameters:
  ;   {1} -- number of NOPs to insert
  ;
  ; Cycles: {1} * 2
  ; =============================================================================
  MACRO INSERT_NOPS
.NUM_NOPS SET {1}
    REPEAT .NUM_NOPS
      nop     ; 2 cycles per nop, 1 ROM byte
    REPEND
  ENDM

  ; =============================================================================
  ; CHECK_Y_COORD_WITHIN_RANGE
  ; =============================================================================
  ;
  ; Tests whether the current scanline (reg Y) falls within the vertical range of
  ; a sprite, defined as [.VARIABLE, .VARIABLE + .RANGE_SIZE). If in range,
  ; branches to {3}. If out of range, clears reg A and reg X and jumps to {4}.
  ;
  ; Parameters:
  ;   {1} -- zero-page variable holding the sprite's top Y coordinate
  ;   {2} -- sprite height in scanlines
  ;   {3} -- label to branch to when the scanline is within range
  ;   {4} -- label to jump to when the scanline is out of range
  ;
  ; Cycles: 12 (in range) / 18 (out of range)
  ; =============================================================================
  MACRO CHECK_Y_COORD_WITHIN_RANGE
.VARIABLE SET {1}
.RANGE_SIZE SET {2}
.TARGET_BRANCH SET {3}
.END_OF_SCANLINE_BRANCH SET {4}
    tya                ; 2 (2) - A = current scanline (Y)
    sec                ; 2 (4)
    sbc .VARIABLE      ; 3 (7)
    adc #.RANGE_SIZE   ; 2 (9) - A = Y - .VARIABLE + #.RANGE_SIZE
    bcs .TARGET_BRANCH ; 2/3 (11/12)
.y_outside_range:      ; - (11)
    lda #0             ; 2 (13)
    tax                ; 2 (15)
    jmp .END_OF_SCANLINE_BRANCH ; 3 (18)
  ENDM

  ; =============================================================================
  ; LOAD_DINO_GRAPHICS_IF_IN_RANGE
  ; =============================================================================
  ;
  ; Checks whether the current scanline (reg Y) falls within the dino's vertical
  ; range. If so, loads the dino sprite (P0) and missile 0 (M0) configuration
  ; for the next scanline. If not, clears reg A, reg X, and ENAM0, then jumps
  ; to {2}.
  ;
  ; Behavior:
  ; - If the scanline is within the dino's range:
  ;     - Load dino sprite data into reg A.
  ;     - Load M0 configuration and write fine motion (HMM0).
  ;     - Write NUSIZ0 and ENAM0.
  ;     - Leave dino graphics in reg A, ready to be latched with 'sta GRP0'
  ;       on the next scanline.
  ; - If the scanline is outside the dino's range:
  ;     - Clear reg A, reg X, and ENAM0.
  ;     - Jump to {2}.
  ;
  ; M0 data byte encoding:
  ;     bit index: 7 6 5 4 3 2 1 0
  ;                \_____/ \_/ ↑
  ;                 HMM0    │  │
  ;                         │  └─ ENAM0
  ;                      NUSIZ0 (shifted left twice before writing to NUSIZ0)
  ;
  ; ⚠ NOTE: Assumes 24+ cycles have elapsed since the last HMOVE — required for
  ;         safe writes to HMMx registers.
  ;
  ; Parameters:
  ;   {1} -- 1 to insert SEC before SBC (safe subtraction); 0 to skip and save
  ;          2 cycles if carry is already set from a prior operation
  ;   {2} -- label to jump to when the scanline is outside the dino's range
  ;
  ; Cycles: 46 (with SEC) / 44 (without SEC)
  ; =============================================================================
  MACRO LOAD_DINO_GRAPHICS_IF_IN_RANGE
.SET_CARRY_BEFORE_SUBTRACTION SET {1}
.TARGET_BRANCH_WHEN_FINISHED SET {2}
    ; Calculate: (current Y - dino Y) + dino height
    ; If result overflows (carry set), Y is within the obstacle
    tya                              ; 2 (2) - A = current scanline

    IF .SET_CARRY_BEFORE_SUBTRACTION
      sec                            ; 2 (4) -
    ENDIF

    sbc DINO_TOP_Y_INT               ; 3 (7) - A = Y - obstacle Y
    adc #DINO_HEIGHT                 ; 2 (9) - A += obstacle height

    sta HMCLR                        ; 3 (12)
    bcs .dino_y_within_range         ; 2/3 (14/15) - Branch if inside

    IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .dino_y_within_range) & $FF00
      ECHO "PAGE CROSSING","ERROR ",.dino_y_within_range," at ",*
      ERR
    ENDIF

.dino_y_outside_range:        ; - (14) (12 if ignoring the carry)
    lda #0                    ; 2 (16) - Clear A and X
    tax                       ; 2 (18)
    sta ENAM0                 ; 3 (21)

    jmp .TARGET_BRANCH_WHEN_FINISHED  ; 3 (24)

.dino_y_within_range:         ; - (15)
    ; Between this macro's call and execution reaching this point, it
    ; is assumed that 24+ CPU cycles have passed since the last HMOVE,
    ; meaning it is safe to modify HMMx registers without triggering unwanted
    ; shifts.  First, we use HMCLR to reset HMP1 and HMM1. It also clears all
    ; HMMx regs, which is fine — HMM0 and HMP0 are about to be updated anyway.

    ; dino graphics offset
    lda (PTR_DINO_OFFSET),y   ; 5 (20)
    sta HMP0                  ; 3 (23)

    ; --- Dino Missile Setup ---
    ; The data pointed to by PTR_DINO_MISSILE_0_CONF has the following bit layout:
    ;
    ; bit index: 7 6 5 4 3 2 1 0
    ;            \_____/ \_/ ↑
    ;             HMM0    │  │
    ;                     │  └── ENAM0
    ;                   NUSIZ0 (need to be shifted to the left twice)
    lda (PTR_DINO_MISSILE_0_CONF),y  ; 5 (28) - Load config byte into A and X
    sta HMM0                         ; 3 (31)
    sta ENAM0                        ; 3 (34)
    asl                              ; 2 (36)
    asl                              ; 2 (38)
    sta NUSIZ0                       ; 3 (41)

    ; dino graphics- leave them in reg A so they are ready to be used in the 2nd
    ; scanline, this implies not touching reg A for the rest of this scan line
    lda (PTR_DINO_SPRITE),y   ; 5 (46)
  ENDM

  ; =============================================================================
  ; LOAD_DINO_P0_IF_IN_RANGE
  ; =============================================================================
  ;
  ; Checks whether the current scanline (reg Y) falls within the dino's vertical
  ; range. If so, loads the P0 sprite graphics and sets horizontal fine motion
  ; (HMP0) for the next scanline. Unlike LOAD_DINO_GRAPHICS_IF_IN_RANGE, this
  ; version does not configure the missile (M0).
  ;
  ; Result:
  ;   reg A, reg X -- dino sprite graphics byte (in range), or both zeroed
  ;                   (out of range)
  ;
  ; ⚠ NOTE: Assumes 24+ cycles have elapsed since the last HMOVE — required for
  ;         safe writes to HMMx registers.
  ;
  ; Parameters:
  ;   {1} -- 1 to insert SEC before SBC (safe subtraction); 0 to skip and save
  ;          2 cycles if carry is already set from a prior operation
  ;   {2} -- label to jump to when the scanline is outside the dino's range
  ;
  ; Cycles: 28 (with SEC) / 26 (without SEC)
  ; =============================================================================
  MACRO LOAD_DINO_P0_IF_IN_RANGE
.SET_CARRY_BEFORE_SUBTRACTION SET {1}
.TARGET_BRANCH_WHEN_FINISHED SET {2}
    ; Calculate: (Y - dino Y) + dino height
    ; If carry is set after the addition, scanline is within range.
    tya                              ; 2 (2) - A = current scanline

    IF .SET_CARRY_BEFORE_SUBTRACTION
      sec                            ; 2 (4) - Ensure proper SBC result
    ENDIF

    sbc DINO_TOP_Y_INT               ; 3 (7) - A = scanline - dino top Y
    adc #DINO_HEIGHT                 ; 2 (9) - A += dino height

    bcs .dino_y_within_range         ; 2/3 (11/12) - In range if carry set
    IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .dino_y_within_range) & $FF00
      ECHO "PAGE CROSSING","ERROR in .dino_y_within_range",.dino_y_within_range," at ",*
      ERR
    ENDIF
.dino_y_outside_range:               ; - (11 or 9 cycles total if SEC skipped)

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; In case ROM is needed, the padding instructions, that make this branch 
    ; have the same CPU cycle count as the other branch, could be removed
    ;--------------------------------------------------------------------------
    inc $2D                          ; 5 (16) - Waste 5 cycles (2 bytes)
    ;--------------------------------------------------------------------------

    lda #0                           ; 2 (18) - Clear A and X
    tax                              ; 2 (20)

    sta ENAM0                        ; 3 (22)
    sta HMCLR                        ; 3 (25)
    jmp .TARGET_BRANCH_WHEN_FINISHED ; 3 (28)
.dino_y_within_range:                ; - (12)

    ; Safe to write to HMMx at this point in the scanline.
    sta HMCLR                        ; 3 (15) - Clear HMMx, HMP1, HMM1

    ; Set horizontal motion for P0 (dino) from offset table
    lda (PTR_DINO_OFFSET),y          ; 5 (20)
    sta HMP0                         ; 3 (23)

    ; Load sprite graphics for P0 into X using undocumented LAX opcode.
    ; X must not be modified afterward (will be used in the next scanline).
    LAX (PTR_DINO_SPRITE),y          ; 5 (28)
  ENDM

  ; =============================================================================
  ; LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE
  ; =============================================================================
  ;
  ; Checks whether the current scanline (reg Y) falls within the obstacle's
  ; vertical range. If so, loads the obstacle sprite (GRP1) and missile 1 (M1)
  ; configuration for the next scanline. If not, clears reg A, reg X, and
  ; strobes HMCLR, then jumps to {2}.
  ;
  ; Behavior:
  ; - If the scanline is within the obstacle's range:
  ;     - Load obstacle sprite data into reg X (via LAX).
  ;     - Load M1 configuration into reg A.
  ;     - Strobe HMCLR to clear all fine offsets, then write HMM1.
  ; - If the scanline is outside the obstacle's range:
  ;     - Clear reg A and reg X.
  ;     - Strobe HMCLR.
  ;     - Jump to {2}.
  ;
  ; M1 data byte encoding:
  ;     bit index: 7 6 5 4 3 2 1 0
  ;                \_____/ \_/ ↑
  ;                 HMM1    │  │
  ;                         │  └─ ENAM1
  ;                      NUSIZ1 (shifted left twice before writing to NUSIZ1)
  ;
  ; ⚠ NOTE: Assumes 24+ cycles have elapsed since the last HMOVE — required for
  ;         safe writes to HMMx registers.
  ;
  ; Parameters:
  ;   {1} -- 1 to insert SEC before SBC (safe subtraction); 0 to skip and save
  ;          2 cycles if carry is already set from a prior operation
  ;   {2} -- label to jump to when the scanline is outside the obstacle's range
  ;
  ; Cycles: 29 (with SEC) / 27 (without SEC)
  ; =============================================================================
  MACRO LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE
.SET_CARRY_BEFORE_SUBTRACTION SET {1}
.TARGET_BRANCH_WHEN_FINISHED SET {2}
    ; Calculate: (current Y - obstacle Y) + obstacle height
    ; If result overflows (carry set), Y is within the obstacle
    tya                              ; 2 (2) - A = current scanline

    IF .SET_CARRY_BEFORE_SUBTRACTION
      sec                            ; 2 (4) -
    ENDIF

    sbc OBSTACLE_Y                   ; 3 (7) - A = Y - obstacle Y
    adc #OBSTACLE_HEIGHT             ; 2 (9) - A += obstacle height

    bcs .obstacle_y_within_range     ; 2/3 (11/12) - Branch if inside
    IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .obstacle_y_within_range) & $FF00
      ECHO "From LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE macro"
      ECHO "PAGE CROSSING FOR .obstacle_y_within_range","ERROR ",.obstacle_y_within_range," at ",*
      ERR
    ENDIF

.obstacle_y_outside_range:    ; - (11) (9 if ignoring the carry)
    nop                       ; 2 (13) - Wait/waste 2 cycles to prevent 
                              ; strobing HMCLR too soon

    lda #0                    ; 2 (15) - Clear A and X
    tax                       ; 2 (17)

    sta HMCLR                         ; 3 (20)
    jmp .TARGET_BRANCH_WHEN_FINISHED  ; 3 (23)

.obstacle_y_within_range:             ; - (12)
    ; LAX (illegal opcode) is used here because there is no 'ldx (aa),y'. The
    ; non-illegal-opcode alternative is to do 'lda (aa),y' and then 'tax'
    ; incurring in 2 extra cycles, whereas LAX will only cost 5
    LAX (PTR_OBSTACLE_SPRITE),y          ; 5 (17)

    ; Load obstacle missile configuration. Bit Layout duplicated here for ref:
    ;     bit index: 7 6 5 4 3 2 1 0
    ;                \_____/ \_/ ↑
    ;                 HMM1    │  │
    ;                         │  └─ ENAM1
    ;                      NUSIZ1 <- needs to be shifted left twice
    lda (PTR_OBSTACLE_MISSILE_1_CONF),y  ; 5 (23)


    ; ⚠ IMPORTANT:
    ; Before applying fine motion to the obstacle ball, clear fine offsets.
    ; This avoids repeated leftover shifts from the other objects
    ; when restarting the 2x kernel's first scanline.
    ; HMOVE timing notes:
    ; - HMxx writes must not happen within 24 CPU cycles of HMOVE.
    ; - By the time this macro runs, enough time should have passed since
    ;   the last HMOVE for HMCLR to be safely strobed.
    sta HMCLR                            ; 3 (26)

    ; reg X holds a copy of the original (without shifting) missile 1
    ; configuration. Bits 7 to 4 contain the untouched fine adjustment
    sta HMM1                             ; 3 (29)
  ENDM

  ; =============================================================================
  ; CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY
  ; =============================================================================
  ;
  ; Computes (Y − OBSTACLE_Y) + OBSTACLE_HEIGHT without inserting SEC first.
  ; Carry set after the addition indicates the current scanline is within the
  ; obstacle's vertical range. Does not branch — caller must test carry.
  ;
  ; Assumes carry is already set before the call (from a prior SEC or operation).
  ;
  ; Result:
  ;   reg A -- (Y - OBSTACLE_Y) + OBSTACLE_HEIGHT
  ;   carry -- set if scanline is within range, clear otherwise
  ;
  ; Cycles: 7
  ; =============================================================================
  MACRO CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY
    tya                   ; 2 (2) - A = current scanline (Y)
    sbc OBSTACLE_Y        ; 3 (5) - A = Y - OBSTACLE_Y
    adc #OBSTACLE_HEIGHT  ; 2 (7)
  ENDM

  ; =============================================================================
  ; DRAW_DINO
  ; =============================================================================
  ;
  ; Latches the dino sprite graphics byte into GRP0. Reg A must hold the sprite
  ; row for the current scanline before invoking this macro.
  ;
  ; Cycles: 3
  ; =============================================================================
  MACRO DRAW_DINO
    sta GRP0      ; 3 (3)
  ENDM

  ; =============================================================================
  ; DRAW_OBSTACLE
  ; =============================================================================
  ;
  ; Draws the obstacle for the current scanline using GRP1 (sprite) and M1
  ; (missile). Expects the obstacle configuration byte already shifted left by
  ; 2 bits in reg A, and the sprite graphics byte in reg X.
  ;
  ; Parameters:
  ;   reg A -- obstacle config byte (HMM1 | NUSIZ1 | ENAM1), shifted left 2 bits
  ;   reg X -- obstacle sprite graphics byte for the current scanline
  ;
  ; Config byte encoding (before shifting):
  ;       bit index: 7 6 5 4 3 2 1 0
  ;                  \_____/ \_/ ↑
  ;                   HMM1    │  │
  ;                           │  └── ENAM1
  ;                        NUSIZ1 (shifted left twice before writing to NUSIZ1)
  ;
  ; ⚠ NOTE: This macro must be invoked as the first instruction of the scanline.
  ;
  ; Cycles: 16
  ; =============================================================================
  MACRO DRAW_OBSTACLE
    stx GRP1          ; 3 (3)
    sta ENAM1         ; 3 (6) - Enable/disable M1 first
    asl               ; 2 (8)
    asl               ; 2 (10)

    ; OBSTACLE_DUPLICATE will contain a NUSIZx modifier (see constants.asm
    ; for the possible values) that will either stretch or duplicate (this
    ; case) the corresponding sprite
    ora OBSTACLE_DUPLICATE ; 3 (13)

    sta NUSIZ1        ; 3 (16)
  ENDM

  ; =============================================================================
  ; MULTIPLY_A_BY_4
  ; =============================================================================
  ;
  ; Multiplies reg A by 4 in place via two left shifts.
  ;
  ; Cycles: 4
  ; =============================================================================
  MACRO MULTIPLY_A_BY_4
    asl
    asl
  ENDM

  ; =============================================================================
  ; DIVIDE_A_BY_4
  ; =============================================================================
  ;
  ; Divides reg A by 4 (integer division) in place via two right shifts.
  ;
  ; Cycles: 4
  ; =============================================================================
  MACRO DIVIDE_A_BY_4
    lsr
    lsr
  ENDM

  ; =============================================================================
  ; SFX_INIT
  ; =============================================================================
  ;
  ; Initialises SFX_TRACKER_1 to start playback from the first note. Sets the
  ; duration counter to 1 and the note index to 0 (packed value: $08).
  ;
  ; Side effects:
  ;   - writes SFX_TRACKER_1
  ;   - clobbers reg A
  ;
  ; Cycles: 5
  ; =============================================================================
  MACRO SFX_INIT
    lda #%00001000
    sta SFX_TRACKER_1
  ENDM

  ; =============================================================================
  ; SFX_UPDATE_PLAYING
  ; =============================================================================
  ;
  ; Advances mono SFX playback by one frame. Each call either continues the
  ; current note or advances to the next one. A note with duration 0 signals
  ; end-of-sequence: the channel is silenced and the tracker is reset.
  ;
  ; SFX_TRACKER_1 packs two fields into one byte:
  ;   bits 7–3 -- frames elapsed on the current note (duration counter)
  ;   bits 2–0 -- note table index (byte offset divided by 4)
  ;
  ; Each ROM note entry is 4 bytes: [duration, AUDC0, AUDF0, AUDV0].
  ;
  ; Parameters:
  ;   {1} -- ROM label pointing to the start of the sound effect data table
  ;
  ; Side effects:
  ;   - writes AUDC0, AUDF0, AUDV0, SFX_TRACKER_1
  ;   - clobbers reg A, reg X, reg Y
  ; =============================================================================
  MACRO SFX_UPDATE_PLAYING
.SFX_ROM_LABEL SET {1}
    lda SFX_TRACKER_1
    beq .end_update_sfx_mono

    ; The lower 3 bits contain the index into the data byte
    ; with the current playing note, the upper 5 bits contain 
    ; the duration played so far
    tay  ; Clone reg A into reg Y temporarily
    and #%00000111

    MULTIPLY_A_BY_4

    tax

    tya  ; Restore reg A from reg Y and isolate the duration
    lsr
    lsr
    lsr

    ; Check if the duration for the current note has been reached
    cmp .SFX_ROM_LABEL,x
    bcs .play_next_note
.play_current_note:
    ; First, update SFX_TRACKER_1
    ; reg A contains the current duration
    ;
    ; The following instructions do:
    ; (++current_duration << 3) | (note_index / 4)
    tay
    iny
    tya
    asl
    asl
    asl
    sta SFX_TRACKER_1
    txa
    DIVIDE_A_BY_4
    ora SFX_TRACKER_1
    sta SFX_TRACKER_1

    ; reg X still contains the index into the current note sound data
    jmp .play_note
.play_next_note:
    ; Increment the index to the next note data
    txa
    clc
    adc #4
    tax

    ; If the next note's duration is 0, is the signal to stop the sound
    lda .SFX_ROM_LABEL,x
    beq .stop_sound

    ; Update SFX_TRACKER_1.
    ; Set the duration to 1, otherwise, next call to this macro
    ; when the index is 0 will assume that the sound finished playing
    ; (as 0 is used to indicate that)
    lda #1
    asl
    asl
    asl
    sta SFX_TRACKER_1
    txa
    DIVIDE_A_BY_4
    ora SFX_TRACKER_1
    sta SFX_TRACKER_1

.play_note:
    lda .SFX_ROM_LABEL+#1,x
    sta AUDC0
    lda .SFX_ROM_LABEL+#2,x
    sta AUDF0
    lda .SFX_ROM_LABEL+#3,x
    sta AUDV0
    jmp .end_update_sfx_mono
.stop_sound:
    lda #0
    sta AUDC0
    sta AUDF0
    sta AUDV0
    sta SFX_TRACKER_1
.end_update_sfx_mono:
  ENDM


  ; =============================================================================
  ; GENERATE_RANDOM_NUMBER_BETWEEN_160_AND_238
  ; =============================================================================
  ;
  ; Generates a pseudo-random number in the range [160, 238] by combining two
  ; rnd8 calls with masking and addition.
  ;
  ; Result:
  ;   reg A -- random value in [160, 238]
  ;
  ; Side effects:
  ;   - updates RANDOM (via rnd8)
  ;   - clobbers TEMP, reg A
  ; =============================================================================
  MACRO GENERATE_RANDOM_NUMBER_BETWEEN_160_AND_238
    jsr rnd8
    and #63
    sta TEMP
    jsr rnd8
    and #15
    adc #160
    adc TEMP
  ENDM

  ; =============================================================================
  ; SET_STITCHED_SPRITE_X_POS
  ; =============================================================================
  ;
  ; Coarse-positions a stitched sprite (two objects placed side-by-side, e.g.
  ; GRP1 + M1) on screen. Handles four placement cases based on the obstacle X
  ; position, including partial occlusion on both screen edges and fully
  ; off-screen positions.
  ;
  ; Obstacle X values are unsigned in the range 0–170, where:
  ;   obstacle_x = screen_x + 8 (first 8 pixels hidden by HMOVE blanking)
  ;
  ; ┌ obstacle pos (obstacle_x)
  ; │┌ screen pixel
  ; ││                                           obstacle_x = screen_x + 8
  ; ││                                                      |
  ; │└→ -8 -7 ... -1 0     ...     8           ...          |  █    160 161 ...
  ; └──→ 0  1 ...  7 8     ...    16           ...          ↓  █ █  168 169 ...
  ;                ↓ ↓             ↓                         █ █ █   ↓ ↓
  ;      ____ ... __│▓▓▓ HMOVE ▓▓▓|_____       ...            ███_____│______
  ;                 │▓▓▓ black ▓▓▓|                            █      │
  ;                 │▓▓▓ area  ▓▓▓|                            █      │
  ;                 ↑                                                 ↑
  ;       left edge of the screen                      right edge of the screen
  ;
  ;  ┌→ │ 0 ≤ x ≤ 8 │  8 < x ≤ 16 │        16 < x ≤ 162        │ x > 162 │
  ;  │  ├───────────┼─────────────┼────────────────────────────┼─────────┤
  ;  │  │   case 1  │    case 2   │          case 3            │  case 4 │
  ;  │  └───────────┴─────────────┴────────────────────────────┴─────────┘
  ;  └─── "x" refers to obstacle_x
  ;
  ; ⚠ NOTE: Reg A must hold the sprite X position on entry.
  ; ⚠ NOTE: Caller is responsible for invoking 'sta WSYNC' after this macro.
  ;
  ; Parameters:
  ;   {1}   -- TIA object index for the left object (offset into RESP0/HMP0)
  ;   {2}   -- TIA object index for the right object (offset into RESP0/HMP0)
  ;   reg A -- obstacle X position (unsigned, 0–170)
  ;
  ; CPU times:
  ;   scanline 1: up to 27 cycles
  ;   scanline 2: one full scanline
  ;   scanline 3: 28 cycles
  ; =============================================================================
  MACRO SET_STITCHED_SPRITE_X_POS
.OBJECT_1_INDEX SET {1}
.OBJECT_2_INDEX SET {2}
    ; 1st (current) scanline ==================================================
    ;
    ; ⚠ IMPORTANT: This assumes the sprite X position is already in reg A
    ;
    ; Logic summary:
    ; if (reg A ≤ 8) {
    ;   case 1: object1 is fully offscreen (to the left), object2 is partially
    ;   visible
    ; } else if (reg A ≤ 16) {
    ;   case 2: object1 is partially visible, object2 is fully visible
    ; } else if (reg A > 162) {
    ;   case 4: object1 is partially offscreen (to the right), object2 is fully
    ;   hidden
    ; } else if (reg A > 170) {
    ;   case 5: both objects are fully hidden, strobe their registers
    ;   on HBLANK so to make sure they stay out of screen (hidden behind the
    ;   the HMOVE black curtain
    ; } else {
    ;   setup logic before invoking case 3
    ;   case 3: both object1 and object2 are fully visible
    ; }
    cmp #8                                                  ; 2 (5)
    bcc .case_1__obj1_fully_hidden_obj2_partially_visible   ; 2/3 (7/8)
    cmp #17                                                 ; 2 (9)
    bcc .case_2__obj1_partially_visible_obj2_fully_visible  ; 2/3 (11/12)
    cmp #171
    bcs .case_5__both_obj1_and_obj2_fully_hidden
    cmp #163                                                ; 2 (13)
    bcs .case_4__obj1_partially_visible_obj2_fully_hidden   ; 2/3 (15/16)

.prepare_before_invoking_case_3: ; - (15)
    ; Based on results from tools/simulate-coarse-pos-loop.py: Starting with an
    ; input value of #45, the coarse positioning algorithm sets the object's
    ; coarse location and leaves a remainder in register A within the range
    ; [-7, 7], suitable for HMOVE fine adjustment.
    ;
    ; The earliest screen position set by this routine is physical pixel 5 (the
    ; 6th pixel, zero-indexed). Earlier positions are handled by: 
    ; - Case 1: input x = 0 to 8 → offscreen (pixels -8 to 0)
    ; - Case 2: input x = 9 to 16 → HMOVE blanking area (pixels 1 to 8)
    ;
    ; The latest valid position before requiring another scanline is pixel 154
    ; (indexed as 153), which corresponds to input x = 162.
    ;
    ; Thus, Case 3 handles obstacle_x values from 16 (maps to screen pixel 8)
    ; up to 162 (maps to pixel 153).
    ;
    ; To align with the algorithm's expected input range, obstacle_x = 16 must
    ; be translated to x = 3 (the value that places at pixel 8), so 13 is
    ; subtracted from the base input (#45).
    clc          ; 2 (17)
    adc #45-#13  ; 2 (19)

    sec   ; 2 (21) - Set carry to do subtraction. Remember SBC is
          ;          actually an ADC with A2 complement
          ;          A - B = A + ~B + 1
          ;                           ^this is the carry set by sec

    jmp .case_3__obj1_and_obj2_fully_visible       ; 3 (24)

.case_1__obj1_fully_hidden_obj2_partially_visible: ; - (8)
    sta WSYNC      ; 3 (11)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)
    ; Strobing M1 after HMOVE set the missile coarse position on screen pixel 
    ; 3 (the fourth pixel starting from pixel 0). This was found after testing
    ; taking screenshots in Stella. The offset needs to be adjusted for those
    ; 4 pixels by doing a -4 fine adjustment with HMM1. GRP1 position doesn't 
    ; matter as it will be zero (as it's offscreen)
    sta RESP0+.OBJECT_2_INDEX        ; 3 (6)
    ; This doesn't matter, as it should have 0 as value (is not visible)
    ;sta OBJECT_1
    ; offset calculation
    sec
    sbc #15-#4
    jmp .end_of_cases_1_2_and_3

.case_2__obj1_partially_visible_obj2_fully_visible: ; - (12)
    sta WSYNC      ; 3 (15)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)
    sta RESP0+.OBJECT_1_INDEX        ; 3 (6)

    ; Strobing RESPx at this point places the GRP1 coarse position at screen
    ; pixel 4 (the fifth pixel, zero-indexed). This was determined empirically
    ; using Stella screenshots.
    ;
    ; The obstacle_x input will be in the range [8, 16], where:
    ;   - x = 8  → maps to screen pixel 0 (just off the left edge)
    ;   - x = 16 → maps to screen pixel 8 (last pixel of the HMOVE blanking
    ;              region)
    ;
    ; For these values, the following fine offsets are applied:
    ;   x =  8 → offset -4 (index  3 in the offset table)
    ;   x =  9 → offset -3 (index  4)
    ;   ...
    ;   x = 15 → offset  3 (index 10)
    ;   x = 16 → offset  4 (index 11)
    ;
    ; This offset is computed as: offset = x - 6
    ;
    ; Note: the accumulator is later shared with case 3 logic, which expects the
    ; value (obstacle_x - 15). To align with that shared code path, the
    ; subtraction is done here.
    sec         ; 2 (8)
    sbc #5+#15  ; 2 (10)

    pha      ; 3 (13) wait/waste 12 CPU cycles (in 4 bytes) until the CPU is at
    pla      ; 4 (17) cycle 22 so strobing RESM1 leaves it 8px from where GRP1
    sta $2D  ; 3 (20)
    ldx #$F0 ; 2 (22)

    ; Strobing RESP0+.OBJECT_2_INDEX at CPU cycle 25 works well regardless
    ; .OBJECT_2_INDEX refers to a GRPx or a MISSILE
    sta RESP0+.OBJECT_2_INDEX   ; 3 (25)

    ; At cycle 25, M1 appears 7px to the right of GRP1 instead of 8px. To fix
    ; this 1px misalignment, here a slight nudge to the right is applied to M1
    ; using HMM1

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; Once ROM becomes critical, this offset code can be removed. In that
    ; case, the 12-cycle setup before strobing RESP0+.OBJECT_2_INDEX could be
    ; replaced with a cheaper 'inc $2D' instruction.
    ;
    ; Side effect: When the stitched sprite exits the screen on the left edge,
    ; a small visual artifact will appear. The glitch is noticeable but minor,
    ; and may be an acceptable trade-off for the ROM savings.
    ;--------------------------------------------------------------------------
    stx HMP0+.OBJECT_2_INDEX    ; 3 (28)

    jmp .end_of_cases_1_2_and_3 ; 3 (31)

.case_4__obj1_partially_visible_obj2_fully_hidden: ; - (16)
    sta WSYNC      ; 3 (19)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)

    ; For case 4, RESP1 will be strobed at CPU cycle 70. The strobe completes
    ; at cycle 73.
    ;
    ; Theoretically, strobing RESP1 at CPU cycle 73 corresponds to TIA cycle 219
    ; (73 * 3), which should map to screen pixel 151 (219 - 68 cycles of HBLANK),
    ; but in practice, GRP1 appears at screen pixel 156... Go figure ¯\_(ツ)_/¯
    ;
    ; First, configure the fine offset. Then, delay until cycle 70 for RESP1.
    ;
    ; The rightmost position case 3 can handle without resorting to an extra 
    ; scanline is x=162 which maps to screen pixel 154, case 4 should continue
    ; from here, meaning the input x will be 163 onwards.
    ;
    ; For obstacle_x = 163, the obstacle should appear at screen pixel 155.
    ; However, the coarse position after strobing RESP1 at cycle 73 results in
    ; GRP1 being placed at screen pixel 156. This requires an offset of -1 pixels
    ; to correct the position. Similarly:
    ;   x = 164 → offset -2
    ;   x = 165 → offset -3
    ;   ...
    ;   x = 171 → offset +4

    sec             ; 2 (5)
    ; reg A contains x ∈ [163, 171]
    ; x needs to be mapped to index ∈ [6, 11] (offsets from -1 to 4)
    ; This is computed as: x - 157
    ; But A will later be shared with case 1, 2 and 3 logic, which subtract 15.
    sbc #157+#15        ; 2 (7)

    ; reg A now holds the correct offset index to be used later during
    ; the 4th scanline. The CPU is currently at cycle 7 and must reach cycle 71,
    ; leaving 64 cycles to waste.
    ;
    ; The following loop consumes 59 cycles:
    ;   - 11 iterations × 5 cycles (DEX + BNE) = 55 cycles
    ;   - Final iteration (DEX + BNE fails) = 4 cycles
    ldx #12         ; 2 (9)
.wait_until_cpu_is_at_cycle_68:         ; - (9) \
    dex                                 ; 2      > total: 59 cycles
    bne .wait_until_cpu_is_at_cycle_68 ; 2/3   /

    IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .wait_until_cpu_is_at_cycle_68) & $FF00
      ECHO "PAGE CROSSING in .wait_until_cpu_is_at_cycle_68","ERROR ",.wait_until_cpu_is_at_cycle_68," at ",*
      ERR
    ENDIF

    ; The CPU is now at cycle 68. A dummy instruction fills the gap to cycle 70.
    nop            ; 2 (70)

    sta RESP0+.OBJECT_1_INDEX     ; 3 (73)

    jmp .end_case_4               ; 3 (76)

.case_5__both_obj1_and_obj2_fully_hidden:
    sta WSYNC      ; 3 (?)
    ; 2nd scanline ============================================================
    sta HMOVE      ; 3 (3)
    sta RESP0+.OBJECT_1_INDEX
    sta RESP1+.OBJECT_2_INDEX
    sta WSYNC
    sta HMOVE
    jmp .end_case_5


.case_3__obj1_and_obj2_fully_visible: ; - (24)
    sta WSYNC      ; 3 (27)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)

.div_by_15_loop:        ; - (3)
    sbc #15             ; 2 (5) - Divide by 15 (sucessive subtractions)
    bcs .div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)
    IF (* ^ .div_by_15_loop) & $FF00
      ECHO "PAGE CROSSING","ERROR in .div_by_15_loop",.div_by_15_loop," at ",*
      ERR
    ENDIF

    sta RESP0+.OBJECT_1_INDEX
    sta RESP0+.OBJECT_2_INDEX

.end_of_cases_1_2_and_3:
    sta WSYNC      ; if coming from scenario A, CPU count after this will be 33
                   ; if coming from scenario B, MAX CPU count will be 76
                   ; scenario A will jump past this 'sta WSYNC' and below's
                   ; 'sta HMOVE' (scenario A will take care of the HMOVE)
    ; 3rd scanline ============================================================
.end_case_4:
                   ; - (0)
    sta HMOVE      ; 3 (3)

    ; This section may look a bit like magic at first glance. Originally, this
    ; logic used a lookup table with 16 entries (16 bytes total) plus
    ; additional code to compute the index from the remainder. However, that
    ; approach consumed too much ROM, so it was replaced by the arithmetic
    ; below.
    ;
    ; The remainder here is a negative value in the range [-15 .. -1], stored
    ; as an unsigned 8-bit number. Conceptually, +15 was added to this
    ; remainder to map it into a table index:
    ;
    ;   -15 + 15 = index 0  -> HMMx $70 (-7 pixels)
    ;   -14 + 15 = index 1  -> HMMx $60 (-6 pixels)
    ;   -13 + 15 = index 2  -> HMMx $50 (-5 pixels)
    ;     ...
    ;    -8 + 15 = index 7  -> HMMx $00 (no offset)
    ;     ...
    ;    -1 + 15 = index 14 -> HMMx $E0 (+7 pixels)
    ;
    ; Shown below are the unsigned representations of these negative
    ; values, along with their expected HMMx offsets:
    ;
    ;     unsigned
    ;         ↓            expected offset (HMMx)
    ;  -15 = 241 = 11110001 | $70 = 01110000
    ;  -14 = 242 = 11110010 | $60 = 01100000
    ;  -13 = 243 = 11110011 | $50 = 01010000
    ;    ...
    ;   -8 = 248 = 11111000 | $00 = 00000000
    ;   -7 = 249 = 11111001 | $F0 = 11110000
    ;   -6 = 250 = 11111010 | $E0 = 11100000
    ;    ...
    ;   -1 = 255 = 11111111 | $90 = 10010000
    ;
    ; The original table also had a 16th entry ($80, +8 pixels), used to
    ; eliminate the 1-pixel gap between the two "sprite" objects. Object 2 was
    ; offset using the computed index, and object 1 (to the left) used index+1,
    ; effectively shifting it one pixel to the right and closing the gap.
    ;
    ; Observing the bit patterns above, we want to transform:
    ;   241 (11110001) -> $70 (01110000)
    ;   242 (11110010) -> $60 (01100000)
    ;   etc.
    ;
    ; If we focus only on the lower 4 bits (e.g. 0001 for 241), converting them
    ; to 0111 (7) and then shifting left by 4 bits yields the desired HMMx
    ; value.
    ;
    ; This conversion can be expressed as: (8 - input) << 4
    ;
    ; The upper 4 bits do not matter, since the left shift discards them
    ; entirely. This formula holds for the full range of values.
    ;
    sta TEMP       ; 3 (6)
    lda #8         ; 2 (8)
    sec            ; 2 (10)
    sbc TEMP       ; 3 (13)
    asl            ; 2
    asl            ; 2
    asl            ; 2
    asl            ; 2  ; 4 ASLs = << 4 (21)

    ; Subtract $10 from the HMMx value computed above, effectively shifting the
    ; horizontal offset 1 pixel to the right (e.g. $70 -> $60, $00 -> $F0).
    tax            ; 2 (23)
    sec
    sbc #$10

    sta HMP0+.OBJECT_1_INDEX  ; 3 (28)
    stx HMP0+.OBJECT_2_INDEX  ; 3 (31)
.end_case_5:
    ;❗ IMPORTANT: Caller is responsible of invoking 'sta WSYNC'
  ENDM


  ; =============================================================================
  ; SET_SPRITE_X_POS
  ; =============================================================================
  ;
  ; Coarse-positions a single TIA sprite object on screen using the same
  ; case-based approach as SET_STITCHED_SPRITE_X_POS, but for one object only.
  ; Handles partial occlusion on both edges and fully off-screen positions.
  ;
  ; ⚠ NOTE: Reg A must hold the sprite X position on entry.
  ;
  ; Parameters:
  ;   {1}   -- TIA object index (offset into RESP0/HMP0)
  ;   reg A -- sprite X position (unsigned, 0–170)
  ;
  ; CPU times:
  ;   scanline 1: up to 24 cycles
  ;   scanline 2: one full scanline
  ;   scanline 3: 25 cycles
  ; =============================================================================
  MACRO SET_SPRITE_X_POS
.OBJECT_INDEX SET {1}
    ; (current) scanline ==================================================
    ;
    cmp #9                                                  ; 2 (5)
    bcc .case_1_and_5__obj_fully_offscreen   ; 2/3 (7/8)
    cmp #171
    bcs .case_1_and_5__obj_fully_offscreen
    cmp #17                                                 ; 2 (9)
    bcc .case_2__obj_partially_visible_on_left_side_of_screen  ; 2/3 (11/12)
    cmp #163                                                ; 2 (13)
    bcs .case_4__obj_partially_visible_on_right_side_of_screen   ; 2/3 (15/16)
    ; case 3: obj fully visible
.prepare_before_invoking_case_3:    ; - (15)
    clc                             ; 2 (17)
    adc #45-#13                     ; 2 (19)
    sec                             ; 2 (21)
    jmp .case_3__obj_fully_visible  ; 3 (24)

.case_1_and_5__obj_fully_offscreen: ; - (8)
    sta WSYNC                       ; 3 (11)
    ; 2nd scanline ============================================================
                                    ; - (0)
    sta HMOVE                       ; 3 (3)
    sta RESP0+.OBJECT_INDEX         ; 3 (6)
    jmp .end_of_cases_1_and_5       ; 3 ()

.case_2__obj_partially_visible_on_left_side_of_screen: ; - (12)
    sta WSYNC                       ; 3 (15)
    ; 2nd scanline ============================================================
                                    ; - (0)
    sta HMOVE                       ; 3 (3)
    sta RESP0+.OBJECT_INDEX         ; 3 (6)
    sec                             ; 2 (8)
    sbc #2+#15                      ; 2 (10)
    jmp .end_of_cases_2_and_3       ; 3 (33)

.case_4__obj_partially_visible_on_right_side_of_screen: ; - (16)
    sta WSYNC                       ; 3 (19)
    ; 2nd scanline ============================================================
                                    ; - (0)
    sta HMOVE                       ; 3 (3)
    sec                             ; 2 (5)
    sbc #160+#15                    ; 2 (7)
    ldx #12                         ; 2 (9)
.wait_until_cpu_is_at_cycle_71:         ; - (9) \
    dex                                 ; 2      > total: 59 cycles
    bne .wait_until_cpu_is_at_cycle_71  ; 2/3   /
    ;sta $2D                        ; 3 (71)
    nop                             ; 2 (70)
    sta RESP0+.OBJECT_INDEX         ; 3 (73)
    jmp .end_case_4                 ; 3 (76) - No WSYNC

.case_3__obj_fully_visible: ; - (24)
    sta WSYNC      ; 3 (27)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)

.div_by_15_loop:        ; - (3)
    sbc #15             ; 2 (5) - Divide by 15 (sucessive subtractions)
    bcs .div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)
    sta RESP0+.OBJECT_INDEX

.end_of_cases_2_and_3:
    sta WSYNC      ;
    ; 3rd scanline ============================================================
.end_case_4:
                   ; - (0)
    sta HMOVE      ; 3 (3)
    ldx #0         ; 2 (5)

    ; Offsets the remainder from [-14, 0] to [0, 14]
    ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
    clc            ; 2 (7)
    adc #15        ; 2 (9)
    tay            ; 2 (11)
    pha                         ; 4 (15) - Wait/waste 7 cycles (2 bytes)
    pla                         ; 3 (18)
    lda FINE_POSITION_OFFSET,y  ; 4 (22) - y should range between [-7, 7]
    sta HMP0+.OBJECT_INDEX      ; 3 (25)

.end_of_cases_1_and_5:
  ENDM


  ; =============================================================================
  ; CLOUD_KERNEL
  ; =============================================================================
  ;
  ; Renders the cloud layer, one scanline per iteration, looping until reg Y
  ; reaches zero. On each scanline, checks whether the current row falls within
  ; the cloud's vertical range; if so, loads the appropriate sprite row into
  ; GRP0 and/or GRP1. If not, clears those registers.
  ;
  ; {1} and {2} select which player registers to drive. When both are set, two
  ; sprite halves are composited: cloud part 1 via GRP0, cloud part 2 via GRP1.
  ;
  ; Parameters:
  ;   {1}   -- 1 to enable GRP0 (cloud part 1); 0 to disable
  ;   {2}   -- 1 to enable GRP1 (cloud part 2); 0 to disable
  ;   reg Y -- scanline counter (counts down to 0)
  ;
  ; Side effects:
  ;   - writes GRP0 and/or GRP1
  ;   - clobbers reg A, reg X, TEMP
  ; =============================================================================
  MACRO CLOUD_KERNEL
.USE_GRP0 SET {1}
.USE_GRP1 SET {2}

.start_of_scanline:
    sta WSYNC   ; 3 (70 -> 73) if coming from '.end_of_scanline'
                ; - (0)
    sta HMOVE   ; 3 (3)
    IF .USE_GRP0
      stx GRP0  ; 3 (6)
    ENDIF

    IF .USE_GRP1
      sta GRP1  ; 3 (9)
    ENDIF

    IF .USE_GRP0 | .USE_GRP1
      sec                        ; 2 (11)
      tya                        ; 2 (13)
      sbc CURRENT_CLOUD_TOP_Y    ; 3 (16)
      adc #CLOUD_HEIGHT          ; 2 (18)
      bcs .cloud_y_within_range  ; 2/3 (20/21)

      IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .cloud_y_within_range) & $FF00
        ECHO "PAGE CROSSING IN CLOUD KERNEL MACRO (.cloud_y_within_range branch)","ERROR ",.cloud_y_within_range," at ",*
        ERR
      ENDIF
.cloud_y_outside_range:          ; - (18)
      lda #0                     ; 2 (20)
      tax                        ; 2 (22)
      jmp .end_of_scanline       ; 3 (28)
.cloud_y_within_range:           ; - (21)
    ENDIF

    ; IF use_grp0 AND ignore_grp1
    IF .USE_GRP0 & !.USE_GRP1
      OFFSET_SPRITE_POINTER_BY_Y_COORD CURRENT_CLOUD_TOP_Y, TEMP, CLOUD_PART_1_END ; 17 (41)
      LAX (TEMP),y ; 5 (46)
    ENDIF
    ; ELSE IF use_grp1 AND ignore_grp0
    IF .USE_GRP1 & !.USE_GRP0
      OFFSET_SPRITE_POINTER_BY_Y_COORD CURRENT_CLOUD_TOP_Y, TEMP, CLOUD_PART_2_END ; 17 (41)
      lda (TEMP),y ; 5 (46)
    ENDIF
    ; ELSE
    IF .USE_GRP0 & .USE_GRP1
      OFFSET_SPRITE_POINTER_BY_Y_COORD CURRENT_CLOUD_TOP_Y, TEMP, CLOUD_PART_1_END ; 17 (21 -> 38)
      LAX (TEMP),y      ; 5 (43)
      OFFSET_SPRITE_POINTER_BY_Y_COORD CURRENT_CLOUD_TOP_Y, TEMP, CLOUD_PART_2_END ; 17 (60)
      lda (TEMP),y      ; 5 (65)
    ENDIF

.end_of_scanline:
    dey                ; 2 (max CPU count here would be 67)
    bne .start_of_scanline ; 2/3 (69/70)
    IF ENABLE_PAGE_CROSSING_CHECK && (* ^ .start_of_scanline) & $FF00
      ECHO "PAGE CROSSING IN CLOUD KERNEL MACRO (.start_of_scanline branch)","ERROR ",.start_of_scanline," at ",*
      ERR
    ENDIF
  ENDM

  ; =============================================================================
  ; OFFSET_SPRITE_POINTER_BY_Y_COORD
  ; =============================================================================
  ;
  ; Computes a ROM sprite pointer by subtracting the sprite's top Y coordinate
  ; from the sprite's end-of-data label address. The resulting pointer, when
  ; indexed by reg Y (counting down), yields the correct scanline row on each
  ; iteration.
  ;
  ; Parameters:
  ;   {1} -- zero-page variable holding the sprite's top Y coordinate
  ;   {2} -- zero-page destination for the computed pointer (low byte;
  ;          high byte written to {2}+1)
  ;   {3} -- ROM label marking the end of the sprite data table
  ;
  ; Cycles: 17
  ; =============================================================================
  MACRO OFFSET_SPRITE_POINTER_BY_Y_COORD
.Y_COORD SET {1}
.SPRITE_PTR SET {2}
.SPRITE_ROM_LABEL SET {3}
    sec                           ; 2 (2)
    lda #<.SPRITE_ROM_LABEL       ; 2 (4)
    sbc .Y_COORD                  ; 3 (7)
    sta .SPRITE_PTR               ; 3 (10)
    lda #>.SPRITE_ROM_LABEL       ; 2 (12)
    sbc #0                        ; 2 (14)
    sta .SPRITE_PTR+1             ; 3 (17)
  ENDM



  ; =============================================================================
  ; UPDATE_X_POS
  ; =============================================================================
  ;
  ; Subtracts a fixed-point velocity from a fixed-point position, implementing
  ; horizontal scrolling. Borrow from the fractional subtraction propagates into
  ; the integer part via the carry flag.
  ;
  ; Parameters:
  ;   {1} -- zero-page variable: position integer part
  ;   {2} -- zero-page variable: position fractional part
  ;   {3} -- velocity integer part (zero-page variable or immediate constant)
  ;   {4} -- velocity fractional part (zero-page variable or immediate constant)
  ;   {5} -- 1 to treat {3}/{4} as immediate constants; 0 to read from zero page
  ;
  ; Side effects:
  ;   - updates {1} and {2} in zero page
  ;   - clobbers reg A
  ; =============================================================================
  MACRO UPDATE_X_POS
.OBJECT_POSITION_INTEGER_PART SET {1}
.OBJECT_POSITION_FRACT_PART SET {2}
.OBJECT_VELOCITY_INTEGER_PART SET {3}
.OBJECT_VELOCITY_FRACTIONAL_PART SET {4}
.TREAT_SPEED_AS_A_CONSTANT SET {5}

    sec
    lda .OBJECT_POSITION_FRACT_PART

    IF .TREAT_SPEED_AS_A_CONSTANT
      sbc #.OBJECT_VELOCITY_FRACTIONAL_PART
    ELSE
      sbc .OBJECT_VELOCITY_FRACTIONAL_PART
    ENDIF

    sta .OBJECT_POSITION_FRACT_PART

    lda .OBJECT_POSITION_INTEGER_PART

    IF .TREAT_SPEED_AS_A_CONSTANT
      sbc #.OBJECT_VELOCITY_INTEGER_PART
    ELSE
      sbc .OBJECT_VELOCITY_INTEGER_PART
    ENDIF

    sta .OBJECT_POSITION_INTEGER_PART
  ENDM
