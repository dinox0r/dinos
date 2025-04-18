
  ; Paints N scanlines with the given background colour, used to draw
  ; placeholder areas on the screen
  ; --------------------------------------------------------------------
  MAC DEBUG_SUB_KERNEL
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
  MAC LOAD_ADDRESS_TO_PTR  ; 12 cycles
.ADDRESS SET {1}
.POINTER SET {2}
    lda #<.ADDRESS    ; 3 (3)
    sta .POINTER      ; 3 (6)
    lda #>.ADDRESS    ; 3 (9)
    sta .POINTER+1    ; 3 (12)
  ENDM

  ; Insert N nop operations
  ; --------------------------------------------------------------------
  MAC INSERT_NOPS
.NUM_NOPS SET {1}
    REPEAT .NUM_NOPS
      nop     ; 2 cycles per nop, 1 ROM byte
    REPEND
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC DECODE_MISSILE_PLAYER ; 13 cycles
    sta MISSILE_P{1}      ; 3 (3)
    sta HMM{1}            ; 3 (6)
    asl                   ; 2 (8)
    asl                   ; 2 (10)
    sta NUSIZ{1}          ; 3 (13)
  ENDM

  ; Same as DECODE_MISSILE_PLAYER but using the BALL register
  ; --------------------------------------------------------------------
  MAC DECODE_BALL   ; 13 cycles
    sta ENABLE_BALL ; 3 (3)
    sta HMBL        ; 3 (6)
    asl             ; 2 (8)
    asl             ; 2 (10)
    sta CTRLPF      ; 3 (13)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_DINO       ; 9 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sec                         ; 2 (4)
    sbc DINO_TOP_Y_INT          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (9)
  ENDM

  ; Same as CHECK_Y_WITHIN_DINO but assumes carry is set
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_DINO_IGNORING_CARRY  ; 7 cycles
    tya                         ; 2 (2) - A = current scanline (Y)
    sbc DINO_TOP_Y_INT          ; 3 (3) - A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_OBSTACLE  ; 9 cycles
    tya                     ; 2 (2) - A = current scanline (Y)
    sec                     ; 2 (4)
    sbc OBSTACLE_Y          ; 3 (7) - A = X - DINO_TOP_Y_INT
    adc #OBSTACLE_HEIGHT    ; 2 (9)
  ENDM

  ; Same as CHECK_Y_WITHIN_OBSTACLE but assumes carry is set
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY       ; 7 cycles
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
  MAC DRAW_OBSTACLE   ; 11 cycles
    sta CTRLPF        ; 3 (3)
    lsr               ; 2 (5) - Shift A right once to align ENABL bit
    sta ENABL         ; 3 (8) - Enable/disable ball based on shifted bit
    stx GRP1          ; 3 (11)
  ENDM

