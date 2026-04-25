;------------------------------------------------------------------------------
; GAME INITIALIZATION
;------------------------------------------------------------------------------
_clear_game_flags:
  lda #0
  sta GAME_FLAGS

_init_score:
  ; Reset the score back to 000000
  sta SCORE
  sta SCORE+1
  sta SCORE+2

  ; Suppress the hi-score display until the player has completed at least one
  ; run. MAX_SCORE is zero on power-on, so a non-zero value means a previous
  ; game over has already written a score into it. FLAG_MAX_SCORE_PRESENT gates
  ; the hi-score section in the score kernel, matching the original game's
  ; behaviour where "HI" only appears after the player fails their first run.
  ;
  ; First run (game over):
  ;                                                   00042
  ;       O██   █
  ;   █   ███ █ █ █
  ; -- ████  -█████-----------------------------------------
  ;     ██      █
  ;
  ; Next run (game starts):
  ;                                          HI 00042 00000
  ;       ███
  ;   █   ███
  ; -- ████  -----------------------------------------------
  ;     ██

  lda MAX_SCORE
  ora MAX_SCORE+1
  ora MAX_SCORE+2
  bne __max_score_present

__max_score_present:
  lda #FLAG_MAX_SCORE_PRESENT
  ora GAME_FLAGS
  sta GAME_FLAGS

_reset_dino_y_pos:
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT

  lda #FRG_DARK_GRAY
  sta FOREGROUND_COLOUR
  ; Setting both the colour of the player and the background here
  ; in  case the game is in "splash screen" mode, in which case the 
  ; branch that updates these colours during frame setup will be skipped
  sta COLUP0
  lda #BKG_LIGHT_GRAY
  sta BACKGROUND_COLOUR
  sta COLUBK

_init_dino_conf:
  lda #<[DINO_SPRITE_1 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE
  lda #>[DINO_SPRITE_1 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE+1

  lda #<[DINO_SPRITE_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_OFFSET
  lda #>[DINO_SPRITE_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_OFFSET+1

  lda #<[DINO_MISSILE_0_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_MISSILE_0_CONF
  lda #>[DINO_MISSILE_0_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_MISSILE_0_CONF+1

_init_pebble_conf:
  lda #250
  sta PEBBLE_X_INT
  lda #0
  sta PEBBLE_X_FRACT

  ; If the game is in "splash screen" mode (6th bit of game flags) then skip
  ; these sections and jump to the start of the frame
  bit GAME_FLAGS
  bvs start_of_frame

_init_obstacle_conf:

  lda #0
  sta OBSTACLE_DUPLICATE
  jsr spawn_obstacle

  lda #OBSTACLE_INITIAL_SPEED
  sta OBSTACLE_VX_FRACT
  lda #0
  sta OBSTACLE_VX_INT

_init_sky_conf:
  lda #167
  ldx #0
  jsr reset_cloud

  lda #200
  ldx #1
  jsr reset_cloud

  lda #224
  ldx #2
  jsr reset_cloud

  jsr reset_star
  jsr reset_moon
