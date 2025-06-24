; set_obstacle_data: Computes a ROM address offset by OBSTACLE_Y and
;                    stores the result in a zero-page pointer.
;
; Description:
;   This subroutine adjusts a given ROM address by subtracting OBSTACLE_Y
;   and stores the resulting address in a zero-page pointer.
;
;   The operation is equivalent to:
;
;      sec                     ; Set carry for subtraction
;      lda #<SOME_ROM_ADDRESS   ; Load low byte of base address
;      sbc OBSTACLE_Y           ; Subtract Y offset
;      sta ZERO_PAGE_ADDRESS    ; Store low byte of result
;      lda #>SOME_ROM_ADDRESS   ; Load high byte of base address
;      sbc #0                   ; Subtract carry (propagating from low byte)
;      sta ZERO_PAGE_ADDRESS+1  ; Store high byte of result
;
; Parameters:
;   A  - Low byte of SOME_ROM_ADDRESS
;   Y  - High byte of SOME_ROM_ADDRESS
;   X  - Zero-page pointer location (i.e., ZERO_PAGE_ADDRESS)
;
; Result:
;   (X)   = Low byte of adjusted address
;   (X+1) = High byte of adjusted address
;
; Example:
;   If SOME_ROM_ADDRESS = $F252 and OBSTACLE_Y = 10:
;     Adjusted address = $F252 - 10 = $F248
;     ZERO_PAGE_ADDRESS (at X) now holds $F248.
;
set_obstacle_data subroutine
  sec             ; 2 (2) Ensure subtraction works correctly
  sbc OBSTACLE_Y  ; 3 (5) Subtract Y offset from low byte
  sta $00,x       ; 4 (9) Store adjusted low byte at pointer X
  tya             ; 2 (11) Load high byte of original address
  sbc #0          ; 2 (13) Subtract carry from high byte
  sta $01,x       ; 4 (17) Store adjusted high byte at pointer X+1
  rts             ; 6 (23) Return from subroutine

rnd8 subroutine
  lda RANDOM
  lsr
  bcc .no_xor
  eor #$D4
.no_xor:
  sta RANDOM
  rts
