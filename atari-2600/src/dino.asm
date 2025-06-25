  PROCESSOR 6502

  INCLUDE "../include/vcs.h"
  ; Including this just for the sbcs, sbeq, etc macros, that look like 
  ; the branching instructions but add a page boundary check
  INCLUDE "../include/macro.h"

  LIST ON           ; turn on program listing, for debugging on Stella

;=============================================================================
; MACROS
;=============================================================================

  include "macros.asm"

;=============================================================================
; CONSTANTS
;=============================================================================
RND_MEM_LOC_1 = $c1  ; "random" memory locations to sample the upper/lower
RND_MEM_LOC_2 = $e5  ; bytes when the machine starts. Hopefully this finds
                     ; some garbage values that can be used as seed

; Constants for the LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE macro
SET_CARRY = #1
IGNORE_CARRY = #0

BKG_LIGHT_GRAY = #13
DINO_HEIGHT = #20
INIT_DINO_POS_Y = #8
INIT_DINO_TOP_Y = #INIT_DINO_POS_Y + #DINO_HEIGHT

OBSTACLE_M1_MAX_SCREEN_X = #160   ; if obstacle_x >= 160, m1 = 0
OBSTACLE_GRP1_MIN_SCREEN_X = #9  ; if obstacle_x < 8, grp1 = 0

OBSTACLE_MIN_X = #0
OBSTACLE_MAX_X = #163

; TODO Set this value to a beginner level
OBSTACLE_INITIAL_SPEED = #250

CACTUS_Y = #27

PTERO_OPEN_WINGS_TABLE_ENTRY_INDEX = #1
PTERO_CLOSED_WINGS_TABLE_ENTRY_INDEX = #2

GAME_OVER_TIMER_TOTAL_TIME = #50

PLAY_AREA_SCANLINES = #61    ; All of these are measured as 2x scanlines
FLOOR_SCANLINES = #2
GRAVEL_SCANLINES = #9

PLAY_AREA_TOP_Y = #PLAY_AREA_SCANLINES + #FLOOR_SCANLINES + #GRAVEL_SCANLINES
PLAY_AREA_BOTTOM_Y = #PLAY_AREA_TOP_Y - #PLAY_AREA_SCANLINES

GROUND_AREA_TOP_Y = #PLAY_AREA_BOTTOM_Y - #FLOOR_SCANLINES
GROUND_AREA_BOTTOM_Y = #GROUND_AREA_TOP_Y - #GRAVEL_SCANLINES

; Crouching Kernel
; -----------------------------------------------------------------------------
CROUCHING_SCANLINES = #8

CROUCHING_REGION_TOP_Y = #PLAY_AREA_BOTTOM_Y + #CROUCHING_SCANLINES

   ; For debugging:
   ECHO "For debugging: ----------------------------------"
   ECHO "PLAY_AREA_BOTTOM_Y =", #PLAY_AREA_BOTTOM_Y
   ECHO "CROUCHING_REGION_TOP_Y =", #CROUCHING_REGION_TOP_Y
   ECHO "CROUCHING_SCANLINES = ", #CROUCHING_SCANLINES
   ECHO "DINO_CROUCHING_REGION_3_MISSILE_AND_BALL_CONF_END = ", #DINO_CROUCHING_REGION_3_MISSILE_AND_BALL_CONF_END
   ECHO "-------------------------------------------------"

DINO_JUMP_INIT_VY_INT = #5
DINO_JUMP_INIT_VY_FRACT = #40
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #78

PTERO_HEIGHT = #20
; To save a cycle per scanline, all the obstacles are to have the max obstacle
; height, it wastes some rom though
OBSTACLE_HEIGHT = #PTERO_HEIGHT


;=============================================================================
; GAME_FLAGS
;=============================================================================
; bit 0: 1 -> splash screen mode / 0 -> game mode
FLAG_SPLASH_SCREEN =  #%00000001

; When in splash screen mode:
;   bit 7: dino blinking ON / OFF
FLAG_DINO_BLINKING =  #%10000000

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

;=============================================================================
; ZERO PAGE MEMORY / VARIABLES
;=============================================================================
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
OBSTACLE_TYPE                .byte   ; 1 byte   (12)
OBSTACLE_Y                   .byte   ; 1 byte   (13)
OBSTACLE_X_INT               .byte   ; 1 byte   (14)
OBSTACLE_X_FRACT             .byte   ; 1 byte   (15)
OBSTACLE_VX_INT              .byte   ; 1 byte   (16)
OBSTACLE_VX_FRACT            .byte   ; 1 byte   (17)

PTR_OBSTACLE_SPRITE          .word   ; 2 bytes  (19)
PTR_OBSTACLE_OFFSET          .word   ; 2 bytes  (21)
PTR_OBSTACLE_MISSILE_1_CONF  .word   ; 2 bytes  (23)

; Play area
PLAY_AREA_MIN_Y              .byte   ; 1 byte   (24)
FOREGROUND_COLOUR            .byte   ; 1 byte   (25)
BACKGROUND_COLOUR            .byte   ; 1 byte   (26)

PTR_AFTER_PLAY_AREA_KERNEL   .word   ; 2 bytes  (28)

; Ground area
FLOOR_PF0                    .byte   ; 1 byte   (29)
FLOOR_PF1                    .byte   ; 1 byte   (30)
FLOOR_PF2                    .byte   ; 1 byte   (31)
FLOOR_PF3                    .byte   ; 1 byte   (32)
FLOOR_PF4                    .byte   ; 1 byte   (33)
FLOOR_PF5                    .byte   ; 1 byte   (34)

PEBBLE_X_INT                 .byte   ; 1 byte   (35)
PEBBLE_X_FRACT               .byte   ; 1 byte   (36)
PEBBLE_CACHED_OBSTACLE_GRP1  .byte   ; 1 byte   (37)
PEBBLE_CACHED_OBSTACLE_M1    .byte   ; 1 byte   (38)

PEBBLE_PF0                   .byte   ; 1 byte   (39)
PEBBLE_PF1                   .byte   ; 1 byte   (40)
PEBBLE_PF2                   .byte   ; 1 byte   (41)
PEBBLE_PF3                   .byte   ; 1 byte   (42)
PEBBLE_PF4                   .byte   ; 1 byte   (43)
PEBBLE_PF5                   .byte   ; 1 byte   (44)

; Gameplay variables
GAME_FLAGS                   .byte   ; 1 byte   (45)
FRAME_COUNT                  .word   ; 2 bytes  (47)
RANDOM                       .byte   ; 1 byte   (48)
GAME_OVER_TIMER              .byte   ; 1 byte   (50)

; Sound
SFX_TRACKER_1                .byte   ; 1 byte   (51)
SFX_TRACKER_2                .byte   ; 1 byte   (52)

; To save the state of a register temporarily during tight situations
; ⚠ WARNING: Should not be used across frames
TEMP                         .byte   ; 1 byte   (53)

; This section is to include variables that share the same memory but are 
; referenced under different names, something like temporary variables that 
; can be used differently by different kernels (which are only active one 
; at a time, leaving no risk of overlap)


;=============================================================================
; ROM / GAME CODE
;=============================================================================
  SEG code
  ORG $F000

  ; -----------------------
  ; RESET
  ; -----------------------
reset:
  sei     ; SEt Interruption disable
  cld     ; (CLear Decimal) disable BCD math

  ; At the start, the machine memory could be in any state, and that's good!
  ; We can use those leftover bytes as seed for RND before doing cleaning ZP
  lda RANDOM
  adc RND_MEM_LOC_1
  adc RND_MEM_LOC_2
  sta RANDOM

  ; -----------------------
  ; CLEAR ZERO PAGE MEMORY
  ; -----------------------
  ldx #0
  txa
  tay  ; Y = A = X = 0
clear_zero_page_memory:
  dex
  txs  ; This is the classic trick that exploits the fact that both
  pha  ; the stack and ZP RAM are the very same 128 bytes
  bne clear_zero_page_memory

game_init:
  ; -----------------------
  ; GAME INITIALIZATION
  ; -----------------------
  ; lda #FLAG_SPLASH_SCREEN  ; 2 enable splash screen
  lda #0  ; disable splash screen 
  sta GAME_FLAGS
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT

  lda #3
  sta FOREGROUND_COLOUR
  lda #BKG_LIGHT_GRAY
  sta BACKGROUND_COLOUR

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

_init_obstacle_conf:
; min 0, max 168

DEBUG_OBSTACLE_X_POS = #168 
  ; TODO: Remove/Update after testing obstacle positioning
  lda #1
  sta OBSTACLE_TYPE
  lda #PLAY_AREA_TOP_Y  ; DEBUG
  lda #CACTUS_Y
  lda #PLAY_AREA_TOP_Y-#35
  sta OBSTACLE_Y
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT
  lda #0
  sta OBSTACLE_X_FRACT

  lda #OBSTACLE_INITIAL_SPEED
  ;lda #0    ; Uncomment this to make the obstacle state
  sta OBSTACLE_VX_FRACT
  lda #0
  sta OBSTACLE_VX_INT

;=============================================================================
; FRAME
;=============================================================================
start_of_frame:

vsync_and_vblank:
  lda #2     ;
  sta VBLANK ; Enables VBLANK (and turns video signal off)

  ; last line of overscan
  sta WSYNC

  ; -----------------------
  ; V-SYNC (3 scanlines)
  ; -----------------------
vsync:
  sta VSYNC  ; Enables VSYNC
  sta WSYNC  ; 1st line of vsync
  sta WSYNC  ; 2nd line of vsync
  sta WSYNC  ; 3rd (final) line of vsync
  lda #0   ; A <- 0
  sta VSYNC  ; VSYNC = A (A=0) disables vsync

  ; -----------------------
  ; V-BLANK (37 scanlines)
  ; -----------------------
  ; Set the timer for the remaining VBLANK period (37 lines)
  ; 76 cpu cycles per scanline, 37 * 76 = 2812 cycles / 64 cycles per ticks = 43
  lda #43
  sta TIM64T

  ; TODO: Can this be removed?
  sta HMCLR             ; Clear horizontal motion registers

;==============================================================================
; BEGIN FRAME SETUP (VBLANK TIME)
;==============================================================================
start_frame_setup:
  lda #BKG_LIGHT_GRAY   ;
  sta COLUBK            ; Set initial background

  lda FOREGROUND_COLOUR       ; dino sprite colour
  sta COLUP0
  sta COLUP1

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
  lda #%11110000   ; Query if any direction was pressed
  and SWCHA
  cmp #%11110000
  beq __no_input
__button_pressed:
  jmp game_init    ; If any button was preset, reset
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
_on_joystick_up:
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
  ; If the dino is already crouching or jumping, ignore the input
  lda #FLAG_DINO_CROUCHING_OR_JUMPING
  bit GAME_FLAGS
  bne _end_check_joystick

  lda #FLAG_DINO_CROUCHING
  ora GAME_FLAGS
  sta GAME_FLAGS

_end_check_joystick:

  lda #FLAG_SPLASH_SCREEN
  bit GAME_FLAGS
  beq in_game_screen
  jmp in_splash_screen

; -----------------------------------------------------------------------------
; GAME SCREEN SETUP
; -----------------------------------------------------------------------------
in_game_screen:
  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
  beq update_obstacle
  jmp end_frame_setup

update_obstacle:
_update_obstacle_pos:
  ; update obstacle x
  sec
  lda OBSTACLE_X_FRACT
  sbc OBSTACLE_VX_FRACT
  sta OBSTACLE_X_FRACT
  lda OBSTACLE_X_INT
  sbc OBSTACLE_VX_INT
  sta OBSTACLE_X_INT

_check_obstacle_pos:
  lda OBSTACLE_X_INT
  cmp #0 ; -3
  beq _reset_obstacle_position
  jmp _update_obstacle_sprite

_reset_obstacle_position:
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT
  lda #0
  sta OBSTACLE_X_FRACT

_update_obstacle_sprite:
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
  CHECK_IF_OBSTACLE_SPRITE_IS_OFFSCREEN __use_zero_for_obstacle_sprite

  ; The next '.byte $2C' will turn the following 'ldx #0' (opcodes A2 00) into
  ; 'bit $A200' (opcodes 2C A2 00), effectively cancelling it
  .byte $2C
__use_zero_for_obstacle_sprite:
  ldx #0

  ldy OBSTACLES_SPRITES_TABLE+#1,x
  lda OBSTACLES_SPRITES_TABLE,x
  ldx #PTR_OBSTACLE_SPRITE
  jsr set_obstacle_data

  ; Check the obstacle x position and use empty data if it's offscreen
  CHECK_IF_OBSTACLE_MISSILE_IS_OFFSCREEN __use_zero_for_obstacle_missile

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
  jsr set_obstacle_data
end_update_obstacle:

update_floor:
_update_pebble_pos:
  sec
  lda PEBBLE_X_FRACT
  sbc OBSTACLE_VX_FRACT
  sta PEBBLE_X_FRACT
  lda PEBBLE_X_INT
  sbc OBSTACLE_VX_INT
  sta PEBBLE_X_INT

  cmp #8
  bcs __end_update_pebble_pos
  ; Reset pebble pos to a random x beyond the screen right edge
  jsr rnd8
  ; reg A has the random byte
  sta PEBBLE_X_FRACT
  jsr rnd8
  ; reg A has the random byte
  and #63
  sta TEMP
  jsr rnd8
  and #15
  adc #160
  adc TEMP
  sta PEBBLE_X_INT
__end_update_pebble_pos:

_update_pebble_anim:
  lda FOREGROUND_COLOUR
  sta COLUPF

  ; reset FLOOR_PFx
  lda #%11111111
  sta FLOOR_PF0
  sta FLOOR_PF1
  sta FLOOR_PF2
  sta FLOOR_PF3
  sta FLOOR_PF4
  sta FLOOR_PF5
  lda #0
  sta PEBBLE_PF0
  sta PEBBLE_PF1
  sta PEBBLE_PF2
  sta PEBBLE_PF3
  sta PEBBLE_PF4
  sta PEBBLE_PF5

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
  sec
  lda #<DINO_SPRITE_1_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_SPRITE
  lda #>DINO_SPRITE_1_END
  sbc #0
  sta PTR_DINO_SPRITE+1

  sec
  lda #<DINO_SPRITE_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_OFFSET
  lda #>DINO_SPRITE_OFFSETS_END
  sbc #0
  sta PTR_DINO_OFFSET+1

  sec
  lda #<DINO_MISSILE_0_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_MISSILE_0_CONF
  lda #>DINO_MISSILE_0_OFFSETS_END
  sbc #0
  sta PTR_DINO_MISSILE_0_CONF+1
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
  and #%00000111             ; animation
  cmp #7                     ;
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

; -----------------------------------------------------------------------------
; SPLASH SCREEN SETUP
; -----------------------------------------------------------------------------
in_splash_screen:
  lda FRAME_COUNT+1
  and #%00000001
  beq _skip_blink

  ; do the dino blinking
  lda GAME_FLAGS
  ora #FLAG_DINO_BLINKING  ; Remember, the Enable Ball bit is in the 7th-bit
                            ; hence the flag for blinking is in the 7th bit

  dec FRAME_COUNT+1         ; Turn the 0-bit of FRAME_COUNT+1 off, so the
                            ; next frame does not enable blinking again
  sta GAME_FLAGS
  jmp _skip_opening_eyes

_skip_blink:
  ; if dino's eyes are closed then check if we should open them
  lda FRAME_COUNT
  cmp #14                    ; 14 frames (actually 15 because is 0 index)
                             ; or ~250 milliseconds (assuming 60 FPS) is the
                             ; pause that looked better for the blinking. After
                             ; these 15 frames has passed, the eyes are then
                             ; opened
  bcc _skip_opening_eyes
  lda GAME_FLAGS
  and #TOGGLE_FLAG_DINO_BLINKING_OFF
  sta GAME_FLAGS

_skip_opening_eyes:

end_frame_setup:

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

  lda GAME_FLAGS           ; if the splash screen is enabled then jump to the
  and #FLAG_SPLASH_SCREEN  ; splash screen kernel after disabling VBLANK

  beq game_kernels
  jmp splash_screen_kernel

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; GAME KERNELs
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
game_kernels:

score_setup_kernel:;---->>> 2 scanlines <<<----
  DEBUG_SUB_KERNEL #$10, #2

score_kernel:;---------->>> 10 scanlines <<<---
  DEBUG_SUB_KERNEL #$20,#10

sky_setup_kernel:;-->>> 2 scanlines <<<-----
  DEBUG_SUB_KERNEL #$30,#2

sky_kernel:;-------->>> 15 scanlines <<<----
  DEBUG_SUB_KERNEL #$4C,#24

play_area_setup_kernel:;----->>> 5 scanlines <<<-----
  ; From the DEBUG_SUB_KERNEL macro:
  ;  sta HMOVE   3 cycles (3 so far in this scanline)
  ;  bne .loop   not taken, so 2 cycles (5)

  sta WSYNC     ; 3 (8)

  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)

  ; Set GRP0 coarse position
  ; 28 cycles for dino in standing position, and 27 for crouching
  ;
  ; TODO: These instructions could be replaced by something more useful
  php        ; 3 (6) - Adds 7 cycles so time aligns
  plp        ; 4 (10) -

  php        ; 3 (13)
  plp        ; 4 (17)

  lda #FLAG_DINO_CROUCHING      ; 2 (19)
  bit GAME_FLAGS                ; 3 (22)
  sbeq _dino_is_not_crouching_1 ; 2/3 (24/25)

                                ; - (24)
  sta RESP0                     ; 3 (27)

  ; Turns the next 'sta RESP0' (opcodes 85 10) into (2C 85 10) or 'bit $8510'
  ; which does nothing, avoiding the need for a 'jmp _end_grp0_coarse_position'
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
  sta COLUBK       ; 3 (6)

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

; Coarse positioning setup for the obstacle. The obstacle graphics are stored in
; GRP1, with optional detail added using M1. Positioning is handled by four 
; routines (or cases). Three of these cover situations where the obstacle is 
; partially or fully obscured by the left or right edges of the screen. 
; The third routine (case 3) handles most visible, on-screen placements but 
; cannot accommodate those edge cases.
;
; To simplify positioning logic and avoid signed arithmetic, obstacle_x values 
; are treated as unsigned integers in the range 0–168. The visible Atari 2600 
; screen is 160 pixels wide, with the first 8 pixels of each scanline obscured 
; by the HMOVE blanking interval.
;
; ┌ obstacle pos (obstacle_x)
; │┌ screen pixel
; ││                                           obstacle_x = screen_x + 8
; ││                                                      |
; │└→ -8 -7 ... -1 0     ...     8           ...          |  █    160 161 ...
; └──→ 0  1 ...  7 8     ...    16           ...          ↓  █ █  168 169 ...
;                ↓ ↓             ↓                         █ █ █   ↓ ↓
;      ____ ... __│▓▓▓ HMOVE ▓▓▓|_____       ...            ███_____│______
;                 │▓▓▓ black ▓▓▓|                            █      │
;                 │▓▓▓ area  ▓▓▓|                            █      │
;                 ↑                                                 ↑
;       left edge of the screen                        right edge of the screen
;
;  ┌→ │ 0 ≤ x ≤ 8 │  8 < x ≤ 16 │        16 < x ≤ 162        │ x > 162 │
;  │  ├───────────┼─────────────┼────────────────────────────┼─────────┤
;  │  │   case 1  │    case 2   │          case 3            │  case 4 │
;  │  └───────────┴─────────────┴────────────────────────────┴─────────┘
;  └─── "x" refers to obstacle position (obstacle_x)
_set_obstacle_x_position:
  sta HMCLR        ; 3 (Worst case scenario CPU count at this point is 37)

  ; Logic summary:
  ; if (obstacle_x ≤ 8) {
  ;   case 1: GRP1 is fully offscreen (to the left), M1 is partially visible
  ; } else if (obstacle_x ≤ 16) {
  ;   case 2: GRP1 is partially visible, M1 is fully visible
  ; } else if (obstacle_x > 162) {
  ;   case 4: GRP1 is partially offscreen (to the right), M1 is fully hidden
  ; } else {
  ;   setup logic before invoking case 3
  ;   case 3: both GRP1 and M1 are fully visible
  ; }
  lda OBSTACLE_X_INT                                   ; 3 (40)
  cmp #9                                               ; 2 (42)
  bcc _case_1__p1_fully_hidden_m1_partially_visible    ; 2/3 (44/45)
  cmp #17                                              ; 2 (46)
  bcc _case_2__p1_partially_visible_m1_fully_visible   ; 2/3 (48/49)
  cmp #163                                             ; 2 (50)
  bcs _case_4__p1_partially_visible_m1_fully_hidden    ; 2/3 (52/53)

_prepare_before_invoking_case_3:
  ; Based on results from tools/simulate-coarse-pos-loop.py:
  ; Starting with an input value of #45, the coarse positioning algorithm sets
  ; the object's coarse location and leaves a remainder in register A within 
  ; the range [-7, 7], suitable for HMOVE fine adjustment.
  ;
  ; The earliest screen position set by this routine is physical pixel 5 
  ; (the 6th pixel, zero-indexed). Earlier positions are handled by:
  ;   - Case 1: input x = 0 to 8 → offscreen (pixels -8 to 0)
  ;   - Case 2: input x = 9 to 16 → HMOVE blanking area (pixels 1 to 8)
  ;
  ; The latest valid position before requiring another scanline is pixel 154 
  ; (indexed as 153), which corresponds to input x = 162.
  ;
  ; Thus, Case 3 handles obstacle_x values from 16 (maps to screen pixel 8) 
  ; up to 162 (maps to pixel 153).
  ;
  ; To align with the algorithm's expected input range, obstacle_x = 16 must be
  ; translated to x = 3 (the value that places at pixel 8), so 13 is subtracted
  ; from the base input (#45).
  clc          ; 2 (52)
  adc #45-#13  ; 2 (54)

  sec      ; 2 (56) - Set carry to do subtraction. Remember SBC is
           ;          actually an ADC with A2 complement
           ;          A - B = A + ~B + 1
           ;                           ^this is the carry set by sec

  jmp _case_3__p1_and_m1_fully_visible ; 3 (59)

_case_1__p1_fully_hidden_m1_partially_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline ================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ; Strobing M1 after HMOVE set the missile coarse position on screen pixel 
  ; 3 (the fourth pixel starting from pixel 0). This was found after testing
  ; taking screenshots in Stella. The offset needs to be adjusted for those
  ; 4 pixels by doing a -4 fine adjustment with HMM1. GRP1 position doesn't 
  ; matter as it will be zero (as it's offscreen)
  sta RESM1        ; 3 (6)
  ; This doesn't matter, as it will be 0
  ;sta RESP1
  ; offset calculation
  sec
  sbc #15-#4
  jmp _end_of_cases_1_2_and_3

_case_2__p1_partially_visible_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline ================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  sta RESP1        ; 3 (6)

  ; Strobing RESP1 at this point places the GRP1 coarse position at screen
  ; pixel 4 (the fifth pixel, zero-indexed). This was determined empirically
  ; using Stella screenshots.
  ;
  ; The obstacle_x input will be in the range [8, 16], where:
  ;   - x = 8  → maps to screen pixel 0 (just off the left edge)
  ;   - x = 16 → maps to screen pixel 8 (last pixel of the HMOVE blanking
  ;              region)
  ;
  ; For these values, the following fine offsets are applied:
  ;   x =  8 → offset -4 (index  3 in the offset table)
  ;   x =  9 → offset -3 (index  4)
  ;   ...
  ;   x = 15 → offset  3 (index 10)
  ;   x = 16 → offset  4 (index 11)
  ;
  ; This offset is computed as: offset = x - 6
  ;
  ; Note: the accumulator is later shared with case 3 logic, which expects the
  ; value (obstacle_x - 15). To align with that shared code path, the
  ; subtraction is done here.
  sec         ; 2 (8)
  sbc #5+#15  ; 2 (10)

  pha      ; 12 (22) wait/waste 12 CPU cycles (in 4 bytes) until the CPU is at
  pla      ;         cycle 22 so strobing RESM1 leaves it 8px from where GRP1
  inc $2D  ;         was strobed

  sta RESM1        ; 3 (25)

  ; At cycle 25, M1 appears 7px to the right of GRP1 instead of 8px. To fix
  ; this 1px misalignment, here a slight nudge to the right is applied to M1
  ; using HMM1
  ldx #$F0         ; 2 (27) - 1px to the right
  stx HMM1         ; 3 (30)

  jmp _end_of_cases_1_2_and_3 ; 3 (33)

_case_4__p1_partially_visible_m1_fully_hidden:
  sta WSYNC        ; 3 (48)
  ; 3rd scanline (scenario C: obstacle_x ≥ 158) ==========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; For case 4, RESP1 must be strobed at CPU cycle 71. The strobe completes
  ; at cycle 74, leaving just enough space for a 2-cycle instruction (like
  ; 'nop') before the scanline ends. There is no room for a 'sta WSYNC'.
  ;
  ; Theoretically, strobing RESP1 at CPU cycle 74 corresponds to TIA cycle 222
  ; (74 * 3), which should map to screen pixel 154 (222 - 68 cycles of HBLANK),
  ; but in practice, GRP1 appears at screen pixel 159... Go figure ¯\_(ツ)_/¯
  ;
  ; First, configure the fine offset. Then, delay until cycle 71 for RESP1.
  ;
  ; The rightmost position case 3 can handle without resorting to an extra 
  ; scanline is x=162 which maps to screen pixel 154, case 4 should continue
  ; from here, meaning the input x will be 163 onwards.
  ;
  ; For obstacle_x = 163, the obstacle should appear at screen pixel 155.
  ; However, the coarse position after strobing RESP1 at cycle 74 results in
  ; GRP1 being placed at screen pixel 159. This requires an offset of -4 pixels
  ; to correct the position. Similarly:
  ;   x = 164 → offset -3
  ;   x = 165 → offset -2
  ;   ...
  ;   x = 171 → offset +1

  sec             ; 2 (5)
  ; reg A contains x ∈ [163, 171]
  ; x needs to be mapped to index ∈ [3, 8] (offsets from -4 to +1)
  ; This is computed as: x - 160
  ; But A will later be shared with case 1, 2 and 3 logic, which subtract 15.
  sbc #160+#15        ; 2 (7)

  ; reg A now holds the correct offset index to be used later during
  ; the 4th scanline. The CPU is currently at cycle 7 and must reach cycle 71,
  ; leaving 64 cycles to waste.
  ;
  ; The following loop consumes 59 cycles:
  ;   - 11 iterations × 5 cycles (DEX + BNE) = 55 cycles
  ;   - Final iteration (DEX + BNE fails) = 4 cycles
  ldx #12         ; 2 (9)
__wait_until_cpu_is_at_cycle_71:        ; - (9) \
  dex                                   ; 2      > total: 59 cycles
  bne __wait_until_cpu_is_at_cycle_71   ; 2/3   /

  ; The CPU is now at cycle 68. A dummy instruction fills the gap to cycle 71.
  sta $2D       ; 3 (71)

  sta RESP1     ; 3 (74)

  ; At cycle 74, there is no room for 'sta WSYNC' (which requires 3 cycles).
  ; A 2-cycle instruction is used instead to complete the scanline.
  nop           ; 2 (76)

  ; 4th scanline ==============================================================
  sta HMOVE
  jmp _end_case_4

_case_3__p1_and_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline (scenario B: obstacle 9 ≤ x ≤ 157) ===========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

__div_by_15_loop:      ; - (3)
  sbc #15              ; 2 (5) - Divide by 15 (sucessive subtractions)
  bcs __div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)

  sta RESP1
  sta RESM1

_end_of_cases_1_2_and_3:
  sta WSYNC        ; if coming from scenario A, CPU count after this will be 33
                   ; if coming from scenario B, MAX CPU count will be 76
                   ; scenario A will jump past this 'sta WSYNC' and below's
                   ; 'sta HMOVE' (scenario A will take care of the HMOVE)
  ; 4th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

_end_case_4:
  ; Clear reg X to make sure no graphics are drawn in the first scanline of
  ; the sky_kernel
  ldx #0           ; 2 (5) - Do the fine offset in the next scanline, I'm
                   ;         avoiding doing it in the

  pha              ; 4 (9) - Wait/waste 7 cycles (2 bytes)
  pla              ; 3 (12)

  ; Offsets the remainder from [-14, 0] to [0, 14]
  ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
  clc             ; 2 (14)
  adc #15         ; 2 (16)
  ;lda #7 ; DEBUG

  tay                         ; 2 (18)
  lda FINE_POSITION_OFFSET,y  ; 4 (22) - y should range between [-7, 7]
  ; Apply the fine offset to both the GRP1 and the BALL, these won't shift the
  ; coarse position set above until the next time HMOVE is strobed
  sta HMP1       ; 3 (25)
  sta HMM1       ; 3 (28)

  sta WSYNC      ; 3 (31)

_last_setup_scanline:
  ; 5th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ldy #PLAY_AREA_TOP_Y   ; 2 (5)

  lda #FLAG_DINO_CROUCHING   ; 2 (7)
  bit GAME_FLAGS             ; 3 (10)
  bne __assign_crouching_kernel  ; 2/3 (12/13)

  lda #<legs_and_floor_kernel      ; 2 (14)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (17)
  lda #>legs_and_floor_kernel      ; 2 (19)
  sta PTR_AFTER_PLAY_AREA_KERNEL+1 ; 3 (22)

  lda #PLAY_AREA_BOTTOM_Y          ; 2 (24)

  jmp __end_middle_section_kernel_setup ; 3 (27)

__assign_crouching_kernel:         ; - (13)
  lda  #<dino_crouching_kernel     ; 2 (15)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (18)
  lda  #>dino_crouching_kernel     ; 2 (20)
  sta PTR_AFTER_PLAY_AREA_KERNEL+1 ; 3 (23)

  lda #CROUCHING_REGION_TOP_Y      ; 2 (25)

__end_middle_section_kernel_setup:

  sta PLAY_AREA_MIN_Y  ; (30/28) - If crouching, the play area min y is changed

  ; TODO can remove this sec?
  sec         ; 2 (32/30) Set the carry ahead of time for the next scanline

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR   ; 3 (35/33) 

  lda #$0C    ; for debugging purposes
  sta COLUBK  ;

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the BALL state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0
  tax

  sta CXCLR  ; Clear all collisions

play_area_kernel: ;------------------>>> 31 2x scanlines <<<--------------------
  sta WSYNC      ; 3 (37/35)

  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first then load dino's data for the next scanline
  DRAW_OBSTACLE  ; 13 (16)

  ; 46 (62)
  LOAD_DINO_GRAPHICS_IF_IN_RANGE #SET_CARRY, _play_area__end_of_1st_scanline

_play_area__end_of_1st_scanline: ; - (62)
  sta WSYNC                      ; 3 (65)

  ; 2nd scanline ==============================================================
                           ; - (0)
  sta HMOVE                ; 3 (3)
  DRAW_DINO                ; 3 (6)

  ; 29 (35)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY, _play_area__end_of_2nd_scanline

_play_area__end_of_2nd_scanline:  ; - (35)

  dey                      ; 2 (37)
  cpy PLAY_AREA_MIN_Y      ; 3 (40)
  bne play_area_kernel     ; 2/3 (42/43)

  ; At the final scanline of the play area, and just before the next scanline
  ; begins, jump to the next kernel. The destination depends on the dino's
  ; state—either the crouching kernel (if the dino is crouching) or the floor
  ; kernel (if it's not).
  jmp (PTR_AFTER_PLAY_AREA_KERNEL)  ; 5 (47)

dino_crouching_kernel: ;------------------>>> 31 2x scanlines <<<-----------------
_region_1:
  ;                 ████████ <-- this will be drawn by this region
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  sta WSYNC      ; 3 (from play_area_kernel: 58 -> 65)
                 ; 3 (from this kernel: 60 -> 63)

  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first, then load the dino's crouching data to draw
  ; on the next scanline
  DRAW_OBSTACLE  ; 13 (16)

  lda #%00000101 ; 2 (18) - Set P0 2px size
  sta NUSIZ0     ; 3 (21)

  ;         0 0 0 0 1 1 1 1  <-- GRP0 data, P0 is configured as double width
  ;         ........████████
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  lda #%00001111 ; 2 (25) - GRP0 sprite data

  sta HMCLR

  sta WSYNC      ; 3 ()

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  sta GRP0       ; 3 (6) - Draw the dino sprite

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 29 (35)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY, _region_1__end_of_2nd_scanline
_region_1__end_of_2nd_scanline:

  dey           ; 2 (59) - Keep decrementing the scanline counter
  sta WSYNC     ; 3 (62)

_region_2:
  ;                 ▒▒▒▒▒▒▒▒
  ;   █   ███████  ██ ███████ \__ this region will draw these 2 scanlines
  ;   ███████████████████████ /
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  DRAW_OBSTACLE ; 13 (16)

  lda FOREGROUND_COLOUR ; 3 (19)
  sta COLUPF            ; 3 (22)

  lda #$F0        ; 2 (24) - 24 CPU cycles has passed, it is safe to update the
                  ;           HMMx registers
  sta HMCLR       ; 3 (27) - First clear all obstacle's offsets
  sta HMP0        ; 3 (30)
  sta HMM0        ; 3 (33)
  lda #$10        ; 2 (35)
  sta HMBL        ; 3 (38)

  lda #%11010111  ; 2 (40) - GRP0 sprite data

  sec             ; 2 (42)
  sta WSYNC       ; 3 (45)

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  sta GRP0       ; 3 (6) - Draw the dino sprite
  sta ENAM0      ; 3 (9) - GRP0 = (11010111)₂ so both bit 1 and 0 are alreay
  sta ENABL      ; 3 (12)  set. These bits enable M0 and the ball respectively
  lda #%10000000 ; 2 (14)
  sta PF1        ; 3 (17)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (45)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_2__end_of_2nd_scanline
_region_2__end_of_2nd_scanline:

  sta TEMP              ; 3 (48)
  ; COLUPF must be restored to the game background color between
  ; CPU cycle 39 (after PF1 is drawn by the TIA for the first time in the 
  ; scanline) and cycle 54 (just before PF1 is drawn again in the same scanline
  ; —if the playfield is not reflected).
  lda #0                ; 2 (50)
  sta PF1               ; 3 (53)

  lda TEMP              ; 3 (56)

  dey                   ; 2 (58) - Keep y (2x scanline counter) updated
  sta WSYNC             ; 3 (61)

  ; 3rd scanline ==============================================================
                    ; - (0)
  sta HMOVE         ; 3 (3)
  DRAW_OBSTACLE     ; 13 (16)

  lda #%10000000    ; 2 (18) - PF1 can be changed before CPU
  sta PF1           ; 3 (21)   hits cycle 28, and should be cleared before
                    ;          CPU cycle 54

  ; Preload the HyMx register values
  lda #$10          ; 2 (23) - Positioning P0 1px to the left and the ball
                    ;          6px to the right.
                    ;          P0 will remain static in this position for
                    ;          the rest of the region
  ldx #$A0          ; 2 (25)

  sta HMCLR         ; 3 (28)

  sta HMP0          ; 3 (31)
  stx HMBL          ; 3 (34)
                    ;          the sprite detail

  lda #%00110101    ; 2 (36) - Set missile 0 size to 8px while 
  sta NUSIZ0        ; 3 (39)   keeping P0 at 2x size

  sec               ; 2 (41) - Delaying changing PF1 until is displayed

  lda #0            ; 2 (42) - Reset PF1. PF1 rendering finishes by CPU
  sta PF1           ; 3 (45)   cycle 39

  lda #$ff          ; 2 (47) - GRP0 sprite data for next scanline

_region_3:

  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ███████████████████████ \
  ;    ██████████████████████ | This region will draw these scanlines
  ;    █████████████████      |
  ;     ██████████  ███████   /
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  sta WSYNC              ; 3 (50, 43 if is coming from the branch below)
  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  sta GRP0      ; 3 (6)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_3__end_of_1st_scanline
_region_3__end_of_1st_scanline:

  dey    ; 2 (35) - Update the 2x scanline counter here (1st scanline of this 
         ;          kernel) as the region started in the middle of a 2x scanline

  ; Last scanline of this region is one above the play area bottom Y, the
  ; remaining scanline is for region 4
  cpy #PLAY_AREA_BOTTOM_Y+#1 ; 2 (37)
  beq _region_4 ; 2/3 (39/40)

  sta WSYNC                 ; 3 (42)
  ; 2nd scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)
  DRAW_OBSTACLE ; 13 (16)

; REGION_3_OFFSET = -(-#CROUCHING_REGION_TOP_Y + #3 - #1) =
;                 = -(-#CROUCHING_REGION_TOP_Y + #2)
; 3 from the already drawn scanlines, and 1 to move the *_END label back
REGION_3_OFFSET = #CROUCHING_REGION_TOP_Y - #2
  lda DINO_CROUCHING_REGION_3_MISSILE_AND_BALL_CONF_END - #REGION_3_OFFSET,y ; 4 (20)
  ldx DINO_CROUCHING_REGION_3_SPRITE_END - #REGION_3_OFFSET,y ; 4 (24)

  sta HMCLR     ; 3 (27)
  sta HMM0      ; 3 (30)
  asl           ; 2 (32)
  asl           ; 2 (34)
  asl           ; 2 (36)
  asl           ; 2 (38)
  sta HMBL      ; 3 (41)
  txa           ; 2 (43)
  jmp _region_3 ; 3 (46)

_region_4:
  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ███ ██  ██ <- this region draws this scanline
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  sta WSYNC     ; 3 (49)

  ; 1st scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  DRAW_OBSTACLE    ; 13 (16)

  lda ($80,x)      ; 6 (22) - Wait/waste 6 CPU cycles (2 bytes)

  sta HMCLR        ; 3 (25)

  lda #$F0         ; 2 (28) - Move M0 1px to the right
  sta HMM0         ; 3 (31)

  ldx #%00010000   ; 2 (33) - Set M0 to 2px and make P0 back to 1px size

  sec              ; 2 (35) - Set carry for next scanline and delay applying
                   ;          changes to NUSIZ0 and ENABL until the dino 
                   ;          finished drawing (around CPU cycle 42 for this
                   ;          scanline)

  lda #%10110011   ; 2 (37)

  stx NUSIZ0       ; 3 (40) - Update the NUSIZ0 configuration stored in reg X
                   ;          a few instructions ago
  stx ENABL        ; 3 (43) - Bit 0 of reg X is 0, so it can be used to turn
                   ;          the ball OFF

  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒█ ██  ██
  ;        10110011 <-- GRP0 sprite value
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  sta WSYNC        ; 3 (46)

  ; 2nd scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  sta GRP0      ; 3 (6)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_4__end_of_2nd_scanline
_region_4__end_of_2nd_scanline:

  ; Restore the dino's Y-position to standing after crouching is fully drawn.
  ; This prevents the standing sprite from being drawn prematurely during the
  ; crouch (which would result in overlapping graphics if both kernels render).
  ; Using Y = 0 during crouch suppresses standing sprite rendering. Restoring
  ; it here ensures normal leg drawing resumes, since both states share leg
  ; data.
  sta TEMP               ; 3 (36)
  lda #INIT_DINO_TOP_Y   ; 2 (38)
  sta DINO_TOP_Y_INT     ; 3 (41)
  lda TEMP               ; 3 (44)

  dey                    ; 2 (46)

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
  sec          ; 2 (71)
  sta WSYNC    ; 3 (74)

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
  tya                  ; 2 (50)
  sbc DINO_TOP_Y_INT   ; 3 (53)
  adc #DINO_HEIGHT     ; 2 (55)
  bcs _legs_3rd_scanline__dino_y_within_range ; 2/3 (57/58)
  lda #0               ; 2 (60)
  tax                  ; 2 (62)
  sta ENAM0            ; 3 (65)
  jmp _legs_and_floor__end_of_3rd_scanline ; 3 (68)

_legs_3rd_scanline__dino_y_within_range: ; - (57)
  lda (PTR_DINO_OFFSET),y  ; 5 (62)
  sta HMP0                 ; 3 (65)
  LAX (PTR_DINO_SPRITE),y  ; 5 (60)

_legs_and_floor__end_of_3rd_scanline:
  sta WSYNC                ; 3 (73)

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

gravel_area_kernel:
  ; Use this to handle collission detection
  DEBUG_SUB_KERNEL #$AA,#5
  jmp end_of_frame

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; END GAME KERNEL
;=============================================================================

;##############################################################################

;=============================================================================
; SPLASH SCREEN KERNEL
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
splash_screen_kernel:
  DEBUG_SUB_KERNEL #$7A,#35

_splash__dino_kernel_setup: ;------------->>> 32 2x scanlines <<<--------------
  lda BACKGROUND_COLOUR     ; 3
  sta COLUBK                ; 3

  INSERT_NOPS 7    ; 14 Fix the dino_x position for the rest of the kernel
                   ;    (notice I'm not starving for ROM atm of writing this)
  sta RESM0        ; 3  TV beam should now be at a dino coarse x position
  sta RESP0        ; 3  M0 will be 3 cycles (9 px) far from P0
  sta WSYNC        ; 3


  lda #0                ; 2
  sta GRP0              ; 3 (5)
  sta ENAM0             ; 3 (8)
  sta HMCLR             ; 3 (11)
  ldy #DINO_HEIGHT      ; 2 (13)

  INSERT_NOPS 6         ; 12 (25)
  sta RESBL             ; 3 (28)

  lda #$F0              ; 3 moves the ball to x+1
  sta HMBL

  sta WSYNC             ; 3

_splash__dino_kernel: ;----------->>> #DINO_HEIGHT 2x scanlines <<<----------------

  ; 1st scanline (setup) ======================================================
  sta HMOVE
  INSERT_NOPS 10                       ; 20 add some 'distance' between the last
                                       ; sta HMOVE (has to be 24+ cycles)
  lda DINO_SPRITE_OFFSETS-#1,y        ; 4
  sta HMP0                             ; 3

  LAX DINO_MISSILE_0_OFFSETS-#1,y      ; 4

  ; missile
  sta HMM0                             ; 3
  asl                                  ; 2
  asl                                  ; 2
  sta NUSIZ0                           ; 3

  lda DINO_SPRITE_1-#1,y               ; 4

  ;sta HMBL

  sta WSYNC                            ; 3

  ; 2nd scanline ==============================================================
  sta HMOVE                            ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  stx ENAM0                             ; 3
  and GAME_FLAGS               ; 3
  rol
  rol
  rol
  sta ENABL                             ; 3


  INSERT_NOPS 8
  sta HMCLR

  sta WSYNC                             ; 3
  sta HMOVE                             ; 3

  dey                                   ; 2
  bne _splash__dino_kernel                   ; 2/3

  lda #0
  sta GRP0
  sta ENAM0
  sta HMM0
  sta HMP0
  INSERT_NOPS 11
  sta WSYNC
  sta HMOVE

  DEBUG_SUB_KERNEL #$7A,#116
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; END SPLASH SCREEN KERNEL
;=============================================================================

end_of_frame:
  ; -----------------------
  ; OVERSCAN (30 scanlines)
  ; -----------------------
  ; 30 lines of OVERSCAN, 30 * 76 / 64 = 35
  lda #35
  sta TIM64T
  lda #2
  sta VBLANK

  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
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
  sta OBSTACLE_VX_FRACT
  sta OBSTACLE_VX_INT
  sta DINO_VY_INT     ; Clearing the vertical speed will stop the
  sta DINO_VY_FRACT   ; dino vertical movement (in case it was jumping)

  ; Remove the crouching flag in case it was crouching
  lda #FLAG_DINO_CROUCHING
  bit GAME_FLAGS
  beq __set_dino_game_over_sprite
  lda #TOGGLE_FLAG_DINO_CROUCHING_OFF
  and GAME_FLAGS
  sta GAME_FLAGS
  ; Restore the Y position to the standing default position
  lda DINO_TOP_Y_INT
  bne __set_dino_game_over_sprite
  lda #INIT_DINO_TOP_Y
  sta DINO_TOP_Y_INT

__set_dino_game_over_sprite:
  sec
  lda #<DINO_GAME_OVER_SPRITE_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_SPRITE
  lda #>DINO_GAME_OVER_SPRITE_END
  sbc #0
  sta PTR_DINO_SPRITE+1

  sec
  lda #<DINO_SPRITE_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_OFFSET
  lda #>DINO_SPRITE_OFFSETS_END
  sbc #0
  sta PTR_DINO_OFFSET+1

  sec
  lda #<DINO_GAME_OVER_MISSILE_0_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_MISSILE_0_CONF
  lda #>DINO_GAME_OVER_MISSILE_0_OFFSETS_END
  sbc #0
  sta PTR_DINO_MISSILE_0_CONF+1

__init_game_over_sound:
  SFX_INIT GAME_OVER_SOUND

_already_game_over:
  SFX_UPDATE_PLAYING GAME_OVER_SOUND

  lda GAME_OVER_TIMER
  beq _update_random
  dec GAME_OVER_TIMER

_no_collision:

_update_random:
  inc RANDOM
  jsr rnd8

  lda #FLAG_DINO_JUMPING
  bit GAME_FLAGS
  ; Continue to '_update_frame_count' if not jumping
  beq _update_frame_count
  ; Also check if not game over, in which, the game over sound has priority
  lda #FLAG_GAME_OVER
  bit GAME_FLAGS
  bne _update_frame_count

  SFX_UPDATE_PLAYING JUMP_SOUND

_update_frame_count:
  inc FRAME_COUNT
  bne __skip_inc_frame_count_upper_byte
  inc FRAME_COUNT+1
__skip_inc_frame_count_upper_byte:

_remaining_overscan:
  lda INTIM
  bne _remaining_overscan
  ; We're on the final OVERSCAN line and 40 cpu cycles remain,
  ; do the jump now to consume some cycles and a WSYNC at the
  ; beginning of the next frame to consume the rest

  sta WSYNC
  jmp start_of_frame


;=============================================================================
; SUBROUTINES
;=============================================================================
  include "subroutines.asm"

;=============================================================================
; SPRITE GRAPHICS DATA
;=============================================================================
  include "sprites.asm"

;=============================================================================
; SOUND DATA
;=============================================================================
  include "sounds.asm"

;-----------------------------------------------------------------------------
; FINE OFFSETS TABLE
;-----------------------------------------------------------------------------
; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
  ORG $ffe0
FINE_POSITION_OFFSET:
  .byte $70  ; offset -7
  .byte $60  ; offset -6
  .byte $50  ; offset -5
  .byte $40  ; offset -4
  .byte $30  ; offset -3
  .byte $20  ; offset -2
  .byte $10  ; offset -1
  .byte $00  ; offset  0
  .byte $F0  ; offset  1
  .byte $E0  ; offset  2
  .byte $D0  ; offset  3
  .byte $C0  ; offset  4
  .byte $B0  ; offset  5
  .byte $A0  ; offset  6
  .byte $90  ; offset  7
  .byte $80  ; offset  8

POWERS_OF_2_NEGATED:
  .byte #%11111110
  .byte #%11111101
  .byte #%11111011
  .byte #%11110111
  .byte #%11101111
  .byte #%11011111
  .byte #%10111111
  .byte #%01111111
;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
