;------------------------------------------------------------------------------
; OVERSCAN (30 scanlines)
;------------------------------------------------------------------------------
overscan:

  ; 30 lines of OVERSCAN, 30 * 76 / 64 = 35
  lda #35
  sta TIM64T
  lda #ENABLE_VBLANK
  sta VBLANK

  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
  ; If the game is in splash screen mode (6th bit of flags), update the dino
  ; blinking state. Otherwise, continue with the game over check
  bvc _resume_game_over_check

__update_dino_blinking_state:
  inc SPLASH_SCREEN_DINO_BLINK_TIMER

  lda GAME_FLAGS
  bmi __dino_eyes_are_closed
__dino_eyes_are_open:
  ldx #255
  ; This '.byte $2C' will turn the following 'ldx #15' (opcodes A2 15) into
  ; 'bit $A215' (opcodes 2C A2 15), effectively cancelling it
  .byte $2C

__dino_eyes_are_closed:
  ldx #15

  ; Assumes x contains the expected time to do the state change
__check_and_update_dino_eyes_state:
  cpx SPLASH_SCREEN_DINO_BLINK_TIMER
  bne __end_update_dino_blinking_state

  ; Reset the blinking timer
  lda #0
  sta SPLASH_SCREEN_DINO_BLINK_TIMER

  ; Flip the blinking state
  lda #FLAG_DINO_BLINKING
  eor GAME_FLAGS
  sta GAME_FLAGS

__end_update_dino_blinking_state:
  jmp _update_random

_resume_game_over_check:
  bne _already_game_over ; Skip the collision detection if the game over 
                         ; flag is already set, otherwise the game over timer
                         ; is reset

  ; Collision detection
  bit CXPPMM
  bmi _set_game_over
  jmp _no_collision
_set_game_over:
  lda #GAME_OVER_TIMER_TOTAL_TIME
  sta GAME_OVER_TIMER

  lda #FLAG_GAME_OVER
  ora GAME_FLAGS
  sta GAME_FLAGS

  ; Set the speed of the obstacles and dino to 0
  lda #0
  sta SKY_FLAGS
  sta OBSTACLE_VX_FRACT
  sta OBSTACLE_VX_INT
  sta DINO_VY_INT     ; Clearing the vertical speed will stop the
  sta DINO_VY_FRACT   ; dino vertical movement (in case it was jumping)
  sta FRAME_COUNT
  sta FRAME_COUNT+1

  ; Remove the crouching flag in case it was crouching
  lda #FLAG_DINO_CROUCHING
  bit GAME_FLAGS
  beq __set_dino_game_over_sprite
  lda #TOGGLE_FLAG_DINO_CROUCHING_OFF
  and GAME_FLAGS
  sta GAME_FLAGS
  ; Restore the Y position to the standing default position
  ; TODO: This could be a constant, thus reducing 1 cycle
  lda DINO_TOP_Y_INT
  bne __set_dino_game_over_sprite
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT

__set_dino_game_over_sprite:
  lda DINO_TOP_Y_INT
  sta PARAM_SPRITE_Y
  lda #<DINO_GAME_OVER_SPRITE_END
  ldy #>DINO_GAME_OVER_SPRITE_END
  ldx #PTR_DINO_SPRITE
  jsr set_sprite_data
  lda #<DINO_SPRITE_OFFSETS_END
  ldy #>DINO_SPRITE_OFFSETS_END
  ldx #PTR_DINO_OFFSET
  jsr set_sprite_data
  lda #<DINO_GAME_OVER_MISSILE_0_OFFSETS_END
  ldy #>DINO_GAME_OVER_MISSILE_0_OFFSETS_END
  ldx #PTR_DINO_MISSILE_0_CONF
  jsr set_sprite_data

__init_game_over_sound:
  SFX_INIT GAME_OVER_SOUND

_already_game_over:
  SFX_UPDATE_PLAYING GAME_OVER_SOUND

  lda GAME_OVER_TIMER
  beq _check_play_jumping_sound
  dec GAME_OVER_TIMER

_no_collision:

_update_score_sprites:
  ; Update the score sprites, this will be done accross 6 frames to update 
  ; both the SCORE and MAX_SCORE sprites (even if the MAX_SCORES sprites are
  ; not visible)
  lda #%00000111
  and FRAME_COUNT
  ; Valid indexes are 0-5 (6 digit pair buffers). Skip 6 and 7.
  cmp #6
  bcs _check_increment_score

  tay
  jsr assemble_score_digit_pair_sprite

_check_increment_score:
  lda #%00001111
  and FRAME_COUNT
  bne _check_play_jumping_sound

  ; if SCORE == 99999 then skip incrementing the score
  lda SCORE
  cmp #99
  bne _increment_score
  lda SCORE+1
  cmp #99
  bne _increment_score
  lda SCORE+2
  cmp #9
  beq _check_play_jumping_sound

_increment_score:
  sed
  clc

  lda SCORE
  adc #1
  sta SCORE

  lda SCORE+1
  adc #0
  sta SCORE+1

  lda SCORE+2
  adc #0
  sta SCORE+2

  cld

_update_max_score:
  ; if SCORE > MAX_SCORE then MAX_SCORE = SCORE
  sec
  lda MAX_SCORE
  sbc SCORE
  lda MAX_SCORE+1
  sbc SCORE+1
  lda MAX_SCORE+2
  sbc SCORE+2
  bcs _check_play_jumping_sound  ; MAX_SCORE >= SCORE: skip

  ldx #3
__do_update_max_score:
  lda SCORE-1,x
  sta MAX_SCORE-1,x
  dex
  bne __do_update_max_score

_check_play_jumping_sound:
  lda #FLAG_DINO_JUMPING
  bit GAME_FLAGS
  ; Continue to '_update_frame_count' if not jumping
  beq _check_if_should_kickoff_daytime_transition
  ; Also check if not game over, in which, the game over sound has priority
  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
  bne _update_frame_count

  SFX_UPDATE_PLAYING JUMP_SOUND

_check_if_should_kickoff_daytime_transition:
  ; if *FRAME_COUNT == 0 && *(FRAME_COUNT+1) == DAY_TIME_TRANSITION_MARK then
  ; set the transition counter in the SKY_FLAGS to 2
  lda FRAME_COUNT
  bne _update_frame_count
  lda FRAME_COUNT+1
  and #%00001111
  cmp #DAY_TIME_TRANSITION_MARK
  bne _update_frame_count
  lda #%00001000 ; sets the transition counter to 2, the initial value
  ora SKY_FLAGS
  sta SKY_FLAGS

_update_frame_count:
  inc FRAME_COUNT
  bne __skip_inc_frame_count_upper_byte
  inc FRAME_COUNT+1
__skip_inc_frame_count_upper_byte:

_update_random:
  inc RANDOM
  jsr rnd8

_remaining_overscan:
  lda INTIM
  bne _remaining_overscan
  ; We're on the final OVERSCAN line and 40 cpu cycles remain,
  ; do the jump now to consume some cycles and a WSYNC at the
  ; beginning of the next frame to consume the rest

  sta WSYNC
