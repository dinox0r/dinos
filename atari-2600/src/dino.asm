  PROCESSOR 6502

  INCLUDE "../lib/vcs.h"
  ; Including this just for the sbcs, sbeq, etc macros, that look like 
  ; the branching instructions but add a page boundary check
  INCLUDE "../lib/macro.h"

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

BKG_LIGHT_GRAY = #13
DINO_HEIGHT = #20
INIT_DINO_POS_Y = #8
INIT_DINO_TOP_Y = #INIT_DINO_POS_Y+#DINO_HEIGHT

SKY_LINES = #31
CACTUS_LINES = #30
FLOOR_LINES = #2
GROUND_LINES = #9

DINO_PLAY_AREA_LINES = #SKY_LINES+#CACTUS_LINES+#FLOOR_LINES+#GROUND_LINES
SKY_MAX_Y = #DINO_PLAY_AREA_LINES
SKY_MIN_Y = #SKY_MAX_Y-#SKY_LINES
CACTUS_AREA_MAX_Y = #SKY_MIN_Y
CACTUS_AREA_MIN_Y = #CACTUS_AREA_MAX_Y-#CACTUS_LINES
GROUND_AREA_MAX_Y = #CACTUS_AREA_MIN_Y-#FLOOR_LINES
GROUND_AREA_MIN_Y = #GROUND_AREA_MAX_Y-#GROUND_LINES

; The 1st region of the crouching area covers 15 + 7 = 22 double scanlines:
; 15 empty 2x scanlines from the top to where the dino's head would be when
; standing, plus an additional 7 scanlines without the dino, since is now
; crouching. The 2nd region is 8 2x scanlines, because the dino crouching
; sprite spans 8 scanlines without the legs (which are drawn by the legs
; and floor kernel)
CROUCHING_LINES_REGION_1 = #15+#7
CROUCHING_LINES_REGION_2 = #8
CROUCHING_LINES = #CROUCHING_LINES_REGION_1+#CROUCHING_LINES_REGION_2

  ; The crouching kernel and the cactus kernel cover the same area of
  ; the screen, hence they have to have the same Y position and height
  IF CROUCHING_LINES != CACTUS_LINES
    ECHO "Error: CROUCHING_LINES should be equal to CACTUS_LINES"
    ERR
  ENDIF

; Crouching area starts at the same location where the cactus area is at
CROUCHING_REGION_1_MAX_Y = #CACTUS_AREA_MAX_Y
CROUCHING_REGION_1_MIN_Y = #CROUCHING_REGION_1_MAX_Y-#CROUCHING_LINES_REGION_1
CROUCHING_REGION_1_MIN_Y = #CROUCHING_REGION_1_MAX_Y-#CROUCHING_LINES_REGION_1
CROUCHING_REGION_2_MAX_Y = #CROUCHING_REGION_1_MIN_Y
CROUCHING_REGION_2_MIN_Y = #CROUCHING_REGION_2_MAX_Y-#CROUCHING_LINES_REGION_2


DINO_JUMP_INIT_VY_INT = #5
DINO_JUMP_INIT_VY_FRACT = #40
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #98

PTERO_HEIGHT = #17

DEBUG_OBSTACLE_X_POS = #157

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

DINO_TOP_Y_INT       .byte   ; 1 byte   (1)
DINO_TOP_Y_FRACT     .byte   ; 1 byte   (2)
BG_COLOUR            .byte   ; 1 byte   (3)
DINO_COLOUR          .byte   ; 1 byte   (4)
DINO_SPRITE          .byte   ; 1 byte   (5)
DINO_SPRITE_OFFSET   .byte   ; 1 byte   (6)
MISSILE_P0            .byte   ; 1 byte   (7)
MISSILE_P1            .byte   ; 1 byte   (7)
ENABLE_BALL          .byte   ; 1 byte
GAME_FLAGS           .byte   ; 1 byte   (8)
PTR_DINO_SPRITE      .word   ; 2 bytes  (10)
PTR_DINO_SPRITE_2    .word   ; 2 bytes  (12)
PTR_DINO_OFFSET      .word   ; 2 bytes  (14)
PTR_DINO_OFFSET_2    .word   ; 2 bytes  (16)
PTR_DINO_MIS0        .word   ; 2 bytes  (18)
PTR_DINO_MIS0_COPY   .word   ; 2 bytes  (20)
PTR_DINO_MIS1        .word   ; 2 bytes
RND_SEED             .word   ; 2 bytes  (22)
FRAME_COUNT          .word   ; 2 bytes  (23)
DINO_VY_INT          .byte   ; 1 byte   (24)
DINO_VY_FRACT        .byte   ; 1 byte   (25)
UP_PRESSED_FRAMES    .byte   ; 1 byte   (25)

OBSTACLE_TYPE        .byte
OBSTACLE_Y           .byte
OBSTACLE_X_INT       .byte   ; 1 byte
OBSTACLE_X_FRACT     .byte   ; 1 byte
OBSTACLE_VX_INT   .byte   ; 1 byte
OBSTACLE_VX_FRACT .byte   ; 1 byte

PTR_OBSTACLE_SPRITE  .word   ; 2 bytes
PTR_OBSTACLE_OFFSET  .word   ; 2 bytes
PTR_OBSTACLE_BALL    .word   ; 2 bytes

PTR_MIDDLE_SECTION_KERNEL .word  ; 2 bytes


; This section is to include variables for performance, to save cycles in tight 
; spots. They could potentially be reused under different names by using a new
; declaration (maybe use new ORG $something that directly points to the offset
; of this variable to assign a new name)

;DINO_IS_CROUCHING         .byte   ; 1 byte (performance variable, to save 2
                                  ; cycles in sky_kernel and others)

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
  tay     ; Y = A = X = 0
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

  lda #<PTERO_WINGS_CLOSED_SPRITE_OFFSETS_END
  ldy #>PTERO_WINGS_CLOSED_SPRITE_OFFSETS_END
  ldx #PTR_OBSTACLE_OFFSET
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

  lda #<PTERO_WINGS_OPEN_SPRITE_OFFSETS_END
  ldy #>PTERO_WINGS_OPEN_SPRITE_OFFSETS_END
  ldx #PTR_OBSTACLE_OFFSET
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
  lda #<[DINO_CROUCHING_SPRITE - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_SPRITE_2
  lda #>[DINO_CROUCHING_SPRITE - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_SPRITE_2+1

  lda #<[DINO_CROUCHING_SPRITE_OFFSETS - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_OFFSET_2
  lda #>[DINO_CROUCHING_SPRITE_OFFSETS - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_OFFSET_2+1

  lda #<[DINO_CROUCHING_MISSILE_0 - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS0_COPY
  lda #>[DINO_CROUCHING_MISSILE_0 - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS0_COPY+1

  lda #<[DINO_CROUCHING_MISSILE_1 - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS1
  lda #>[DINO_CROUCHING_MISSILE_1 - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS1+1


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

sky_setup_kernel:;----->>> 5 scanlines <<<-----
  ; From the DEBUG_SUB_KERNEL macro:
  ;  sta HMOVE   3 cycles (3 so far in this scanline)
  ;  bne .loop   not taken, so 2 cycles (5)

  sta WSYNC     ; 3 (8)

  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)

  ; Set GRP0 coarse position
  ;
  ; TODO: These instructions could be replaced by something more useful
  INSERT_NOPS 11   ; 22 (25)

  sta RESP0        ; 3 (28) TV beam should now be at a dino coarse x pos
  sta WSYNC        ; 3 (31)

  ; 2nd scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; Maybe a more useful instruction here? We need this 3 cycles so 
  ; the numbers below add up (don't think of strobing HMCLR, remember that
  ; you can't touch HMMx registers 24 cyles after strobing HMOVE
  sta COLUBK       ; 3 (6)

  ; Set M0 coarse position
  ;
  ; If dino is crouching, M0 needs to be in the same exact position as GRP0
  ; that is, M0 needs to be strobed at cycle 25. Otherwise, M0 needs to be
  ; strobed at cycle 22
  lda #FLAG_DINO_CROUCHING   ; 2 (8)
  bit GAME_FLAGS             ; 3 (11)
  ; this nop shifts the _dino_is_not_crouching
  ; label so it doesn't cross page boundary
  nop
  nop
  ; using the sbeq macro here as is super important to get the timing
  ; right in this section
  sbeq _dino_is_not_crouching ; 2/3 (13/14)
                       ; - (13)
  INSERT_NOPS 1        ; 6 (19)

  lda COLUBK           ; 3 (22)
  sta RESM1            ; 3 (25)
  sta RESM0            ; 3 (28) <-- same place as GRP0
  jmp _end_m0_coarse_position  ; 3 (31)

_dino_is_not_crouching: ; - (14)
  INSERT_NOPS 2        ; 8 (22)

  sta RESM0            ; 3 (25) <-- 3 cycles before GRP0

_end_m0_coarse_position: ; (25/31)

  ; Do the obstacle's coarse positioning preparations on the remaining of
  ; M0's positioning scanline

_set_obstacle_position:
  sta HMCLR        ; 3 (35/41) Clear any previous HMMx

  clc                ; 2 (27/33) Clear the carry for the addition below
  lda OBSTACLE_X_INT ; 3 (30/36)

  cmp #8
  bcs _set_obstacle_x_pos_over_8_or_equal

_set_obstacle_x_pos_under_8:
  sta WSYNC

  ; 3rd scanline ==============================================================
  sta HMOVE ; 3 (3)
  ; wait 23 cycles
  dec $2D   ; 5 (8)   2 bytes / 2
  dec $2D   ; 5 (13)  2 bytes / 4
  dec $2D   ; 5 (13)  2 bytes / 4
  ;php       ; 3 (16)  1 byte  / 5
  ;plp       ; 4 (20)  1 byte  / 6
  nop       ; 2 (22)
  nop       ; 2 (22)
  sta RESP1  ; 3 (26)
  sta RESBL  ; 3 (29)
  ; now hit HMOVE with the most possible amount to the left in this scanline
  ;lda #0
  lda #$70
  sta HMP1
  sta HMBL

  sta WSYNC

  ; 4th scanline ==============================================================
  sta HMOVE             ; 3 (3)
  ; we have x < 8, 
  ; 7 hmove -1 -> $10
  ; 6 hmove -2 -> $20
  ; 5 -3
  ; 4 -4
  ; 3 -5
  ; 2 -6
  ; 1 -7
  ; 0  X
  ; wait 24 cycles to hit
  ; in the next scanline, we now move 
  lda #8                ; 2 (5)
  sec                   ; 2 (7)
  sbc OBSTACLE_X_INT    ; 3 (9)
  asl                   ; 2 (11)
  asl                   ; 2 (13)
  asl                   ; 2 (15)
  asl                   ; 2 (17)
  php                   ; 3 (20)
  plp                   ; 4 (24)
  sta $2D               ; 3 (27)
  sta $2D               ; 3 (27)
  lda #$70
  sta HMP1              ; 3 ()
  sta HMBL              ; 3 ()

  sta WSYNC

  jmp _last_setup_scanline

_set_obstacle_x_pos_over_8_or_equal:
  ; TODO: Improve the explanation of the 37
  ; tia cycles = x + 68 - 9 - 9 - 12 
  ; 68 TIA colour cycles ~ 22.5 6507 CPU cycles from HBLANK to the start of 
  ; visible px in the screen, minus 9 TIA cycles (3 CPU cycles) from the
  ; 'sta HMOVE' needed at the start of the scanline 68 - 9 = 59. 12 TIA cycles 
  ; from the last 'divide by 15' iteration and 9 more for 'sta RESP1'
  ; this adds up to 38
  ; -2 shifts the fine offset range from [-8, 6] to [-6, 8]
  adc #36          ; 2 (32/38) 

  sec              ; 2 (37/43) Set carry to do subtraction. Remember SBC is 
                   ;           actually an ADC with A2 complement
                   ;           A-B = A + ~B + 1 (<- this 1 is the carry you set)

  sta WSYNC        ; 3 (40/46)
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

  ; TODO can remove this sec
  sec              ; 2 (27/25) Set the carry ahead of time for the next scanline

  INSERT_NOPS 2    ; 4 (31/29) The usual "leave 24 cycles after HMOVE" shenanigan

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR        ; 3 (34/32) 

  lda #$20
  sta HMP1
  sta HMBL


  lda #$78         ; for debugging purposes
  sta COLUBK       ;

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the BALL state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0
  tax

sky_kernel: ;------------------>>> 31 2x scanlines <<<--------------------

  sta WSYNC        ; 3 (37/35)

  ; 1st scanline ==============================================================
            ; - (0)
  sta HMOVE ; 3 (3)

  ; Draw the obstacle first
  sta CTRLPF                     ; 3 (6)
  lsr                            ; 2 (8)
  sta ENABL                      ; 3 (11)
  stx GRP1                       ; 3 (14)

  ; CHECK_Y_WITHIN_DINO takes 9 cycles
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
  ; dino missile
  ; the data pointed by PTR_DINO_MIS0 has the following format:
  ; bit index: 7 6 5 4 3 2 1 0
  ;            \-----/ \-/ ^
  ;             HMM0    |  |
  ;                     |  +-- ENAM0
  ;                   NUSIZ0 (need to be shifted to the left twice)
  LAX (PTR_DINO_MIS0),y          ; 5 (31)
  asl                            ; 2 (33)
  asl                            ; 2 (35)
  sta NUSIZ0                     ; 3 (38)
  ; thanks to LAX, reg X will have a copy of the data encoded in *PTR_DINO_MIS0
  ; which means prior to shifting, hence the HMM0 can be applied, and at this
  ; point, more than 24 CPU cycles had passed since 'sta HMOVE', which means 
  ; HMMx registers can be written to without side effects. First is to clear
  ; the HMP1 and HMBL registers in one go using HMCLR, which also clears the 
  ; other HMMx registers but is fine because from this point, the fine offsets
  ; for the dino are written to HMM0 and HMP0
  sta HMCLR                      ; 3 (41)
  stx HMM0                       ; 3 (44)
  ; Also thanks to the above's LAX instruction, reg X will contain the orignal
  ; ENAM0 state which will be kept until the 2nd scanline. So no updates 
  ; reg X can happen from this moment

  ; dino graphics offset
  lda (PTR_DINO_OFFSET),y        ; 5 (49)
  sta HMP0                       ; 3 (52)

  ; dino graphics- leave them in reg A so they are ready to be used in the 2nd
  ; scanline, this implies not touching reg A for the rest of this scan line
  lda (PTR_DINO_SPRITE),y        ; 5 (57)

_sky__end_of_1st_scanline:       ; - (39/57)
  sec                            ; 2 (41/59) Set the carry for the sbc instruction
                                 ; that will happen in the next scanline for the
                                 ; Y-bounds check of the ptero
  sta WSYNC                      ; 3 (44/62)

  ; 2nd scanline ==============================================================
                                 ; - (0)
  sta HMOVE                      ; 3 (3)
  sta GRP0                       ; 3 (6)
  stx ENAM0                      ; 3 (9)

  ; 'sec' is invoked at the end of the 1st scanline (saving 2 cycles here)
  CHECK_Y_WITHIN_PTERO_IGNORING_CARRY  ; 7 (16)
  bcs _sky__y_within_ptero   ; 2/3 (18/19)
_sky__y_not_within_ptero:        ; - (18)
  lda #0                         ; 2 (20)
  tax                            ; 2 (22)
  nop                            ; 2 (24) needed to reach 24 cycles afte
  nop                            ; 2 (26) strobing HMOVE
  ; Remove HMP0 and HMM0 fine offsets so they don't keep shifting the dino
  ; when jumping back to the 1st scanline. Doing HMCLR is fine because there
  ; won't be fine offsets for the ptero (we are in y_not_within_ptero)
  sta HMCLR                      ; 3 (29)
  jmp _sky__end_of_2nd_scanline  ; 3 (32)

_sky__y_within_ptero:            ; - (19)
  ; ptero graphics offset
  lda (PTR_OBSTACLE_OFFSET),y    ; 5 (24)
  ; We still have to remove HMP0 and HMM0 fine offsets so they don't shift
  ; the dino again when jumping back to the 1st scanline, but the HMxx
  ; registers don’t play nice if you set them within 24 CPU cycles of strobing 
  ; HMOVE. At this point, enough time has passed to do this clearing, just 
  ; before setting the fine offsets for the ptero
  sta HMCLR                      ; 3 (27)
  sta HMP1                       ; 3 (30)

  ; ptero graphics
  LAX (PTR_OBSTACLE_SPRITE),y    ; 5 (55)
  ; Using an illegal opcode (LAX) which will leave a copy of A into X, I'm doing
  ; this here because there is no 'ldx (aa),y', the non illegal opcode option is
  ; is to do 'lda (aa),y' first and then 'tax' which will costs 7 cycles, but
  ; the illegal opcode only takes 5. 
  ; reg X will contain the ptero data, so
  ; next scanline we can do 'stx GRP1' provided we don't overwrite reg X

  ; ptero ball
  ; the data pointed by PTR_OBSTACLE_BALL has the same format as the dino's:
  ; bit index: 7 6 5 4 3 2 1 0
  ;            \-----/ \-/ ^
  ;             HMBL    |  |
  ;                     |  +-- ENABL
  ;                   CTRLPF (needs to be shifted to the left twice)
  ; ball
  lda (PTR_OBSTACLE_BALL),y      ; 5 (24)
  ; thanks to LAX, reg X will have a copy of the data encoded in
  ; (*PTR_OBSTACLE_BALL) which means is a copy of the data prior to shifting,
  ; hence the fine offsets for the ball can be applied.
  sta HMBL                       ; 3 (37)
  asl                            ; 2 (39)
  asl                            ; 2 (41)

_sky__end_of_2nd_scanline:  ; - (36/41)

  ; Cactus/Crouching area very first scanline
  dey                       ; 2 (38/57)
  ; The +#1 bellow is because the carry will be set if Y ≥ SKY_MIN_Y,
  ; (both when Y > SKY_MIN_Y or Y == SKY_MIN_Y), we want to ignore
  ; the carry being set when Y == SKY_MIN_Y, that is, to turn this
  ; from Y ≥ C to Y > C. For that Y ≥ C + 1 ≡ Y > C.
  ; For example, x ≥ 4 ≡ x > 3  (for an integer x)
  cpy #SKY_MIN_Y+#1          ; 2 (40/59)
  bcs sky_kernel             ; 2/3 (taken 43/57) (not taken 42/56)
  ; On the last scanline of this area, and just before starting the next 
  ; scanline

_check_if_crouching:         ; - (42/61)
  ; At this point, there are 2 counts, one comes from the Y coordinate not 
  ; being within the ptero bounds (50 or whatever, we have room and can 
  ; ignore for now), the other one comes from the Y coordinate being within
  ; the ptero bounds, and has 67)
  jmp (PTR_MIDDLE_SECTION_KERNEL)  ; 5 (42 -> 47, 61 -> 66)


dino_crouching_kernel: ;------------------>>> 31 2x scanlines <<<-----------------
; The crouching part is split into two regions:
; 1. Obstacles only: This region draws obstacles (either cacti or pterodactyl)
;    *without* the dino, following the same logic as in
;    'cactus_area_kernel.' It covers 15 + 7 = 22 double scanlines:
;    15 empty 2x scanlines from the top to where the dino'shead would be when
;    standing, plus an additional 7 scanlines since the dino is now crouching.
;
; 2. Dino head and body: This sub-kernel draws the dino's head and body, as 
;    well as the obstacles:
;
;                             GRP0 (8 pixels)
;                               /      \
;                              | ██████ |
;                 ░  ▓▓▓▓▓▓▓▓  |██ █████|   <-- missile set to size 8
;                 ░░░░░XXX▓▓▓▓▓|████████|   \
;                 ░░░░░XXX▓▓▓▓▓|████████|   |  Both the ball and missile are
;                  ░░░░XXXX▓▓▓▓|████████|    > set to size 8 in all these
;                  ░░░░XXXX▓▓▓▓|████    |   |  scanlines.
;                   ░░XXXXXX▓▓ | █████  |   /
;                  |███ ██  |▓▓   <-- missile set to size 2
;                   \      /
;                  GRP0 (8 pixels)
;
; The rest of the dino (the legs) will be drawn by the floor kernel, as they
; match the same position as the dino when standing:
;                  |██   ██ |
;                  |█       |
;                  |██      |
;
; Legend:    ▒ missile pixels    █ GRP0 pixels    X overlapping pixels

_crouching_region_1:
  sta WSYNC                 ; 3 (from sky_kernel: 62 -> 65)
  ; 1st scanline ==============================================================
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  ; TODO: Copy the obstacle drawing code from the catus kernel here

  sta WSYNC                 ; 3 (3)

  ; 2nd scanline ==============================================================
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  ; TODO: Copy the obstacle drawing code from the catus kernel here

  dey                                   ; 2
  cpy #CROUCHING_REGION_1_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_1               ; 2/3

_crouching_region_2:
  sta WSYNC                 ; 3 (3)
  ; 1st scanline ==============================================================
  ; TODO: Copy the obstacle drawing code from the catus kernel here
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  lda (PTR_DINO_SPRITE_2),y           ; 5 (8)
  sta DINO_SPRITE                     ; 3 (11)

  lda (PTR_DINO_OFFSET_2),y           ; 5 (16)
  sta HMP0                            ; 3 (19)

  lda (PTR_DINO_MIS0_COPY),y              ; 5 (24)
  DECODE_MISSILE_PLAYER 0             ; 13 (37)

  lda (PTR_DINO_MIS1),y               ; 5 (42)
  DECODE_MISSILE_PLAYER 1             ; 13 

  sta WSYNC                           ; 3 (57)

  ; 2nd scanline ==============================================================
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  lda MISSILE_P1
  sta ENAM1
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISSILE_P0                         ; 3
  sta ENAM0                             ; 3
  INSERT_NOPS 10                        ; 20

  sta HMCLR


  dey                                   ; 2
  cpy #CROUCHING_REGION_2_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_2               ; 2/3


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

  lda #%00111111
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
