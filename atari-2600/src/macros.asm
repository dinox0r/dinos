
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
  MACRO DECODE_MISSILE_PLAYER ; 13 cycles
    sta MISSILE_P{1}      ; 3 (3)
    sta HMM{1}            ; 3 (6)
    asl                   ; 2 (8)
    asl                   ; 2 (10)
    sta NUSIZ{1}          ; 3 (13)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_DINO       ; 9 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sec                         ; 2 (4)
    sbc DINO_TOP_Y_INT          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (9)
  ENDM

  ; Same as CHECK_Y_WITHIN_DINO but assumes carry is set
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_DINO_IGNORING_CARRY  ; 7 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sbc DINO_TOP_Y_INT          ; 3 (3) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_OBSTACLE  ; 9 cycles
    tya                     ; 2 (2) - A = current scanline (Y)
    sec                     ; 2 (4)
    sbc OBSTACLE_Y          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT    ; 2 (9)
  ENDM

; -------------------------------------------------------------------------
; LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE
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
  MACRO LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE ; (29 cycles, 27 if carry is ignored)
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

    pha                       ; 3 (14) - Wait/waste 9 cycles (3 bytes)
    pla                       ; 4 (18)
    nop                       ; 2 (20)

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

  ; Same as CHECK_Y_WITHIN_OBSTACLE but assumes carry is set
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY       ; 7 cycles
    tya                   ; 2 (2) - A = current scanline (Y)
    sbc OBSTACLE_Y        ; 3 (5) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT  ; 2 (7)
  ENDM

  ; Description:
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
    sta ENAM1         ; 3 (3) - Enable/disable M1 first. It is assumed this
                      ;         macro will be invoked first thing in the scanline
    asl               ; 2 (5)
    asl               ; 2 (7)
    sta NUSIZ1        ; 3 (10)
    stx GRP1          ; 3 (13)
  ENDM

