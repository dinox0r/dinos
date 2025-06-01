
  ; Paints N scanlines with the given background colour, used to draw
  ; placeholder areas on the screen
  ; --------------------------------------------------------------------
  MACRO DEBUG_SUB_KERNEL
.BGCOLOR SET {1}
.KERNEL_LINES SET {2}
    lda #.BGCOLOR
    sta COLUBK
    ldx #.KERNEL_LINES
.loop:
    dex
    sta WSYNC
    sta HMOVE
    bne .loop
  ENDM

  ; Loads a 16 bit value from ROM into 2 consecutive bytes in zero page RAM
  ; --------------------------------------------------------------------
  MACRO LOAD_ADDRESS_TO_PTR  ; 12 cycles
.ADDRESS SET {1}
.POINTER SET {2}
    lda #<.ADDRESS    ; 3 (3)
    sta .POINTER      ; 3 (6)
    lda #>.ADDRESS    ; 3 (9)
    sta .POINTER+1    ; 3 (12)
  ENDM

  ; Insert N nop operations
  ; --------------------------------------------------------------------
  MACRO INSERT_NOPS
.NUM_NOPS SET {1}
    REPEAT .NUM_NOPS
      nop     ; 2 cycles per nop, 1 ROM byte
    REPEND
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_DINO       ; 9 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sec                         ; 2 (4)
    sbc DINO_TOP_Y_INT          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (9)
  ENDM

  ;----------------------------------------------------------------------------
  ; Same as CHECK_Y_WITHIN_DINO but assumes carry is set
  ;----------------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_DINO_IGNORING_CARRY  ; 7 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sbc DINO_TOP_Y_INT          ; 3 (3) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

  ;----------------------------------------------------------------------------
  ; TODO
  ;----------------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_OBSTACLE  ; 9 cycles
    tya                     ; 2 (2) - A = current scanline (Y)
    sec                     ; 2 (4)
    sbc OBSTACLE_Y          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT    ; 2 (9)
  ENDM

  ;----------------------------------------------------------------------------
  ; Macro LOAD_DINO_GRAPHICS_IF_IN_RANGE (46 cycles, 44 if carry is ignored)
  ;
  ; Checks if the current Y position (scanline) falls within the dino's
  ; vertical range. If so, loads the dino sprite P0 and missile 0
  ; data for the next scanline.
  ;
  ; Behavior:
  ; - If the scanline is within the dino's range:
  ;     - Load obstacle sprite data into A (and X).
  ;     - Load obstacle missile 0 configuration into A.
  ;     - Setup fine motion for M0 (HMM0) and prepare graphics for drawing.
  ; - If the scanline is outside the obstacle's range:
  ;     - Clear A and X.
  ;     - Jump to a user-provided label to continue execution.
  ;
  ; Missile data uses the following encoding:
  ;     bit index: 7 6 5 4 3 2 1 0
  ;                \_____/ \_/ ↑
  ;                 HMM0    │  │
  ;                         │  └─ ENAM0
  ;                      NUSIZ0 (needs to be shifted left twice)
  ;
  ; Parameters:
  ;   {1} = Label to jump to when scanline is outside obstacle range
  ;----------------------------------------------------------------------------
  MACRO LOAD_DINO_GRAPHICS_IF_IN_RANGE ; (46 cycles, 44 if carry is ignored)
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

    bcs .dino_y_within_range         ; 2/3 (11/12) - Branch if inside

.dino_y_outside_range:        ; - (11) (9 if ignoring the carry)

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; In case ROM is needed, the padding instructions, that make this branch 
    ; have the same CPU cycle count as the other branch, could be removed
    ;--------------------------------------------------------------------------
    pha                       ; 3 (14) - Wait/waste 23 cycles (6 bytes)
    pla                       ; 4 (18)
    pha                       ; 3 (21)
    pla                       ; 4 (25)
    pha                       ; 3 (28)
    pla                       ; 4 (32)
    nop                       ; 2 (34)
    ;--------------------------------------------------------------------------

    lda #0                    ; 2 (36) - Clear A and X
    tax                       ; 2 (38)
    sta ENAM0                 ; 3 (40)

    sta HMCLR                         ; 3 (43)
    jmp .TARGET_BRANCH_WHEN_FINISHED  ; 3 (46)

.dino_y_within_range:         ; - (12)

    ; By the moment this macro is call and the execution reaches this point, it
    ; is assumed that 24+ CPU cycles have passed since this scanline's HMOVE,
    ; meaning it is safe to modify HMMx registers without triggering unwanted
    ; shifts.  First, we use HMCLR to reset HMP1 and HMM1. It also clears all
    ; HMMx regs, which is fine — HMM0 and HMP0 are about to be updated anyway.
    sta HMCLR                 ; 3 (15)

    ; dino graphics offset
    lda (PTR_DINO_OFFSET),y   ; 5 (20)
    sta HMP0                  ; 3 (23)

    ; dino graphics- leave them in reg X so they are ready to be used in the 2nd
    ; scanline, this implies not touching reg X for the rest of this scan line
    LAX (PTR_DINO_SPRITE),y   ; 5 (28)

    ; --- Dino Missile Setup ---
    ; The data pointed to by PTR_DINO_MISSILE_0_CONF has the following bit layout:
    ;
    ; bit index: 7 6 5 4 3 2 1 0
    ;            \_____/ \_/ ↑
    ;             HMM0    │  │
    ;                     │  └── ENAM0
    ;                   NUSIZ0 (need to be shifted to the left twice)
    lda (PTR_DINO_MISSILE_0_CONF),y  ; 5 (33) - Load config byte into A and X
    sta HMM0                         ; 3 (36)
    sta ENAM0                        ; 3 (39)
    asl                              ; 2 (41)
    asl                              ; 2 (43)
    sta NUSIZ0                       ; 3 (46)
  ENDM

  ;----------------------------------------------------------------------------
  ; Macro LOAD_DINO_P0_IF_IN_RANGE (28 cycles, 26 if carry is ignored)
  ;
  ; Checks if the current scanline (Y) is within the dino's vertical range.
  ; If so, loads sprite and position data for Player 0 (P0) to draw the dino.
  ; This version ignores the missile and focuses only on sprite setup.
  ;
  ; Parameters:
  ;   {1} = Label to jump to if scanline is outside the dino's visible Y range.
  ;   {2} = Set to 1 to insert 'SEC' before SBC (for safe subtraction);
  ;         Set to 0 to skip it and save 2 cycles if carry is already set.
  ;
  ; Notes:
  ; - Assumes 24+ cycles have passed since HMOVE when called (safe to
  ;   write HMMx).
  ; - Register X will hold the P0 graphics data afterward — must remain
  ;   untouched for the rest of the scanline.
  ;
  ;----------------------------------------------------------------------------
  MACRO LOAD_DINO_P0_IF_IN_RANGE ; (28, 26 if carry is ignored)
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

; -------------------------------------------------------------------------
; Macro LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE (29 cycles, 27 if carry is ignored)
;
; Checks if the current Y position (scanline) falls within the obstacle's
; vertical range. If so, loads the corresponding obstacle sprite and missile 1
; data for the next scanline.
;
; Behavior:
; - If the scanline is within the obstacle's range:
;     - Load obstacle sprite data into A (and X).
;     - Load obstacle missile 1 configuration into A.
;     - Setup fine motion for M1 (HMM1) and prepare graphics for drawing.
; - If the scanline is outside the obstacle's range:
;     - Clear A and X.
;     - Jump to a user-provided label to continue execution.
;
; Ball data uses the same encoding format as the dino missile:
;     bit index: 7 6 5 4 3 2 1 0
;                \_____/ \_/ ↑
;                 HMM1    │  │
;                         │  └─ ENAM1
;                      NUSIZ1 (needs to be shifted left twice)
;
; Parameters:
;   {1} = Label to jump to when scanline is outside obstacle range
  MACRO LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE ; (29, 27 if carry is ignored)
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

.obstacle_y_outside_range:    ; - (11) (9 if ignoring the carry)

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; In case ROM is needed, the padding instructions, that make this branch 
    ; have the same CPU cycle count as the other branch, could be removed
    ;--------------------------------------------------------------------------
    pha                       ; 3 (14) - Wait/waste 9 cycles (3 bytes)
    pla                       ; 4 (18)
    nop                       ; 2 (20)
    ;--------------------------------------------------------------------------

    lda #0                    ; 2 (22) - Clear A and X
    tax                       ; 2 (24)

    sta HMCLR                         ; 3 (26)
    jmp .TARGET_BRANCH_WHEN_FINISHED  ; 3 (29)

.obstacle_y_within_range:             ; - (12)
    ; LAX (illegal opcode) is used here because there is no 'ldx (aa),y'. The
    ; non-illegal-opcode alternative is to do 'lda (aa),y' and then 'tax'
    ; incurring in 2 extra cycles, whereas LAX will only cost 5
    LAX (PTR_OBSTACLE_SPRITE),y          ; 5 (23)

    ; Load obstacle missile configuration. Bit Layout duplicated here for ref:
    ;     bit index: 7 6 5 4 3 2 1 0
    ;                \_____/ \_/ ↑
    ;                 HMM1    │  │
    ;                         │  └─ ENAM1
    ;                      NUSIZ1 <- needs to be shifted left twice
    lda (PTR_OBSTACLE_MISSILE_1_CONF),y  ; 5 (17)


    ; ⚠ IMPORTANT:
    ; Before applying fine motion to the obstacle ball, clear fine offsets.
    ; This avoids repeated leftover shifts from the other objects
    ; when restarting the 2x kernel's first scanline.
    ; HMOVE timing notes:
    ; - HMxx writes must not happen within 24 CPU cycles of HMOVE.
    ; - By the time this macro runs, enough time should have passed since
    ;   the last HMOVE for HMCLR to be safely written.
    sta HMCLR                            ; 3 (26)

    ; reg X holds a copy of the original (without shifting) missile 1
    ; configuration. Bits 7 to 4 contain the untouched fine adjustment
    sta HMM1                             ; 3 (29)
  ENDM

  ; -------------------------------------------------------------------------
  ; Macro CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY (7 cycles)
  ; -------------------------------------------------------------------------
  ;
  ; Same as CHECK_Y_WITHIN_OBSTACLE but assumes carry is set
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY       ; 7 cycles
    tya                   ; 2 (2) - A = current scanline (Y)
    sbc OBSTACLE_Y        ; 3 (5) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT  ; 2 (7)
  ENDM

  ; -------------------------------------------------------------------------
  ; Macro DRAW_DIN (3 cycles)
  ; -------------------------------------------------------------------------
  MACRO DRAW_DINO ; 3 cycles
    stx GRP0      ; 3 (3)
  ENDM

  ; -------------------------------------------------------------------------
  ; Macro DRAW_OBSTACLE (13 cycles)
  ;
  ; Draws a horizontal obstacle using the missile 1 object (ENAM1) and GRP1
  ; sprite graphics. The macro assumes that a copy of the obstacle
  ; configuration (HMM1 + NUSIZ1 + ENAM1) has already been shifted 2 bits to
  ; the left and is currently in the A register. The X register contains the
  ; obstacle sprite.
  ;
  ; Inputs:
  ;   A - Obstacle data byte (HMM1 + NUSIZ1 + ENAM1), shifted left by 2 bits.
  ;       Bit layout in memory before shifting:
  ;
  ;       bit index: 7 6 5 4 3 2 1 0
  ;                  \_____/ \_/ ↑
  ;                   HMM1    │  │
  ;                           │  └── ENAM1
  ;                        NUSIZ1 ←─ needs to be shifted to the left twice
  ;
  ;       After the left shift by 2 (done previous to the macro invocation),
  ;       reg A holds:
  ;
  ;       bit index: 7 6 5 4 3 2 1 0
  ;                  __/ \_/ ↑
  ;                HMM1   │  │
  ;                       │  └── ENAM1
  ;                    NUSIZ1
  ;
  ;   X - Obstacle sprite graphics, to be written to GRP1.
  ;------------------------------------------------------------------------------
  MACRO DRAW_OBSTACLE ; 13 cycles
    stx GRP1          ; 3 (3)
    sta ENAM1         ; 3 (6) - Enable/disable M1 first. It is assumed this
                      ;         macro will be invoked first thing in the scanline
    asl               ; 2 (8)
    asl               ; 2 (10)
    sta NUSIZ1        ; 3 (13)
  ENDM

  MACRO CHECK_IF_OBSTACLE_SPRITE_IS_OFFSCREEN
.TARGET_BRANCH_IF_OFFSCREEN SET {1}
    ; First, check if the obstacle sprite data is off-screen in which case
    ; it doesn't matter the data for the sprite will be zeroed
    lda OBSTACLE_X_INT
    ; If obstacle_x > 0, then some part of it is still onscreen (not covered) by
    ; the HMOVE black area
    cmp #OBSTACLE_GRP1_MIN_SCREEN_X
    bcc .TARGET_BRANCH_IF_OFFSCREEN
    ; If obstacle_x < 0, then definitely the obstacle is offscreen
    cmp #OBSTACLE_MIN_X
    bcs .TARGET_BRANCH_IF_OFFSCREEN
  ENDM

  MACRO CHECK_IF_OBSTACLE_MISSILE_IS_OFFSCREEN
.TARGET_BRANCH_IF_OFFSCREEN SET {1}
    lda OBSTACLE_X_INT
    cmp #OBSTACLE_M1_MAX_SCREEN_X
    bcc .TARGET_BRANCH_IF_OFFSCREEN
    ; make sure that obstacle_x is a non-negative value (in which case
    ; obstacle_x > #OBSTACLE_M1_MAX_SCREEN_X would be evaluated as true
    cmp #OBSTACLE_MIN_X
    bcs .TARGET_BRANCH_IF_OFFSCREEN
  ENDM
