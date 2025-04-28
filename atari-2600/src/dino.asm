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
INIT_DINO_TOP_Y = #INIT_DINO_POS_Y+#DINO_HEIGHT

SKY_SCANLINES = #31
CACTUS_SCANLINES = #30
FLOOR_SCANLINES = #2
GRAVEL_SCANLINES = #9

DINO_PLAY_AREA_SCANLINES = #SKY_SCANLINES+#CACTUS_SCANLINES+#FLOOR_SCANLINES+#GRAVEL_SCANLINES
SKY_MAX_Y = #DINO_PLAY_AREA_SCANLINES
SKY_MIN_Y = #SKY_MAX_Y-#SKY_SCANLINES
CACTUS_AREA_MAX_Y = #SKY_MIN_Y
CACTUS_AREA_MIN_Y = #CACTUS_AREA_MAX_Y-#CACTUS_SCANLINES
GROUND_AREA_MAX_Y = #CACTUS_AREA_MIN_Y-#FLOOR_SCANLINES
GROUND_AREA_MIN_Y = #GROUND_AREA_MAX_Y-#GRAVEL_SCANLINES

; Crouching Kernel Regions
; -----------------------------------------------------------------------------
; The crouching sprite is divided into two regions, measured in 2x scanlines:
;
; Region 1: 15 + 6 + 1 = 22 scanlines
; - The first 15 scanlines are empty (above the dino), spanning from the top of
;   the screen down to where the dino's head would be if standing. Only the
;   obstacle is drawn in this area.
; - The next 6 scanlines are also empty—these would normally include the dino's
;   head, but since it's crouching, only the obstacle is drawn here as well.
; - The last scanline in this region draws the top of the crouching dino's head.
;   It uses a 1x pixel sprite pattern and no missiles, which breaks the
;   optimization strategy used in Region 2. For this reason, it's included in
;   Region 1. This scanline also serves as a setup line for the next phase
;   of the kernel.
;
; Region 2: 8 scanlines
; - These scanlines make up the main body of the crouching dino.
; - They share a consistent sprite pattern, enabling several optimizations:
;   - GRP0 stays in a fixed position, avoiding HMM0 updates.
;   - NUSIZ0 remains unchanged (2x size).
;   - Both missiles will remain enabled, only updating offsets and sizes.
;
; The dino's legs are drawn by the "legs and floor" kernel,
; which runs immediately after Region 2.

CROUCHING_SCANLINES_REGION_1 = #15+#7
CROUCHING_SCANLINES_REGION_2 = #8
CROUCHING_SCANLINES = #CROUCHING_SCANLINES_REGION_1+#CROUCHING_SCANLINES_REGION_2

  ; Sanity Check
  ; ---------------------------------------------------------------------------
  ; The crouching and cactus kernels share the same screen region,
  ; so they must match in both vertical position and total scanline count.
  IF CROUCHING_SCANLINES != CACTUS_SCANLINES
    ECHO "Error: CROUCHING_SCANLINES must equal CACTUS_SCANLINES"
    ERR
  ENDIF

; Crouching area starts at the same location where the cactus area is at
CROUCHING_REGION_1_MAX_Y = #CACTUS_AREA_MAX_Y
CROUCHING_REGION_1_MIN_Y = #CROUCHING_REGION_1_MAX_Y-#CROUCHING_SCANLINES_REGION_1
CROUCHING_REGION_2_MAX_Y = #CROUCHING_REGION_1_MIN_Y
CROUCHING_REGION_2_MIN_Y = #CROUCHING_REGION_2_MAX_Y-#CROUCHING_SCANLINES_REGION_2
   ; For debugging:
   ;ECHO "CROUCHING_REGION_2_MAX_Y =",#CROUCHING_REGION_2_MAX_Y
   ;ECHO "DINO_CROUCHING_SPRITE_END =",#DINO_CROUCHING_SPRITE_END
DINO_JUMP_INIT_VY_INT = #5
DINO_JUMP_INIT_VY_FRACT = #40
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #98

PTERO_HEIGHT = #17
; To save a cycle per scanline, all the obstacles are to have the max obstacle
; height, it wastes some rom though
OBSTACLE_HEIGHT = #PTERO_HEIGHT

DEBUG_OBSTACLE_X_POS = #149

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

; Dino Sprite Variables
DINO_TOP_Y_INT             .byte   ; 1 byte   (1)
DINO_TOP_Y_FRACT           .byte   ; 1 byte   (2)
DINO_COLOUR                .byte   ; 1 byte   (3)
DINO_SPRITE                .byte   ; 1 byte   (4)
DINO_SPRITE_OFFSET         .byte   ; 1 byte   (5)
DINO_VY_INT                .byte   ; 1 byte   (6)
DINO_VY_FRACT              .byte   ; 1 byte   (7)
UP_PRESSED_FRAMES          .byte   ; 1 byte   (8)

PTR_DINO_SPRITE            .word   ; 2 bytes  (10)
PTR_DINO_OFFSET            .word   ; 2 bytes  (14)
PTR_DINO_MIS0              .word   ; 2 bytes  (18)

; Obstacle Variables
OBSTACLE_TYPE              .byte   ; 1 byte   (23)
OBSTACLE_Y                 .byte   ; 1 byte   (24)
OBSTACLE_X_INT             .byte   ; 1 byte   (25)
OBSTACLE_X_FRACT           .byte   ; 1 byte   (26)
OBSTACLE_VX_INT            .byte   ; 1 byte   (27)
OBSTACLE_VX_FRACT          .byte   ; 1 byte   (28)

PTR_OBSTACLE_SPRITE        .word   ; 2 bytes  (30)
PTR_OBSTACLE_OFFSET        .word   ; 2 bytes  (32)
PTR_OBSTACLE_BALL          .word   ; 2 bytes  (34)

; TIA Object Control
MISSILE_P0                 .byte   ; 1 byte   (35)
ENABLE_BALL                .byte   ; 1 byte   (37)
BG_COLOUR                  .byte   ; 1 byte   (38)

; Game State / Control
GAME_FLAGS                 .byte   ; 1 byte   (39)
FRAME_COUNT                .word   ; 2 bytes  (41)
RND_SEED                   .word   ; 2 bytes  (43)

; Kernel Pointer
PTR_MIDDLE_SECTION_KERNEL  .word   ; 2 bytes  (45)

; This section is to include variables that share the same memory but are 
; referenced under different names, something like temporary variables that 
; can be used differently by different kernels (which are only active one 
; at a time, leaving no risk of overlap)

; To save the state of a register temporarily during tight situations
TEMP                       .byte  ; 1 byte 

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
  sta DINO_COLOUR
  lda #BKG_LIGHT_GRAY
  sta BG_COLOUR

  lda #<[DINO_SPRITE_1 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE
  lda #>[DINO_SPRITE_1 - INIT_DINO_POS_Y]
  sta PTR_DINO_SPRITE+1

  lda #<[DINO_SPRITE1_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_OFFSET
  lda #>[DINO_SPRITE1_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_OFFSET+1

  lda #<[DINO_MIS_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_MIS0
  lda #>[DINO_MIS_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_MIS0+1

  ; TODO: Remove/Update after testing obstacle positioning
  lda #1
  sta OBSTACLE_TYPE
  lda #SKY_MAX_Y-#4
  sta OBSTACLE_Y
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT

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

  sta HMCLR             ; Clear horizontal motion registers

;==============================================================================
; BEGIN FRAME SETUP (VBLANK TIME)
;==============================================================================
start_frame_setup:
  lda #BKG_LIGHT_GRAY   ;
  sta COLUBK            ; Set initial background

  lda DINO_COLOUR       ; dino sprite colour
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
  inc UP_PRESSED_FRAMES
  bne _keep_checking_joystick_up  ; if up-counter > 255 then up-counter = 255
  lda #255
  sta UP_PRESSED_FRAMES

_keep_checking_joystick_up:
  lda UP_PRESSED_FRAMES
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
  ; if it's already crouching or jumping, ignore
  lda #FLAG_DINO_CROUCHING_OR_JUMPING
  bit GAME_FLAGS
  bne _reset_up_counter

  ora GAME_FLAGS ; A <- A | GAME_FLAGS  => #FLAG_DINO_CROUCHING | GAME_FLAGS
  sta GAME_FLAGS
  ;
  ; fall through to reset the up-counter
_reset_up_counter:
  lda #0
  sta UP_PRESSED_FRAMES

_end_check_joystick:

  lda #FLAG_SPLASH_SCREEN
  bit GAME_FLAGS
  beq in_grame_screen
  jmp in_splash_screen

; -----------------------------------------------------------------------------
; GAME SCREEN SETUP
; -----------------------------------------------------------------------------
in_grame_screen:

_update_obstacle:
_update_ptero_wing_anim:
  lda FRAME_COUNT
  and #%00001111
  cmp #7
  bcs _open_wings

  lda #<PTERO_WINGS_CLOSED_SPRITE_END
  ldy #>PTERO_WINGS_CLOSED_SPRITE_END
  ldx #PTR_OBSTACLE_SPRITE
  jsr set_obstacle_data

  lda #<PTERO_WINGS_CLOSED_BALL_END
  ldy #>PTERO_WINGS_CLOSED_BALL_END
  ldx #PTR_OBSTACLE_BALL
  jsr set_obstacle_data

  jmp _end_ptero_wing_anim
_open_wings:
  lda #<PTERO_WINGS_OPEN_SPRITE_END
  ldy #>PTERO_WINGS_OPEN_SPRITE_END
  ldx #PTR_OBSTACLE_SPRITE
  jsr set_obstacle_data

  lda #<PTERO_WINGS_OPEN_BALL_END
  ldy #>PTERO_WINGS_OPEN_BALL_END
  ldx #PTR_OBSTACLE_BALL
  jsr set_obstacle_data
_end_ptero_wing_anim:

  ; TODO update the obstacle speed to adjust dynamically based on obstacle
  ; type and difficulty
  lda #150 ; 
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
  cmp #1 ; -3
  beq _reset_obstacle_position
  jmp _check_if_dino_is_jumping

_reset_obstacle_position:
  lda #DEBUG_OBSTACLE_X_POS
  sta OBSTACLE_X_INT
  lda #0
  sta OBSTACLE_X_FRACT

_check_if_dino_is_jumping:
  lda #FLAG_DINO_JUMPING
  bit GAME_FLAGS
  bne _jumping

_check_if_dino_is_crouching:
  lda #FLAG_DINO_CROUCHING
  bit GAME_FLAGS
  bne _crouching

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

  ; if DINO_TOP_Y_INT >= DINO_INIT_Y then turn off jumping
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
  lda #<DINO_SPRITE1_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_OFFSET
  lda #>DINO_SPRITE1_OFFSETS_END
  sbc #0
  sta PTR_DINO_OFFSET+1

  sec
  lda #<DINO_MIS_OFFSETS_END
  sbc DINO_TOP_Y_INT
  sta PTR_DINO_MIS0
  lda #>DINO_MIS_OFFSETS_END
  sbc #0
  sta PTR_DINO_MIS0+1
  jmp _end_legs_anim

_crouching:


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
; GAME KERNEL
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
game_kernels:

score_setup_kernel:;---->>> 2 scanlines <<<----
  DEBUG_SUB_KERNEL #$10, #2

score_kernel:;---------->>> 10 scanlines <<<---
  DEBUG_SUB_KERNEL #$20,#10

clouds_kernel_setup:;-->>> 2 scanlines <<<-----
  DEBUG_SUB_KERNEL #$30,#2

clouds_kernel:;-------->>> 15 scanlines <<<----
  DEBUG_SUB_KERNEL #$4C,#15

dino_setup_kernel:;----->>> 5 scanlines <<<-----
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
             ;

_end_grp0_coarse_position:
  lda #$10         ; 2 (30/32) - In both cases, Player 0 has to be shifted
  sta HMP0         ; 3 (33/35) to the left by 1 pixel
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
  nop
  nop
  ; using the sbeq macro here as is super important to get the timing
  ; right in this section
  sbeq _dino_is_not_crouching_2 ; 2/3 (13/14)
                       ; - (13)
  inc $2D              ; 5 (18) - Wait 5 cycles, 2 bytes only

  sta RESM1            ; 3 (21)
  sta RESM0            ; 3 (24)
  jmp _end_m0_coarse_position  ; 3 (31)

_dino_is_not_crouching_2: ; - (14)
  INSERT_NOPS 2        ; 4 (18)

  sta RESM0            ; 3 (21)

_end_m0_coarse_position: ; (25/31)

  ; Do the obstacle's coarse positioning preparations on the remaining of
  ; M0's positioning scanline

_set_obstacle_position:
  sta HMCLR        ; 3 (35/41) Clear any previous HMMx

  clc                ; 2 (27/33) Clear the carry for the addition below
  lda OBSTACLE_X_INT ; 3 (30/36)

  ; TODO: Improve the explanation of the 37
  ; tia cycles = x + 68 - 9 - 9 - 12 
  ; 68 TIA colour cycles ~ 22.5 6507 CPU cycles from HBLANK to the start of 
  ; visible px in the screen, minus 9 TIA cycles (3 CPU cycles) from the
  ; 'sta HMOVE' needed at the start of the scanline 68 - 9 = 59. 12 TIA cycles 
  ; from the last 'divide by 15' iteration and 9 more for 'sta RESP1'
  ; this adds up to 38
  ; -2 shifts the fine offset range from [-8, 6] to [-6, 8]
  clc              ; 2 (32/38)
  adc #45          ; 2 (34/40) 

  sec              ; 2 (39/45) Set carry to do subtraction. Remember SBC is 
                   ;           actually an ADC with A2 complement
                   ;           A-B = A + ~B + 1 (<- this 1 is the carry you set)

  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline ==============================================================
                   ; - (0)

  sta HMOVE        ; 3 (3)
_div_by_15_loop:
  sbc #15                        ; 2 (5) Divide by 15 (sucessive subtractions)
  bcs _div_by_15_loop ; 2/3 (obstacle-x / 5 + 5)

  sta RESP1
  sta RESBL

  ; the fine adjustment offset will range between -7 to 7
  ; try the accompanying simulation.py script to confirm this
  sta WSYNC
  ; 4th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; Clear reg X to make sure no graphics are drawn in the first scanline of
  ; the sky_kernel
  ldx #0           ; 2 (5); do the fine offset in the next scanline, I'm avoiding doing it in the

  ; same scanline as the coarse positioning because for x > 150 the strobing
  ; will occur near the end of the scanline leaving barely room for strobing
  ; wsync
  INSERT_NOPS 9              ; 18 (23)
  ; Offsets the remainder from [-14, 0] to [0, 14]
  ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
  adc #15
  tay                         ; 2 (25)
  lda FINE_POSITION_OFFSET,y  ; 4 (29) - y should range between [-7, 7]
  ; Apply the fine offset to both the GRP1 and the BALL, these won't shift the
  ; coarse position set above until the next time HMOVE is strobed
  sta HMP1  ; 3 (32)
  sta HMBL  ; 3 (35)

  sta WSYNC                   ; 3 (38)

_last_setup_scanline:
  ; 5th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ldy #SKY_MAX_Y   ; 2 (5)

  ; Prefetch the IS_CROUCHING value to save 2 cycles doing the check
  lda #FLAG_DINO_CROUCHING   ; 2 (7)
  bit GAME_FLAGS             ; 3 (10)
  bne __assign_crouching_kernel  ; 2/3 (12/13)

  lda #<cactus_area_kernel        ; 2 (14)
  sta PTR_MIDDLE_SECTION_KERNEL   ; 3 (17)
  lda #>cactus_area_kernel        ; 2 (19)
  sta PTR_MIDDLE_SECTION_KERNEL+1 ; 3 (22)
  jmp __end_middle_section_kernel_setup ; 3 (25)

__assign_crouching_kernel:        ; - (13)
  lda  #<dino_crouching_kernel    ; 2 (15)
  sta PTR_MIDDLE_SECTION_KERNEL   ; 3 (18)
  lda  #>dino_crouching_kernel    ; 2 (20)
  sta PTR_MIDDLE_SECTION_KERNEL+1 ; 3 (23)
__end_middle_section_kernel_setup:

  ; TODO can remove this sec?
  sec              ; 2 (27/25) Set the carry ahead of time for the next scanline

  INSERT_NOPS 2    ; 4 (31/29) The usual "leave 24 cycles after HMOVE" shenanigan

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR        ; 3 (34/32) 

  lda #$78         ; for debugging purposes
  sta COLUBK       ;

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the BALL state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0
  tax

sky_kernel: ;------------------>>> 31 2x scanlines <<<--------------------
  sta WSYNC      ; 3 (37/35)
  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first then load dino's data for the next scanline
  DRAW_OBSTACLE  ; 11 (14)

  CHECK_Y_WITHIN_DINO            ; 9 (23)
  bcs _sky__y_within_dino        ; 2/3 (25/26)

_sky__y_not_within_dino:         ; - (25)
  lda #0                         ; 2 (27)  Disable the missile for P0
  tax                            ; 2 (29)  Good time to write to HMMx regs!!
  ; Remove HMP1 and HMBL fine offsets so they don't keep shifting the ptero
  ; in the second scanline. Doing HMCLR is fine because there won't be 
  ; fine offsets for the dino (we are in y_no_within_dino)
  sta HMCLR                      ; 3 (32)
  jmp _sky__end_of_1st_scanline  ; 3 (35)

_sky__y_within_dino:             ; - (26)
  ; --- Dino Missile Setup ---
  ; The data pointed to by PTR_DINO_MIS0 has the following bit layout:
  ;
  ; bit index: 7 6 5 4 3 2 1 0
  ;            \_____/ \_/ ↑
  ;             HMM0    │  │
  ;                     │  └── ENAM0
  ;                   NUSIZ0 (need to be shifted to the left twice)
  ;
  ; LAX (an undocumented/illegal opcode) loads the byte at (PTR_DINO_MIS0),Y
  ; into both A and X registers simultaneously. This gives us:
  ; - A: to extract and store the shifted NUSIZ0 value
  ; - X: a copy of the original byte for HMM0 and ENAM0 logic later
  ;
  LAX (PTR_DINO_MIS0),y  ; 5 (31) - Load config byte into A and X
  asl                    ; 2 (33)
  asl                    ; 2 (35)
  sta NUSIZ0             ; 3 (38)

  ; By now, 24+ CPU cycles have passed since the last HMOVE, meaning we can
  ; safely modify HMMx registers without triggering unwanted shifts.
  ; First, we use HMCLR to reset HMP1 and HMBL. It also clears all HMMx regs,
  ; which is fine — HMM0 and HMP0 are about to be updated anyway.
  sta HMCLR                    ; 3 (41) - Clear horizontal motion registers
  stx HMM0                     ; 3 (44) - Restore HMM0 from original byte

  ; X still holds the unmodified value loaded by LAX. This includes the ENAM0
  ; bit, which will be used later in the second scanline. So X can't be written
  ; to from this moment.

  ; dino graphics offset
  lda (PTR_DINO_OFFSET),y        ; 5 (49)
  sta HMP0                       ; 3 (52)

  ; dino graphics- leave them in reg A so they are ready to be used in the 2nd
  ; scanline, this implies not touching reg A for the rest of this scan line
  lda (PTR_DINO_SPRITE),y        ; 5 (57)

_sky__end_of_1st_scanline: ; - (39/57)
  sec                      ; 2 (41/59) - Set the carry for the sbc instruction
                           ; that will happen in the next scanline for the
                           ; Y-bounds check of the ptero
  sta WSYNC                ; 3 (44/62)

  ; 2nd scanline ==============================================================
                                 ; - (0)
  sta HMOVE                      ; 3 (3)
  sta GRP0                       ; 3 (6) - Dino sprite
  stx ENAM0                      ; 3 (9) - Toggle missile for dino extra detail
                                 ; in this scanline (if needed)

  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY,_sky__end_of_2nd_scanline ; 30 (39)

_sky__end_of_2nd_scanline:  ; - (39)

  ; Cactus/Crouching area very first scanline
  dey                       ; 2 (41)
  ; The +#1 bellow is because the carry will be set if Y ≥ SKY_MIN_Y,
  ; (both when Y > SKY_MIN_Y or Y == SKY_MIN_Y), we want to ignore
  ; the carry being set when Y == SKY_MIN_Y, that is, to turn this
  ; from Y ≥ C to Y > C. For that Y ≥ C + 1 ≡ Y > C.
  ; For example, x ≥ 4 ≡ x > 3  (for an integer x)
  cpy #SKY_MIN_Y+#1          ; 2 (43)
  bcs sky_kernel             ; 2/3 (45/46)
  ; On the last scanline of this area, and just before starting the next 
  ; scanline

_check_if_crouching:               ; - (45)
  jmp (PTR_MIDDLE_SECTION_KERNEL)  ; 5 (50)


dino_crouching_kernel: ;------------------>>> 31 2x scanlines <<<-----------------
; The crouching part is split into two regions:
; 1. Obstacles only: This region draws obstacles (either cacti or pterodactyl)
;    *without* the dino, following the same logic as in
;    'cactus_area_kernel.' It covers 15 + 7 = 22 double scanlines:
;    15 no-dino 2x scanlines from the top to where the dino's head would begin
;    when standing, plus 7 no-dino scanlines from the head to where the actual
;    crouching starts.
;
; 2. Dino head and body: This sub-kernel draws the dino's head and body, as 
;    well as the obstacles:
;
;                               ██████ 
;                 ░  ▓▓▓▓▓▓▓▓  ██ █████
;                 ░░░░░XXX▓▓▓▓▓████████
;                 ░░░░░XXX▓▓▓▓▓████████
;                  ░░░░XXXX▓▓▓▓████████
;                  ░░░░XXXX▓▓▓▓████    
;                   ░░XXXXXX▓▓  █████  
;                   ███ ██   ▓▓
;
; The rest of the dino (the legs) will be drawn by the floor kernel, as their
; graphics match the same position as the dino when standing:
;                  |██   ██ |
;                  |█       |
;                  |██      |
;

_crouching_region_1:
  sta WSYNC        ; 3 (from sky_kernel: 62 -> 65)
                   ;   (from this kernel: 70 -> 73)
  ; 1st scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  DRAW_OBSTACLE    ; 11 (14)

  lda #0           ; 2 (16) - Clear reg A in case this is not the last scanline
                   ; this will then leave the dino empty in the next scanline

  ; Check if this is the last scanline of the first region
  cpy #CROUCHING_REGION_1_MIN_Y       ; 2 (18)
  bne _region_1__end_of_1st_scanline  ; 2/3 (20/21)

  ; Final scanline of Region 1:
  ; The next scanline will draw the top of the crouching dino's head.
  ; GRP0 and sprite data must be prepared in advance.
                  ; - (20)
  lda #%00000101  ; 2 (22) - Configure GRP0 for 2-pixel width (2x size)
  sta NUSIZ0      ; 3 (25)
  lda #%00001111  ; 2 (27) - Sprite pattern for the top of the crouching dino's head
  ;
  ;         ________████████  <-- this will be drawn in the next scanline
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒     '██' are the non-empty 2px GRP0 pixels
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒      and '__' are the 2px GRP0 spaces
  ;                                (1 and 0 respectively)

_region_1__end_of_1st_scanline: ; - (max count up to here is 30)
  ; Remove HMP1 and HMBL fine offsets so they don't keep shifting the obstacle
  ; in the second scanline
  sta HMCLR        ; 3 (30)
  sec              ; 2 (32)

  sta WSYNC        ; 3 (35)
  ; 2nd scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  sta GRP0         ; 3 (6) - Draw the dino's top of the head (if this is the
                   ; last scanline

  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY,_region_1__end_of_2nd_scanline ; 30 (36)

_region_1__end_of_2nd_scanline:  ; - (max count: 36)

  ; Check if this is the last scanline of the first region
  cpy #CROUCHING_REGION_1_MIN_Y       ; 2 (38)
  bne _region_1__check_end_of_region  ; 2/3 (max count here 38 -> 40/41)
  ; If this is the last scanline of this region, some preparation needs to be
  ; done for the next region, first save reg A in the stack to keep
  ; the graphics for the obstacle that need to be drawn in the first scanline
  ; of the region 2
  sta TEMP        ; 3 (41 -> 44)

  lda #$F5        ; 2 (46)
  sta HMP0        ; 3 (49) - Move the dino's sprite back 1px
  sta NUSIZ0      ; 3 (52) - Set M0 size to 8px while keeping P0 at 2x size

  lda #2          ; 2 (54) - Enable both missiles
  sta ENAM0       ; 3 (57)
  sta ENAM1       ; 3 (60)

  lda TEMP        ; 3 (63) - Restores the obstacle sprite in reg A

_region_1__check_end_of_region:         ; - (max possible count here is 63)
  dey                                   ; 2 (65)
  cpy #CROUCHING_REGION_1_MIN_Y         ; 2 (67)
  bpl _crouching_region_1               ; 2/3 (69/70)

_crouching_region_2:
  ; If the crouching region 1 is complete, then the crouching region 2 
  ; is next, which spans for 7 scanlines
  sta WSYNC                             ; 3 (72)

  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first, then load the dino's crouching data to draw
  ; son the next canline
  DRAW_OBSTACLE  ; 11 (14)

  lda #0         ; 2 (16)
  sta NUSIZ1     ; 3 (19)

  lda DINO_CROUCHING_MIS_0_END-#CROUCHING_REGION_2_MAX_Y,y ; 4 (18)
  sta HMM0      ; 3 (21)

  lda DINO_CROUCHING_SPRITE_END-#CROUCHING_REGION_2_MAX_Y,y ; 4 (18)

  sta HMCLR
  sta WSYNC                   ; 3 (57)

  ; 2nd scanline ==============================================================
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  sta GRP0                  ; 3 (6) - Draw the dino sprite

  ; After this macro, both reg A and X can't be changed, as they contain the
  ; obstacle sprite data
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY,_region_2_end_of_2nd_scanline ; 32 (38)

_region_2_end_of_2nd_scanline:
  ; Clear fine offsets to avoid shifting the dino sprite and missiles again
  sta HMCLR

  dey                                   ; 2
  cpy #CROUCHING_REGION_2_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_2               ; 2/3


  sta TEMP
  lda #0         ; 2 (16)
  sta NUSIZ1     ; 3 (19)
  lda TEMP

  jmp legs_and_floor_kernel

cactus_area_kernel: ;-------------->>> 31 2x scanlines <<<-----------------
  sta WSYNC                 ; 3 (from sky_kernel: 62 -> 65)

  ; 1st scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)

  lda #$BA
  sta COLUBK

  CHECK_Y_WITHIN_DINO         ; 9 (12)
  bcs _cactus__y_within_dino  ; 2/3 (14 / 15)

_cactus__y_not_within_dino:
  lda #0                              ; 3 (17)  Disable the missile for P0
  sta DINO_SPRITE                     ; 3 (20)
  sta DINO_SPRITE_OFFSET              ; 3 (23)
  sta MISSILE_P0                       ; 3 (26)
  jmp _cactus__end_of_1st_scanline    ; 3 (29)

_cactus__y_within_dino:
  ; graphics
  LAX (PTR_DINO_SPRITE),y               ; 5+ (20) LAX undocumented opcode
  sta DINO_SPRITE                       ; 3  (23)

  ; graphics offset
  lda (PTR_DINO_OFFSET),y               ; 5+ (28)
  sta HMP0                              ; 3  (31)

  ; missile
  lda (PTR_DINO_MIS0),y                  ; 5+ (36)
  DECODE_MISSILE_PLAYER 0        ; 13

_cactus__end_of_1st_scanline:
  sta WSYNC                             ; 3

  ; 2nd scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  lda DINO_SPRITE             ; 3
  ;lda #0                     ; for debugging, hides GRP0
  sta GRP0                    ; 3
  lda MISSILE_P0              ; 3
  sta ENAM0                   ; 3
  INSERT_NOPS 10              ; 20
  sta HMCLR                   ; 3

  dey                                   ; 2 (5)
  cpy #CACTUS_AREA_MIN_Y+#1             ; 2 (7) - +1 turns Y ≥ C into Y > C
  bcs cactus_area_kernel            ; 2/3 (9 / 10)

legs_and_floor_kernel:

  lda #47                              ; 2 (11)
  sta COLUBK                            ; 3 (14)

  ; If dino was crouching, we need to offset GPR0 2 pixels to the left 
  ; otherwise the HMP0 offset won't match with the legs
  lda #FLAG_DINO_CROUCHING
  bit GAME_FLAGS
  beq _scanline1_dino_is_not_crouching
  ;lda #$20
  ;sta HMP0

  sta WSYNC
  sta HMOVE
  jmp _scanline1_dino_is_crouching

_scanline1_dino_is_not_crouching:
  sta WSYNC                             ; 3

  ;============================================================================
  ; 1st DOUBLE SCANLINE
  ;============================================================================
  ; 1st scanline (SETUP) ========================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)

  CHECK_Y_WITHIN_DINO         ; 9 (12)

  bcs _scanline1__y_within_dino  ; 2/3 (14/15)

_scanline1__y_not_within_dino:
  lda #0                         ; 2 (16)
  sta DINO_SPRITE                ; 3 (19)
  sta DINO_SPRITE_OFFSET         ; 3 (21)
  jmp _scanline1__end_of_setup   ; 3 (24)

_scanline1__y_within_dino:
  lda (PTR_DINO_OFFSET),y        ; 5 (28)
  sta DINO_SPRITE_OFFSET         ; 3 (31)

_scanline1_dino_is_crouching:
  ; graphics
  lda (PTR_DINO_SPRITE),y        ; 5 (20)
  sta DINO_SPRITE                ; 3 (23)

_scanline1__end_of_setup:
  sta WSYNC

  ; 2nd scanline (DRAWING) ========================================================
                              ; - (0)
  lda #0
  sta ENAM0

  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3

  INSERT_NOPS 12                        ; 24

  lda DINO_SPRITE_OFFSET
  sta HMP0

  dey


  lda #77                              ; 2 (11)
  sta COLUBK                            ; 3 (14)
  sta WSYNC
  ;============================================================================
  ; 2nd DOUBLE SCANLINE
  ;============================================================================
  ; 1st scanline (SETUP) ========================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  CHECK_Y_WITHIN_DINO         ; 9 (12)

  bcs _scanline2__y_within_dino   ; 2/3

_scanline2__y_not_within_dino:
  lda #0                          ; 3   Disable the misSile for P0
  sta DINO_SPRITE                 ; 3
  sta DINO_SPRITE_OFFSET
  jmp _scanline2__end_of_setup ; 3

_scanline2__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+
  sta DINO_SPRITE                       ; 3

  lda (PTR_DINO_OFFSET),y
  lda DINO_SPRITE_OFFSET

  INSERT_NOPS 12                        ; 24
  sta HMP0

  sta WSYNC

_scanline2__end_of_setup:
  ; 2nd scanline (DRAWING) ========================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)

  lda DINO_COLOUR
  sta COLUPF
  lda #%01110000
  sta PF0

  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  ;sta GRP0                              ; 3

  lda #%00011111
  sta PF1

  lda #255
  sta PF2

  ; Experimenting changing background color instead of playfield
;lda DINO_COLOUR
;  sta COLUBK
;ldx BG_COLOUR
;  lda DINO_COLOUR
;  stx COLUBK
;  sta COLUBK

  INSERT_NOPS 12                        ; 24
  sta HMCLR

  dey

ground_area_kernel:
  sta WSYNC                             ; 3
  ; 1st scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  nop

  lda BG_COLOUR
  sta COLUBK

  lda #0
  sta PF0
  sta PF1
  sta PF2
  sta ENAM0

  CHECK_Y_WITHIN_DINO
  bcs _ground__y_within_dino                   ; 2/3

_ground__y_not_within_dino:
  lda #0                                ; 3   Disable the misSile for P0
  sta DINO_SPRITE                       ; 3
  sta DINO_SPRITE_OFFSET
  jmp _ground__end_of_1st_scanline     ; 3

_ground__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+
  sta DINO_SPRITE                       ; 3

  ; graphics offset
  lda (PTR_DINO_OFFSET),y               ; 5+
  sta HMP0                              ; 3


_ground__end_of_1st_scanline:
  sta WSYNC                             ; 3

  ; 2nd scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  INSERT_NOPS 10                        ; 20
  sta HMCLR

  dey                                   ; 2
  cpy #GROUND_AREA_MIN_Y+#1             ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs ground_area_kernel           ; 2/3

  sta WSYNC                             ; 3
  sta HMOVE


void_area_kernel:
  DEBUG_SUB_KERNEL #$FA,#14
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

_splash__dino_kernel_setup: ;------------->>> 32 2x scanlines <<<------------------G
  lda BG_COLOUR    ; 3
  sta COLUBK       ; 3

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
  INSERT_NOPS 5                        ; 10 add some 'distance' between the last
                                       ; sta HMOVE (has to be 24+ cycles)
  lda DINO_SPRITE_1-#1,y               ; 4
  sta DINO_SPRITE                      ; 3
  lda DINO_MIS_OFFSETS-#1,y            ; 4

  ; missile
  sta MISSILE_P0                        ; 3
  sta HMM0                             ; 3
  asl                                  ; 2
  asl                                  ; 2
  sta NUSIZ0                           ; 3

  lda DINO_SPRITE1_OFFSETS-#1,y        ; 4
  sta HMP0                             ; 3

  ;sta HMBL

  sta WSYNC                            ; 3
  sta HMOVE                            ; 3

  ; 2nd scanline ==============================================================
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISSILE_P0                         ; 3
  sta ENAM0                             ; 3
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
