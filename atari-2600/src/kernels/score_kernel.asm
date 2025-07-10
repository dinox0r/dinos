score_setup_kernel:;---->>> 2 scanlines <<<----
               ; - (0)
  sta HMOVE    ; 3 (3)
  lda #$75
  sta COLUBK
  sta WSYNC

  sta HMOVE   
  sta WSYNC

score_kernel:;---------->>> 10 scanlines <<<---
  DEBUG_SUB_KERNEL #$20, #8
