ENABLE_VBLANK = #2

;------------------------
; MACRO constants
;------------------------

ENABLE_PAGE_CROSSING_CHECK = #0

; UPDATE_X_POS macro
TREAT_SPEED_PARAMETER_AS_A_CONSTANT = #1
TREAT_SPEED_PARAMETER_AS_A_VARIABLE = #0

; LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE macro
SET_CARRY = #1
IGNORE_CARRY = #0

OBSTACLE_M1_MAX_SCREEN_X = #160   ; if obstacle_x >= 160, m1 = 0
OBSTACLE_GRP1_MIN_SCREEN_X = #8  ; if obstacle_x < 8, grp1 = 0

USE_GRP0 = #1
IGNORE_GRP0 = #0
USE_GRP1 = #1
IGNORE_GRP1 = #0


RND_MEM_LOC_1 = $f1  ; "random" memory locations to sample the upper/lower
RND_MEM_LOC_2 = $35  ; bytes when the machine starts. Hopefully this finds
                     ; some garbage values that can be used as seed

FRG_DARK_GRAY = #2
BKG_LIGHT_GRAY = #13

DINO_HEIGHT = #20
INIT_DINO_POS_Y = #8
INIT_DINO_TOP_Y = #INIT_DINO_POS_Y + #DINO_HEIGHT

OBSTACLE_MIN_X = #0
OBSTACLE_MAX_X = #163

; TODO Set this value to a beginner level
OBSTACLE_INITIAL_SPEED = #250

CACTUS_Y = #27

GAME_OVER_TIMER_TOTAL_TIME = #50

PLAY_AREA_2X_SCANLINES = #57    ; These are measured as 2x scanlines
FLOOR_SCANLINES = #2
GRAVEL_SCANLINES = #9

PLAY_AREA_TOP_Y = #PLAY_AREA_2X_SCANLINES + #FLOOR_SCANLINES + #GRAVEL_SCANLINES
PLAY_AREA_BOTTOM_Y = #PLAY_AREA_TOP_Y - #PLAY_AREA_2X_SCANLINES

GROUND_AREA_TOP_Y = #PLAY_AREA_BOTTOM_Y - #FLOOR_SCANLINES
GROUND_AREA_BOTTOM_Y = #GROUND_AREA_TOP_Y - #GRAVEL_SCANLINES

PLAYER_0_INDEX = #0
PLAYER_1_INDEX = #1
MISSILE_0_INDEX = #2
MISSILE_1_INDEX = #3

; Sky kernel
; -----------------------------------------------------------------------------
SKY_SCANLINES = #31      ; Contrary to the play area, these are 1x kernel lines

CLOUD_HEIGHT = #11
CLOUD_VX_INT = #0
CLOUD_VX_FRACT = #100

MOON_AND_STARS_LAYER_SETUP_SCANLINES = #6
SKY_SINGLE_CLOUD_SCANLINES = #SKY_SCANLINES 
SKY_2_CLOUDS_SCANLINES = #13
SKY_CLOUDS_2_AND_3_TOP_Y = #CLOUD_HEIGHT+#2

STAR_HEIGHT = #5
MOON_HEIGHT = #14
MOON_POS_Y = #20

MIN_MOON_AND_STAR_POS_X = #6
MAX_MOON_AND_STAR_POS_X = #155

; Crouching Kernel
; -----------------------------------------------------------------------------
CROUCHING_2X_SCANLINES = #8

CROUCHING_REGION_TOP_Y = #PLAY_AREA_BOTTOM_Y + #CROUCHING_2X_SCANLINES

DINO_JUMP_INIT_VY_INT = #4
DINO_JUMP_INIT_VY_FRACT = #205
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #78

PTERO_HEIGHT = #20
; To save a cycle per scan/line, all the obstacles are to have the max obstacle
; height, it wastes some rom though
OBSTACLE_HEIGHT = #PTERO_HEIGHT

PTERO_OPEN_WINGS_TABLE_ENTRY_INDEX = #1
PTERO_CLOSED_WINGS_TABLE_ENTRY_INDEX = #2

;=============================================================================
; GAME_FLAGS
;=============================================================================

; When in game mode:
;   bit 0: game over ON / OFF
;   bit 1: dino left/right leg up sprite
;   bit 2: dino jumping ON / OFF
;   bit 3: dino crouching ON / OFF
FLAG_GAME_OVER           = #%00000001
FLAG_DINO_LEFT_LEG       = #%00000010
FLAG_DINO_JUMPING        = #%00000100
FLAG_DINO_CROUCHING      = #%00001000
FLAG_DUPLICATED_OBSTACLE = #%00010000
; bit 6: 1 -> splash screen mode / 0 -> game mode
FLAG_SPLASH_SCREEN       = #%01000000
; When in splash screen mode:
;   bit 7: dino blinking ON / OFF
FLAG_DINO_BLINKING       = #%10000000

DINO_EYE_SCANLINE_Y = #25

FLAG_DINO_CROUCHING_OR_JUMPING = #FLAG_DINO_CROUCHING | #FLAG_DINO_JUMPING

FLAG_GAME_OVER_OR_SPLASH_SCREEN_MODE = #FLAG_GAME_OVER | #FLAG_SPLASH_SCREEN

TOGGLE_FLAG_GAME_OVER_OFF           = #%11111110
TOGGLE_FLAG_DINO_JUMPING_OFF        = #%11111011
TOGGLE_FLAG_DINO_CROUCHING_OFF      = #%11110111
TOGGLE_FLAG_DUPLICATED_OBSTACLE_OFF = #%11101111

TOGLLE_OFF_FLAGS_BUT_SPLASH_SCREEN = #%01000000

; Day nigth cycle
;   bit 1,0: Moon phase
;          00 -> Waning crescent
;          01 -> Waxing crescent
;          10 -> Full moon
SKY_FLAG_DAYTIME               = #%10000000 ; 0 day / 1 night
SKY_FLAG_SINGLE_CLOUD_LAYER_ON = #%01000000
SKY_FLAG_STAR_SPRITE           = #%00100000 ; If 0, use sprite 1, else sprite 2
SKY_FLAG_MOON_PHASE            = #%00000011
SKY_FLAG_TRANSITION_COUNTER    = #%00011100

; For debugging set to 1, set to a more complicated patter to delay the transition
;DAY_TIME_TRANSITION_MARK = #%00011001
DAY_TIME_TRANSITION_MARK = #1

NUSIZX_ONE_COPY            = #%00000000
NUSIZX_TWO_COPIES_CLOSE    = #%00000001
NUSIZX_TWO_COPIES_MEDIUM   = #%00000010
NUSIZX_THREE_COPIES_CLOSE  = #%00000011
NUSIZX_TWO_COPIES_WIDE     = #%00000100
NUSIZX_2X_PLAYER_WIDTH     = #%00000101
NUSIZX_THREE_COPIES_MEDIUM = #%00000110
NUSIZX_4X_PLAYER_WIDTH     = #%00000111
