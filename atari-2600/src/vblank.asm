;------------------------------------------------------------------------------
; V-BLANK (37 scanlines)
;------------------------------------------------------------------------------
vblank:

  ; Set the timer for the remaining VBLANK period (37 lines)
  ; 76 cpu cycles per scanline, 37 * 76 = 2812 cycles / 64 cycles per ticks = 43
  lda #43
  sta TIM64T

;==============================================================================
; BEGIN FRAME SETUP (VBLANK TIME)
;==============================================================================
start_frame_setup:

  ; Check Joystick for Jump
check_joystick:
  ; SWCHA reference: REMEMBER! The bit will be 0 only if pressed
  ;
  ; Bit    |  Mask       |
  ; (L->R) | (in binary) | Direction | Player
  ; ------------------------------------------
  ;    7   | #%10000000  | right     | 0
  ;    6   | #%01000000  | left      | 0
  ;    5   | #%00100000  | down      | 0
  ;    4   | #%00010000  | up        | 0
  ;    3   | #%00001000  | right     | 1
  ;    2   | #%00000100  | lef       | 1
  ;    1   | #%00000010  | down      | 1
  ;    0   | #%00000001  | up        | 1
  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
  ; If in splash screen mode (6th bit of game flags), jump straight into check
  ; if any button has been pressed
  bvs _check_for_any_button
  beq _check_joystick_down
  ; If the game over timer is still going, ignore any input, this is to 
  ; give the player a brief pause so they get to see the game over screen 
  ; and don't skip it by an accidental button press
  lda GAME_OVER_TIMER
  beq _check_for_any_button
  jmp end_frame_setup

_check_for_any_button:
  ; Check the button first
  bit INPT4
  bpl __button_pressed
  ; If not, check all joystick directions
  lda #%11110000      ; Query if any direction was pressed
  and SWCHA
  cmp #%11110000
  beq __no_input
__button_pressed:
  jmp on_game_init    ; If any button was preset, reset
__no_input:
  jmp end_frame_setup

_check_joystick_down:
  lda #%00100000 ; down (player 0)
  bit SWCHA
  beq _on_joystick_down

  ; Clear the crouching flag as the player might have released the
  ; joystick down, in which case the dino is not crouching anymore
  lda GAME_FLAGS
  and #TOGGLE_FLAG_DINO_CROUCHING_OFF
  sta GAME_FLAGS

_check_joystick_button:
  bit INPT4        ; bit 7 will be on if the button was pressed
  bpl _on_button_pressed

_check_joystick_up:
  lda #%00010000 ; up (player 0)
  bit SWCHA
  bne _end_check_joystick  ; not pressing UP

_on_button_pressed:
  jsr rnd8
_on_joystick_up:
  jsr rnd8
  ; if it's already jumping, ignore
  lda #FLAG_DINO_JUMPING
  bit GAME_FLAGS
  bne _end_check_joystick

  ora GAME_FLAGS ; A <- A | GAME_FLAGS  => #FLAG_DINO_JUMPING | GAME_FLAGS
  sta GAME_FLAGS

  ; inititalize jumping velocity integer and fractional part (fixed point)
  lda #DINO_JUMP_INIT_VY_INT
  sta DINO_VY_INT
  lda #DINO_JUMP_INIT_VY_FRACT
  sta DINO_VY_FRACT

  SFX_INIT JUMP_SOUND

  jmp _end_check_joystick

_on_joystick_down:
  jsr rnd8
  ; If the dino is already crouching or jumping, ignore the input
  lda #FLAG_DINO_CROUCHING_OR_JUMPING
  bit GAME_FLAGS
  bne _end_check_joystick

  lda #FLAG_DINO_CROUCHING
  ora GAME_FLAGS
  sta GAME_FLAGS

_end_check_joystick:

; -----------------------------------------------------------------------------
; GAME SCREEN SETUP
; -----------------------------------------------------------------------------
in_game_screen:
  lda #FLAG_GAME_OVER_OR_SPLASH_SCREEN_MODE
  bit GAME_FLAGS
  ; If is in splash screen mode (flag 6th bit from left to right) or game over 
  ; skip updating the sky
  beq update_sky
  jmp end_frame_setup

update_sky:
  ; Updates the sky transition (day ↔ night) logic.
  ;
  ; The transition check only runs once every 4 frames to slow
  ; down the visual change, creating a smooth day/night animation.
  lda FRAME_COUNT
  and #%00000011        ; Only check when the last 2 bits
                        ; are 0 (effectively every 4 frames)
  bne _update_bg_and_fg_colours

  ; Check if a day/night transition is currently active.
  ; The 3-bit transition counter is stored inside SKY_FLAGS.
  ; If the counter is zero, there is no ongoing transition.
  lda SKY_FLAGS
  and #SKY_FLAG_TRANSITION_COUNTER ; isolate 3-bit transition counter
  beq _update_bg_and_fg_colours    ; skip if counter == 0 (no transition)

  ; The day ↔ night transition counter starts at 2 and ends at 7.
  ; Each step corresponds to a different foreground colour
  ; (the background colour is its complement).
  ;
  ; Transition value table:
  ;
  ; for day → night transition | for night → day transition
  ; ---------------------------------------------------------
  ;   counter     |  colour   |   counter     |  colour
  ;   2 -> (010)₂ => 0x02     |   2 -> (010)₂ => 0x0C
  ;   3 -> (011)₂ => 0x04     |   3 -> (011)₂ => 0x0A
  ;   4 -> (100)₂ => 0x06     |   4 -> (100)₂ => 0x08
  ;           ...             |           ...
  ;   7 -> (111)₂ => 0x0C     |   7 -> (111)₂ => 0x02
  ;
  ; Formulae:
  ;   foreground_colour = (counter - 1) * 2
  ;   background_colour = 14 - foreground_colour
  ;
  ; During daylight, the transition proceeds towards night colours.
  ; The calculation below assumes a day → night transition.
  ; If the flag indicates a night → day transition, the colours
  ; will later be swapped.

  tay   ; Preserve the raw counter (for later increment/update)

  lsr   ; Compute (SKY_FLAGS & %00011100) >> 2
  lsr

  ; The result (0–7) is stored again in Y so it can be incremented
  ; later and written back to SKY_FLAGS. This design choice makes
  ; the counter math more compact than recalculating it inline.
  tay

  ; Compute (counter - 1) * 2
  sec
  sbc #1
  asl

  tax    ; Store foreground colour (temp) in X

  ; Compute 14 - A
  ; Note: XOR with 14 gives the same result for even numbers.
  ; Example: 14 xor 2 = 12, 14 xor 6 = 8, 14 xor 8 = 6, etc.
  eor #14

  ; At this point:
  ;   X = foreground colour
  ;   A = background colour
  ;
  ; If the transition is night → day, swap A and X to reverse
  ; the colour direction.
  bit SKY_FLAGS
  bpl _update_transition_colours    ; skip if day → night
  sta TEMP                          ; swap foreground/background
  txa
  ldx TEMP

_update_transition_colours:
  sta BACKGROUND_COLOUR
  stx FOREGROUND_COLOUR

_update_transition_counter:
  ; Increment and update the transition counter.
  ; If it wraps from 7 → 0, the daytime flag is toggled.
  iny
  tya
  and #7         ; keep only 3 bits (counter range 0–7)
  asl
  asl            ; shift left by 2 bits (counter occupies bits 4–2)
                 ; A = 000xxx00

  bne _update_sky_flags ; if not wrapped, just update the counter bits

_reset_transition_counter_and_flip_daytime:
  lda SKY_FLAGS
  ; When the counter wraps (0 after 7), the daytime flag flips.
  ;
  ; Breakdown of mask:
  ;                     10011100
  ;                     ↑  └┬┘
  ; XOR with this mask  │   └─ zeros out the previous counter bits
  ; flips the daytime ──┘
  ; flag while resetting the counter bits (which were 111₂ = 7).
  eor #%10011100
  jmp _store_sky_flags

_update_sky_flags:
  ; Update SKY_FLAGS with the new counter value (no overflow).
  sta TEMP           ; store new counter bits
  lda SKY_FLAGS      ; load current SKY_FLAGS
  and #%11100011     ; clear previous counter bits (bits 4–2)
  ora TEMP           ; insert new counter bits

_store_sky_flags:
  sta SKY_FLAGS

_update_bg_and_fg_colours:
  ; Apply the current background and foreground colours to TIA.
  lda BACKGROUND_COLOUR
  sta COLUBK

  lda FOREGROUND_COLOUR
  sta COLUP0
  sta COLUP1

_update_sky_layers:
  ; Flip the sky layer on each frame
  lda SKY_FLAGS
  eor #SKY_FLAG_SINGLE_CLOUD_LAYER_ON
  sta SKY_FLAGS

  lda SKY_FLAGS
  ; If it's daytime, ignore updating the moon and star
  bpl _update_cloud_pos

_update_moon_and_stars:
__update_star_x_pos:
  lda FRAME_COUNT
  and #3
  cmp #2
  bne __check_star_x_pos
  dec STAR_POS_X

__check_star_x_pos:
  lda STAR_POS_X
  ; x range for both the star and moon is [6, 155]
  cmp #7
  bcs __update_moon_x_pos
  jsr reset_star

__update_moon_x_pos:
  lda FRAME_COUNT
  and #15
  cmp #15
  bne __check_moon_x_pos
  dec MOON_POS_X

__check_moon_x_pos:
  lda MOON_POS_X
  cmp #7
  bcs _update_cloud_pos
  jsr reset_moon

_update_cloud_pos:

  ; The following is equivalent to:
  ; for (x = 2; x >= 0; x--)
  ;   if frame_count mod 4 == 0 // every 4 frames
  ;     cloud_x_pos[x]--
  ;
  ;   if cloud_x_pos[x] > 1
  ;     continue
  ;   else
  ;     call reset_cloud(new_x_pos=255, cloud_index=x)
  ldx #2
__update_cloud_x_pos_loop:
  lda FRAME_COUNT
  and #3
  cmp #2
  beq ___decrement_x_pos
  .byte $2C
___decrement_x_pos:
  dec CLOUD_1_X,x

  lda CLOUD_1_X,x
  cmp #2
  bcs ___continue_next_cloud    ; if x > 1
___reset_cloud_pos:
  lda #230
  jsr reset_cloud
___continue_next_cloud:
  dex
  bpl __update_cloud_x_pos_loop

update_obstacle:
_update_obstacle_pos:
  ; update obstacle x

  UPDATE_X_POS OBSTACLE_X_INT, OBSTACLE_X_FRACT, OBSTACLE_VX_INT, OBSTACLE_VX_FRACT, #TREAT_SPEED_PARAMETER_AS_A_VARIABLE

  lda #FLAG_DUPLICATED_OBSTACLE
  bit GAME_FLAGS
  beq _check_obstacle_pos

  ; A duplicated obstacle, first check if the X position of this sprite 
  ; is already off-screen
  lda OBSTACLE_X_INT
  cmp #OBSTACLE_GRP1_MIN_SCREEN_X
  bcs _check_if_duplication_can_be_enabled

  ; Given that the first obstacle is not longer visible,
  ; The trick here is to swap the OBSTACLE_X_INT with the one of the second
  ; (duplicated) sprite, that way the first sprite takes the place of the
  ; second sprite and keeps going in the screen
  lda #39
  sta OBSTACLE_X_INT

  ; After swapping the first sprite with the duplicated, turn duplication off

  lda GAME_FLAGS
  and #TOGGLE_FLAG_DUPLICATED_OBSTACLE_OFF
  sta GAME_FLAGS
  lda #0
  sta OBSTACLE_DUPLICATE

  ; Continue like if this sprite was a single sprite all along
  jmp _update_obstacle_sprite

_check_if_duplication_can_be_enabled:
  ; When the obstacle is at this X position, the second (duplicated) sprite
  ; can appear on screen, otherwise it will wrap and appear on the left side
  ; of the screen.
  cmp #OBSTACLE_MIN_X_BEFORE_DUPLICATION

  bcs _check_obstacle_pos
  lda #NUSIZX_TWO_COPIES_MEDIUM
  sta OBSTACLE_DUPLICATE

_check_obstacle_pos:
  lda OBSTACLE_X_INT
  bne _update_obstacle_sprite

  jsr spawn_obstacle

_update_obstacle_sprite:
  ; For the 'set_sprite_data' subroutine
  lda OBSTACLE_Y
  sta TEMP+1

  lda OBSTACLE_TYPE
  ; obstacle_type == 0 is the empty obstacle
  beq __no_ptero

  ; pterodactile is obstacle_type 1 (ptero with open wings) or 2 (ptero with
  ; closed wings)
  cmp #3      ; if obstacle_type ≥ 3 then is not a pterodactile obstacle type
  bcs __no_ptero

  ; Handle the pterodactile obstacle differently, as it has a wing animation
  ; that needs updating, whereas the cacti are all static sprites
  lda FRAME_COUNT
  and #%00001111
  cmp #15
  bne __end_update_ptero

  ; Alternate wings
  lda OBSTACLE_TYPE
  eor #%00000011
  sta OBSTACLE_TYPE

__end_update_ptero:
  lda OBSTACLE_TYPE
__no_ptero:
  ; multiply the OBSTACLE_TYPE stored in reg A by 2, this will be the index for
  ; both OBSTACLES_SPRITES_TABLE and OBSTACLES_MISSILE_1_CONF_TABLE tables
  ; multiplying by 2 because each entry is 2 bytes (one word) long
  asl
  tax ; Use reg X as the index

  stx TEMP ; Store a copy of reg X for later when loading the missile conf

  ; Check the obstacle x position and use empty data if it's offscreen
  lda OBSTACLE_X_INT
  cmp #OBSTACLE_GRP1_MIN_SCREEN_X
  bcc __use_zero_for_obstacle_sprite

  ; The next '.byte $2C' will turn the following 'ldx #0' (opcodes A2 00)
  ; 'bit $A200' (opcodes 2C A2 00), effectively cancelling it
  .byte $2C
__use_zero_for_obstacle_sprite:
  ldx #0

  ldy OBSTACLES_SPRITES_TABLE+#1,x
  lda OBSTACLES_SPRITES_TABLE,x
  ldx #PTR_OBSTACLE_SPRITE
  jsr set_sprite_data

  ; Similar to the obstacle sprite data, check the obstacle missile x position
  ; and use empty data if it's offscreen
  lda OBSTACLE_X_INT
  cmp #OBSTACLE_M1_MAX_SCREEN_X
  bcs __use_zero_for_obstacle_missile

  ldx TEMP

  ; The next '.byte $2C' will turn the following 'ldx #0' (opcodes A2 00) into
  ; 'bit $A200' (opcodes 2C A2 00), effectively cancelling it
  .byte $2C
__use_zero_for_obstacle_missile:
  ldx #0    ; override the stored x value, so it lands of the first entry of
            ; the OBSTACLES_MISSILE_1_CONF table, which points to zero data

  ldy OBSTACLES_MISSILE_1_CONF_TABLE+#1,x
  lda OBSTACLES_MISSILE_1_CONF_TABLE,x
  ldx #PTR_OBSTACLE_MISSILE_1_CONF
  jsr set_sprite_data
end_update_obstacle:

update_floor:
_update_pebble_pos:
  UPDATE_X_POS PEBBLE_X_INT, PEBBLE_X_FRACT, OBSTACLE_VX_INT, OBSTACLE_VX_FRACT, #TREAT_SPEED_PARAMETER_AS_A_VARIABLE

  cmp #8
  bcs __end_update_pebble_pos
  ; Reset pebble pos to a random x beyond the screen right edge
  jsr rnd8
  ; reg A has the random byte
  sta PEBBLE_X_FRACT

  GENERATE_RANDOM_NUMBER_BETWEEN_160_AND_238
  sta PEBBLE_X_INT
__end_update_pebble_pos:

_update_pebble_anim:
  lda FOREGROUND_COLOUR
  sta COLUPF

  ; reset FLOOR_PFx and PEBBLE_PFx
  lda #%11111111
  ldx #5
.floor_reset_loop:
  sta FLOOR_PF0,x
  dex
  bpl .floor_reset_loop
  lda #0
  ldx #5
.pebble_reset_loop:
  sta PEBBLE_PF0,x
  dex
  bpl .pebble_reset_loop

  lda PEBBLE_X_INT
  ldy #0
  cmp #160
  bcs __pebble_out_of_bounds
  cmp #128
  ldx #5
  bcs __update_pf2
  cmp #96
  ldx #4
  bcs __update_pf1
  cmp #80
  ldx #3
  bcs __update_pf0
  cmp #48
  ldx #2
  bcs __update_pf2
  cmp #16
  ldx #1
  bcs __update_pf1
  ldx #0

__update_pf0:
  and #%00001100
  lsr
  lsr
  tay
  lda POWERS_OF_2_NEGATED+#4,y
  jmp _end_pebble_anim

__update_pf1:
  ldy #4
  cmp #96
  bcs ___range_is_96_to_127 ; [96, 128) - PF4
  ; range is [16, 32)
  cmp #32
  bcc ___pf1_adjust_low_nibble
  ldy #0  ; ≥ 32
  jmp ___pf1_adjust_low_nibble
___range_is_96_to_127:
  cmp #112
  bcc ___pf1_adjust_low_nibble
  ldy #0
  jmp ___pf1_adjust_low_nibble
___pf1_adjust_low_nibble:
  and #%00001100
  lsr
  lsr
  eor #%00000011
  sty TEMP
  clc
  adc TEMP
  tay
  lda POWERS_OF_2_NEGATED,y
  jmp _end_pebble_anim

__update_pf2:
  cmp #128
  bcc ___range_is_48_to_79 ; [48, 80)
  ; range is [128, 160)
  cmp #144
  bcc ___pf2_adjust_low_nibble
  ldy #4
  jmp ___pf2_adjust_low_nibble
___range_is_48_to_79:
  cmp #64
  bcc ___pf2_adjust_low_nibble
  ldy #4
___pf2_adjust_low_nibble:
  and #%00001100
  lsr
  lsr
  sty TEMP
  clc
  adc TEMP
  tay
  lda POWERS_OF_2_NEGATED,y
  jmp _end_pebble_anim

__pebble_out_of_bounds:
  ldx #0

_end_pebble_anim:
  sta FLOOR_PF0,x
  eor #%11111111
  sta PEBBLE_PF0,x

  lda DINO_TOP_Y_INT
  ; Remember: 'cmp' under the hood acts like: 256 + (a - b)
  cmp #INIT_DINO_TOP_Y+#20
  bcs __dino_y_over_20
  cmp #INIT_DINO_TOP_Y+#10
  bcs __dino_y_over_10

  lda FLOOR_PF0
  and #%01111111
  sta FLOOR_PF0
  lda PEBBLE_PF0
  and #%01111111
  sta PEBBLE_PF0

  lda FLOOR_PF1
  and #%00111111
  sta FLOOR_PF1
  lda PEBBLE_PF1
  and #%00111111
  sta PEBBLE_PF1

  jmp end_update_floor

__dino_y_over_10:
  lda FLOOR_PF1
  and #%01111111
  sta FLOOR_PF1
  lda PEBBLE_PF1
  and #%01111111
  sta PEBBLE_PF1
  jmp end_update_floor

__dino_y_over_20:
end_update_floor:

update_dino:
_check_if_dino_is_jumping:
  lda #FLAG_DINO_JUMPING
  bit GAME_FLAGS
  bne _jumping

_check_if_dino_is_crouching:
  lda #FLAG_DINO_CROUCHING
  bit GAME_FLAGS
  bne _crouching

  ; If the dino is neither jumping nor crouching, restore its standing Y
  ; position. This ensures the dino is drawn correctly after the player
  ; releases the down input.
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT

  ; neither jumping or crouching, just standing, update the leg animation
  jmp _update_leg_anim

_jumping:
  ; update dino_y <- dino_y - vy
  clc
  lda DINO_TOP_Y_FRACT
  adc DINO_VY_FRACT
  sta DINO_TOP_Y_FRACT
  lda DINO_TOP_Y_INT
  adc DINO_VY_INT
  sta DINO_TOP_Y_INT

  ; if DINO_TOP_Y_INT >= INIT_DINO_TOP_Y then turn off jumping
  cmp #INIT_DINO_TOP_Y
  bcs _update_jump

_finish_jump:
  ; Restore dino-y position to the original
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT
  lda #0
  sta DINO_TOP_Y_FRACT

  ; turn off the jumping flag
  lda GAME_FLAGS
  and #TOGGLE_FLAG_DINO_JUMPING_OFF
  sta GAME_FLAGS
  jmp _update_jump_pos

_update_jump:
  ; update vy = vy + acc_y
  sec
  ; Update the fractional part
  lda DINO_VY_FRACT
  sbc #DINO_JUMP_ACCEL_FRACT
  sta DINO_VY_FRACT
  ; Update the integer part
  lda DINO_VY_INT
  sbc #DINO_JUMP_ACCEL_INT
  sta DINO_VY_INT

_update_jump_pos:
  lda DINO_TOP_Y_INT
  sta PARAM_SPRITE_Y
  lda #<DINO_SPRITE_1_END
  ldy #>DINO_SPRITE_1_END
  ldx #PTR_DINO_SPRITE
  jsr set_sprite_data
  lda #<DINO_SPRITE_OFFSETS_END
  ldy #>DINO_SPRITE_OFFSETS_END
  ldx #PTR_DINO_OFFSET
  jsr set_sprite_data
  lda #<DINO_MISSILE_0_OFFSETS_END
  ldy #>DINO_MISSILE_0_OFFSETS_END
  ldx #PTR_DINO_MISSILE_0_CONF
  jsr set_sprite_data

  jmp _end_legs_anim

_crouching:
  ; Set the dino's Y position to the top of the crouching region.
  ; This can be any value outside the standing range. The idea is to ensure the
  ; dino won't be drawn as standing before the crouching kernels kick in.
  lda #0
  sta DINO_TOP_Y_INT

_update_leg_anim:
  ; Dino leg animation
  lda FRAME_COUNT            ; Check if is time to update dino's legs
  and #%00000011             ; animation
  cmp #3                     ;
  bne _end_legs_anim         ;

  lda #FLAG_DINO_LEFT_LEG    ; Check which leg is up, and swap
  bit GAME_FLAGS
  beq _right_leg

  lda #<[DINO_SPRITE_3 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE
  lda #>[DINO_SPRITE_3 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE+1

  jmp _swap_legs

_right_leg:
  lda #<[DINO_SPRITE_2 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE
  lda #>[DINO_SPRITE_2 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE+1

_swap_legs:
  lda GAME_FLAGS
  eor #FLAG_DINO_LEFT_LEG
  sta GAME_FLAGS

_end_legs_anim:
end_update_dino:
  jmp end_frame_setup

end_frame_setup:
  ; Clear any previous NUSIZ1 duplication settings before drawing anything. If
  ; not reset here, the clouds may appear duplicated on the game over screen.
  ; This occurs because the normal update* routine (which disables duplication)
  ; is not executed during game over, leaving NUSIZ1 latched with its previous
  ; value.
  lda #0
  sta NUSIZ1

;==============================================================================
; END FRAME SETUP (VBLANK TIME)
;==============================================================================

  lda #0
remaining_vblank:
  lda INTIM
  bne remaining_vblank
               ; 2752 cycles + 2 from bne, 2754 (out of 2812 vblank)

  sta WSYNC
  sta VBLANK   ; Disables VBLANK (A=0)
