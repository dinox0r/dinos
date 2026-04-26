; There are 2 subkernels for the score:
;
; 1. The primary score kernel, which shows the continuously updating
;    5-digit score:
;
;                                           primary score kernel
;                                                  /-----\
;                                                   00042
;       o██                       █
;   █   ███                     █ █ █
; -- ████  ---------------------█████---------------------
;     ██                          █
;
; 2. The hi-score overlay kernel, which shows the hi-score in full and
;    3 digits from the primary score (only 3 because that's all that can be
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
; The sprite layout for the primary score kernel is:
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
;         sta RESP0 at CPU cycle 63
;           │
;           ↓
;            00042 - principal score kernel
;   HI 00123 000   - hi-score overlay kernel
;  ↑
;  │
;  sta RESP0 at CPU cycle 52
;
score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)

  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

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
  ; if TEMP goto primary_score_kernel_setup
  ;
  ; This implementation reduces ROM usage and avoids extra branching.
  ; Both paths start with the same CPU cycle count, making it easier for
  ; the score positioning code to keep track of the colour cycle timing.
  lda #FLAG_MAX_SCORE_AVAILABLE       ; 2 (5)
  and GAME_FLAGS                      ; 3 (8)
  eor #FLAG_MAX_SCORE_AVAILABLE       ; 2 (10)
  sta TEMP                            ; 3 (13)
  lda FRAME_COUNT                     ; 3 (16)
  and #3                              ; 2 (18)
  ora TEMP                            ; 3 (21)
  bne hi_score_overlay_kernel_setup   ; 2/3 (23/24)

principal_score_kernel_setup:  ; - (23)

  ;
  ; Need to reach CPU cycle 65 
  lda #NUSIZX_TWO_COPIES_CLOSE ; 2 (25)
  sta NUSIZ0                   ; 3 (28)

  ; Offset GRP1 by -1px (1px to the left) so it joins GRP0 at its end
  lda #$10                     ; 2 (30)
  sta HMP1                     ; 3 (33)

  ; Target position is CPU cycle 63:
  ldy #5                       ; 2 (35)
_principal_score_kernel_coarse_pos:
  dey                                    ;\
  bne _principal_score_kernel_coarse_pos ;/ 5 * 4 + 4 = 29 (59)
  nop                          ; 2 (61)
  nop                          ; 2 (63)

  sta RESP0                    ; 3 (66)
  sta RESP1                    ; 3 (69)

  sta WSYNC                    ; 3 (72)

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  ; Even though, some resources stay that is fine, strobing HMCLR before 24
  ; cycles after a sta HMOVE has always produced positioning glitches in this
  ; project
  ldy #3         ; 2 (5)
_wait_for_hmclr_safe_strobing:
  dey                               ; \
  bne _wait_for_hmclr_safe_strobing ; / 5 * 3 + 4 = 19 (24)

  sta HMCLR      ; 3 (27)

  sta WSYNC      ; 3 (30)

  ; 3rd scanline ==============================================================
                 ; - (0)
  sta HMOVE
  ldy #6
principal_score_kernel:
  sta WSYNC
  ; 4 to 10th scanline ========================================================
                       ; - (0)
  sta HMOVE
  lda #$59
  sta COLUBK

  dey
  bne principal_score_kernel
  sta WSYNC
  ; AI suggested edit: jmp end_of_score_kernel — replaced with beq: the loop
  ; exits when dey makes Y=0, and sta WSYNC doesn't affect flags, so Z=1
  beq end_of_score_kernel

hi_score_overlay_kernel_setup: ; - (18)

  lda #NUSIZX_THREE_COPIES_CLOSE   ; 2 (20)
  sta NUSIZ0   ; 3 (23)
  sta NUSIZ1   ; 3 (26)

  ; Enable the VDEL (A is #3 = #%00000011 so already has the bit 0 ON)
  sta VDELP0   ; 3 (29)
  sta VDELP1   ; 3 (32)

  sta WSYNC    ; 3 (?)

  ; 2nd scanline ==============================================================
               ; - (0)
  sta HMOVE
  sta WSYNC

  ; 3rd scanline ==============================================================
               ; - (0)
  sta HMOVE
  ldy #6
hi_score_overlay_kernel:
  sta WSYNC
  sta HMOVE
  dey
  bne hi_score_overlay_kernel
  sta WSYNC

end_of_score_kernel:
  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  lda BACKGROUND_COLOUR
  sta COLUBK
  sta COLUBK
  sta COLUBK
  sta COLUBK
  sta COLUBK
  sta COLUBK

  lda #NUSIZX_ONE_COPY   ; 2 (5)
  sta NUSIZ0   ; 3 (8)
  sta NUSIZ1   ; 3 (11)

  sta VDELP0   ; 3 (14)
  sta VDELP1   ; 3 (17)

  sta GRP0
  sta GRP1

  sta WSYNC    ; 3 (?)
