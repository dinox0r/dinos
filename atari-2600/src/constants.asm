
RND_MEM_LOC_1 = $c1  ; "random" memory locations to sample the upper/lower
RND_MEM_LOC_2 = $e5  ; bytes when the machine starts. Hopefully this finds
                     ; some garbage values that can be used as seed


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

;------------------------
; MACRO constants
;------------------------

ENABLE_PAGE_CROSSING_CHECK = #0

; UPDATE_X_POS macro
TREAT_SPEED_PARAMETER_AS_A_CONSTANT = #1
TREAT_SPEED_PARAMETER_AS_A_VARIABLE = #0

; SET_STITCHED_SPRITE_X_POS macro
USE_SEAMLESS_STITCHING = #1
DONT_USE_SEAMLESS_STITCHING = #0

; LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE macro
SET_CARRY = #1
IGNORE_CARRY = #0

OBSTACLE_M1_MAX_SCREEN_X = #160   ; if obstacle_x >= 160, m1 = 0
OBSTACLE_GRP1_MIN_SCREEN_X = #9  ; if obstacle_x < 8, grp1 = 0

USE_GRP0 = #1
IGNORE_GRP0 = #0
USE_GRP1 = #1
IGNORE_GRP1 = #0

; Sky kernel
; -----------------------------------------------------------------------------
SKY_SINGLE_CLOUD_SCANLINES = #29 ; Contrary to the play area, these
SKY_2_CLOUDS_SCANLINES = #12     ; are 1x kernel lines

CLOUD_VX_INT = #0
CLOUD_VX_FRACT = #100
CLOUD_HEIGHT = #11

; Crouching Kernel
; -----------------------------------------------------------------------------
CROUCHING_2X_SCANLINES = #8

CROUCHING_REGION_TOP_Y = #PLAY_AREA_BOTTOM_Y + #CROUCHING_2X_SCANLINES

DINO_JUMP_INIT_VY_INT = #4
DINO_JUMP_INIT_VY_FRACT = #205
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #78

PTERO_HEIGHT = #20
; To save a cycle per scanline, all the obstacles are to have the max obstacle
; height, it wastes some rom though
OBSTACLE_HEIGHT = #PTERO_HEIGHT

PTERO_OPEN_WINGS_TABLE_ENTRY_INDEX = #1
PTERO_CLOSED_WINGS_TABLE_ENTRY_INDEX = #2

;=============================================================================
; GAME_FLAGS
;=============================================================================
; bit 0: 1 -> splash screen mode / 0 -> game mode
FLAG_SPLASH_SCREEN =  #%00000001

; When in splash screen mode:
;   bit 7: dino blinking ON / OFF
FLAG_DINO_BLINKING =  #%10000000

; When in game screen mode:
;   bit 7: The current sky frame is layer 1 (out of the 2)
FLAG_SKY_LAYER_1_ON = #%10000000

; When in game mode:
;   bit 1: dino left/right leg up sprite
;   bit 2: dino jumping ON / OFF
;   bit 4: dino crouching ON / OFF
FLAG_DINO_LEFT_LEG =  #%00000010
FLAG_DINO_JUMPING =   #%00000100
FLAG_DINO_CROUCHING = #%00010000

FLAG_GAME_OVER = #%01000000

FLAG_DINO_CROUCHING_OR_JUMPING = FLAG_DINO_CROUCHING | FLAG_DINO_JUMPING

TOGGLE_FLAG_DINO_BLINKING_OFF  = #%01111111
TOGGLE_FLAG_DINO_JUMPING_OFF   = #%11111011
TOGGLE_FLAG_DINO_CROUCHING_OFF = #%11101111
TOGGLE_FLAG_GAME_OVER_OFF      = #%10111111
