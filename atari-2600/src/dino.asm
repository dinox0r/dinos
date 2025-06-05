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

OBSTACLE_M1_MAX_SCREEN_X = #156   ; if obstacle_x >= 155, m1 = 0
OBSTACLE_GRP1_MIN_SCREEN_X = #8  ; if obstacle_x < 17, grp1 = 0

OBSTACLE_MIN_X = #0
OBSTACLE_MAX_X = #163

CACTUS_Y = #27

PTERO_OPEN_WINGS_TABLE_ENTRY_INDEX = #1
PTERO_CLOSED_WINGS_TABLE_ENTRY_INDEX = #2


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

FLAG_DINO_CROUCHING_OR_JUMPING = FLAG_DINO_CROUCHING | FLAG_DINO_JUMPING

TOGGLE_FLAG_DINO_BLINKING_OFF  = #%01111111
TOGGLE_FLAG_DINO_JUMPING_OFF   = #%11111011
TOGGLE_FLAG_DINO_CROUCHING_OFF = #%11101111

;=============================================================================
; ZERO PAGE MEMORY / VARIABLES
;=============================================================================
  SEG.U variables
  ORG $80

; Dino State Variables
DINO_TOP_Y_INT             .byte   ; 1 byte   (0)
DINO_TOP_Y_FRACT           .byte   ; 1 byte   (1)
DINO_VY_INT                .byte   ; 1 byte   (2)
DINO_VY_FRACT              .byte   ; 1 byte   (3)

PTR_DINO_SPRITE            .word   ; 2 bytes  (4)
PTR_DINO_OFFSET            .word   ; 2 bytes  (6)
PTR_DINO_MISSILE_0_CONF      .word   ; 2 bytes  (8)

; Input variables
KEY_UP_PRESSED_FRAMES      .byte   ; 1 byte   (10)

; Obstacle Variables
OBSTACLE_TYPE              .byte   ; 1 byte   (11)
OBSTACLE_Y                 .byte   ; 1 byte   (12)
OBSTACLE_X_INT             .byte   ; 1 byte   (13)
OBSTACLE_X_FRACT           .byte   ; 1 byte   (14)
OBSTACLE_VX_INT            .byte   ; 1 byte   (15)
OBSTACLE_VX_FRACT          .byte   ; 1 byte   (16)

PTR_OBSTACLE_SPRITE        .word   ; 2 bytes  (17)
PTR_OBSTACLE_OFFSET        .word   ; 2 bytes  (19)
PTR_OBSTACLE_MISSILE_1_CONF  .word   ; 2 bytes  (21)

; Play area
PLAY_AREA_MIN_Y            .byte   ; 1 byte   (23)
FOREGROUND_COLOUR          .byte   ; 1 byte   (24)
BACKGROUND_COLOUR          .byte   ; 1 byte   (25)

PTR_AFTER_PLAY_AREA_KERNEL .word   ; 2 bytes  (26)

; Ground area
FLOOR_PF0                  .byte   ; 1 byte ()
FLOOR_PF1                  .byte   ; 1 byte ()
FLOOR_PF2                  .byte   ; 1 byte ()

; Gameplay variables
GAME_FLAGS                 .byte   ; 1 byte   (28)
FRAME_COUNT                .word   ; 2 bytes  (29)
RND_SEED                   .word   ; 2 bytes  (31)

; This section is to include variables that share the same memory but are 
; referenced under different names, something like temporary variables that 
; can be used differently by different kernels (which are only active one 
; at a time, leaving no risk of overlap)

; To save the state of a register temporarily during tight situations
TEMP                       .byte   ; 1 byte   (36)

;=============================================================================
; ROM / GAME CODE
;=============================================================================
  SEG code
  ORG $f000

  ; -----------------------
  ; RESET
  ; -----------------------
reset:
  sei     ; SEt Interruption disable
  cld     ; (CLear Decimal) disable BCD math

  ; At the start, the machine memory could be in any state, and that's good!
  ; We can use those leftover bytes as seed for RND before doing cleaning ZP
  lda #<RND_SEED
  adc RND_MEM_LOC_1
  sta RND_SEED
  ;
  lda #>RND_SEED
  adc RND_MEM_LOC_2
  sta RND_SEED+1

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

_init_obstacle_conf:
DEBUG_OBSTACLE_X_POS = #16
  ; TODO: Remove/Update after testing obstacle positioning
  lda #3 ; Debug arrow
  ;lda #7
  sta OBSTACLE_TYPE
  lda #PLAY_AREA_TOP_Y  ; DEBUG
  ;lda #CACTUS_Y
  sta OBSTACLE_Y
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT
  lda #0
  sta OBSTACLE_X_FRACT

;=============================================================================
; FRAME
;=============================================================================
start_of_frame:

vsync_and_vblank:
  lda #2     ;
  sta VBLANK ; Enables VBLANK (and turns video signal off)

  ;inc <RND_SEED
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

_check_joystick_down:
  lda SWCHA
  lda #%00100000 ; down (player 0)
  bit SWCHA
  beq _on_joystick_down

  ; We need to clear the crouching flag as the player might have released the
  ; joystick down and we have to make sure the dino is not crouching anymore
  lda GAME_FLAGS
  and #TOGGLE_FLAG_DINO_CROUCHING_OFF
  sta GAME_FLAGS

_check_joystick_up:
  lda #%00010000 ; up (player 0)
  bit SWCHA
  bne _reset_up_counter  ; not pressing UP, reset up counter

_on_joystick_up:
  inc KEY_UP_PRESSED_FRAMES
  bne _keep_checking_joystick_up  ; if up-counter > 255 then up-counter = 255
  lda #255
  sta KEY_UP_PRESSED_FRAMES

_keep_checking_joystick_up:
  lda KEY_UP_PRESSED_FRAMES
  cmp #10
  bcs _end_check_joystick

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
  jmp _end_check_joystick

_on_joystick_down:
  ; If the dino is already crouching or jumping, ignore the input
  lda #FLAG_DINO_CROUCHING_OR_JUMPING
  bit GAME_FLAGS
  bne _reset_up_counter

  lda #FLAG_DINO_CROUCHING
  ora GAME_FLAGS
  sta GAME_FLAGS

  ;
  ; fall through to reset the up-counter
_reset_up_counter:
  lda #0
  sta KEY_UP_PRESSED_FRAMES

_end_check_joystick:

  lda #FLAG_SPLASH_SCREEN
  bit GAME_FLAGS
  beq in_game_screen
  jmp in_splash_screen

; -----------------------------------------------------------------------------
; GAME SCREEN SETUP
; -----------------------------------------------------------------------------
in_game_screen:

update_floor:
  lda #0
  sta FLOOR_PF2

  ; 256 + (a - b)
  lda DINO_TOP_Y_INT
  cmp #INIT_DINO_TOP_Y+#20
  bcs __dino_y_over_20
  cmp #INIT_DINO_TOP_Y+#10
  bcs __dino_y_over_10

  lda #%10000000
  sta FLOOR_PF0
  lda #%11000000
  sta FLOOR_PF1

  jmp update_obstacle

__dino_y_over_10:
  lda #%00000000
  sta FLOOR_PF0
  lda #%10000000
  sta FLOOR_PF1
  jmp update_obstacle

__dino_y_over_20:
  lda #0
  sta FLOOR_PF0
  sta FLOOR_PF1

update_obstacle:
  ; If it reaches here, then the obstacle is on-screen
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

_update_obstacle_pos:
  ; TODO update the obstacle speed to adjust dynamically based on obstacle
  ; type and difficulty
  ;lda #250 ;
  lda #0    ; DEBUG
  sta OBSTACLE_VX_FRACT
  lda #0
  sta OBSTACLE_VX_INT

  ; update obstacle x
  sec
  lda OBSTACLE_X_FRACT
  sbc OBSTACLE_VX_FRACT
  sta OBSTACLE_X_FRACT
  lda OBSTACLE_X_INT
  sbc OBSTACLE_VX_INT
  sta OBSTACLE_X_INT
  cmp #0 ; -3
  beq _reset_obstacle_position
  jmp _check_if_dino_is_jumping

_reset_obstacle_position:
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT
  lda #0
  sta OBSTACLE_X_FRACT

_end_update_obstacle:

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
  ; the following assumes DINO_SPRITE_1 does not cross page boundary
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
; routines (or scenarios). Three of these handle cases where the obstacle is 
; partially or completely hidden by the far left or right edges of the screen. 
; The third routine (scenario B) handles most on-screen cases but cannot handle 
; these edge cases:
;
; - On the *left edge*, scenario B cannot place the obstacle earlier than the 
;   9th pixel, even when strobing RESP1 during HBLANK. To position it at pixel 5,
;   RESP1 must be strobed *after* HMOVE.
;
; - On the *right edge*, scenario B ends up strobing RESP1 around CPU cycles 
;   72–75, which causes M1 to be strobed on the following scanline. This results 
;   in an unwanted additional scanline (a waste, as M1 isn't visible anyway).
;
; To simplify positioning logic (and avoid signed arithmetic), obstacle X 
; positions are treated as unsigned values in the range 0–163. The visible Atari 
; 2600 screen is 160 pixels wide, with the first 8 pixels of each scanline 
; blacked out due to HMOVE blanking.
;
; ┌ obstacle pos
; │ ┌ screen pixel
; │ │                                         obstacle_x = screen_x + 3
; │ │                                                    |
; │ └─→ -8 -7 ... 0     ...     8           ...          |  █      160 161 ...
; └────→ 0  1 ... 8     ...    16           ...          ↓  █ █    168 169 ...
;                 ↓             ↓                         █ █ █     ↓
;                 │▓▓▓ HMOVE ▓▓▓|                          ███      │
;       offscreen │▓▓▓ black ▓▓▓| <-------  visible area  --█-----> │ offscreen
;                 │▓▓▓ area  ▓▓▓|                           █       │
;                 ↑                                                 ↑
;       left edge of the screen                        right edge of the screen
;
_set_obstacle_x_position:
  sta HMCLR        ; 3 (Worst case scenario CPU count at this point is 37)

  ; Logic summary:
  ; if (obstacle_x < 8) {
  ;   case 1: obstacle GRP1 is fully hidden, but M1 is partially on-screen
  ; } else if (obstacle_x < 17) {
  ;   case 2: obstacle GRP1 is partially on-screen
  ; } else if (obstacle_x ≥ 158) {
  ;   scenario C: obstacle is partially or fully offscreen to the right
  ; } else {
  ;   scenario B: obstacle is fully onscreen
  ; }
  lda OBSTACLE_X_INT                                   ; 3 (40)
  cmp #8
  bcc _case_1_grp1_fully_hidden_m1_partially_visible
  cmp #17                                               ; 2 (46)
  bcc _case_2_grp1_partially_visible_m1_fully_visible              ; 2/3 (48/49)
  cmp #158                                             ; 2 (42)
  bcs _case_3_grp1_partially_visible_m1_fully_hidden  ; 2/3 (44/45)

  clc      ; 2 (50)
  ; TODO: Explain the #37
  ; Hint, it came from observations while running the 
  ; tools/simulate-coarse-pos-loop.py script, 45 was the only value that did
  ; what was needed, but because of the 8 pixels offset, it becomes 37
  adc #37  ; 2 (52) 

  sec      ; 2 (54) - Set carry to do subtraction. Remember SBC is
           ;          actually an ADC with A2 complement
           ;          A - B = A + ~B + 1
           ;                           ^this is the carry set by sec

  jmp _case_4_grp1_and_m1_fully_visible ; 3 (57)

_case_1_grp1_fully_hidden_m1_partially_visible:
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
  sta RESP1
  ; offset calculation
  sec
  sbc #15-#4
  jmp _end_cases_1_2_and_4

_case_2_grp1_partially_visible_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline ================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  sta RESP1        ; 3 (6)

  ; Strobing P1 at this location, places its coarse position at pixel 4 (fifth pixel on the screen starting from 0).
  ; Found this empirically after taking screenshots with Stella.
  ; The obstacle's X value (x) will be in the range [8, 16], where:
  ;   x = 8 maps to screen pixel 0 (just off the left edge) and x = 16
  ; maps to screen pixel 8 (last pixel of the HMOVE black area)
  ;
  ; For these values of x, the following fine offsets are applied:
  ;   x = 8 → offset -4 (index 3 in the offset table)
  ;   x = 9 → offset -3 (index 4)
  ;   x = 10 → offset -2 (index 5)
  ;   x = 11 → offset -1 (index 6)
  ;   x = 12 → offset 0 (index 7)
  ;   x = 13 → offset 1 (index 8)
  ;   x = 14 → offset 2 (index 9)
  ;   x = 15 → offset 3 (index 10)
  ;   x = 16 → offset 4 (index 11)
  ; These means that the offset is computed as x - 6
  ;
  ; Note: accumulator A will later be shared with scenario B code, which
  ; subtracts 15 from obstacle_x. This subtraction also happens here to align
  ; with the shared logic at `_end_cases_1_2_and_4`.
  sec      ; 2 (8)
  sbc #5+#15  ; 2 (10)

  pha      ; 12 (22) wait/waste 12 CPU cycles (in 4 bytes) until the CPU is at
  pla      ;         cycle 22 so strobing RESM1 leaves it 8px from where GRP1
  inc $2D  ;         was strobed

  sta RESM1        ; 3 (25)

  ; At cycle 25, M1 appears 7px to the right of GRP1 instead of 8px.
  ; To fix this 1px misalignment (to match scenario B), apply a slight
  ; left nudge to M1 using HMM1:
  ldx #$F0         ; 2 (27)
  stx HMM1         ; 3 (30)

  jmp _end_cases_1_2_and_4 ; 3 (33)

_case_3_grp1_partially_visible_m1_fully_hidden:
  sta WSYNC        ; 3 (48)
  ; 3rd scanline (scenario C: obstacle_x ≥ 158) ==========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; For scenario C, RESP1 must be strobed at CPU cycle 71. The strobe completes
  ; at cycle 74, leaving just enough space for a 2-cycle instruction (like
  ; 'nop') before the scanline ends—no room for a 'sta WSYNC'.
  ;
  ; Theoretically, strobing RESP1 at CPU cycle 74 corresponds to TIA cycle 222
  ; (74 * 3), which should map to screen pixel 154 (222 - 68 cycles of HBLANK),
  ; but in practice, GRP1 appears at screen pixel 159... Go figure ¯\_(ツ)_/¯
  ;
  ; First, configure the fine offset. Then, delay until cycle 71 for RESP1.
  ;
  ; For obstacle_x = 158, the obstacle should appear at screen pixel 155.
  ; However, the coarse position after strobing RESP1 at cycle 74 results in
  ; GRP1 being placed at screen pixel 159. This requires an offset of -4 pixels
  ; to correct the position. Similarly:
  ;   x = 158 → offset -4
  ;   x = 159 → offset -3
  ;   x = 160 → offset -2
  ;   ...
  ;   x = 163 → offset +1

  sec             ; 2 (5)
  ; reg A contains x ∈ [158, 163]
  ; x needs to be mapped to index ∈ [3, 8] (offsets from -4 to +1)
  ; This is computed as: x - 155
  ; But A will later be shared with scenario B logic, which subtracts 15.
  ; So instead is pre-adjusted here: x - 155 - 15 = x - 170
  ;
  sbc #170        ; 2 (7)

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
  jmp _end_case_3

_case_4_grp1_and_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline (scenario B: obstacle 9 ≤ x ≤ 157) ===========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

__div_by_15_loop:      ; - (3)
  sbc #15              ; 2 (5) - Divide by 15 (sucessive subtractions)
  bcs __div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)

  sta RESP1
  sta RESM1

_end_cases_1_2_and_4:
  sta WSYNC        ; if coming from scenario A, CPU count after this will be 33
                   ; if coming from scenario B, MAX CPU count will be 76
                   ; scenario A will jump past this 'sta WSYNC' and below's
                   ; 'sta HMOVE' (scenario A will take care of the HMOVE)
  ; 4th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

_end_case_3:
  ; Clear reg X to make sure no graphics are drawn in the first scanline of
  ; the sky_kernel
  ldx #0           ; 2 (5) - Do the fine offset in the next scanline, I'm
                   ;         avoiding doing it in the

  ; same scanline as the coarse positioning because for x > 150 the strobing
  ; will occur near the end of the scanline leaving barely room for strobing
  ; wsync
  INSERT_NOPS 8              ; 18 (23)
  ; Offsets the remainder from [-14, 0] to [0, 14]
  ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
  clc
  adc #15
  ;lda #7 ; DEBUG

  tay                         ; 2 (25)
  lda FINE_POSITION_OFFSET,y  ; 4 (29) - y should range between [-7, 7]
  ; Apply the fine offset to both the GRP1 and the BALL, these won't shift the
  ; coarse position set above until the next time HMOVE is strobed
  sta HMP1  ; 3 (32)
  sta HMM1  ; 3 (35)

  sta WSYNC                   ; 3 (38)

_last_setup_scanline:
  ; 5th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ldy #PLAY_AREA_TOP_Y   ; 2 (5)

  lda #FLAG_DINO_CROUCHING   ; 2 (7)
  bit GAME_FLAGS             ; 3 (10)
  bne __assign_crouching_kernel  ; 2/3 (12/13)

  lda #<legs_and_floor_kernel        ; 2 (14)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (17)
  lda #>legs_and_floor_kernel        ; 2 (19)
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
  sec              ; 2 (32/30) Set the carry ahead of time for the next scanline

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR        ; 3 (35/33) 

  lda #$0C         ; for debugging purposes
  sta COLUBK       ;

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the BALL state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0
  tax

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
  sta WSYNC     ; 3 (70)

  ; 2nd scanline ========================================================
                ; - (0)
  sta HMOVE     ; 3 (3)

  DRAW_DINO     ; 3 (6)

  ;lda #77
  ;sta COLUBK

  ; 29 (35)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY, _legs_and_floor__end_of_2nd_scanline
_legs_and_floor__end_of_2nd_scanline:  ; - (35)
  dey          ; 2 (37)

  sta WSYNC

  ; 3rd scanline ========================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  DRAW_OBSTACLE               ; 13 (16)

  ; 28 (44)
  LOAD_DINO_P0_IF_IN_RANGE #SET_CARRY, _legs_and_floor__end_of_3rd_scanline
_legs_and_floor__end_of_3rd_scanline:

  lda BACKGROUND_COLOUR
  sta COLUPF
  lda FOREGROUND_COLOUR

  sec
  sta WSYNC

  ; 4th scanline ========================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)

  sta COLUBK                  ; 3 (6)
  lda FLOOR_PF0               ; 3 (9)
  sta PF0                     ; 3 (12)

  DRAW_DINO                   ; 3 (15)

  lda FLOOR_PF1               ; 3 (18)
  sta PF1                     ; 3 (21)

    ;--------------------------------------------------------------------------
    ; <...>: INLINING
    ;--------------------------------------------------------------------------
    ; Inline the LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE macro here so the playfield
    ; updates can happen in between at the right times 
    ;--------------------------------------------------------------------------
    CHECK_Y_WITHIN_OBSTACLE_IGNORING_CARRY          ; 7 (28)
    bcs _legs_3rd_scanline__obstacle_y_within_range ; 2/3 (30/31)
                              ; ↓
                              ; - (30)
    lda #0                    ; 2 (32)
    tax                       ; 2 (34)

  ; Update the playfield
  sta PF0                     ; 3 (37)
  sta PF1                     ; 3 (40)

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; In case ROM is needed, the padding instructions, that make this branch 
    ; have the same CPU cycle count as the other branch, could be removed
    ;--------------------------------------------------------------------------
    pha                       ; 3 (43) - Wait/waste 9 CPU cycles so this
    pla                       ; 4 (47)   branch has the same count as the
    nop                       ; 2 (49)   other main branch
    ;--------------------------------------------------------------------------

    sta HMCLR                 ; 3 (52)
    jmp _legs_and_floor__end_of_4th_scanline ; 3 (55)

_legs_3rd_scanline__obstacle_y_within_range: ; - (31)

  ; Update the playfield
  lda #0                      ; 2 (33)
  sta PF0                     ; 3 (36)
  sta PF1                     ; 3 (39)

    ;--------------------------------------------------------------------------
    ; <...>: INLINING
    ;--------------------------------------------------------------------------
    ; ... continue the inlining of the macro
    ;--------------------------------------------------------------------------
    sta HMCLR                            ; 3 (42)
    LAX (PTR_OBSTACLE_SPRITE),y          ; 5 (47)
    lda (PTR_OBSTACLE_MISSILE_1_CONF),y  ; 5 (52)
    sta HMM1                             ; 3 (55)

_legs_and_floor__end_of_4th_scanline:
  dey                         ; 2 (57)
  sec                         ; 2 (59)

ground_area_kernel:
  sta TEMP                    ; 3 (62, 41 if coming from this kernel)
  lda BACKGROUND_COLOUR       ; 3 (65, 44 if coming from this kernel)
  sta WSYNC                   ; 3 (68, 47 if coming from this kernel)

  ; 1st scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  sta COLUBK                  ; 3 (6)
  lda TEMP                    ; 3 (9)
  DRAW_OBSTACLE               ; 13 (22)

  ; 28 (50)
  LOAD_DINO_P0_IF_IN_RANGE #IGNORE_CARRY, _ground__end_of_1st_scanline
_ground__end_of_1st_scanline:
  sec                         ; 2 (52)
  sta WSYNC                   ; 3 (55)

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

  sta WSYNC                   ; 3 (57)
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
_overscan:
  lda INTIM
  bne _overscan
  ; We're on the final OVERSCAN line and 40 cpu cycles remain,
  ; do the jump now to consume some cycles and a WSYNC at the 
  ; beginning of the next frame to consume the rest

  inc FRAME_COUNT
  bne __skip_inc_frame_count_upper_byte
  inc FRAME_COUNT+1
__skip_inc_frame_count_upper_byte:

  jmp start_of_frame


;=============================================================================
; SUBROUTINES
;=============================================================================
  include "subroutines.asm"

;=============================================================================
; SPRITE GRAPHICS DATA
;=============================================================================
  include "sprites.asm"

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

;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
