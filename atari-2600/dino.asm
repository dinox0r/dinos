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
CACTUS_LINES = #31
FLOOR_LINES = #2
GROUND_LINES = #8

DINO_PLAY_AREA_LINES = #SKY_LINES+#CACTUS_LINES+#FLOOR_LINES+#GROUND_LINES
SKY_MAX_Y = #DINO_PLAY_AREA_LINES
SKY_MIN_Y = #SKY_MAX_Y-#SKY_LINES
CACTUS_AREA_MAX_Y = #SKY_MIN_Y
CACTUS_AREA_MIN_Y = #CACTUS_AREA_MAX_Y-#CACTUS_LINES
GROUND_AREA_MAX_Y = #CACTUS_AREA_MIN_Y
GROUND_AREA_MIN_Y = #GROUND_AREA_MAX_Y-#GROUND_LINES

; The 1st region of the crouching area covers 15 + 7 = 22 double scanlines:
; 15 empty 2x scanlines from the top to where the dino's head would be when
; standing, plus an additional 7 scanlines without the dino, since is now
; crouching. The 2nd region is 9 2x scanlines, because the dino crouching
; sprite spans 9 scanlines without the legs (which are drawn by the floor
; kernel)
CROUCHING_LINES_REGION_1 = #15+#7
CROUCHING_LINES_REGION_2 = #9
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
FLAG_DINO_CROUCHING_OR_JUMPING = #%00010100

TOGGLE_FLAG_DINO_BLINKING_OFF  = #%01111111
TOGGLE_FLAG_DINO_JUMPING_OFF   = #%11111011
TOGGLE_FLAG_DINO_CROUCHING_OFF = #%11101111

;=============================================================================
; MEMORY / VARIABLES
;=============================================================================
  SEG.U variables
  ORG $80

DINO_TOP_Y_INT     .byte   ; 1 byte   (1)
DINO_TOP_Y_FRACT   .byte   ; 1 byte   (2)
BG_COLOUR          .byte   ; 1 byte   (3)
DINO_COLOUR        .byte   ; 1 byte   (4)
DINO_SPRITE        .byte   ; 1 byte   (5)
DINO_SPRITE_OFFSET .byte   ; 1 byte   (6)
MISILE_P0          .byte   ; 1 byte   (7)
GAME_FLAGS         .byte   ; 1 byte   (9)
PTR_DINO_SPRITE    .word   ; 2 bytes  (11)
PTR_DINO_OFFSET    .word   ; 2 bytes  (13)
PTR_DINO_MIS       .word   ; 2 bytes  (15)
RND_SEED           .word   ; 2 bytes  (17)
FRAME_COUNT        .word   ; 2 bytes  (19)
DINO_VY_INT        .byte   ;
DINO_VY_FRACT      .byte   ; 2 bytes  (21)

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
  bne _end_check_joystick

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
  jmp _end_check_joystick

_on_joystick_down:
  ; if it's already crouching or jumping, ignore
  lda #FLAG_DINO_CROUCHING_OR_JUMPING
  bit GAME_FLAGS
  bne _end_check_joystick

  ora GAME_FLAGS ; A <- A | GAME_FLAGS  => #FLAG_DINO_CROUCHING | GAME_FLAGS
  sta GAME_FLAGS

  jmp _end_check_joystick

_end_check_joystick:

  lda #FLAG_SPLASH_SCREEN
  bit GAME_FLAGS
  beq in_grame_screen
  jmp in_splash_screen

; -----------------------------------------------------------------------------
; GAME SCREEN
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

clouds_sub_kernel:;-------->>> 20 scanlines <<<----
  DEBUG_SUB_KERNEL #$40,#20

sky_sub_kernel_setup:;----->>> 2 scanlines <<<-----
  lda BG_COLOUR    ; 3
  sta COLUBK       ; 3

  INSERT_NOPS 7    ; 14 Fix the dino_x position for the rest of the kernel
                   ;    (notice I'm not starving for ROM atm of writing this)
  sta RESM0        ; 3  TV beam should now be at a dino coarse x position
  sta RESP0        ; 3  M0 will be 3 cycles (9 px) far from P0

  ldy #SKY_MAX_Y

  ; T0D0: set the coarse position of the cactus/pterodactile

  sta WSYNC                ; 3

sky_sub_kernel: ;------------------>>> 31 2x scanlines <<<--------------------

  ; 1st scanline ==============================================================
  tya                                   ; 2   A = current scanline (Y)
  sec                                   ; 2
  sbc DINO_TOP_Y_INT                        ; 3 - A = X - DINO_TOP_Y_INT
  adc #DINO_HEIGHT                      ; 2
  bcs _sky__y_within_dino                   ; 2/3

_sky__y_not_within_dino:
  lda #0                                ; 3   Disable the misile for P0
  sta DINO_SPRITE                       ; 3
  sta DINO_SPRITE_OFFSET
  sta MISILE_P0
  jmp _sky__end_of_1st_scanline                 ; 3

_sky__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+
  sta DINO_SPRITE                       ; 3

  ; graphics offset
  lda (PTR_DINO_OFFSET),y               ; 5+
  sta HMP0                              ; 3

  ; missile
  lda (PTR_DINO_MIS),y                  ; 5+
  sta MISILE_P0                         ; 3
  sta HMM0                              ; 3
  asl
  asl
  sta NUSIZ0


_sky__end_of_1st_scanline:
  sta WSYNC                             ; 3 (3)
  sta HMOVE                             ; 3 (6)

  ; 2nd scanline ==============================================================
  lda DINO_SPRITE                       ; 3 (9)
  ;lda #0                               ; 3 (9) for debugging, hides GRP0
  sta GRP0                              ; 3 (12)
  lda MISILE_P0                         ; 3 (15)
  sta ENAM0                             ; 3 (18)


  ; The HMxx registers don’t play nice if you set them within 24 CPU cycles of
  ; strobing HMOVE—otherwise, you might get some funky TIA behavior. The NOPs 
  ; here just give things a bit of breathing room.
  INSERT_NOPS 10                        ; 20 (38)
  sta HMCLR                             ; 3 (41)

  sta WSYNC                             ; 3 (3)
  sta HMOVE                             ; 3 (6)

  dey                                   ; 2 (8)
  ; The +#1 bellow is because the carry will be set if Y ≥ SKY_MIN_Y,
  ; (both when Y > SKY_MIN_Y or Y == SKY_MIN_Y), we want to ignore
  ; the carry being set when Y == SKY_MIN_Y, that is, to turn this
  ; from Y ≥ C to Y > C. For that Y ≥ C + 1 ≡ Y > C.
  ; For example, x ≥ 4 ≡ x > 3  (for an integer x)
  cpy #SKY_MIN_Y+#1                    ; 2 (10)
  bcs sky_sub_kernel                   ; 2/3 (12 / 13)

  ; On the last scanline of this area, and just before starting the next 
  ; scanline
_check_if_crouching:
  lda #83
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
;    15 empty 2x scanlines from the top to where the dino's head would be when
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
;                   ░░░XXXXX▓▓▓| █████  |   /
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
  ; 1st scanline ==============================================================
  ; TODO: Copy the obstacle drawing code from the catus kernel here
  sta WSYNC
  sta HMOVE
  ; 2nd scanline ==============================================================
  sta WSYNC
  sta HMOVE

  dey                                   ; 2
  cpy #CROUCHING_REGION_1_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_1               ; 2/3

_crouching_region_2:
  ; 1st scanline ==============================================================
  ; TODO: Copy the obstacle drawing code from the catus kernel here
  sta WSYNC
  sta HMOVE
  ; 2nd scanline ==============================================================
  sta WSYNC
  sta HMOVE

  dey                                   ; 2
  cpy #CROUCHING_REGION_2_MIN_Y+#1      ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs _crouching_region_1               ; 2/3
  jmp floor_sub_kernel

cactus_area_sub_kernel: ;-------------->>> 31 2x scanlines <<<-----------------

  ; 1st scanline ==============================================================
  tya                                   ; 2 (5)  A = currrent scanline (Y)
  sec                                   ; 2 (7)
  sbc DINO_TOP_Y_INT                    ; 3 (10) A = X - DINO_TOP_Y_INT
  adc #DINO_HEIGHT                      ; 2 (12)
  bcs _cactus__y_within_dino            ; 2/3 (14 / 15)

_cactus__y_not_within_dino:
  lda #0                                ; 3 (17)  Disable the misile for P0
  sta DINO_SPRITE                       ; 3 (20)
  sta DINO_SPRITE_OFFSET                ; 3 (23)
  sta MISILE_P0                         ; 3 (26)
  jmp _cactus__end_of_1st_scanline      ; 3 (29)

_cactus__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+ (20)
  sta DINO_SPRITE                       ; 3  (23)

  ; graphics offset
  lda (PTR_DINO_OFFSET),y               ; 5+ (28)
  sta HMP0                              ; 3  (31)

  ; missile
  lda (PTR_DINO_MIS),y                  ; 5+ (36)
  sta MISILE_P0                         ; 3  (39)
  sta HMM0                              ; 3  (41)
  asl                                   ; 2  (43)
  asl                                   ; 2  (45)
  sta NUSIZ0                            ; 3  (48)


_cactus__end_of_1st_scanline:
  sta WSYNC                             ; 3
  sta HMOVE                             ; 3

  ; 2nd scanline ==============================================================
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISILE_P0                         ; 3
  sta ENAM0                             ; 3
  INSERT_NOPS 10                        ; 20
  sta HMCLR

  sta WSYNC                             ; 3
  sta HMOVE                             ; 3

  dey                                   ; 2
  cpy #CACTUS_AREA_MIN_Y+#1             ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs cactus_area_sub_kernel                   ; 2/3

floor_sub_kernel:
  lda #87
  sta COLUBK
  ; 1st scanline SETUP ==============================================================
  tya                                   ; 2   A = current scanline (Y)
  sec                                   ; 2
  sbc DINO_TOP_Y_INT                        ; 3 - A = X - DINO_TOP_Y_INT
  adc #DINO_HEIGHT                      ; 2
  bcs _floor__y_within_dino                   ; 2/3

_floor__y_not_within_dino:
  lda #0                                ; 3   Disable the misile for P0
  sta DINO_SPRITE                       ; 3
  sta DINO_SPRITE_OFFSET
  jmp _floor__end_of_1st_scanline     ; 3

_floor__y_within_dino:
  ; graphics
  lda (PTR_DINO_SPRITE),y               ; 5+
  sta DINO_SPRITE                       ; 3


_floor__end_of_1st_scanline:
  sta WSYNC                             ; 3
  sta HMOVE                             ; 3

  ; 2nd scanline ==============================================================

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

;lda DINO_COLOUR
;  sta COLUBK


;ldx BG_COLOUR
;  lda DINO_COLOUR
;  stx COLUBK
;  sta COLUBK

  INSERT_NOPS 12                        ; 24
  sta HMCLR

  sta WSYNC                             ; 3
  sta HMOVE                             ; 3
  dey

ground_area_sub_kernel:
  lda BG_COLOUR
  sta COLUBK

  lda #0
  sta PF0
  sta PF1
  sta PF2

  ; 1st scanline ==============================================================
  tya                                   ; 2   A = current scanline (Y)
  sec                                   ; 2
  sbc DINO_TOP_Y_INT                        ; 3 - A = X - DINO_TOP_Y_INT
  adc #DINO_HEIGHT                      ; 2
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
  sta HMOVE                             ; 3

  ; 2nd scanline ==============================================================
  lda DINO_SPRITE                       ; 3
  ;lda #0                               ; for debugging, hides GRP0
  sta GRP0                              ; 3
  lda MISILE_P0                         ; 3
  sta ENAM0                             ; 3
  INSERT_NOPS 10                        ; 20
  sta HMCLR

  sta WSYNC                             ; 3
  sta HMOVE                             ; 3

  dey                                   ; 2
  cpy #GROUND_AREA_MIN_Y+#1             ; Similarly that what we did in the sky
                                        ; kernel, +1 turns Y ≥ C into Y > C
  bcs ground_area_sub_kernel           ; 2/3


void_area_sub_kernel:
  DEBUG_SUB_KERNEL #$FA,#31
  jmp end_of_frame

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; END GAME KERNEL
;=============================================================================

;=============================================================================
; SPLASH SCREEN KERNEL
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
splash_screen_kernel:
  DEBUG_SUB_KERNEL #$7A,#35

_splash__dino_sub_kernel_setup: ;------------->>> 32 2x scanlines <<<------------------
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
;           76543210        |          12345678
;                           \--------/
;                         these █ pixels to be
;                         drawn using the missile
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
  ;                     ▒ missile pixels, █ GRP0 pixels  X overlapping pixels
DINO_MIS_OFFSETS_END = *


; Crouching sprite diagram:
; Legend: ░ ball   ▓ missile 0   █ player 0  X collision
;
; 2 sub-kernels for crouching:
;                                 GRP0
;                              /-8 bits-\
; 1st sub-kernel:              | ██████ |
;                 ░  ▓▓▓▓▓▓▓▓  |██ █████|   <-- missile set to size 8
;                 ░░░░░XXX▓▓▓▓▓|████████|   \
;                 ░░░░░XXX▓▓▓▓▓|████████|   |  both ball and missile
;                  ░░░░XXXX▓▓▓▓|████████|    > are set to size 8
;                  ░░░░XXXX▓▓▓▓|████    |   |  in all these scan lines
;                   ░░░XXXXX▓▓▓| █████  |   /
; 2nd sub-kernel:   |███ ██  ▓▓   <-- missile set to size 2
;                   |██   ██ |
;                   \-8 bits-/
;                      GRP0
;
;                   |█       |
;                   |██      |
;                   |        |
; In the 1st sub-kernel, 3 objects are used, ball, m0 and p0
; In the 2nd sub-kernel, only 2 objects are used, m0 and p0
;
; This is the sprite data for the 1st crouching sub-kernel:
DINO_CROUCHING_GRP0_1:
  .ds 1             ; |        |
  .byte %01111100   ; | █████  |
  .byte %11110000   ; |████    |
  .byte %11111111   ; |████████|
  .byte %11111111   ; |████████|
  .byte %11111111   ; |████████|
  .byte %11011111   ; |██ █████|
  .byte %01111110   ; | ██████ |
  .ds 1             ; |        |

DINO_CROUCHING_GRP0_2:
  .ds 1             ; |        |
  .byte %11000000   ; |██      |
  .byte %10000000   ; |█       |
  .byte %11000110   ; |██   ██ |
  .byte %11101100   ; |███ ██  |
  .ds 1             ; |        |

DINO_CROUCHING_MIS_OFFSET_1:

;                   |        |
;                   |██      |
;                   |█       |
;                   |██   ██ |
; 2nd sub-kernel:   |███ ██  ▓▓   <-- missile set to size 2
;                   ░░░XXXXX▓▓▓| █████  |   /
;                  ░░░░XXXX▓▓▓▓|████    |   |  in all these scan lines
;                  ░░░░XXXX▓▓▓▓|████████|    > are set to size 8
;                 ░░░░░XXX▓▓▓▓▓|████████|   |  both ball and missile
;                 ░░░░░XXX▓▓▓▓▓|████████|   \
;                 ░  ▓▓▓▓▓▓▓▓  |██ █████|   <-- missile set to size 8
; 1st sub-kernel:              | ██████ |
  .ds 1           ;                  HMM0 bits 7,6,5,4   NUSIZE bits 5,4

  .byte %00000000 ;    |        |  |        |
  .byte %00000000 ;    |██      |  |        |
  .byte %00000000 ;    |█       |  |        |
  .byte %00000000 ;    |██   ██ |  |        |
  .byte %00000000 ;    |███ ██  |▓▓|        |
  .byte %00000000 ;   ░|░░XXXXX▓|▓▓| █████  |
  .byte %00000000 ;  ░░|░░XXXX▓▓|▓▓|████    |
  .byte %00000000 ;  ░░|░░XXXX▓▓|▓▓|████████|
  .byte %00000000 ; ░░░|░░XXX▓▓▓|▓▓|████████|
  .byte %00000000 ; ░░░|░░XXX▓▓▓|▓▓|████████|
  .byte %00000000 ; ░  |▓▓▓▓▓▓▓▓|  |██ █████|
  .byte %00000000 ;    |        |  | ██████ |

;  .byte %00000000 ; |   ██   |██      |       0                0
;  .byte %00000000 ; |   █    |█       |       0                0
;  .byte %00000000 ; |   ██   |█       |       0                0
;  .byte %00000000 ; |   ███ █|█       |       0                0
;  .byte %00000000 ; |  ██████|██      |       0                0
;  .byte %11110010 ; | ▒██████|██      |      +1                1
;  .byte %00001010 ; |▒▒▒M████|███     |       0                4
;  .byte %00001110 ; |▒▒▒▒▒MMM|███ █   |       0                8
;  .byte %00001110 ; |▒▒▒▒▒MMM|█████   |       0                8
;  .byte %00000110 ; |▒▒  ████|███     |       0                2
;  .byte %00000010 ; |▒    ███|███     |       0                1
;  .byte %01110010 ; |▒     ██|██████  |       0                1
;  .byte %00000000 ; |       █|████    |       0                0
;  .byte %00000010 ; |       ▒|████████|      +8                1
;  .byte %00000010 ; |       ▒|████████|      +8                1
;  .byte %00000010 ; |       ▒|████████|      +8                1
;  .byte %10000010 ; |       ▒|█ ██████|      +8                1
;  .byte %00000000 ; |        |███████ |       0                0
;  .ds 1;

;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
