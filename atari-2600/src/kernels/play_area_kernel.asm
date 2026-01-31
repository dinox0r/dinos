play_area_setup_kernel:;----->>> 5 scanlines <<<-----
  ; End the last scanline from the previous kernel (sky kernel)
  sta WSYNC     ; 3 (8)

  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)

  ; Set GRP0 coarse position: 28 cycles for dino in standing position, and 27
  ; for crouching

  lda BACKGROUND_COLOUR ; 3 (6)
  sta COLUBK            ; 3 (9)

  lda #0                ; 2 (11)
  sta GRP0              ; 3 (14)
  sta GRP1              ; 3 (17)

  lda #FLAG_DINO_CROUCHING      ; 2 (19)
  bit GAME_FLAGS                ; 3 (22)
  sbeq _dino_is_not_crouching_1 ; 2/3 (24/25)

                                ; - (24)
  sta RESP0                     ; 3 (27)

  ; Turns the next 'sta RESP0' (opcodes 85 10) into '2C 85 10' or 'bit $8510'
  ; which does nothing (meaningful), avoiding the need for a
  ; 'jmp _end_grp0_coarse_position'
  .byte $2C

_dino_is_not_crouching_1:       ; - (25)
  sta RESP0  ; 3 (28) - TV beam is now at dino's x pos

_end_grp0_coarse_position:
  lda #$10         ; 2 (30/32) - In both cases, Player 0 has to be shifted
  sta HMP0         ; 3 (33/35)   to the left by 1 pixel
  sta WSYNC        ; 3 (36/39)

  ; 2nd scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; Maybe a more useful instruction here? We need this 3 cycles so 
  ; the numbers below add up (don't think of strobing HMCLR, remember that
  ; you can't touch HMMx registers 24 cyles after strobing HMOVE
  sta $2D       ; 3 (6)

  ; Set M0 coarse position
  ;
  ; If dino is crouching, M0 needs to be strobed at cycle 25. Otherwise,
  ; M0 needs to be strobed at cycle 22
  lda #FLAG_DINO_CROUCHING   ; 2 (8)
  bit GAME_FLAGS             ; 3 (11)
  ; this nop shifts the _dino_is_not_crouching
  ; label so it doesn't cross page boundary
  nop             ; 2 (13)
  nop             ; 2 (15)
  ; using the sbeq macro here as is super important to get the timing
  ; right in this section
  sbeq _dino_is_not_crouching_2 ; 2/3 (17/18)
_dino_is_crouching_2:  ; - (17)
  inc $2D              ; 5 (22) - Wait/waste 5 cycles (2 bytes)

  sta RESM0            ; 3 (25)
  sta $2D              ; 3 (28) - Wait/waste 3 cycles (2 bytes)
  sta RESBL            ; 3 (31)

  jmp _end_m0_coarse_position  ; 3 (34)

_dino_is_not_crouching_2: ; - (18)
  INSERT_NOPS 2        ; 4 (22)

  sta RESM0            ; 3 (25)

_end_m0_coarse_position: ; (25/34)

_set_obstacle_x_position:
  sta HMCLR        ; 3 (Worst case scenario CPU count at this point is 37)

  lda OBSTACLE_X_INT
  SET_STITCHED_SPRITE_X_POS #PLAYER_1_INDEX, #MISSILE_1_INDEX
  sta WSYNC      ; 3 (31)

_last_setup_scanline:
  ; 5th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ldy #PLAY_AREA_TOP_Y   ; 2 (5)

  lda #FLAG_DINO_CROUCHING       ; 2 (7)
  bit GAME_FLAGS                 ; 3 (10)
  bne __assign_crouching_kernel  ; 2/3 (12/13)

  lda #<legs_and_floor_kernel      ; 2 (14)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (17)
  lda #>legs_and_floor_kernel      ; 2 (19)
  sta PTR_AFTER_PLAY_AREA_KERNEL+1 ; 3 (22)

  lda #PLAY_AREA_BOTTOM_Y          ; 2 (24)

  jmp __end_setting_up_middle_section_kernel ; 3 (27)

__assign_crouching_kernel:         ; - (13)
  lda  #<dino_crouching_kernel     ; 2 (15)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (18)
  lda  #>dino_crouching_kernel     ; 2 (20)
  sta PTR_AFTER_PLAY_AREA_KERNEL+1 ; 3 (23)

  lda #CROUCHING_REGION_TOP_Y      ; 2 (26)

__end_setting_up_middle_section_kernel:

  sta PLAY_AREA_MIN_Y  ; 3 (27/29) - If crouching, the play area min y is changed

  ; TODO can remove this sec?
  sec         ; 2 (31) Set the carry ahead of time for the next scanline

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR   ; 3 (34)

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the M1 state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0      ; 2 (36)
  tax         ; 2 (38)

  sta CXCLR   ; 3 (41) Clear all collisions

play_area_kernel: ;------------------>>> 31 2x scanlines <<<--------------------
  sta WSYNC      ; 3 (43)

  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first then load dino's data for the next scanline
  DRAW_OBSTACLE  ; 13 (16)

  ; 44 (60)
  LOAD_DINO_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _play_area__end_of_1st_scanline

  ; --- Dino eye blink override (splash screen only) -------------------------
  ;
  ; When the kernel reaches the scanline corresponding to the dino's eye
  ; position, this logic conditionally overrides the sprite data so the
  ; eyes appear closed, producing a simple blinking animation.
  ;
  ; Visual effect (per scanline):
  ;
  ;     eyes open             eyes closed
  ;      ▒▒▒▒▒▒▒▒              ▒▒▒▒▒▒▒▒       <-- previous scanline
  ;     ██ ███████            ██████████      <-- current (eye) scanline
  ;     ▒▒▒▒▒▒▒▒▒▒            ▒▒▒▒▒▒▒▒▒▒      <-- next scanline
  ;
  ; This behavior is enabled only during the splash screen, where the
  ; dino is rendered at a fixed Y position. This constraint allows the
  ; blink effect to be implemented by modifying a single scanline rather
  ; than introducing a dedicated "eyes closed" sprite, saving
  ; approximately 20 bytes of ROM.
  ;
  ; The sprite override occurs only when all of the following conditions
  ; are met:
  ;   - The current scanline equals DINO_EYE_SCANLINE_Y
  ;   - Splash screen mode is active
  ;   - The blink flag is set
  ;
  ; When these conditions are satisfied, register X is forced to $FF,
  ; selecting the "eyes closed" sprite data for this scanline only.
  ;
  cpy #DINO_EYE_SCANLINE_Y            ; 2 (62)
  bne _play_area__end_of_1st_scanline ; 2/3 (64/65)
  bit GAME_FLAGS                      ; 3 (67)
  ; GAME_FLAGS bit usage:
  ;   bit 7 = blink active
  ;   bit 6 = splash screen mode
  ; bit 7 ON implies bit 6 ON
  bpl _play_area__end_of_1st_scanline ; 2/3 (69/70) - blink not active
  ; Override sprite index for this scanline (eyes closed)
  ldx #$FF                            ; 2 (72)

_play_area__end_of_1st_scanline: ; -
  sta WSYNC                      ; 3 (worst case 72 -> 75)

  ; 2nd scanline ==============================================================
                           ; - (0)
  sta HMOVE                ; 3 (3)
  DRAW_DINO                ; 3 (6)

  ; 29 (35)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY, _play_area__end_of_2nd_scanline

_play_area__end_of_2nd_scanline:  ; - (35)

  dey                      ; 2 (37)
  cpy PLAY_AREA_MIN_Y      ; 3 (40)
  sec                      ; 2 (42) Set the carry for the dino scanline
  bne play_area_kernel     ; 2/3 (44/45)

  ; At the final scanline of the play area, and just before the next scanline
  ; begins, jump to the next kernel. The destination depends on the dino's
  ; state—either the crouching kernel (if the dino is crouching) or the floor
  ; kernel (if it's not).
  jmp (PTR_AFTER_PLAY_AREA_KERNEL)  ; 5 (50)
