  PROCESSOR 6502

  INCLUDE "include/vcs.h"

  ; constats ------------------------------------------------------------------
SPRITE_HEIGHT = 10
SPRITE_Y_POS = 150

  ; variables -----------------------------------------------------------------
  SEG.U variables
  ORG $80

  ; code ----------------------------------------------------------------------
  SEG code
  ORG $F000

reset:
  sei
  cld

  lda #0
  tax
  tay
_clear_mem_loop:
  dex
  txs
  pha
  bne _clear_mem_loop

on_begin_frame:
  ; turn VBLANK and VSYNC on
  lda #2
  sta VBLANK
  sta VSYNC

  ; 3 scanlines of VSYNC
  sta WSYNC
  sta WSYNC
  sta WSYNC
  ; turn VSYNC off
  lda #0
  sta VSYNC

  sta WSYNC
  nop ; 5
  nop ; 5
  nop ; 5
  nop ; 9
  nop ; 9
  nop ; 9
  nop ; 11
  nop ; 13
  nop ; 15
  dec $2D ; 20
  sta RESM0
  sta RESP1 ; 23
  sta RESM1

; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
  lda #$C0
  sta HMM0
  lda #$50
  sta HMM1
  ;lda #$80
  ;sta HMM0
  sta WSYNC
  sta HMOVE

  inc $2D
  inc $2D
  inc $2D
  inc $2D
  inc $2D

  lda #$00
  sta HMM0
  sta HMP1

  ;lda #$E0
  ;sta HMM0
  sta WSYNC
  sta HMOVE

  inc $2D
  inc $2D
  inc $2D
  inc $2D
  inc $2D

  sta HMCLR

  ; 37 (minus the few above for positioning) scanlines of VBLANK
  lda #43
  sta TIM64T

_on_vblank_timer:
  lda INTIM
  bne _on_vblank_timer

  ; turn VBLANK off
  lda #0
  sta VBLANK

  lda #$0C
  sta COLUBK

  lda #$04        ; 2 (29)
  sta COLUP0      ; 3 (32)
  sta COLUP1      ; 3 (32)

  ; scaline 191
  sta HMOVE
  ; remaining 190 scanlines
  ldy #190

scanline:
  sta WSYNC
  sta HMOVE       ; 3

  tya
  sec               ; 2 (10)
  sbc #SPRITE_Y_POS ; 2 (12)
  cmp #SPRITE_HEIGHT ; 2 (14)
  bcc _draw_sprite ; 2/3 (16/17)

  lda #0
  sta GRP1
  sta ENAM1
  sta ENAM0

  jmp _end_of_scanline

_draw_sprite:     ; - (17)
  lda #%11010111  ; 2 (24)
  sta GRP1        ; 3 (27)
  lda #2  ; 
  sta ENAM1
  sta ENAM0
  lda #%00100101  ; 2 (19) 2x GRP1 4x M1
  sta NUSIZ1      ; 3 (22)
  lda #1
  sta NUSIZ0

_end_of_scanline:
  dey             ; 2 (34)
  bne scanline    ; 3
  sta WSYNC
  sta HMOVE

on_end_frame:
overscan:
  lda #2
  sta VBLANK
  ; 30 scanlines of overscan
  lda #35
  sta TIM64T
_on_overscan_timer:
  lda INTIM
  bne _on_overscan_timer
  sta WSYNC

  jmp on_begin_frame

; Sprite data
;SPRITE:
;  .ds 1
;  .byte %00111100
;  .byte %01000010
;  .byte %10011001
;  .byte %10100101
;  .byte %10000001
;  .byte %10100101
;  .byte %01000010
;  .byte %00111100
;  .ds 1
; ---- Cartridge beginning ----
  ORG $fffc
  .word reset
  .word reset
