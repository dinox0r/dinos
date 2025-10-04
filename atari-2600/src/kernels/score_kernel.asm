score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)
  sta HMOVE    ; 3 (3)
  lda #$75
  sta COLUBK
  sta WSYNC

  sta HMOVE   
  sta WSYNC

score_kernel:;---------->>> 8 scanlines <<<---
  DEBUG_SUB_KERNEL #13, #8
