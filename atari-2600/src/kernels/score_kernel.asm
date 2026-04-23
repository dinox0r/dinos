score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)

  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  lda #FLAG_MAX_SCORE_PRESENT               ; 2 (5)
  bit GAME_FLAGS                            ; 3 (8)
  beq simple_score_subkernel_setup          ; 2/3 (10/11)
  lda FRAME_COUNT                           ; 3 (13)
  and #3                                    ; 2 (15)
  beq score_with_hi_score_subkernel_setup   ; 2/3 (17/18)

simple_score_subkernel_setup:  ; - (either 11 or 17)

  lda #NUSIZX_TWO_COPIES_CLOSE ; 2 (19)
  sta NUSIZ0                   ; 3 (22)

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
