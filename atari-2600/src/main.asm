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
  INCLUDE "constants.asm"

;=============================================================================
; ZERO PAGE MEMORY / VARIABLES
;=============================================================================
  INCLUDE "variables.asm"

;=============================================================================
; ROM / GAME CODE
;=============================================================================
  SEG code
  ORG $F000
CARTRIDGE_ROM_START = *

  ; -----------------------
  ; RESET
  ; -----------------------
reset:
  ;sei     ; SEt Interruption disable (save 1 byte by ignoring this)
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

; Set the splash screen on power on/reset
set_splash_screen_flag:
  lda #FRG_DARK_GRAY
  sta COLUPF
  lda #%00110000
  sta FLOOR_PF1
  lda #%01000000
  sta FLOOR_PF0

  lda #FLAG_SPLASH_SCREEN  ; enable splash screen
  ;lda #0                  ; disable splash screen
  sta GAME_FLAGS
  ; Skip the clearing flags during initialization, doing this
  ; to preserve the splash screen ON flag
  jmp _reset_dino_y_pos

on_game_init:
  INCLUDE_AND_LOG_SIZE "init.asm"

;=============================================================================
; FRAME
;=============================================================================
start_of_frame:

vsync_and_vblank:
  lda #ENABLE_VBLANK
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
  lda #0     ; A <- 0
  sta VSYNC  ; VSYNC = A (A=0) disables vsync

  ; -----------------------
  ; V-BLANK (37 scanlines)
  ; -----------------------
  INCLUDE_AND_LOG_SIZE "vblank.asm"

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; GAME KERNELS
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
draw_game:
  INCLUDE_AND_LOG_SIZE "kernels/score_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/sky_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/play_area_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/dino_crouching_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/legs_and_floor_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/ground_area_kernel.asm"
  INCLUDE_AND_LOG_SIZE "kernels/gravel_area_kernel.asm"

;=============================================================================

end_of_frame:
  INCLUDE_AND_LOG_SIZE "overscan.asm"
  jmp start_of_frame

  ECHO "Total bytes used in cartridge ROM (before includes): ",[* - CARTRIDGE_ROM_START]d

;=============================================================================
; SUBROUTINES
;=============================================================================
  INCLUDE_AND_LOG_SIZE "subroutines.asm"

;=============================================================================
; UTILITY TABLES
;=============================================================================
  INCLUDE_AND_LOG_SIZE "tables.asm"

;=============================================================================
; SOUND DATA
;=============================================================================
  INCLUDE_AND_LOG_SIZE "sounds.asm"

;=============================================================================
; SPRITE GRAPHICS DATA
;=============================================================================
  INCLUDE_AND_LOG_SIZE "sprites.asm"

  ECHO "========================================="
  ECHO "Available ROM: ", [$fffc - *]d, "bytes"

;=============================================================================
; ROM SETUP
;=============================================================================
  ORG $fffc
  .word reset ; reset button signal
  .word reset ; IRQ
