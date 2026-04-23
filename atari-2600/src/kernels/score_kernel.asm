score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)

  ; 1st scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)

  lda #3       ; 2 (5) Set the graphics to display 3 close copies of GRP0/1
  sta NUSIZ0   ; 3 (8)
  sta NUSIZ1   ; 3 (11)

  ; Enable the V (A is #3 = #%00000011 so already has the bit 0 ON)
  sta VDELP0   ; 3 (14)
  sta VDELP1   ; 3 (17)

  sta WSYNC    ; 3 (?)

  ; 2nd scanline ==============================================================
               ; - (0)
  sta HMOVE
  sta WSYNC

score_kernel:;---------->>> 8 scanlines <<<---
  DEBUG_SUB_KERNEL #13, #8
