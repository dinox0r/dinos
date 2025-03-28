
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
  MAC LOAD_ADDRESS_TO_PTR
.ADDRESS SET {1}
.POINTER SET {2}
    lda #<.ADDRESS
    sta .POINTER
    lda #>.ADDRESS
    sta .POINTER+1
  ENDM

  ; Insert N nop operations
  ; --------------------------------------------------------------------
  MAC INSERT_NOPS
.NUM_NOPS SET {1}
    REPEAT .NUM_NOPS
      nop
    REPEND
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC DECODE_MISSILE_PLAYER ; 13 cycles
    sta MISSILE_P{1} ; 3 (3)
    sta HMM{1}      ; 3 (6)
    asl                     ; 2 (8)
    asl                     ; 2 (10)
    sta NUSIZ{1}    ; 3 (13)
  ENDM

  ; Same as DECODE_MISSILE_PLAYER but using the BALL register
  ; --------------------------------------------------------------------
  MAC DECODE_BALL ; 13 cycles
    sta ENABLE_BALL ; 3 (3)
    sta HMBL      ; 3 (6)
    asl           ; 2 (8)
    asl           ; 2 (10)
    sta CTRLPF    ; 3 (13)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_DINO       ; 9 cycles
    tya                         ; 2 (2) A = current scanline (Y)
    sec                         ; 2 (2)
    sbc DINO_TOP_Y_INT          ; 3 (3) A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

  ; Same as CHECK_Y_WITHIN_DINO but assumes carry is set
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_DINO_IGNORING_CARRY       ; 7 cycles
    tya                         ; 2 (2) A = current scanline (Y)
    sbc DINO_TOP_Y_INT          ; 3 (3) A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

  ; TODO
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_PTERO       ; 9 cycles
    tya                         ; 2 (2) A = current scanline (Y)
    sec                         ; 2 (2)
    sbc OBSTACLE_Y          ; 3 (3) A = X - DINO_TOP_Y_INT
    adc #PTERO_HEIGHT            ; 2 (2)
  ENDM

  ; Same as CHECK_Y_WITHIN_PTERO but assumes carry is set
  ; --------------------------------------------------------------------
  MAC CHECK_Y_WITHIN_PTERO_IGNORING_CARRY       ; 7 cycles
    tya                         ; 2 (2) A = current scanline (Y)
    sbc OBSTACLE_Y          ; 3 (3) A = X - DINO_TOP_Y_INT
    adc #PTERO_HEIGHT            ; 2 (2)
  ENDM

