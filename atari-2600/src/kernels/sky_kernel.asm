sky_setup_kernel:;-->>> 4 scanlines <<<-----
  sta WSYNC
                 ; - (0)
  sta HMOVE      ; 3 (3)

  lda #SKY_FLAG_SINGLE_CLOUD_LAYER_ON ; 2 (13)
  bit SKY_FLAGS                       ; 3 (16)
  bne double_cloud_layer              ; 2/3 (18/19)

  lda SKY_FLAGS                       ; 3 (21)
  ; If is nightime, then show moon and stars, otherwise the single cloud layer
  bmi moon_and_stars_layer            ; 2/3 (23/24)

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
single_cloud_layer:                ; - (22)

  lda #SKY_SINGLE_CLOUD_SCANLINES  ; 2 (24)
  sta CLOUD_LAYER_SCANLINES        ; 3 (25)
  lda CLOUD_1_TOP_Y                ; 3 (28)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (31)
  lda CLOUD_1_X                    ; 3 (34)
  sta CURRENT_CLOUD_X              ; 3 (37)
  jsr render_cloud_layer           ; 6 (43) + 33 (render_cloud_layer)

  jmp end_of_sky_kernel            ; 3 (12)

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
double_cloud_layer:                ; - (13)

  lda #SKY_2_CLOUDS_SCANLINES      ; 2 (14)
  sta CLOUD_LAYER_SCANLINES        ; 3 (17)
  lda #SKY_CLOUDS_2_AND_3_TOP_Y    ; 2 (19)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (22)
  lda CLOUD_2_X                    ; 3 (25)
  sta CURRENT_CLOUD_X              ; 3 (28)
  jsr render_cloud_layer           ; 6 (?)

  lda #SKY_CLOUDS_2_AND_3_TOP_Y    ; 2 (?)
  sta CURRENT_CLOUD_TOP_Y          ; 3 (?)
  lda CLOUD_3_X                    ; 3 (?)
  sta CURRENT_CLOUD_X              ; 3 (?)
  jsr render_cloud_layer           ; 6 (?)

  sta WSYNC
  sta HMOVE
  jmp end_of_sky_kernel

moon_and_stars_layer:
_moon_and_stars_layer_setup:

  ldx #1
__setup_sprite_pos:
   lda MOON_POS_X,x  ; 4 (_/12)

  ;--------------------------------------------------------------------------
  ; [!] Disclaimer
  ;--------------------------------------------------------------------------
  ; The following positioning code is copied almost verbatim from:
  ; https://forums.atariage.com/topic/377268-strobing-resp0-in-hmove-blanking-area-gives-unexpected-result/
  ;--------------------------------------------------------------------------

  ; Works from 6..155 (as subroutine only until 140)
   sec          ; 2 (14)
   sbc #6       ; 2 (16) - correction for players (+1 if double/quad, -1 rest)
   sta WSYNC
   sta HMOVE
___divide_loop:
   sbc #15
   bcs ___divide_loop
   eor #7
   asl
   asl
   asl
   asl
   sta HMP0,x   ; strobe at 7..142 (min: 7+5-6=6; max: 142+5+8=155 ; for subroutine skip WSYNC)
   sta RESP0,x

__end_setup_sprite_pos:
  sta WSYNC  ;
             ; - (0)
  sta HMOVE  ; 3 (3)
  pha        ; \
  pla        ; |
  pha        ; | 16 cycles (19) - 5 bytes
  pla        ; |
  nop        ; /
  lda #0     ; 2 (21)
  sta HMP0,x ; 4 (25)

  dex        ; 2 (27)
  bpl __setup_sprite_pos ; 2/3 (29/30)

  lda SKY_FLAGS             ; 3 (32)
  and #3                    ; 2 (34)
  bne _prepare_for_scanline ; 2/3 (36/37)
__reflect_moon_sprite:      ; - (36)
  lda #%00001000            ; 2 (38)
  sta REFP0                 ; 3 (41)

_prepare_for_scanline:      ; - (41/37)
  lda #0     ; 2 (43)
  tax        ; 2 (45)
  ldy #SKY_SCANLINES ; 2 (47)
  ;ldy #SKY_SCANLINES-#MOON_AND_STARS_LAYER_SETUP_SCANLINES ; 2 (47)


_moon_and_stars_layer_scanline:
  sta WSYNC    ; 3 (47 -> 50 if coming from 'end_moon_and_stars_layer')
               ; - (0)
  sta HMOVE    ; 3 (3)
  sta GRP0     ; 3 (6)
  stx GRP1     ; 3 (9)

__check_y_is_within_star:
  tya              ; 2 (11)
  sec              ; 2 (13)
  sbc STAR_POS_Y   ; 3 (16)
  adc #STAR_HEIGHT ; 2 (18)
  bcs __y_is_within_star  ; 2/3 (20/21)
__y_is_not_within_star:
  ldx #0                       ; 2 (22)
  jmp __check_y_is_within_moon ; 3 (25)
__y_is_within_star:        ; - (21)
  LAX (PTR_STAR_SPRITE),y  ; 5 (26)

__check_y_is_within_moon:  ; - (25/26)
  tya              ; 2 (28) 
  sec              ; 2 (30) - can this 'sec' be removed?
  sbc #MOON_POS_Y  ; 2 (32)
  adc #MOON_HEIGHT ; 2 (34)
  bcs __y_is_within_moon ; 2/3 (36/37)
__y_is_not_within_moon:
  lda #0                       ; 2 (38)
  jmp end_moon_and_stars_layer ; 3 (41)

__y_is_within_moon:
  lda (PTR_MOON_SPRITE),y      ; 5 (42)

end_moon_and_stars_layer:             ; - (41/42)
  dey                                 ; 2 (44)
  bne _moon_and_stars_layer_scanline  ; 2/3 (46/47)

end_of_sky_kernel:
  lda #0
  sta REFP0
