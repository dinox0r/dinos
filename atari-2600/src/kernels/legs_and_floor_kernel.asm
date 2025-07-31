legs_and_floor_kernel:
  sta WSYNC   ; 3 (--)

  ; 1st scanline ========================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  DRAW_OBSTACLE  ; 13 (16)

  ; 28 (44)
  LOAD_DINO_P0_IF_IN_RANGE #SET_CARRY, _legs_and_floor__end_of_1st_scanline

  ; In case the dino was crouching, then restore P0 and M0 to standing mode
  lda #FLAG_DINO_CROUCHING  ; 2 (46)
  bit GAME_FLAGS            ; 3 (49)
  beq _legs_and_floor__end_of_1st_scanline            ; 2/3 (51)
  ; Override the P0 offset if dino was crouching to position it so it matches
  ; the expected location for the legs kernel
  lda #$20    ; 2 (53)
  sta HMP0    ; 3 (56)
  lda #0      ; 2 (58)
  sta NUSIZ0  ; 3 (61)
  sta ENAM0   ; 3 (67)

_legs_and_floor__end_of_1st_scanline:
  sec         ; 2 (69)
  sta WSYNC   ; 3 (72)

  ; 2nd scanline ========================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  DRAW_DINO     ; 3 (6)

  ; 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _legs_and_floor__decrement_y
_legs_and_floor__decrement_y:  ; - (33)
  dey          ; 2 (35)

  ; Do the obstacle y-coord check here and save the result to avoid doing
  ; the check on the 4th scanline, thus saving some cycles needed to do the
  ; playfield update
  sta TEMP             ; 3 (38)
  sec                  ; 2 (40)
  tya                  ; 2 (42)
  sbc OBSTACLE_Y       ; 3 (45)
  adc #OBSTACLE_HEIGHT ; 2 (47)
  ;sbcs _legs_2nd_scanline__obstacle_y_within_range ; 2/3 (49/50)
  bcs _legs_2nd_scanline__obstacle_y_within_range ; 2/3 (49/50)
  lda #0
  sta PEBBLE_CACHED_OBSTACLE_GRP1      ; 3 (58)
  sta PEBBLE_CACHED_OBSTACLE_M1        ; 3 (66)
  jmp _legs_2nd_scanline__end_of_scanline
_legs_2nd_scanline__obstacle_y_within_range: ; - (50)
  lda (PTR_OBSTACLE_SPRITE),y          ; 5 (55)
  sta PEBBLE_CACHED_OBSTACLE_GRP1      ; 3 (58)
  lda (PTR_OBSTACLE_MISSILE_1_CONF),y  ; 5 (63)
  sta PEBBLE_CACHED_OBSTACLE_M1        ; 3 (66)
_legs_2nd_scanline__end_of_scanline:
  lda TEMP     ; 3 (69)
  sta WSYNC    ; 3 ()

  ; 3rd scanline ========================================================
                              ; - (0)
; For reference:
;       ┌──────────────────────────────────┬──────────────────────────────────┐
;       │    Left side of the playfield    │    Right side of the playfield   │
;       ├───────────────┬──────────────────┼───────────────┬──────────────────┤
;       │ write b4 (x≤) │ write again (x≥) │ write b4 (x≤) │ write again (x≥) │
; ┌─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF0 │      22*      │       28         │  ⌊49.3⌋ = 49  │   ⌈54.6⌉ = 55    │
; ├─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF1 │      28       │    ⌈38.6⌉ = 39   │  ⌊54.6⌋ = 54  │   ⌈65.3⌉ = 66    │
; ├─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF2 │  ⌊38.6⌋ = 38  │    ⌈49.3⌉ = 50   │  ⌊65.3⌋ = 65  │    ¯\_(ツ)_/¯    │
; └─────┴───────────────┴──────────────────┴───────────────┴──────────────────┘
; *: All values represent CPU cycles

  sta HMOVE       ; 3 (3)
  ;DRAW_OBSTACLE  ; 13 (16)
  stx GRP1        ; 3 (6)
  sta ENAM1       ; 3 (9)
  lda PEBBLE_PF0  ; 3 (12)
  sta PF0         ; 3 (15)
  lda PEBBLE_PF1  ; 3 (18)
  sta PF1         ; 3 (21)
  lda PEBBLE_PF2  ; 3 (24)
  sta HMCLR       ; 3 (27)

  sta PF2         ; 3 (30)
  lda PEBBLE_PF3  ; 3 (33)
  sta PF0         ; 3 (36)
  lda PEBBLE_PF4  ; 3 (39)
  sta PF1         ; 3 (42)
  lda PEBBLE_PF5  ; 3 (45)
  sta PF2         ; 3 (48)

  ; 28 (44)
  ;LOAD_DINO_P0_IF_IN_RANGE #SET_CARRY, _legs_and_floor__end_of_3rd_scanline
  sec                  ; 2 (50)
  tya                  ; 2 (52)
  sbc DINO_TOP_Y_INT   ; 3 (55)
  adc #DINO_HEIGHT     ; 2 (57)
  bcs _legs_3rd_scanline__dino_y_within_range ; 2/3 (59/60)
  lda #0               ; 2 (62)
  tax                  ; 2 (64)
  sta ENAM0            ; 3 (67)
  jmp _legs_and_floor__end_of_3rd_scanline ; 3 (70)

_legs_3rd_scanline__dino_y_within_range: ; - (59)
  lda (PTR_DINO_OFFSET),y  ; 5 (64)
  sta HMP0                 ; 3 (67)
  LAX (PTR_DINO_SPRITE),y  ; 5 (62)

_legs_and_floor__end_of_3rd_scanline:
  sta WSYNC                ; 3 (75)

  ; 4th scanline ========================================================
                         ; - (0)
  sta HMOVE              ; 3 (3)

; For reference:
;       ┌──────────────────────────────────┬──────────────────────────────────┐
;       │    Left side of the playfield    │    Right side of the playfield   │
;       ├───────────────┬──────────────────┼───────────────┬──────────────────┤
;       │ write b4 (x≤) │ write again (x≥) │ write b4 (x≤) │ write again (x≥) │
; ┌─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF0 │      22*      │       28         │  ⌊49.3⌋ = 49  │   ⌈54.6⌉ = 55    │
; ├─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF1 │      28       │    ⌈38.6⌉ = 39   │  ⌊54.6⌋ = 54  │   ⌈65.3⌉ = 66    │
; ├─────┼───────────────┼──────────────────┼───────────────┼──────────────────┤
; │ PF2 │  ⌊38.6⌋ = 38  │    ⌈49.3⌉ = 50   │  ⌊65.3⌋ = 65  │    ¯\_(ツ)_/¯    │
; └─────┴───────────────┴──────────────────┴───────────────┴──────────────────┘
; *: All values represent CPU cycles
  lda FLOOR_PF0         ; 3 (6)
  sta PF0               ; 3 (9)
  DRAW_DINO             ; 3 (12)
  lda FLOOR_PF1         ; 3 (15)
  sta PF1               ; 3 (18)
  lda FLOOR_PF2         ; 3 (21)
  sta PF2               ; 3 (24)

  sta HMCLR                        ; 3 (27)
  ldx PEBBLE_CACHED_OBSTACLE_GRP1  ; 3 (30)
  lda PEBBLE_CACHED_OBSTACLE_M1    ; 3 (33)
  sta HMM1                         ; 3 (36)

  lda FLOOR_PF3         ; 3 (51)
  sta PF0               ; 3 (54)
  lda FLOOR_PF4         ; 3 (57)
  sta PF1               ; 3 (60)
  lda FLOOR_PF5         ; 3 (63)
  sta PF2               ; 3 (66)

_legs_and_floor__end_of_4th_scanline:
  dey                   ; 2 (68)
  sec                   ; 2 (70)

