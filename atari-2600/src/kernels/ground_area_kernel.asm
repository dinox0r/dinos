ground_area_kernel:
  sta WSYNC                   ; 3 (76, 44 if coming from this kernel)

  ; 1st scanline ==============================================================
                                ; - (0)
  sta HMOVE                     ; 3 (3)
  lda #0                        ; 2 (5)
  sta PF0                       ; 3 (8)
  sta PF1                       ; 3 (11)
  lda PEBBLE_CACHED_OBSTACLE_M1 ; 3 (14)
  DRAW_OBSTACLE                 ; 13 (27)
  lda #0                        ; 3 (30)
  sta PF2                       ; 3 (33)

  ; 28 (61)
  LOAD_DINO_P0_IF_IN_RANGE #IGNORE_CARRY, _ground__end_of_1st_scanline
_ground__end_of_1st_scanline:
  sec                         ; 2 (63)
  sta WSYNC                   ; 3 (66)

  ; 2nd scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  DRAW_DINO                   ; 3 (6)

  ; 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _ground__end_of_2nd_scanline
_ground__end_of_2nd_scanline:

  dey                         ; 2 (35)
  bne ground_area_kernel      ; 2/3 (37/38)

  lda #0                      ; 2 (39)
  sta GRP0                    ; 3 (42)
  sta GRP1                    ; 3 (45)
  sta ENAM0                   ; 3 (48)
  sta ENAM1                   ; 3 (51)
  sta ENABL                   ; 3 (54)
  sta PF0                     ; 3 (57)
  sta PF1                     ; 3 (60)
  sta PF2                     ; 3 (63)

  sta WSYNC                   ; 3 (66)
  ;----------------------------------------------------------------------------
                              ; - (0)
  sta HMOVE                   ; 3 (3)
