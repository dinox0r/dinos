sky_setup_kernel:;-->>> 4 scanlines <<<-----
  sta WSYNC
                 ; - (0)
  sta HMOVE      ; 3 (3)

  lda #$FC       ; 5 cycles - For debugging - paints the sky yellow
  sta COLUBK     ; can be ignored for total CPU cycles count

  lda GAME_FLAGS            ; 3 (6)
  eor #FLAG_SKY_LAYER_1_ON ; 2 (8)
  ;ora #FLAG_SKY_LAYER_1_ON  ; -
  sta GAME_FLAGS            ; 3 (10)

  bpl double_cloud_layer    ; 2/3 (12/13)

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
single_cloud_layer:                ; - (12)

  lda #SKY_SINGLE_CLOUD_SCANLINES  ; 2 (14)
  sta CLOUD_LAYER_SCANLINES        ; 3 (17)
  lda CLOUD_1_TOP_Y                ; 3 (20)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (23)
  lda CLOUD_1_X_INT                ; 3 (26)
  sta CURRENT_CLOUD_X              ; 3 (29)
  jsr render_cloud_layer

  jmp end_of_sky_kernel            ; 3 (12)

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
double_cloud_layer:                ; - (13)

  lda #SKY_2_CLOUDS_SCANLINES      ; 2 (14)
  sta CLOUD_LAYER_SCANLINES        ; 3 (17)
  lda CLOUD_2_TOP_Y                ; 3 (20)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (23)
  lda CLOUD_2_X_INT                ; 3 (26)
  sta CURRENT_CLOUD_X              ; 3 (29)
  jsr render_cloud_layer           ; 6 (?)

  lda CLOUD_3_TOP_Y                ; 3 (?)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (?)
  lda CLOUD_3_X_INT                ; 3 (?)
  sta CURRENT_CLOUD_X              ; 3 (?)
  jsr render_cloud_layer           ; 6 (?)

  sta WSYNC
  sta HMOVE
  jmp end_of_sky_kernel

moon_and_stars_layer:
  

end_of_sky_kernel:
