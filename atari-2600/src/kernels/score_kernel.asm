score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)

  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  ; The intent in the following is to do the check:
  ;
  ; // show the full score (score + hi score) when the max score
  ; // flag is ON and every 4 frames
  ; if (GAME_FLAGS & FLAG_MAX_SCORE_AVAILABLE) and
  ;    (FRAME_COUNT % 4) == 0 then goto setup_score_with_hi_score
  ;
  ; but is implemented as:
  ;
  ; bool TEMP = not (GAME_FLAGS & FLAG_MAX_SCORE_AVAILABLE)
  ; TEMP = TEMP or (FRAME_COUNT % 4) != 0
  ; if TEMP setup_score_with_hi_score
  ;
  ; This implementation reduces both ROM usage and branching.
  ; Both branches start with the same CPU count, making it easier for the score
  ; positioning later to keep track of the colour cycle count
  lda #FLAG_MAX_SCORE_AVAILABLE             ; 2 (5)
  and GAME_FLAGS                            ; 3 (8)
  eor #FLAG_MAX_SCORE_AVAILABLE             ; 2 (10)
  sta TEMP                                  ; 3 (13)
  lda FRAME_COUNT                           ; 3 (16)
  and #3                                    ; 2 (18)
  ora TEMP                                  ; 3 (21)
  bne score_with_hi_score_subkernel_setup   ; 2/3 (23/24)

simple_score_subkernel_setup:  ; - (23)

  lda #NUSIZX_TWO_COPIES_CLOSE ; 2 (25)
  sta NUSIZ0                   ; 3 (28)
  ldy #4                       ; 2 (30)
_simple_score_subkernel_coarse_pos:
  dey                          ; 2 (32,
  bne _simple_score_subkernel_coarse_pos
  ;                            

  sta WSYNC    ; 3 (?)

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE
  sta WSYNC

  ; 3rd scanline ==============================================================
                 ; - (0)
  sta HMOVE
  ldy #6
simple_score_subkernel:
  sta WSYNC
  ; 4 to 10th scanline ========================================================
                       ; - (0)
  sta HMOVE
  dey
  bne simple_score_subkernel
  sta WSYNC
  jmp end_of_score_kernel

score_with_hi_score_subkernel_setup: ; - (18)

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
score_with_hi_score_subkernel:
  sta WSYNC
  sta HMOVE
  dey
  bne score_with_hi_score_subkernel
  sta WSYNC

end_of_score_kernel:
  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  lda #NUSIZX_ONE_COPY   ; 2 (5)
  sta NUSIZ0   ; 3 (8)
  sta NUSIZ1   ; 3 (11)

  sta VDELP0   ; 3 (14)
  sta VDELP1   ; 3 (17)

  sta GRP0
  sta GRP1

  sta WSYNC    ; 3 (?)
