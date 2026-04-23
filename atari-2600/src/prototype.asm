    processor 6502
    include "../include/vcs.h"

;===============================================================================
; Zero Page
;===============================================================================
    SEG.U VARS
    ORG $80

FRAME_COUNTER   ds 1

;===============================================================================
; ROM
;===============================================================================
    SEG CODE
    ORG $F000

;--- Sprite data ---------------------------------------------------------------

Digit00:
    .byte #%00100010
    .byte #%01010101
    .byte #%01010101
    .byte #%01010101
    .byte #%01010101
    .byte #%00100010

Digit11:
    .byte #%00100010
    .byte #%01100110
    .byte #%00100010
    .byte #%00100010
    .byte #%00100010
    .byte #%01110111

;--- Reset / Init --------------------------------------------------------------

Reset:
    sei
    cld
    ldx #$FF
    txs
    lda #0
ClearMem:
    sta $00,x
    dex
    bne ClearMem

;--- Main loop -----------------------------------------------------------------

MainLoop:

    ;---------------------------------------------------------------------------
    ; VSYNC — 3 scanlines
    ;---------------------------------------------------------------------------
    lda #2
    sta VSYNC
    sta WSYNC
    sta WSYNC
    sta WSYNC
    lda #0
    sta VSYNC

    ;---------------------------------------------------------------------------
    ; VBLANK — 37 scanlines
    ;---------------------------------------------------------------------------
    lda #43
    sta TIM64T

    ; Advance frame counter 0–5
    inc FRAME_COUNTER
    lda FRAME_COUNTER
    cmp #6
    bcc .skip_wrap
    lda #0
    sta FRAME_COUNTER
.skip_wrap:

.wait_vblank:
    lda INTIM
    bne .wait_vblank
    sta WSYNC
    lda #0
    sta VBLANK

    ;---------------------------------------------------------------------------
    ; KERNEL — 192 scanlines
    ;---------------------------------------------------------------------------

    ; Scanline 1: colors and NUSIZ
    lda #2              ; dark gray (FRG_DARK_GRAY)
    sta COLUP0
    sta COLUP1
    lda #13             ; light gray (BKG_LIGHT_GRAY)
    sta COLUBK
    ;lda #0              ; single-width player
    ;sta NUSIZ0
    ;sta NUSIZ1
    sta WSYNC           ; end scanline 1

    ; Scanline 2: coarse position P0 and P1
    ;   ldx#6 loop = 31 cycles; 7 NOPs = 14 cycles → sta RESP0 at cycle 45 (~pixel 72)
    ;   1 NOP = 2 cycles → sta RESP1 at cycle 50 (~pixel 87)
    ldx #2
.pos_loop:
    dex
    bne .pos_loop       ; 31 cycles total (ldx + loop)
    nop                 ; 33
    nop                 ; 35
    nop                 ; 37
    nop                 ; 39
    nop                 ; 41
    nop                 ; 43
    nop                 ; 45
    nop
    nop
    nop
    sta RESP0           ; 48  (~pixel 72)
    nop                 ; 50
    sta RESP1           ; 53  (~pixel 87)
    sta WSYNC           ; end scanline 2

    ; Scanline 3: apply HMOVE (HMP0/HMP1 = 0 so no shift, just clears latches)
    sta HMOVE           ; must be within first 24 cycles after WSYNC
    sta HMCLR
    sta WSYNC           ; end scanline 3

    ; Scanlines 4–9: blank top (6 scanlines)
    ldx #6
.blank_top:
    sta WSYNC
    dex
    bne .blank_top

    ; Scanlines 10–15: digit rows (6 scanlines, 1 scanline per pixel row)
    ;   FRAME_COUNTER=0 → show "00" (P0), hide P1
    ;   FRAME_COUNTER=1–5 → show "11" (P1), hide P0
    lda FRAME_COUNTER
    bne .draw_11

.draw_00:
    ldy #0
.digit00_row:
    lda Digit00,y
    sta GRP0
    lda #0
    sta GRP1
    sta WSYNC
    iny
    cpy #6
    bne .digit00_row
    jmp .digits_done

.draw_11:
    ldy #0
.digit11_row:
    lda #0
    sta GRP0
    lda Digit11,y
    sta GRP1
    sta WSYNC
    iny
    cpy #6
    bne .digit11_row

.digits_done:
    lda #0
    sta GRP0
    sta GRP1

    ; Scanlines 16–192: blank bottom (177 scanlines)
    ldx #177
.blank_bottom:
    sta WSYNC
    dex
    bne .blank_bottom

    ;---------------------------------------------------------------------------
    ; OVERSCAN — 30 scanlines
    ;---------------------------------------------------------------------------
    lda #2
    sta VBLANK
    lda #35
    sta TIM64T

.wait_overscan:
    lda INTIM
    bne .wait_overscan
    sta WSYNC

    jmp MainLoop

;--- Vectors -------------------------------------------------------------------
    ORG $FFFC
    .word Reset
    .word Reset
