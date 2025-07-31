sky_setup_kernel:;-->>> 4 scanlines <<<-----
                 ; - (0)
  sta HMOVE      ; 3 (3)

  lda #$FC       ; 5 cycles - For debugging - paints the sky yellow
  sta COLUBK     ; can be ignored for total CPU cycles count

  lda GAME_FLAGS            ; 3 (6)
  ;eor #FLAG_SKY_LAYER_1_ON ; 2 (8)
  ora #FLAG_SKY_LAYER_1_ON  ; -
  sta GAME_FLAGS            ; 3 (10)

  bpl double_cloud_layer    ; 2/3 (12/13)

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
single_cloud_layer:         ; - (12)

  lda #SKY_SCANLINES        ; 2 (14)
  sta CLOUD_LAYER_SCANLINES ; 3 (17)
  lda CLOUD_1_TOP_Y         ; 3 (20)
  sta CURRENT_CLOUD_TOP_Y   ; 3 (23)
  lda CLOUD_1_X_INT         ; 3 (26)
  sta CURRENT_CLOUD_X       ; 3 (29)
  jsr render_cloud_layer

  ;lda #SKY_SCANLINES        ; 2 (14)
  ;sta CLOUD_LAYER_SCANLINES ; 3 (17)
  ;lda CLOUD_1_TOP_Y         ; 3 (20)
  ;sta CURRENT_CLOUD_TOP_Y   ; 3 (23)
  ;lda CLOUD_1_X_INT         ; 3 (26)
  ;sta CURRENT_CLOUD_X       ; 3 (29)
  ;jsr set_cloud_pos_x       ; 6 for jsr + 27 of the subroutine (33 + 29 = 62)
  ;                          ; then the subroutine consumes a whole scanline
  ;                          ; and then resumes execution on cycle 27 of the
  ;                          ; next scanline after
  ;INCLUDE "kernels/single_cloud_kernel_layer.asm"

  sta HMOVE
  jmp end_of_sky_kernel

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
double_cloud_layer:        ; - (13)
double_cloud_layer_setup:
  INCLUDE "src/kernels/two_clouds_kernel_layer.asm"

end_of_sky_kernel:
