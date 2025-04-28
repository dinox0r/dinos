
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

  ; Same as DECODE_MISSILE_PLAYER but using the BALL register
  ; --------------------------------------------------------------------
  MACRO DECODE_BALL   ; 13 cycles
    sta ENABLE_BALL ; 3 (3)
    sta HMBL        ; 3 (6)
    asl             ; 2 (8)
    asl             ; 2 (10)
    sta CTRLPF      ; 3 (13)
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
; vertical range. If so, loads the corresponding obstacle sprite and ball
; data for the next scanline.
;
; Behavior:
; - If the scanline is within the obstacle's range:
;     - Load obstacle sprite data into A (and X).
;     - Load obstacle ball data into A.
;     - Setup fine motion for ball (HMBL) and prepare graphics for drawing.
; - If the scanline is outside the obstacle's range:
;     - Clear A and X.
;     - Jump to a user-provided label to continue execution.
;
; Ball data uses the same encoding format as the dino missile:
;     bit index: 7 6 5 4 3 2 1 0
;                \_____/ \_/   ↑
;                 HMBL    │    │
;                         │    └─ ENABL
;                      CTRLPF  (needs to be shifted left twice)
;
; Parameters:
;   {1} = Label to jump to when scanline is outside obstacle range
  MACRO LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE ; (32 cycles, 30 if carry is ignored)
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
                              ;
                              ; Wait/waste 13 cycles:
    php                       ; 3 (9 -> 12, 11 -> 14)
    plp                       ; 4 (16, 18)
    nop                       ; 2 (18, 20)
    nop                       ; 2 (20, 22) - These total to 4 bytes of ROM

    lda #0                    ; 2 (24) - Clear A and X
    tax                       ; 2 (26)

    sta HMCLR                 ; 3 (29)
    jmp .TARGET_BRANCH_WHEN_FINISHED ; 3 (32)

.obstacle_y_within_range:            ; - (12)
    ; LAX (illegal opcode) is used here to load the sprite data into X,
    ; saving 2 cycles compared to separate LDA + TAX.
    LAX (PTR_OBSTACLE_SPRITE),y       ; 5 (17)

    ; Load obstacle ball (missile) properties. Duplicated here for reference:
    ;     bit index: 7 6 5 4 3 2 1 0
    ;                \_____/ \_/   ↑
    ;                 HMBL    │    │
    ;                         │    └─ ENABL
    ;                      CTRLPF  (needs to be shifted left twice)
    lda (PTR_OBSTACLE_BALL),y         ; 5 (22)

    ; IMPORTANT:
    ; Before applying fine motion to the obstacle ball, clear fine offsets.
    ; This avoids repeated leftover shifts from the other objects
    ; when restarting the 2x kernel's first scanline.
    ; HMOVE timing notes:
    ; - HMxx writes must not happen within 24 CPU cycles of HMOVE.
    ; - By the time this macro runs, enough time should have passed since
    ;   the last HMOVE for HMCLR to be safely written.
    sta HMCLR                        ; 3 (25)

    sta HMBL                         ; 3 (28)
    asl                              ; 2 (30)
    asl                              ; 2 (32)
  ENDM

  ; Same as CHECK_Y_WITHIN_OBSTACLE but assumes carry is set
  ; --------------------------------------------------------------------
  MACRO CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY       ; 7 cycles
    tya                   ; 2 (2) - A = current scanline (Y)
    sbc OBSTACLE_Y        ; 3 (5) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT  ; 2 (7)
  ENDM

  ; Description:
  ; Draws a horizontal obstacle using the ball object (ENABL) and GRP1 sprite
  ; graphics. The macro assumes that a copy of the obstacle configuration
  ; (CTRLPF + HMBL + ENABL) has already been shifted 2 bits to the left and is 
  ; currently in the A register. The X register contains the obstacle sprite.
  ;
  ; Inputs:
  ;   A - Obstacle data byte (HMBL + CTRLPF + ENABL), shifted left by 2 bits.
  ;       Bit layout in memory before shifting:
  ;
  ;       bit index: 7 6 5 4 3 2 1 0
  ;                  \_____/ \_/   ↑
  ;                   HMBL    │    │
  ;                           │    └── ENABL
  ;                         CTRLPF (needs to be shifted to the left twice)
  ;
  ;       After the left shift by 2 (done previous to the macro invocation),
  ;       A holds:
  ;
  ;       bit index: 7 6 5 4 3 2 1 0
  ;                  __/ \_/   ↑
  ;                HMBL   │    │
  ;                       │    └── ENABL <-- Needs to be shifted to right
  ;                     CTRLPF
  ;
  ;   X - Obstacle sprite graphics, to be written to GRP1.
  ;------------------------------------------------------------------------------
  MACRO DRAW_OBSTACLE   ; 11 cycles
    sta CTRLPF        ; 3 (3) - Set the ball size
    lsr               ; 2 (5) - Shift A right once to align ENABL bit
    sta ENABL         ; 3 (8) - Enable/disable ball based on shifted bit
    stx GRP1          ; 3 (11)
  ENDM

