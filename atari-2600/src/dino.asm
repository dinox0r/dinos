  PROCESSOR 6502

  INCLUDE "../include/vcs.h"
  ; Including this just for the sbcs, sbeq, etc macros, that look like 
  ; the branching instructions but add a page boundary check
  INCLUDE "../include/macro.h"

  LIST ON           ; turn on program listing, for debugging on Stella

;=============================================================================
; MACROS
;=============================================================================

  INCLUDE "macros.asm"

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

GAME_OVER_TIMER_TOTAL_TIME = #50

PLAY_AREA_SCANLINES = #59    ; All of these are measured as 2x scanlines
FLOOR_SCANLINES = #2
GRAVEL_SCANLINES = #9

PLAY_AREA_TOP_Y = #PLAY_AREA_SCANLINES + #FLOOR_SCANLINES + #GRAVEL_SCANLINES
PLAY_AREA_BOTTOM_Y = #PLAY_AREA_TOP_Y - #PLAY_AREA_SCANLINES

GROUND_AREA_TOP_Y = #PLAY_AREA_BOTTOM_Y - #FLOOR_SCANLINES
GROUND_AREA_BOTTOM_Y = #GROUND_AREA_TOP_Y - #GRAVEL_SCANLINES

PLAYER_0_INDEX = #0
PLAYER_1_INDEX = #1
MISSILE_0_INDEX = #2
MISSILE_1_INDEX = #3

; Crouching Kernel
; -----------------------------------------------------------------------------
CROUCHING_SCANLINES = #8

CROUCHING_REGION_TOP_Y = #PLAY_AREA_BOTTOM_Y + #CROUCHING_SCANLINES

DINO_JUMP_INIT_VY_INT = #5
DINO_JUMP_INIT_VY_FRACT = #21
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

; Sky area
CLOUD_1_X_INT                .byte 
CLOUD_1_X_FRACT              .byte

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
  ;lda #1
  ;sta OBSTACLE_TYPE
  ;lda #PLAY_AREA_TOP_Y  ; DEBUG
  ;lda #CACTUS_Y
  ;lda #CACTUS_Y+(#PTERO_HEIGHT/2)+#3
  ;sta OBSTACLE_Y
  ;lda #DEBUG_OBSTACLE_X_POS
  ;sta OBSTACLE_X_INT
  ;lda #0
  ;sta OBSTACLE_X_FRACT
  jsr spawn_obstacle

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
  bit GAME_FLAGS           ; #FLAG_GAME_OVER = %#01000000
  bvc _check_joystick_down ; hence can directly check bit 6
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

  lda #FLAG_SPLASH_SCREEN
  bit GAME_FLAGS
  beq in_game_screen
  jmp in_splash_screen

; -----------------------------------------------------------------------------
; GAME SCREEN SETUP
; -----------------------------------------------------------------------------
in_game_screen:
  bit GAME_FLAGS        ; #FLAG_GAME_OVER = %#01000000
  bvc update_obstacle   ; hence can directly check bit 6
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
  bne _update_obstacle_sprite

  jsr spawn_obstacle

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

  GENERATE_RANDOM_NUMBER_BETWEEN_160_AND_238
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

  beq draw_game
  jmp draw_splash_screen

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; GAME KERNELs
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
draw_game:
  INCLUDE "kernels/score_kernel.asm"
  INCLUDE "kernels/sky_kernel.asm"
  INCLUDE "kernels/play_area_kernel.asm"
  INCLUDE "kernels/dino_crouching_kernel.asm"
  INCLUDE "kernels/legs_and_floor_kernel.asm"
  INCLUDE "kernels/ground_area_kernel.asm"
  INCLUDE "kernels/gravel_area_kernel.asm"

  jmp end_of_frame  ; 3 ()

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; END GAME KERNEL
;=============================================================================

;=============================================================================
; SPLASH SCREEN KERNEL
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
draw_splash_screen:
  INCLUDE "kernels/splash_screen_kernel.asm"

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

  bit GAME_FLAGS         ; Remember: #FLAG_GAME_OVER = %#01000000
  bvs _already_game_over ; Skip the collision detection if the game over 
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
  ; Increment the score

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
  INCLUDE "subroutines.asm"

;=============================================================================
; SPRITE GRAPHICS DATA
;=============================================================================
  INCLUDE "sprites.asm"

;=============================================================================
; SOUND DATA
;=============================================================================
  INCLUDE "sounds.asm"

;=============================================================================
; UTILITY TABLES
;=============================================================================
  INCLUDE "tables.asm"

;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
