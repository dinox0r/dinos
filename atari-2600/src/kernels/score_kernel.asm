; There are 2 subkernels for the score:
;
; 1. The main score kernel, which shows the continuously updating
;    5-digit score:
;
;                                             main score kernel
;                                                  /-----\
;                                                   00042
;       o██                       █
;   █   ███                     █ █ █
; -- ████  ---------------------█████---------------------
;     ██                          █
;
; 2. The hi-score overlay kernel, which shows the hi-score in full and
;    3 digits from the main score (only 3 because that's all that can be
;    drawn using the 6-sprite trick):
;
;                                   hi-score overlay kernel
;                                          /----------\
;                                          HI 00123 000
;       o██                       █
;   █   ███                     █ █ █
; -- ████  ---------------------█████---------------------
;     ██                          █
;
; The hi-score overlay kernel is displayed when a max score is available,
; and only on every 4th frame. This gives it a lighter gray tone, simulating
; the hi-score colour from the original game.
;
; When the screen merges both subkernels, the overlapping digits should not
; flicker, and the hi-score should appear lighter:
;
;   HI 00123 000   - frame 0
;            00042 - frame 1
;            00042 - frame 2
;            00042 - frame 3
;   HI 00123 000   - frame 4
;            00042 - frame 5
;            00042 - frame 6
;            00042 - frame 7
;   HI 00123 000   - frame 8
;            00042 - frame 9
;           .....
;
; The sprite layout for the hi-score overlay kernel is:
;
;   G   G   G      Both GRP0 and GRP1 are configured to 3 copies close
;   R   R   R      NSIZx = #3
;   P   P   P
;   0   0   0
;   │   │   │
;   │ G │ G │ G
;   │ R │ R │ R
;   │ P │ P │ P
;   │ 1 │ 1 │ 1
;   │ │ │ │ │ │
;   ├┐├┐├┐├┐├┐├┐
;   ││││││││││││
;   ↓↓↓↓↓↓↓↓↓↓↓↓
;   HI 00123 000__
;
; The sprite layout for the main score kernel is:
;
;   ________ 00042   GRP0 is configured to 2 copies close (NSIZ0 = #1)
;           ↑↑↑↑↑↑
;           ││││││
;           ├┘├┘├┘
;           │ │ │
;           │ G │
;           │ R │
;           │ P │
;           │ 1 │
;           │   │
;           G   G
;           R   R
;           P   P
;           0   0
;
; Positioning:
;
;         sta RESP0 at CPU cycle 62 (so the change is applied at 65)
;           │
;           ↓
;            00042 - main score kernel
;   HI 00123 000   - hi-score overlay kernel
;  ↑
;  │
;  sta RESP0 at CPU cycle 51
;
  ;ALIGN 256
score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)

  ; 1st scanline ==============================================================
               ; - (0)
  ; The v-blank section ends with the following 
  ; sta WSYNC  ; - (0) Finishes any remaining v-blank
  ; sta HMOVE  ; 3 (3)
  ; sta VBLANK ; 3 (6) Turns v-blank off (reg A is 0)

  ; The intent of the following code is to perform this check:
  ;
  ; // Show the hi-score overlay (hi-score + partial current score)
  ; // when the max score flag is set and every 4th frame
  ; if (GAME_FLAGS & FLAG_MAX_SCORE_AVAILABLE) and
  ;    (FRAME_COUNT % 4) == 0 then goto hi_score_overlay_kernel_setup
  ;
  ; However, it is implemented as:
  ;
  ; bool TEMP = not (GAME_FLAGS & FLAG_MAX_SCORE_AVAILABLE)
  ; TEMP = TEMP or (FRAME_COUNT % 4) != 0
  ; if TEMP goto main_score_kernel_setup
  ;
  ; This implementation reduces ROM usage and avoids extra branching.
  ; Both paths start with the same CPU cycle count, making it easier for
  ; the score positioning code to keep track of the colour cycle timing.
  lda #FLAG_MAX_SCORE_AVAILABLE       ; 2 (8)
  and GAME_FLAGS                      ; 3 (11)
  eor #FLAG_MAX_SCORE_AVAILABLE       ; 2 (13)
  sta TEMP                            ; 3 (16)
  lda FRAME_COUNT                     ; 3 (19)
  and #3                              ; 2 (21)
  ora TEMP                            ; 3 (24)
  sbeq hi_score_overlay_kernel_setup  ; 2/3 (26/27)

main_score_kernel_setup:            ; - (26)

  ; Target position is CPU cycle 63:
  ldy #5                            ; 2 (28)
_main_score_kernel_coarse_pos:      ; -
  dey                               ;\
  bne _main_score_kernel_coarse_pos ;/ (5 - 1) * 5 + 4 = 24 (52)

  ;
  ; Need to reach CPU cycle 65
  lda #NUSIZX_TWO_COPIES_CLOSE ; 2 (54)
  sta NUSIZ0                   ; 3 (57)

  ; Offset GRP1 by -1px (1px to the left) so it joins GRP0 at its end
  lda #$10                     ; 2 (59)
  sta HMP1                     ; 3 (62)

  sta RESP0                    ; 3 (65)
  sta RESP1                    ; 3 (68)

  sta WSYNC                    ; 3 (71)

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  ; Even though some resources stay that is fine, strobing HMCLR before 24
  ; cycles after a sta HMOVE has always produced positioning glitches in this
  ; project
  ldx #5         ; 2 (5)
_wait_for_hmclr_safe_strobing:
  dex                               ; \
  bne _wait_for_hmclr_safe_strobing ; / (5 - 1) * 5 + 4 = 24 (29)

  sta HMCLR      ; 3 (32)

  sta WSYNC      ; 3 (35)

  ; 3rd scanline ==============================================================
                 ; - (0)
  sta HMOVE
  ldx #6
main_score_kernel:
  ; end of 3rd, and 4th to 10th scanline ======================================
  sta WSYNC                ; 3 (73 -> 76)
                           ; - (0)
  sta HMOVE                ; 3 (3)
  lda SCORE_DIGITS_54-1,x  ; 4 (7)
  sta GRP0                 ; 3 (10)
  lda SCORE_DIGITS_32-1,x  ; 4 (14)
  sta GRP1                 ; 3 (17)

  lda SCORE_DIGITS_10-1,x  ; 4 (21)
  ;
  ; Wait until the first GRP0 sprite has been drawn to change GRP0 for the
  ; second copy, but that can only be done just after CPU cycle 65 and before
  ; cycle 69, so the sta GRP0 needs to start at cycle 66 so it ends exactly
  ; at CPU cycle 69
  ; ┌───────┬───────┬───────┐
  ; │GRP0(1)│  GRP1 │GRP0(2)│  <-- pixels covered by GRPx
  ; └───────┴───────┴───────┘
  ; ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↑  <-- CPU cycles
  ; 65 66 67 68 69 70 71 72 73
  ;

  ldy #8                 ; 2 (24)
_wait_to_update_grp0_again:
  dey                             ; \
  bne _wait_to_update_grp0_again  ; / (8 - 1) * 5 + 4 = 39 (63)

  nop                    ; 2 (65)
  dex                    ; 2 (67)

  sta GRP0               ; 3 (70)

  bne main_score_kernel  ; 2/3 (72/73)
  sta WSYNC              ; 3 (76)

  ; AI suggested edit: jmp end_of_score_kernel — replaced with beq: the loop
  ; exits when dey makes Y=0, and sta WSYNC doesn't affect flags, so Z=1
  beq end_of_score_kernel

hi_score_overlay_kernel_setup: ; - (27)

  lda #NUSIZX_THREE_COPIES_CLOSE   ; 2 (29)
  sta NUSIZ0   ; 3 (32)
  sta NUSIZ1   ; 3 (35)

  ; Enable the VDEL (A is #3 = #%00000011 so already has the bit 0 ON)
  sta VDELP0   ; 3 (38)
  sta VDELP1   ; 3 (41)

  lda #$f0     ; 2 (43) - Move GRP0 1px to the right
  sta HMP0     ; 3 (46)

  dec $2D      ; 5 (51) - Waste 5 cycles

  sta RESP0    ; 3 (54)
  sta RESP1    ; 3 (57)

  sta WSYNC    ; 3 (?)

  ; 2nd scanline ==============================================================
               ; - (0)
  sta HMOVE

  ldx #5         ; 2 (5)
_wait_for_hmclr_safe_strobing_2:
  dex                                 ; \
  bne _wait_for_hmclr_safe_strobing_2 ; / (5 - 1) * 5 + 4 = 24 (29)
  sta HMCLR

  sta WSYNC

  ; 3rd scanline ==============================================================
               ; - (0)
  sta HMOVE
  ldx #6
hi_score_overlay_kernel:
  ; end of 3rd, and 4th to 10th scanline ======================================
  sta WSYNC                ; 3 (73 -> 76)
                           ; - (0)
hi_score_overlay_kernel_2:
  sta HMOVE                ; 3 (3)
  lda SCORE_TEXT_HI-1,x    ; 4 (7)
  sta GRP0;'               ; 3 (10) GRP0' (buffer) has the "HI" sprite

  lda MAX_SCORE_DIGITS_54-1,x ; 4 (14) GRP0 will have the "HI" sprite
  sta GRP1;'                  ; 3 (17) GRP1' (buffer) has the hi-score 54
                              ;        digits

  lda MAX_SCORE_DIGITS_32-1,x ; 4 (21) GRP1 will have the hi-score 54 digits
  sta GRP0;'                  ; 3 (24) and GRP0' (buffer) the hi-score 32
                              ;        digits

  ldy MAX_SCORE_DIGITS_10-1,x ; 4 (28)

  lda SCORE_DIGITS_54-1,x     ; 4 (32)
  sta TEMP                    ; 3 (35)

  dex                         ; 2 (37)
  stx TEMP+1                  ; 3 (40) Save the index so reg X is free
  lda SCORE_DIGITS_32,x       ; 4 (44)
  sta TEMP+2                  ; 3 (47)
  ldx TEMP+2                  ; 3 (50) reg X has SCORE_DIGITS_32 sprite data (for stx GRP1)

  lda TEMP                    ; 3 (53) Restore reg A to SCORE_DIGITS_54-1,x
  ; GRP0 copy 1 (HI text) spans CC 161-168. sty GRP1 must fire at CC 169+
  ; to avoid splitting the sprite mid-draw. One nop shifts it to CC 171.
  ;nop                         ; 2 (55)
  sta $2D                     ; 3 (56)

  sty GRP1                    ; 3 (59) CC 171 — just after GRP0(0) ends
  sta GRP0                    ; 3 (62) CC 180 — after GRP1(0) ends at CC 178
  stx GRP1                    ; 3 (65) CC 189 — after GRP0(1) ends at CC 184
  sta GRP0                    ; 3 (68) CC 198 — after GRP1(1) ends at CC 194

  ldx TEMP+1                  ; 3 (71)

  sbeq end_of_score_kernel     ; 2/3 (73/74)
  jmp  hi_score_overlay_kernel_2  ; 3 (76)
end_of_hi_score_overlay_kernel_2:
  nop ; 2 (76)
  ;bne hi_score_overlay_kernel_2 ; 2/3 (75/76)
  ;sta WSYNC                   ; 3 (75)

end_of_score_kernel:
  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  lda BACKGROUND_COLOUR
  sta COLUBK

  nop
  nop
  nop
  nop
  nop
  nop

  lda #NUSIZX_ONE_COPY   ; 2 (5)
  sta NUSIZ0   ; 3 (8)
  sta NUSIZ1   ; 3 (11)

  sta VDELP0   ; 3 (14)
  sta VDELP1   ; 3 (17)

  sta GRP0
  sta GRP1

  sta WSYNC    ; 3 (?)
