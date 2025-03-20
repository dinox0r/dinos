  PROCESSOR 6502

  INCLUDE "vcs.h"

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

  ; 37 scanlines of VBLANK
  lda #43
  sta TIM64T

  ; set sprite colour
  lda #$FF
  sta COLUP1
  sta HMCLR


_on_vblank_timer:
  lda INTIM
  bne _on_vblank_timer

  ; turn VBLANK off
  lda #0
  sta VBLANK

  ; scanline 192 (top scanline)
  sta WSYNC
  sta HMOVE ; 3
  nop ; 5
  nop ; 7
  nop ; 9
  nop ; 11
  nop ; 13
  sta RESP1 ; 20

  sta WSYNC

  ; scaline 191
  sta HMOVE
  ; remaining 190 scanlines
  ldy #190
  sta WSYNC
  ; scaline 190
  sta HMOVE

display:
  tya
  sta COLUBK

  sec
  sbc #SPRITE_Y_POS
  cmp #SPRITE_HEIGHT
  bcc _load_sprite_data
  lda #0
  jmp _draw_sprite

_load_sprite_data:
  tax
  lda SPRITE,x

_draw_sprite:
  sta GRP1

  sta WSYNC
  sta HMOVE

  dey
  bne display

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
SPRITE:
  .ds 1
  .byte %00111100
  .byte %01000010
  .byte %10011001
  .byte %10100101
  .byte %10000001
  .byte %10100101
  .byte %01000010
  .byte %00111100
  .ds 1
; ---- Cartridge beginning ----
  ORG $fffc
  .word reset
  .word reset
