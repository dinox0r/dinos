  SEG.U variables
  ORG $80

; Dino State Variables
DINO_TOP_Y_INT               .byte   ; 1 byte   (1)
DINO_TOP_Y_FRACT             .byte   ; 1 byte   (2)
DINO_VY_INT                  .byte   ; 1 byte   (3)
DINO_VY_FRACT                .byte   ; 1 byte   (4)

PTR_DINO_SPRITE              .word   ; 2 bytes  (6)
PTR_DINO_OFFSET              .word   ; 2 bytes  (8)
PTR_DINO_MISSILE_0_CONF      .word   ; 2 bytes  (10)

; Obstacle Variables
OBSTACLE_TYPE                .byte   ; 1 byte   (11)
OBSTACLE_Y                   .byte   ; 1 byte   (12)
OBSTACLE_X_INT               .byte   ; 1 byte   (13)
OBSTACLE_X_FRACT             .byte   ; 1 byte   (14)
OBSTACLE_VX_INT              .byte   ; 1 byte   (15)
OBSTACLE_VX_FRACT            .byte   ; 1 byte   (16)
OBSTACLE_DUPLICATE           .byte   ; 1 byte   (17)

PTR_OBSTACLE_SPRITE          .word   ; 2 bytes  (19)
PTR_OBSTACLE_OFFSET          .word   ; 2 bytes  (21)
PTR_OBSTACLE_MISSILE_1_CONF  .word   ; 2 bytes  (23)

; Play area
PLAY_AREA_MIN_Y              .byte   ; 1 byte   (24)
FOREGROUND_COLOUR            .byte   ; 1 byte   (25)
BACKGROUND_COLOUR            .byte   ; 1 byte   (26)

PTR_AFTER_PLAY_AREA_KERNEL   .word   ; 2 bytes  (28)

; Sky area
;
; These variables are layed out this way (array form) so they can be indexed
; in a subroutine
CLOUD_1_X                    .byte   ; 1 byte   (29)
CLOUD_2_X                    .byte   ; 1 byte   (30)
CLOUD_3_X                    .byte   ; 1 byte   (31)

CLOUD_1_TOP_Y                .byte   ; 1 byte   (32)
; Clouds 2 and 3 have "0" for Y coordinate, there is no enough room
; to place them randomly on the vertical space of the sky

CURRENT_CLOUD_X              .byte   ; 1 byte   (33)
CURRENT_CLOUD_TOP_Y          .byte   ; 1 byte   (34)
CLOUD_LAYER_SCANLINES        .byte   ; 1 byte   (35)
SKY_FLAGS                    .byte   ; 1 byte   (36)

; moon and star X's coordinates are also layed out in array form
MOON_POS_X                   .byte   ; 1 byte   (37)
STAR_POS_X                   .byte   ; 1 byte   (38)

; In Splash Screen mode, this variable (STAR_POS_X) is used as the timer for
; the dino blinking (during splash screen mode, there are no clouds so is safe
; to repurpose it this way)
SPLASH_SCREEN_DINO_BLINK_TIMER = STAR_POS_X

STAR_POS_Y                   .byte   ; 1 byte   (39)
PTR_STAR_SPRITE              .word   ; 2 bytes  (41)
PTR_MOON_SPRITE              .word   ; 2 bytes  (43)

; Ground area
FLOOR_PF0                    .byte   ; 1 byte   (44)
FLOOR_PF1                    .byte   ; 1 byte   (45)
FLOOR_PF2                    .byte   ; 1 byte   (46)
FLOOR_PF3                    .byte   ; 1 byte   (47)
FLOOR_PF4                    .byte   ; 1 byte   (48)
FLOOR_PF5                    .byte   ; 1 byte   (49)

PEBBLE_X_INT                 .byte   ; 1 byte   (50)
PEBBLE_X_FRACT               .byte   ; 1 byte   (51)
PEBBLE_CACHED_OBSTACLE_GRP1  .byte   ; 1 byte   (52)
PEBBLE_CACHED_OBSTACLE_M1    .byte   ; 1 byte   (53)

PEBBLE_PF0                   .byte   ; 1 byte   (54)
PEBBLE_PF1                   .byte   ; 1 byte   (55)
PEBBLE_PF2                   .byte   ; 1 byte   (56)
PEBBLE_PF3                   .byte   ; 1 byte   (57)
PEBBLE_PF4                   .byte   ; 1 byte   (58)
PEBBLE_PF5                   .byte   ; 1 byte   (59)

; Gameplay variables
GAME_FLAGS                   .byte   ; 1 byte   (60)
FRAME_COUNT                  .word   ; 2 bytes  (62)
RANDOM                       .byte   ; 1 byte   (63)
GAME_OVER_TIMER              .byte   ; 1 byte   (64)

; Score
SCORE                        .hex    000000        ; 3 bytes (67)
MAX_SCORE                    .hex    000000        ; 3 bytes (70)

SCORE_DIGITS_10              .hex    000000000000  ; 6 bytes (76)
SCORE_DIGITS_32              .hex    000000000000  ; 6 bytes (82)
SCORE_DIGITS_54              .hex    000000000000  ; 6 bytes (88)

MAX_SCORE_DIGITS_10          .hex    000000000000  ; 6 bytes (94)
MAX_SCORE_DIGITS_32          .hex    000000000000  ; 6 bytes (100)
MAX_SCORE_DIGITS_54          .hex    000000000000  ; 6 bytes (106)

; Sound
SFX_TRACKER_1                .byte   ; 1 byte   (107)
SFX_TRACKER_2                .byte   ; 1 byte   (108)

; To save the state of a register temporarily during tight situations
; ⚠ WARNING: Shared data, don't use to hold any state across scanlines/frames
TEMP                         .hex   00000000     ; 4 bytes  (112)

; Alias for TEMP+1 used by the 'set_sprite_data' subroutine
PARAM_SPRITE_Y = TEMP+1

; This section is to include variables that share the same memory but are 
; referenced under different names, something like temporary variables that 
; can be used differently by different kernels (which are only active one 
; at a time, leaving no risk of overlap)

