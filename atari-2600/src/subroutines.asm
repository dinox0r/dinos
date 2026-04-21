;------------------------------------------------------------------------------
; General subroutines
;------------------------------------------------------------------------------
rnd8 subroutine
  lda RANDOM
  lsr
  bcc .no_xor
  eor #$D4
.no_xor:
  sta RANDOM
  rts

;------------------------------------------------------------------------------
; Obstacle related subroutines
;------------------------------------------------------------------------------
; set_sprite_data: Computes a ROM address offset by the y coordinate in 
;                  PARAM_SPRITE_Y (alias for TEMP+1) and stores the result in a
;                  zero-page pointer.
;
; Description:
;   This subroutine adjusts a given ROM address by subtracting PARAM_SPRITE_Y
;   and stores the resulting address in a zero-page pointer.
;
;   The operation is equivalent to:
;
;      sec                      ; Set carry for subtraction
;      lda #<SOME_ROM_ADDRESS   ; Load low byte of base address
;      sbc PARAM_SPRITE_Y       ; Subtract Y offset
;      sta ZERO_PAGE_ADDRESS    ; Store low byte of result
;      lda #>SOME_ROM_ADDRESS   ; Load high byte of base address
;      sbc #0                   ; Subtract carry (propagating from low byte)
;      sta ZERO_PAGE_ADDRESS+1  ; Store high byte of result
;
; Parameters:
;   In the form of Zero Page memory:
;     PARAM_SPRITE_Y - Sprite's Y pos
;
;   In the form of registers:
;     A  - Low byte of SOME_ROM_ADDRESS
;     Y  - High byte of SOME_ROM_ADDRESS
;     X  - Zero-page pointer location (i.e., ZERO_PAGE_ADDRESS)
;
; Result:
;   (X)   = Low byte of adjusted address
;   (X+1) = High byte of adjusted address
;
; Example:
;   If SOME_ROM_ADDRESS = $F252 and PARAM_SPRITE_Y = 10:
;     Adjusted address = $F252 - 10 = $F248
;     ZERO_PAGE_ADDRESS (at X) now holds $F248.
;
set_sprite_data subroutine
  sec                ; 2 (2) Ensure subtraction works correctly
  ; The subroutine assumes sprite Y coord in PARA_SPRITE_Y before the call
  sbc PARAM_SPRITE_Y ; 3 (5) Subtract Y offset from low byte
  sta $00,x          ; 4 (9) Store adjusted low byte at pointer X
  tya                ; 2 (11) Load high byte of original address
  sbc #0             ; 2 (13) Subtract carry from high byte
  sta $01,x          ; 4 (17) Store adjusted high byte at pointer X+1
  rts                ; 6 (23) Return from subroutine

spawn_obstacle subroutine
  jsr rnd8
  sta OBSTACLE_X_FRACT
  lda #161
  sta OBSTACLE_X_INT

  ; clear any previous duplication flag
  lda GAME_FLAGS
  and #TOGGLE_FLAG_DUPLICATED_OBSTACLE_OFF
  sta GAME_FLAGS
  lda #0
  sta OBSTACLE_DUPLICATE

  jsr rnd8
  and #3 ; equivalent to RND % 4
 lda #3
  sta OBSTACLE_TYPE

  bne .check_if_can_duplicate_obstacle
  ; If is the obstacle type 0 (no obstacle or invisible obstacle)
  ; then overwrite its x coordinate to a value between [0, 127], this is
  ; to give a breather to the player but not for too long
  jsr rnd8
  and #127
  sta OBSTACLE_X_INT
  jmp .set_y_pos

.check_if_can_duplicate_obstacle:
  cmp #3
  bcc .set_y_pos

  ; If the obstacle type is not a ptero (obstacle_type > 2), roll the dice 
  ; again to see if it can be duplicated, that is, 2 cacti sprites instead of
  ; a single one
  jsr rnd8
  cmp #250
  bcs .set_y_pos

  lda GAME_FLAGS
  ora #FLAG_DUPLICATED_OBSTACLE
  sta GAME_FLAGS

.set_y_pos:
  lda OBSTACLE_TYPE
  cmp #3  ; If obstacle_type is less than 3 (ptero but also affects invisible)
  bcc .chose_ptero_random_y_pos
  lda #CACTUS_Y
  sta OBSTACLE_Y
  jmp .end_spawn_obstacle
.chose_ptero_random_y_pos:
  jsr rnd8
  and #3
  tax
  lda PTERO_Y_POS,x
  sta OBSTACLE_Y
.end_spawn_obstacle
  rts

;------------------------------------------------------------------------------
; Sky related subroutines
;------------------------------------------------------------------------------
reset_cloud subroutine
  ; Assumes register A contains the new desired X integer position for the 
  ; cloud. The value is stored into the appropriate cloud slot (indexed by X).
  sta CLOUD_1_X,x
  jsr rnd8
  and #31
  ; Add a small x random offset
  adc CLOUD_1_X,x
  sta CLOUD_1_X,x

  ; If X == 0, this resets the cloud for the single-cloud sky.
  ; If X >= 1, this is one of the two clouds in the double-cloud sky.
  cpx #0
  bne .end_reset_cloud

  ; For the single-cloud sky (reg X == 0), allow a random vertical
  ; placement by masking with AND #15 (i.e., range 0–15).
  jsr rnd8
  and #15
  ; Add a base offset to the Y value, placing the cloud below the HUD
  ; or sky margin. The carry flag is not cleared, as the result doesn't
  ; need to be precise. Leaving the carry random adds slight variation.
  adc #CLOUD_HEIGHT+#3
  sta CLOUD_1_TOP_Y

.end_reset_cloud
  rts

set_cloud_pos_x subroutine
  ; The macro adds 27 cycles to current scanline, then ends it
  ; and consumes a whole new scanline for the positioning
  SET_STITCHED_SPRITE_X_POS #PLAYER_0_INDEX, #PLAYER_1_INDEX
  ; Once is finished, it leaves the execution on a new (3rd) scanline
  ; with 27 cycles (when using SEAMLESS_STITCHING)
  rts ; 6 (33)

render_cloud_layer subroutine
  ; Assumes reg A contains the x position of the cloud
  jsr set_cloud_pos_x        ; 6 for jsr + 27 of the subroutine (+33)
                            ; consumes a whole scanline and then resumes 
                            ; execution on cycle 27 of the next one

  sta WSYNC           ; 3 (30)
                      ; - (0) -------------------------------------------------
  sta HMOVE           ; 3 (3)

  lda #0              ; 2 (5)
  tax                 ; 2 (7)
  sta GRP0            ; 3 (10)
  sta GRP1            ; 3 (13)

  ldy CLOUD_LAYER_SCANLINES  ; 3 (16)

  lda CURRENT_CLOUD_X ; 3 (19)
  cmp #9              ; 2 (21)
  nop                 ; 2 (23)
  sta HMCLR           ; 3 (26)
  bcc .only_show_grp1 ; 2/3 (28/29)
  cmp #160            ; 2 (30)
  bcc .show_both_grp0_and_grp1 ; 2/3 (32/33)
  cmp #167            ; 2 (34)
  bcc .only_show_grp0 ; 2/3 (36/37)

  lda #0              ; 2 (38)
  CLOUD_KERNEL #IGNORE_GRP0, #IGNORE_GRP1
  sta WSYNC           ; 3 (?)
                      ; - (0)
  sta HMOVE           ; 3 (3)
  rts                 ; 6 (9)

.only_show_grp1: ; - (29)
  lda #0         ; 2 (31)
  CLOUD_KERNEL #IGNORE_GRP0, #USE_GRP1
  sta WSYNC           ; 3 (?)
                      ; - (0)
  sta HMOVE           ; 3 (3)
  rts                 ; 6 (9)

.show_both_grp0_and_grp1: ; - (33)
  lda #0                  ; 2 (35)
  CLOUD_KERNEL #USE_GRP0, #USE_GRP1
  sta WSYNC           ; 3 (73)
                      ; - (0)
  sta HMOVE           ; 3 (3)
  rts                 ; 6 (9)

.only_show_grp0:      ; - (37)
  lda #0              ; 2 (39)
  CLOUD_KERNEL #USE_GRP0, #IGNORE_GRP1
  sta WSYNC           ; 3 (?)
                      ; - (0)
  sta HMOVE           ; 3 (3)
  rts                 ; 6 (9)

reset_star subroutine
  lda #MAX_MOON_AND_STAR_POS_X
  sta STAR_POS_X

  jsr rnd8
  and #15
  adc #6
  sta STAR_POS_Y

  sta PARAM_SPRITE_Y

  lda SKY_FLAGS
  bit SKY_FLAG_STAR_SPRITE
  bne .use_star_2_sprite
.use_star_1_sprite:
  lda #<STAR_1_SPRITE_END
  .byte $2C
.use_star_2_sprite:  
  lda #<STAR_2_SPRITE_END

  ; Both sprites share the same upper byte value
  ldy #>STAR_1_SPRITE_END
  ldx #PTR_STAR_SPRITE
  jsr set_sprite_data

  ; Flip the sprite flag for the next reset
  lda SKY_FLAGS
  eor #SKY_FLAG_STAR_SPRITE
  sta SKY_FLAGS

  rts

reset_moon subroutine
  lda #MAX_MOON_AND_STAR_POS_X
  sta MOON_POS_X

  lda #MOON_POS_Y
  sta PARAM_SPRITE_Y

  jsr change_moon_phase
  rts

change_moon_phase subroutine

  inc SKY_FLAGS

  lda SKY_FLAGS
  and #3
  cmp #3
  bne .update_moon_phase_sprite_data
.reset_moon_phase_back_to_zero:
  ; A has 00000011
  eor SKY_FLAGS
  sta SKY_FLAGS

.update_moon_phase_sprite_data:
  and #%00000010
  bne .full_moon_phase
.waning_or_waxing_creasent_phase:

  lda #<MOON_PHASE_SPRITE_END
  ldy #>MOON_PHASE_SPRITE_END
  jmp .load_moon_sprite_data

.full_moon_phase:
  lda #<FULL_MOON_SPRITE_END
  ldy #>FULL_MOON_SPRITE_END

.load_moon_sprite_data:
  ldx #PTR_MOON_SPRITE
  jsr set_sprite_data

  rts

; =============================================================================
; assemble_score_digit_pair_sprite
; =============================================================================
;
; Assembles a 2-digit score sprite in RAM from a packed (BCD) score byte stored
; in the SCORE array. The resulting sprite is OR-ed scanline by scanline into
; the in-memory score sprite buffer.
;
; Each byte in SCORE holds two packed decimal digits (one per nibble):
;
;   SCORE layout (little-endian, represents the score "09 99 99"):
;
;     99 99 09
;      0  1  2  <- byte index (reg Y on entry)
;
; The SCORE array is immediately followed by MAX_SCORE in memory, allowing
; the same indexing scheme to be used for both arrays:
;
;     SCORE         MAX_SCORE
;      |                |
;      v                v
;     99 99 09    99 99 09
;      0  1  2     3  4  5  <- value of reg Y
;
; -----------------------------------------------------------------------------
;
; ⚠ IMPORTANT: The complete on-screen score sprite is rendered RTL as:
;
;   SCORE_DIGITS_54  SCORE_DIGITS_32  SCORE_DIGITS_10
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   reg Y  -- index into SCORE (or MAX_SCORE) identifying the digit pair byte
;   reg X  -- base address of the first scanline of the target score sprite
;             in the in-memory sprite buffer. The mapping is:
;
;               Y=0  ->  SCORE[0]  ->  X = SCORE_DIGITS_10
;               Y=1  ->  SCORE[1]  ->  X = SCORE_DIGITS_32
;               Y=2  ->  SCORE[2]  ->  X = SCORE_DIGITS_54
;
assemble_score_digit_pair_sprite subroutine
;
; About TEMP usage:
;
;   TEMP+0  (.FLAGS / .INDEX_SCORE_DIGIT_PAIR)
;             Dual-purpose byte. The lower 7 bits hold the raw reg Y value
;             (the score byte index). The upper bit carries a processing flag:
;               bit 7 -- "lower digit pending" flag (units digit)
;
;   TEMP+1  (.PTR_MEM_SCORE_SPRITE)
;             Preserves the entry value of reg X (the base address of the
;             in-memory score sprite), so it can be restored when processing
;             the second digit.
;
;   TEMP+2  (.TMP)
;             Used as a scratch register during the D*6 address calculation
;             and to temporarily preserve reg A during the scanline zeroing
;             in the lower digit pass.
;
;   TEMP+3  (.SCORE_SPRITE_SCANLINE_COUNTER)
;             The scanline loop counter, initialised to 6 at the start of
;             each digit pass.
;
.FLAGS = TEMP                  ; The 'lower digit' flag will be on the upper
.INDEX_SCORE_DIGIT_PAIR = TEMP ; bit, while the index on the lower bits
.PTR_MEM_SCORE_SPRITE = TEMP+1
.TMP = TEMP+2
.SCORE_SPRITE_SCANLINE_COUNTER = TEMP+3
;
;
  tya
  ora #%10000000            ; Set bit 7: marks the lower (units) digit for
                            ; first-pass processing

  sta .INDEX_SCORE_DIGIT_PAIR
  stx .PTR_MEM_SCORE_SPRITE

; -----------------------------------------------------------------------------
; .process_digit
;
; Isolates one digit from the SCORE byte identified by reg Y, calculates the
; ROM address of its sprite, then copies 6 scanlines into the in-memory score
; sprite buffer.
;
; On entry: reg Y holds the score byte index (flags stripped).
; -----------------------------------------------------------------------------
.process_digit:
  ; Here, Y should have the score index (without any flags)
  ;         ↓
  lda SCORE,y               ; Load the (BCD) score digit pair from RAM
  bit .FLAGS                ; Test bit 7: is the lower (units) digit pending?
  bpl .digit_in_upper_nibble

.digit_in_lower_nibble:
  ; The lower nibble holds the units digit. Reload the digit pair since the
  ; BIT instruction above clobbered the N and V flags but left reg A intact —
  ; however a clean reload is safer and keeps the logic symmetric.
  lda SCORE,y               ; Reload the (BCD) digit pair from RAM
  jmp .isolate_digit

.digit_in_upper_nibble:
  ; The upper nibble holds the tens digit. Shift it down into the lower
  ; nibble so the same isolation logic applies to both cases.
  lsr                       ;
  lsr                       ; reg A >>= 4  (upper nibble -> lower nibble)
  lsr                       ;
  lsr                       ;

.isolate_digit:
  and #%00000111            ; Mask to 3 bits: score digits range 0-9, encoded
                            ; in 3 bits within the nibble

; -----------------------------------------------------------------------------
; ROM sprite address calculation
;
; Digit sprites are stored in ROM as redundant pairs (00, 11, 22, ...), with
; both nibbles of each byte carrying the same digit. Each sprite occupies
; 6 bytes. The base address of the sprite for digit D is computed as:
;
;   offset = D * 6
;
; This is evaluated using only shifts and addition:
;
;   D * 6  =  D * 4  +  D * 2
;          =  D << 2 +  D << 1
;
; The layout of a ROM digit sprite is as follows (SCORE_DIGIT_11 shown):
;
;   SCORE_DIGIT_11:
;                              /---\ lower nibble: digit 1
;     .byte #%01110111  ;⏐ ███ ███
;     .byte #%00100010  ;⏐  █   █
;     .byte #%00100010  ;⏐  █   █
;     .byte #%00100010  ;⏐  █   █
;     .byte #%01100110  ;⏐ ██  ██
;     .byte #%00100010  ;⏐  █   █
;                         \---/ upper nibble: digit 1
;
; Because both nibbles carry the same digit, the same ROM byte serves both
; the lower and upper nibble destination cases — only the masking differs.
;
; After the offset is computed, reg A holds the ROM index. .TMP is free.
; -----------------------------------------------------------------------------
  asl                       ; reg A <- 2 * D
  sta .TMP                  ; .TMP  <- 2 * D
  asl                       ; reg A <- 4 * D
  clc
  adc .TMP                  ; reg A <- 6 * D  [= ROM byte offset]

  ; ===========================================================================
  ; ⚠ IMPORTANT: .TMP is now free for reuse (scratch during scanline copy)
  ; ===========================================================================
  tay                       ; Temporarily park the ROM offset in reg Y
  lda #6                    ; 6 scanlines per digit sprite
  sta .SCORE_SPRITE_SCANLINE_COUNTER
  tya                       ; Restore the ROM offset to reg A

; -----------------------------------------------------------------------------
; .copy_digit_sprite_scanline
;
; Copies 6 scanlines from the ROM digit sprite into the in-memory score sprite
; buffer. On each iteration:
;
;   reg A  -- current ROM sprite byte (both nibbles carry the same digit)
;   reg X  -- address of the current destination scanline in RAM
;   reg Y  -- current ROM byte index (used for indexed ROM reads)
;
; For the lower digit pass, the destination scanline is zeroed before the
; sprite data is OR-ed in, clearing any stale data from a previous frame.
; For the upper digit pass, the OR composites onto whatever the lower digit
; pass already wrote, preserving both digits in the final scanline byte.
; -----------------------------------------------------------------------------
.copy_digit_sprite_scanline:
  tay                       ; Load reg Y with the current ROM offset
  lda SCORE_DIGIT_00,y      ; Fetch the sprite scanline (both nibbles identical)

  bit .FLAGS
  bpl .digit_goes_on_upper_nibble

.digit_goes_on_lower_nibble:
  ; The units digit occupies the lower nibble of the in-memory pair.
  ; The destination scanline is zeroed first to clear stale data, then the
  ; masked sprite is OR-ed in during .compose_digit_sprite.
  ;
  ; reg A is preserved across the zeroing via .TMP.
  sta .TMP
  lda #0
  sta 0,x
  lda .TMP

  ; Mask out the upper nibble, leaving only the lower digit pixels:
  ;
  ;   | ███ ███|                     | ... ███|
  ;   |  █   █ |   After masking     |  .   █ |
  ;   |  █   █ |  upper nibble  -->  |  .   █ |
  ;   |  █   █ |                     |  .   █ |
  ;   | ██  ██ |                     | ..  ██ |
  ;   |  █   █ |                     |  .   █ |
  ;
  and #$0f
  ; The .byte $2C trick turns the following 'and #$f0' into a 'bit abs'
  ; instruction, effectively skipping it without an explicit branch.
  .byte $2C

.digit_goes_on_upper_nibble:
  ; The tens digit occupies the upper nibble of the in-memory pair.
  ; Mask out the lower nibble, leaving only the upper digit pixels:
  ;
  ;   | ███ ███|                     | ███ ...|
  ;   |  █   █ |   After masking     |  █   . |
  ;   |  █   █ |  lower nibble  -->  |  █   . |
  ;   |  █   █ |                     |  █   . |
  ;   | ██  ██ |                     | ██  .. |
  ;   |  █   █ |                     |  █   . |
  ;
  and #$f0

.compose_digit_sprite:
  ; OR the prepared sprite pixel data onto the current in-memory scanline,
  ; preserving any pixels already written by the lower digit pass.
  ora 0,x
  sta 0,x

  inx                       ; Advance to the next RAM scanline
  iny                       ; Advance to the next ROM scanline

  dec .SCORE_SPRITE_SCANLINE_COUNTER
  bne .copy_digit_sprite_scanline

; -----------------------------------------------------------------------------
; After the 6 scanlines are written, check whether the upper (tens) digit
; still needs to be processed. Bit 7 of .FLAGS is set on entry for the lower
; digit pass; if it is still set here, the upper digit has not yet been handled.
; -----------------------------------------------------------------------------
  bit .FLAGS
  bpl .finish

.process_upper_digit:
  ; Restore reg X and reg Y to their entry-condition values, then strip the
  ; flag bit from .INDEX_SCORE_DIGIT_PAIR so reg Y carries only the raw
  ; score byte index into .process_digit.
  ldx .PTR_MEM_SCORE_SPRITE
  ldy .INDEX_SCORE_DIGIT_PAIR
  tya
  and #%01111111            ; Clear bit 7 (the lower digit pending flag)
  tay
  jmp .process_digit

.finish:
  rts
