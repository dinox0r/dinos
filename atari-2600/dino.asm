  PROCESSOR 6502

  INCLUDE "vcs.h"

  LIST ON           ; turn on program listing, for debugging on Stella

;=============================================================================
; MACROS
;=============================================================================

  MAC DEBUG_SUB_KERNEL
.BGCOLOR SET {1}
.KERNEL_LINES SET {2}
    lda #.BGCOLOR
    sta COLUBK
    ldx #.KERNEL_LINES
.loop:
    dex
    sta WSYNC
    sta HMOVE
    bne .loop
  ENDM

  MAC LOAD_ADDRESS_TO_PTR
.ADDRESS SET {1}
.POINTER SET {2}
    lda #<.ADDRESS
    sta .POINTER
    lda #>.ADDRESS
    sta .POINTER+1
  ENDM

  MAC INSERT_NOPS  ; insert N nops
.NUM_NOPS SET {1}
    REPEAT .NUM_NOPS
      nop
    REPEND
  ENDM

  MAC DECODE_MISSILE_OFFSET_AND_SIZE ; 13 cycles
    sta MISILE_P0       ; 3 (3)
    sta HMM0            ; 3 (6)
    asl                 ; 2 (8)
    asl                 ; 2 (10)
    sta NUSIZ0          ; 3 (13)
  ENDM

  MAC CHECK_Y_WITHIN_DINO       ; 9 cycles
    tya                         ; 2 (2) A = current scanline (Y)
    sec                         ; 2 (2)
    sbc DINO_TOP_Y_INT          ; 3 (3) A = X - DINO_TOP_Y_INT
    adc #DINO_HEIGHT            ; 2 (2)
  ENDM

;=============================================================================
; SUBROUTINES
;=============================================================================


;=============================================================================
; CONSTANTS
;=============================================================================
RND_MEM_LOC_1 = $c1   ; "random" memory locations to sample the upper/lower
RND_MEM_LOC_2 = $e5   ; bytes when the machine starts. Hopefully this finds
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
SKY_MAX_Y = #DINbO_PLAY_AREA_LINES
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

  IF CROUCHING_LINES != CACTUS_LINES
    ECHO "Error: CROUCHING_LINES should be equal to CACTUS_LINES"
    ERR
  ENDIF

; Crouching area starts at the same location where the cactus area is
CROUCHING_REGION_1_MAX_Y = #CACTUS_AREA_MAX_Y
CROUCHING_REGION_1_MIN_Y = #CROUCHING_REGION_1_MAX_Y-#CROUCHING_LINES_REGION_1
CROUCHING_REGION_2_MAX_Y = #CROUCHING_REGION_1_MIN_Y
CROUCHING_REGION_2_MIN_Y = #CROUCHING_REGION_2_MAX_Y-#CROUCHING_LINES_REGION_2


DINO_JUMP_INIT_VY_INT = #5
DINO_JUMP_INIT_VY_FRACT = #40
DINO_JUMP_ACCEL_INT = #0
DINO_JUMP_ACCEL_FRACT = #98

;=============================================================================
; GAME_FLAGS
;=============================================================================
; bit 0: 1 -> splash screen mode / 0 -> game mode
; bit 1: in game mode dino left/right leg up sprite
; bit 2: in game mode dino jumping ON / OFF
; bit 4: in game mode dino crouching ON / OFF
; bit 7: in splash screen mode, dino blinking ON / OFF
FLAG_DINO_BLINKING =  #%10000000
FLAG_DINO_LEFT_LEG =  #%00000010
FLAG_DINO_JUMPING =   #%00000100
FLAG_SPLASH_SCREEN =  #%00000001
FLAG_DINO_CROUCHING = #%00010000

FLAG_DINO_CROUCHING_OR_JUMPING = FLAG_DINO_CROUCHING | FLAG_DINO_JUMPING

TOGGLE_FLAG_DINO_BLINKING_OFF  = #%01111111
TOGGLE_FLAG_DINO_JUMPING_OFF   = #%11111011
TOGGLE_FLAG_DINO_CROUCHING_OFF = #%11101111

;=============================================================================
; MEMORY / VARIABLES
;=============================================================================
  SEG.U variables
  ORG $80

DINO_TOP_Y_INT       .byte   ; 1 byte   (1)
DINO_TOP_Y_FRACT     .byte   ; 1 byte   (2)
BG_COLOUR            .byte   ; 1 byte   (3)
DINO_COLOUR          .byte   ; 1 byte   (4)
DINO_SPRITE          .byte   ; 1 byte   (5)
DINO_SPRITE_OFFSET   .byte   ; 1 byte   (6)
MISILE_P0            .byte   ; 1 byte   (7)
ENABLE_BALL          .byte   ; 1 byte
GAME_FLAGS           .byte   ; 1 byte   (8)
PTR_DINO_SPRITE      .word   ; 2 bytes  (10)
PTR_DINO_SPRITE_2    .word   ; 2 bytes  (12)
PTR_DINO_OFFSET      .word   ; 2 bytes  (14)
PTR_DINO_OFFSET_2    .word   ; 2 bytes  (16)
PTR_DINO_MIS         .word   ; 2 bytes  (18)
PTR_DINO_MIS_2       .word   ; 2 bytes  (20)
PTR_DINO_BALL        .word   ; 2 bytes
RND_SEED             .word   ; 2 bytes  (22)
FRAME_COUNT          .word   ; 2 bytes  (23)
DINO_VY_INT          .byte   ; 1 byte   (24)
DINO_VY_FRACT        .byte   ; 1 byte   (25)
UP_PRESSED_FRAMES    .byte   ; 1 byte   (25)

OBSTACLE_TYPE        .byte
OBSTACLE_Y           .byte
OBSTACLE_X_INT       .byte   ; 1 byte
OBSTACLE_X_FRACT     .byte   ; 1 byte

PTR_OBSTACLE_SPRITE  .word   ; 2 bytes
PTR_OBSTACLE_OFFSET  .word   ; 2 bytes
PTR_OBSTACLE_MIS     .word   ; 2 bytes

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
  sta PTR_DINO_MIS
  lda #>[DINO_MIS_OFFSETS - INIT_DINO_POS_Y]
  sta PTR_DINO_MIS+1

  lda #1
  sta OBSTACLE_TYPE
  lda #SKY_MAX_Y-#4
  sta OBSTACLE_Y
  lda #50
  sta OBSTACLE_X_INT

  ; TODO: Remove after testing obstacle positioning
  lda #72
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
    lda #0   ; A <- 0
  sta WSYNC  ; 3rd (final) line of vsync
  sta VSYNC  ; VSYNC = A (A=0) disables vsync

  ; -----------------------
  ; V-BLANK (37 scanlines)
  ; -----------------------
  ; Set the timer for the remaining VBLANK period (37 lines)
  ; 76 cpu cycles per scanline, 37 * 76 = 2812 cycles / 64 ticks => 43
  lda #43
  sta TIM64T

  sta HMCLR             ; Clear horizontal motion registers

  ; =======================
  ; BEGIN FRAME SETUP/LOGIC
  ; - - - - - - - - - - - - - - - - - - - - - - - -
start_frame_setup:
  lda #BKG_LIGHT_GRAY   ;
  sta COLUBK            ; Set initial background

  lda DINO_COLOUR       ; dino sprite colour
  sta COLUP0

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

  ; We need to clear the crouching flag as the user might have released the
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
  sta PTR_DINO_MIS
  lda #>DINO_MIS_OFFSETS_END
  sbc #0
  sta PTR_DINO_MIS+1
  jmp _end_legs_anim

_crouching:

  echo "DINO_CROUCHING_SPRITE=",#DINO_CROUCHING_SPRITE
  echo "CROUCHING_REGION_2_MIN_Y=",#CROUCHING_REGION_2_MIN_Y

  lda #<[DINO_CROUCHING_SPRITE - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_SPRITE_2
  lda #>[DINO_CROUCHING_SPRITE - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_SPRITE_2+1

  lda #<[DINO_CROUCHING_SPRITE_OFFSETS - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_OFFSET_2
  lda #>[DINO_CROUCHING_SPRITE_OFFSETS - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_OFFSET_2+1

  lda #<[DINO_CROUCHING_MIS_OFFSET - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS_2
  lda #>[DINO_CROUCHING_MIS_OFFSET - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_MIS_2+1

  lda #<[DINO_CROUCHING_BALL - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_BALL
  lda #>[DINO_CROUCHING_BALL - CROUCHING_REGION_2_MIN_Y]
  sta PTR_DINO_BALL+1


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
; SPLASH SCREEN
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


  ; - - - - - - - - - - - - - - - - - - - - - - - -
  ; END FRAME SETUP/LOGIC
  ; =======================

  lda #0
vblank:
  lda INTIM
  bne vblank
               ; 2752 cycles + 2 from bne, 2754 (out of 2812 vblank)

  sta WSYNC
  sta VBLANK   ; Disables VBLANK (A=0)

  lda GAME_FLAGS           ; if the splash screen is enabled then jump to the
  and #FLAG_SPLASH_SCREEN  ; splash screen kernel after disabling VBLANK
  beq game_kernels
  jmp splash_screen_kernel

;=============================================================================
; GAME KERNEL
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
game_kernels:

score_sub_kernel_setup:;---->>> 2 scanlines <<<----
  DEBUG_SUB_KERNEL #$10, #2

score_sub_kernel:;---------->>> 10 scanlines <<<---
  DEBUG_SUB_KERNEL #$20,#10

clouds_sub_kernel_setup:;-->>> 2 scanlines <<<-----
  DEBUG_SUB_KERNEL #$30,#2

clouds_sub_kernel:;-------->>> 18 scanlines <<<----
  DEBUG_SUB_KERNEL #$40,#16

sky_sub_kernel_setup:;----->>> 4 scanlines <<<-----
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
  beq _dino_is_not_crouching ; 2/3 (13 / 14)

  INSERT_NOPS 3        ; 6 (19)

  lda COLUBK           ; 3 (22)
  sta RESBL            ; 3 (25)
  sta RESM0            ; 3 (28) <-- same place as GRP0
  jmp _m0_coarse_position_set  ; 3 (31)

_dino_is_not_crouching:
  INSERT_NOPS 4        ; 8 (22)

  sta RESM0            ; 3 (25) <-- 3 cycles before GRP0

_m0_coarse_position_set:

  ; T0D0: set the coarse position of the cactus/pterodactile
_set_obstacle_position:
  clc                ; 2 (27) Clear the carry for the addition below
  lda OBSTACLE_X_INT ; 3 (30) OBSTACLE_X_INT is pre-loaded with 72 for testing
  adc #68            ; 2 (32) 68 TIA colour cycles ~ 22.5 6507 CPU cycles from
                     ;        HBLANK to the start of visible px in the screen
  sta HMCLR          ; 3 (35) Clear any previous HMMx
  sec                ; 2 (37) Set carry to do subtraction. Remember SBC is 
                     ;        actually an ADC with A2 complement
                     ;        A-B = A + ~B + 1 (<- this 1 is the carry you set)

  sta WSYNC          ; 3 (36)
  ; 3rd scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
_set_obstacle_coarse_x_pos:
  sbc #15                        ; 2 (5) Divide by 15 (sucessive subtractions)
  bcs _set_obstacle_coarse_x_pos ; 2/3 (obstacle-x / 5 + 5)
  
  ldy #SKY_MAX_Y   ; 2 (xx)


sky_sub_kernel: ;------------------>>> 31 2x scanlines <<<--------------------
  sta WSYNC        ; 3 (31)

  ; 1st scanline ==============================================================
            ; - (0)
  sta HMOVE ; 3 (3)

  CHECK_Y_WITHIN_DINO         ; 9 (12)
  bcs _sky__y_within_dino        ; 2/3 (14/15)

_sky__y_not_within_dino:         ; (14)
  lda #0                         ; 3 (17)  Disable the misile for P0
  sta DINO_SPRITE                ; 3 (20)
  sta DINO_SPRITE_OFFSET         ; 3 (23)
  sta MISILE_P0                  ; 3 (26)
  jmp _sky__end_of_1st_scanline  ; 3 (29)

_sky__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y        ; 5+ (20)
  sta DINO_SPRITE                ; 3  (23)

  ; graphics offset
  lda (PTR_DINO_OFFSET),y        ; 5+ (28)
  sta HMP0                       ; 3  (31)

  ; missile
  lda (PTR_DINO_MIS),y           ; 5+ (36)
  DECODE_MISSILE_OFFSET_AND_SIZE ; 13

_sky__end_of_1st_scanline:
  sta WSYNC                      ; 3 (32 / )

  ; 2nd scanline ==============================================================
                                 ; - (0)
  sta HMOVE                      ; 3 (3)
  lda DINO_SPRITE                ; 3 (9)
  ;lda #0                        ; 3 (9) for debugging, hides GRP0
  sta GRP0                       ; 3 (12)
  lda MISILE_P0                  ; 3 (15)
  sta ENAM0                      ; 3 (18)


  ; The HMxx registers don’t play nice if you set them within 24 CPU cycles of
  ; strobing HMOVE—otherwise, you might get some funky TIA behavior. The NOPs 
  ; here just give things a bit of breathing room.
  INSERT_NOPS 10            ; 20 (38)
  sta HMCLR                 ; 3 (41)


  ; Cactus/Crouching area very first scanline
  dey                       ; 2 (5)
  ; The +#1 bellow is because the carry will be set if Y ≥ SKY_MIN_Y,
  ; (both when Y > SKY_MIN_Y or Y == SKY_MIN_Y), we want to ignore
  ; the carry being set when Y == SKY_MIN_Y, that is, to turn this
  ; from Y ≥ C to Y > C. For that Y ≥ C + 1 ≡ Y > C.
  ; For example, x ≥ 4 ≡ x > 3  (for an integer x)
  cpy #SKY_MIN_Y+#1          ; 2 (7)
  bcs sky_sub_kernel         ; 2/3 (9 / 10)
_sky__end_of_2nd_scanline:

  ; On the last scanline of this area, and just before starting the next 
  ; scanline
_check_if_crouching:
  lda #93    ; for debugging, light pink
  sta COLUBK

  ; Check if dino is crouching, then jump to the appropiate kernel if so
  lda #FLAG_DINO_CROUCHING             ; 3 (15)
  bit GAME_FLAGS                       ; 3 (18)
  beq cactus_area_sub_kernel           ; 2/3 (20 / 21)

dino_crouching_sub_kernel: ;------------------>>> 31 2x scanlines <<<-----------------
; The crouching part is split into two regions:
; 1. Obstacles only: This region draws obstacles (either cacti or pterodactyl)
;    *without* the dino, following the same logic as in
;    'cactus_area_sub_kernel.' It covers 15 + 7 = 22 double scanlines:
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
  sta WSYNC                 ; 3 (3)
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

  lda (PTR_DINO_SPRITE_2),y           ; 5+ (36)
  sta DINO_SPRITE

  lda (PTR_DINO_OFFSET_2),y           ; 5+ (36)
  sta HMP0

  lda (PTR_DINO_MIS_2),y
  DECODE_MISSILE_OFFSET_AND_SIZE    ; 13

  lda (PTR_DINO_BALL),y
  sta ENABLE_BALL     ; 3 (3)
  sta HMBL            ; 3 (6)
  asl                 ; 2 (8)
  asl                 ; 2 (10)
  sta CTRLPF          ; 3 (13)

  sta WSYNC

  ; 2nd scanline ==============================================================
                            ; - (0)
  sta HMOVE                 ; 3 (3)

  lda ENABLE_BALL
  sta ENABL
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISILE_P0                         ; 3
  sta ENAM0                             ; 3
  INSERT_NOPS 10                        ; 20

  sta HMCLR


  dey                                   ; 2
  cpy #CROUCHING_REGION_2_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_2               ; 2/3


  jmp legs_and_floor_sub_kernel

cactus_area_sub_kernel: ;-------------->>> 31 2x scanlines <<<-----------------
  sta WSYNC                 ; 3 (3)

  ; 1st scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  CHECK_Y_WITHIN_DINO         ; 9 (12)
  bcs _cactus__y_within_dino  ; 2/3 (14 / 15)

_cactus__y_not_within_dino:
  lda #0                              ; 3 (17)  Disable the misile for P0
  sta DINO_SPRITE                     ; 3 (20)
  sta DINO_SPRITE_OFFSET              ; 3 (23)
  sta MISILE_P0                       ; 3 (26)
  jmp _cactus__end_of_1st_scanline    ; 3 (29)

_cactus__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+ (20)
  sta DINO_SPRITE                       ; 3  (23)

  ; graphics offset
  lda (PTR_DINO_OFFSET),y               ; 5+ (28)
  sta HMP0                              ; 3  (31)

  ; missile
  lda (PTR_DINO_MIS),y                  ; 5+ (36)
  DECODE_MISSILE_OFFSET_AND_SIZE        ; 13

_cactus__end_of_1st_scanline:
  sta WSYNC                             ; 3

  ; 2nd scanline ==============================================================
                              ; - (0)
  sta HMOVE                   ; 3 (3)
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISILE_P0                         ; 3
  sta ENAM0                             ; 3
  INSERT_NOPS 10                        ; 20
  sta HMCLR

  dey                                   ; 2 (5)
  cpy #CACTUS_AREA_MIN_Y+#1             ; 2 (7) - +1 turns Y ≥ C into Y > C
  bcs cactus_area_sub_kernel            ; 2/3 (9 / 10)

legs_and_floor_sub_kernel:

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
  sta HMOVE                   ; 3 (3)
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
  lda #0                          ; 3   Disable the misile for P0
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

ground_area_sub_kernel:
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
  lda #0                                ; 3   Disable the misile for P0
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
  bcs ground_area_sub_kernel           ; 2/3

  sta WSYNC                             ; 3
  sta HMOVE


void_area_sub_kernel:
  DEBUG_SUB_KERNEL #$FA,#31
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

_splash__dino_sub_kernel_setup: ;------------->>> 32 2x scanlines <<<------------------G
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

_splash__dino_sub_kernel: ;----------->>> #DINO_HEIGHT 2x scanlines <<<----------------

  ; 1st scanline (setup) ======================================================
  INSERT_NOPS 5                        ; 10 add some 'distance' between the last
                                       ; sta HMOVE (has to be 24+ cycles)
  lda DINO_SPRITE_1-#1,y               ; 4
  sta DINO_SPRITE                      ; 3
  lda DINO_MIS_OFFSETS-#1,y            ; 4

  ; missile
  sta MISILE_P0                        ; 3
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
  lda MISILE_P0                         ; 3
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
  bne _splash__dino_sub_kernel                   ; 2/3

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
; SPRITE GRAPHICS DATA
;=============================================================================
  ;SEG data
  ;ORG $fe00

DINO_SPRITE_1:
;             GRP0              MP0     GRP0
;          /-8 bits-\                          offset   sprite bits
;          |███████ |       |        |███████ |  0      %11111110
;         █|█ ██████|       |       █|█ ██████|  0      %10111111
;         █|████████|       |       █|████████|  0      %11111111
;         █|████████|       |       █|████████|  0      %11111111
;         █|████████|       |       █|████████|  0      %11111111
;         █|████    |       |       .|▒████   | +1      %11111000
;  █     ██|██████  |       |█     ..|▒▒██████| +1      %11111111
;  █    ███|███     |       |█    ...|▒▒▒███  | +2      %11111100
;  ██  ████|███     |       |██  ....|▒▒▒▒███ | +3      %11111110
;  ████████|█████   |       |█████...|▒▒▒█████| +3      %11111111
;  ████████|███ █   |       |█████...|▒▒▒███ █| +3      %11111101
;  ████████|███     |       |███.....|▒▒▒▒▒███| +5      %11111111
;   ███████|██      |       | █......|▒▒▒▒▒▒██| +6      %11111111
;    ██████|██      |       |  ......|▒▒▒▒▒▒██| +6      %11111111
;     ███ █|█       |       |   ... .|▒▒▒ ▒█  | +5      %11101100
;     ██   |█       |       |   ..   |▒▒   █  | +5      %11000100
;     █    |█       |       |   .    |▒    █  | +5      %10000100
;     ██   |██      |       |   ..   |▒▒   ██ | +5      %11000110
;           76543210        |          12345678  ↑
;                           \--------/           these offsets have to be
;                      █ pixels will be          undone when drawing
;                   drawn using the missile 0
;
  .ds 1             ; <------ clears GRP0 so the last row doesn't repeat
  .byte %11000110   ;  ▒▒   ██ 
  .byte %10000100   ;  ▒    █  
  .byte %11000100   ;  ▒▒   █  
  .byte %11101100   ;  ▒▒▒ ▒█  
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒███
  .byte %11111101   ;  ▒▒▒███ █
  .byte %11111111   ;  ▒▒▒█████
  .byte %11111110   ;  ▒▒▒▒███ 
  .byte %11111100   ;  ▒▒▒███  
  .byte %11111111   ;  ▒▒██████
  .byte %11111000   ;  ▒████   
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %10111111   ;  █ ██████
  .byte %11111110   ;  ███████ 
  .ds 1             ; <- this is to match the size of the pixel offsets table
DINO_SPRITE_1_END = * ; * means 'here' or 'this'

DINO_SPRITE_2:
  .ds 1             ;
  .byte %11000000   ;  ▒▒      
  .byte %10000000   ;  ▒       
  .byte %11000110   ;  ▒▒   ██ 
  .byte %11101100   ;  ▒▒▒ ▒█  
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒███
  .byte %11111101   ;  ▒▒▒███ █
  .byte %11111111   ;  ▒▒▒█████
  .byte %11111110   ;  ▒▒▒▒███ 
  .byte %11111100   ;  ▒▒▒███  
  .byte %11111111   ;  ▒▒██████
  .byte %11111000   ;  ▒████   
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %10111111   ;  █ ██████
  .byte %11111110   ;  ███████ 
  .ds 1             ;
DINO_SPRITE_2_END = * 

DINO_SPRITE_3:
  .ds 1             ;
  .byte %00000110   ;       ██ 
  .byte %11000100   ;  ▒▒   █  
  .byte %10000100   ;  ▒    █  
  .byte %11101100   ;  ▒▒▒ ▒█  
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒▒██
  .byte %11111111   ;  ▒▒▒▒▒███
  .byte %11111101   ;  ▒▒▒███ █
  .byte %11111111   ;  ▒▒▒█████
  .byte %11111110   ;  ▒▒▒▒███ 
  .byte %11111100   ;  ▒▒▒███  
  .byte %11111111   ;  ▒▒██████
  .byte %11111000   ;  ▒████   
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %11111111   ;  ████████
  .byte %10111111   ;  █ ██████
  .byte %11111110   ;  ███████ 
  .ds 1             ;
DINO_SPRITE_3_END = *

;DINO_SPRITE_DEAD:
;  .ds 1             ;
;  .byte %11000110   ;  ▒▒   ██
;  .byte %10000100   ;  ▒    █
;  .byte %11000100   ;  ▒▒   █
;  .byte %11101100   ;  ▒▒▒ ▒█
;  .byte %11111111   ;  ▒▒▒▒▒▒██
;  .byte %11111111   ;  ▒▒▒▒▒▒██
;  .byte %11111111   ;  ▒▒▒▒▒███
;  .byte %11111101   ;  ▒▒▒███ █
;  .byte %11111111   ;  ▒▒▒█████
;  .byte %11111100   ;  ▒▒▒███
;  .byte %11111000   ;  ▒▒███
;  .byte %11110000   ;  ▒███
;  .byte %11111110   ;  ▒██████
;  .byte %11111111   ;  ████████
;  .byte %11111111   ;  ████████
;  .byte %10111111   ;  █ ██████
;  .byte %01011111   ;   █ █████
;  .byte %10111110   ;  █ █████
;  .ds 1

DINO_SPRITE1_OFFSETS:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
  .ds 1
  .byte $00  ;  ▒▒   ██    |  -5
  .byte $00  ;  ▒    █     |  -5
  .byte $00  ;  ▒▒   █     |  -5
  .byte $F0  ;  ▒▒▒ ▒█     |  -5
  .byte $00  ;  ▒▒▒▒▒▒██   |  -6
  .byte $10  ;  ▒▒▒▒▒▒██   |  -6
  .byte $20  ;  ▒▒▒▒▒███   |  -5
  .byte $00  ;  ▒▒▒███ █   |  -3
  .byte $F0  ;  ▒▒▒█████   |  -3
  .byte $10  ;  ▒▒▒▒███    |  -4
  .byte $10  ;  ▒▒▒███     |  -3
  .byte $10  ;  ▒▒██████   |  -2
  .byte $10  ;  ▒████      |  -1 <-- Any pixel offset applied in the current
  .byte $00  ;  ████████   |   0     2 line kernel, remains for the next
  .byte $00  ;  ████████   |   0     scanlines
  .byte $00  ;  ████████   |   0
  .byte $00  ;  █ ██████   |   0
  .byte $10  ;  ███████    |   0 <<< push all the pixels to the left one time
  .ds 1      ;                       to stitch with the missiles
DINO_SPRITE1_OFFSETS_END = *

; DINO MISSILE OFFSET
;
; MP0 is strobed at a moment T
;  |         +--- then GRP0 is strobed at T+3 CPU cycles (9 pixels) after MP0
;  |         |
;  |        <<--- BUT all GPR0 will be offset by -1, so it stitches with M0
;  |        |
;  v        v               missile offset and size
;  |        |███████ |             0  0
;  |       ▒|█ ██████|            +8  1
;  |       ▒|████████|            +8  1
;  |       ▒|████████|            +8  1
;  |       ▒|████████|            +8  1
;  |       █|████    |             0  0
;  |▒     ██|██████  |             0  1
;  |▒    ███|███     |             0  1
;  |▒▒  ████|███     |             0  2
;  |▒▒▒▒▒███|█████   |             0  8
;  |▒▒▒▒▒███|███ █   |             0  8
;  |▒▒▒█████|███     |             0  4
;  | ▒██████|██      |            +1  1
;  |  ██████|██      |             0  0
;  |   ███ █|█       |             0  0
;  |   ██   |█       |             0  0
;  |   █    |█       |             0  0
;  |   ██   |██      |             0  0
;
;  ▒ missile pixels, █ GRP0 pixels

;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80

DINO_MIS_OFFSETS:
                  ;                        offset           size
  .ds 1           ;                  HMM0 bits 7,6,5,4   NUSIZE bits 5,4
  .byte %00000000 ; |   ██   |██      |       0                0
  .byte %00000000 ; |   █    |█       |       0                0
  .byte %00000000 ; |   ██   |█       |       0                0
  .byte %00000000 ; |   ███ █|█       |       0                0
  .byte %00000000 ; |  ██████|██      |       0                0
  .byte %11110010 ; | ▒██████|██      |      +1                1
  .byte %00001010 ; |▒▒▒X████|███     |       0                4
  .byte %00001110 ; |▒▒▒▒▒XXX|███ █   |       0                8
  .byte %00001110 ; |▒▒▒▒▒XXX|█████   |       0                8
  .byte %00000110 ; |▒▒  ████|███     |       0                2
  .byte %00000010 ; |▒    ███|███     |       0                1
  .byte %01110010 ; |▒     ██|██████  |       0                1
  .byte %00000000 ; |       █|████    |       0                0
  .byte %00000010 ; |       ▒|████████|      +8                1
  .byte %00000010 ; |       ▒|████████|      +8                1
  .byte %00000010 ; |       ▒|████████|      +8                1
  .byte %10000010 ; |       ▒|█ ██████|      +8                1
  .byte %00000000 ; |        |███████ |       0                0
  .ds 1; ^
  ;      |
  ;      + enable the ball when this bit is ON
  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile pixels
  ;    ░ ball
  ;    X overlapping pixels
  ;    ▯ Non drawn by the current kernel

DINO_MIS_OFFSETS_END = *


; Crouching sprite diagram:
;
; Legend:
;    █ GRP0 pixels
;    ▒ missile pixels
;    ░ ball
;    X overlapping pixels
;    ▯ Non drawn by the current kernel
;
;                 ⏐   ▯▯    ⏐   \
;                 ⏐   ▯     ⏐    > will be drawn by the floor kernel
;                 ⏐   ▯▯   ▯⏐▯  /
;                 ⏐   ███ ██⏐  ▓▓          <-- missile set to size 2
;                 ⏐  ░░░░░░░⏐░██  █▓▓▓▓    \
;                 ⏐ ░░░░XXXX⏐▓▓▓▓████      |  in all these scan lines
;                 ⏐ ░░░░XXXX⏐▓▓▓▓████████   > both ball and missile
;                 ⏐░░░░░XXX▓⏐▓▓▓▓████████  |  are set to size 8
;                 ⏐░░░░░XXX▓⏐▓▓▓▓████████  /
;                 ⏐░  ▓▓▓▓▓▓⏐▓▓  ██ █████  <-- ball size 1 and missile size 8
;                 ⏐         ⏐     ██████
;                 ↑         ↑              HMM0 bits 7,6,5,4   NUSIZE bits 5,4
;                 |     M0/GRP0 position (cycle 23)
;      BALL position (cycle 20)
;
DINO_CROUCHING_SPRITE:
  .ds 1             ; |        |
  .byte %11101100   ; |███ ██  |
  .byte %00111001   ; |  ███  █|
  .byte %11110000   ; |████    |
  .byte %11111111   ; |████████|
  .byte %11111111   ; |████████|
  .byte %11111111   ; |████████|
  .byte %11011111   ; |██ █████|
  .byte %01111110   ; | ██████ |
  .ds 1             ; |        |

DINO_CROUCHING_SPRITE_OFFSETS:
; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80

            ; ⏐   ▯▯    ⏐
            ; ⏐   ▯     ⏐                     GRP0 offset
  .ds 1     ; ⏐   ▯▯   ▯⏐▯
  .byte $40 ; ⏐   ███ ██⏐  ▓▓            -5
  .byte $60 ; ⏐  ░░░░░░░⏐░██  █▓▓▓▓      -6
  .byte $00 ; ⏐ ░░░░░░XX⏐▓▓▓▓XX██         0
  .byte $00 ; ⏐ ░░░░XXXX⏐▓▓▓▓████████     0
  .byte $00 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████     0
  .byte $00 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████     0
  .byte $00 ; ⏐░  ▓▓▓▓▓▓⏐▓▓  ██ █████     0
  .byte $C0 ; ⏐         ⏐     ██████     +4
  .ds 1     ; ↑         ↑
            ; |       M0/GRP0 position (cycle 25)
            ; BALL position (cycle 22)

DINO_CROUCHING_SPRITE_OFFSETS_END = *

DINO_CROUCHING_BALL:
  ;                                          offset           size
  ;                                    HMBL bits 7,6,5,4  CTRLPF bits 5,4
  ; Enable BALL bit ⏐   ▯▯    ⏐
  ;            ⏐    ⏐   ▯     ⏐
  .ds 1 ;      ↓    ⏐   ▯▯   ▯⏐▯
  .byte %00100000 ; ⏐   ███ ██⏐  ▓▓             0               0
  .byte %11111110 ; ⏐  ░░░░░░░⏐░██  █▓▓▓▓      +1               8
  .byte %00001110 ; ⏐ ░░░░░░XX⏐▓▓▓▓XX██         0               8
  .byte %11111110 ; ⏐ ░░░░XXXX⏐▓▓▓▓████████    +1               8
  .byte %00001110 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████     0               8
  .byte %00001110 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████     0               8
  .byte %00000010 ; ⏐░  ▓▓▓▓▓▓⏐▓▓  ██ █████     0               1
  .byte %11110000 ; ⏐         ⏐     ██████     +1               0
  .ds 1 ;    ↑↑     ↑         ↑
  ;          ⏐⏐     ⏐     M0/GRP0 position (cycle 25)
  ;     BALL size   BALL pos (cycle 22)

DINO_CROUCHING_MIS_OFFSET:
  ;                                          offset           size
  ;                                    HMM0 bits 7,6,5,4   NUSIZE bits 5,4
  ; Enable M0 bit   ⏐   ▯▯    ⏐
  ;            ⏐    ⏐   ▯     ⏐
  .ds 1 ;      ↓    ⏐   ▯▯   ▯⏐▯
  .byte %01000110 ; ⏐   ███ ██⏐  ▓▓            -4               2
  .byte %10001010 ; ⏐  ░░░░░░░⏐░██  █▓▓▓▓      +8               4
  .byte %11101110 ; ⏐ ░░░░░░XX⏐▓▓▓▓XX██        +2               8
  .byte %00001110 ; ⏐ ░░░░XXXX⏐▓▓▓▓████████     0               8
  .byte %00001110 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████     0               8
  .byte %11101110 ; ⏐░░░░░XXX▓⏐▓▓▓▓████████    +2               8
  .byte %01011110 ; ⏐░  ▓▓▓▓▓▓⏐▓▓  ██ █████    -5               8
  .byte %00000000 ; ⏐         ⏐     ██████      0               0
  .ds 1           ; ↑         ↑
  ; BALL pos (cycle 22)   M0/GRP0 position (cycle 25)
  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile pixels
  ;    ░ ball
  ;    X overlapping pixels
  ;    ▯ Non drawn by the current kernel

PTERO_WINGS_CLOSED_SPRITE:
  ; Sprite drawn as a combination
  ; of GRP0 and M0 (after applying offsets)
  ;    "unpacked" GRP0 and M0
  ;                                  /- GRP0 -\
  ;       ⏐         |                ⏐        ⏐
  ;       ⏐         |                ⏐        ⏐
  ;       ⏐         |                ⏐        ⏐
  ;       ⏐         |                ⏐        ⏐
  ;   ███ ⏐         |                ⏐    ███ ⏐
  ;  ████ ⏐         |                ⏐   ████ ⏐
  ; ██████⏐         |                ⏐  ██████⏐
  ;█████XX⏐▓▓▓▓▓▓   |                ⏐ █████XX⏐▓▓▓▓▓▓
  ;      █⏐███▓▓▓▓▓▓|▓▓              ⏐    ████⏐▓▓▓▓▓▓▓▓
  ;       ⏐████████ |                ⏐████████⏐
  ;       ⏐██████▓▓▓|▓               ⏐  ██████⏐▓▓▓▓
  ;       ⏐███████  |                ⏐ ███████⏐
  ;       ⏐███      |                ⏐     ███⏐
  ;       ⏐██       |                ⏐     ██ ⏐
  ;       ⏐██       |                ⏐     ██ ⏐
  ;       ⏐█        |                ⏐     █  ⏐
  ;       ⏐         |                ⏐        ⏐
  ;

  .ds 1            ;⏐        ⏐
  .byte %00000100  ;⏐     █  ⏐
  .byte %00000110  ;⏐     ██ ⏐
  .byte %10000110  ;⏐     ██ ⏐
  .byte %00000111  ;⏐     ███⏐
  .byte %01111111  ;⏐ ███████⏐
  .byte %00111111  ;⏐  ██████⏐
  .byte %11111111  ;⏐████████⏐
  .byte %00001111  ;⏐    ████⏐
  .byte %01111111  ;⏐ ███████⏐
  .byte %00111111  ;⏐  ██████⏐
  .byte %00011110  ;⏐   ████ ⏐
  .byte %00001110  ;⏐    ███ ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .ds 1            ;⏐        ⏐

PTERO_WINGS_CLOSED_SPRITE_OFFSETS:

; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80

  .byte $00  ;⏐        ⏐
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .byte $00  ;
  .ds 1            ;⏐        ⏐


PTERO_WINGS_CLOSED_MIS_OFFSETS:
  ;                                    HMM0 bits 7,6,5,4   NUSIZE bits 5,4
  ; Enable M0 bit   ⏐         ⏐         |
  ;            ⏐    ⏐         ⏐         |
  .ds 1 ;      ↓    ⏐         ⏐         |
  .byte %00000000 ; ⏐         ⏐         |       0               0
  .byte %00000000 ; ⏐         ⏐█        |      -5               8
  .byte %00000000 ; ⏐         ⏐██       |      +2               8
  .byte %00000000 ; ⏐         ⏐██       |       0               8
  .byte %00000000 ; ⏐         ⏐███      |       0               8
  .byte %00000000 ; ⏐         ⏐███████  |      +2               8
  .byte %00000000 ; ⏐         ⏐█████████|▓     +8               4
  .byte %00000000 ; ⏐         ⏐████████ |       0               0
  .byte %00000000 ; ⏐        █⏐█████████|▓▓    -5               8
  .byte %00000000 ; ⏐  ███████⏐██████   |      +2               8
  .byte %00000000 ; ⏐   ██████⏐         |       0               8
  .byte %00000000 ; ⏐    ████ ⏐         |       0               8
  .byte %00000000 ; ⏐     ███ ⏐         |      +2               8
  .byte %00000000 ; ⏐         ⏐         |      +8               4
  .byte %00000000 ; ⏐         ⏐         |      -4               2
  .byte %00000000 ; ⏐         ⏐         |      -4               2
  ;                 ↑         ↑
  ; BALL pos (cycle 22)   M0/GRP0 position (cycle 25)
  .ds 1;

  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile pixels
  ;    ░ ball
  ;    X overlapping pixels
  ;    ▯ Non drawn by the current kernel


;             -4               2
;    ██      +8               4
;    ██       +2               8
;  ██████      0               8
; █  █████     0               8
; █  ██  █    +2               8
;    ██  █    -5               8
;    ██        0               0

;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
