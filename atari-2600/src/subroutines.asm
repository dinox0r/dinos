;------------------------------------------------------------------------------
; General subroutines
;------------------------------------------------------------------------------

; =============================================================================
; rnd8
; =============================================================================
;
; Updates the RANDOM variable using a Galois LFSR with XOR polynomial $D4,
; producing a new pseudo-random 8-bit value on each call.
;
; Adapted from "Making Games for the Atari 2600" by Steven Hugg,
; section "Random Number Generation".
;
; -----------------------------------------------------------------------------
; Parameters:   none
;
; -----------------------------------------------------------------------------
; Result:
;
;   reg A   -- new pseudo-random byte
;   RANDOM  -- updated in place
;
rnd8 subroutine
  lda RANDOM   ; 3 (3)
  lsr          ; 2 (5)  - shifts LSB into carry
  bcc .no_xor  ; 2/3 (7/8)
  eor #$D4     ; 2 (9)
.no_xor:
  sta RANDOM   ; 3 (12/11)
  rts          ; 6 (18/17)

;------------------------------------------------------------------------------
; Obstacle related subroutines
;------------------------------------------------------------------------------

; =============================================================================
; set_sprite_data
; =============================================================================
;
; Adjusts a ROM address by subtracting the sprite's Y coordinate and stores
; the resulting pointer in a zero-page address pair. Used to compute the
; correct starting address for indexed sprite reads during the kernel.
;
; The operation performed is:
;
;   sec
;   lda #<SOME_ROM_ADDRESS    ; low byte of base address
;   sbc PARAM_SPRITE_Y        ; subtract Y offset
;   sta ZERO_PAGE_ADDRESS
;   lda #>SOME_ROM_ADDRESS    ; high byte of base address
;   sbc #0                    ; propagate carry from low byte subtraction
;   sta ZERO_PAGE_ADDRESS+1
;
; Example:
;
;   SOME_ROM_ADDRESS = $F252, PARAM_SPRITE_Y = 10
;   → adjusted address = $F252 - 10 = $F248
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   reg A           -- low byte of the ROM base address
;   reg Y           -- high byte of the ROM base address
;   reg X           -- zero-page destination pointer (ZERO_PAGE_ADDRESS)
;   PARAM_SPRITE_Y  -- sprite Y coordinate (alias for TEMP+1)
;
; -----------------------------------------------------------------------------
; Result:
;
;   (X)    -- low byte of the adjusted address
;   (X+1)  -- high byte of the adjusted address
;
set_sprite_data subroutine
  sec                ; 2 (2)
  sbc PARAM_SPRITE_Y ; 3 (5)  - subtract Y offset from low byte
  sta $00,x          ; 4 (9)  - store adjusted low byte
  tya                ; 2 (11) - load high byte of base address
  sbc #0             ; 2 (13) - propagate carry into high byte
  sta $01,x          ; 4 (17) - store adjusted high byte
  rts                ; 6 (23)

; =============================================================================
; spawn_obstacle
; =============================================================================
;
; Spawns a new obstacle at the right edge of the screen with a randomised
; fractional X offset, type, and Y position. Optionally enables sprite
; duplication for cactus-type obstacles.
;
; Obstacle types:
;   0  -- no obstacle (invisible; X is clamped to [0, 127] for a breather)
;   1  -- pterodactyl with open wings
;   2  -- pterodactyl with closed wings
;   3+ -- cactus (eligible for duplication)
;
; ⚠ NOTE: OBSTACLE_TYPE is currently hardcoded to 3 for debugging. The random
;          type selection code is present but overridden by the lda #3 below.
;
; -----------------------------------------------------------------------------
; Parameters:   none
;
; -----------------------------------------------------------------------------
; Side effects:
;
;   OBSTACLE_X_INT      -- set to 161 (right edge)
;   OBSTACLE_X_FRACT    -- set to a random value
;   OBSTACLE_TYPE       -- set to the chosen obstacle type
;   OBSTACLE_Y          -- set based on type (fixed cactus Y or random ptero Y)
;   OBSTACLE_DUPLICATE  -- cleared; may be set if duplication is enabled
;   GAME_FLAGS          -- FLAG_DUPLICATED_OBSTACLE cleared or set
;
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

; =============================================================================
; reset_cloud
; =============================================================================
;
; Resets a cloud slot to a new X position with a small random offset in [0, 31].
; For the single-cloud sky layer (reg X == 0), also assigns a new random Y
; position placing the cloud below the sky margin.
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   reg A  -- base X position for the cloud
;   reg X  -- cloud slot index:
;               0  →  single-cloud layer (also randomises CLOUD_1_TOP_Y)
;               1  →  first cloud in the double-cloud layer
;               2  →  second cloud in the double-cloud layer
;
; -----------------------------------------------------------------------------
; Side effects:
;
;   CLOUD_1_X,x    -- set to A plus a random offset in [0, 31]
;   CLOUD_1_TOP_Y  -- updated with a random Y value (only when reg X == 0)
;
reset_cloud subroutine
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

; =============================================================================
; set_cloud_pos_x
; =============================================================================
;
; Positions GRP0 (P0) and GRP1 (P1) horizontally for a stitched 2-part cloud
; sprite. Must be called from within the kernel at the right point in the
; scanline.
;
; ⚠ TIMING: Consumes up to 27 cycles of the current scanline, then a full
;            second scanline for coarse positioning. Returns at cycle 33 of
;            the third scanline.
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   reg A  -- cloud X position
;
; -----------------------------------------------------------------------------
; Result:   GRP0/GRP1 horizontal positions set; HMOVE pending
;
set_cloud_pos_x subroutine
  SET_STITCHED_SPRITE_X_POS #PLAYER_0_INDEX, #PLAYER_1_INDEX
  rts ; 6 (33)

; =============================================================================
; render_cloud_layer
; =============================================================================
;
; Renders a cloud layer on screen by positioning GRP0/GRP1 then running
; CLOUD_KERNEL for the configured number of scanlines. Selects which player
; registers to use based on the cloud's X position: left edge (GRP1 only),
; fully visible (both), right edge (GRP0 only), or off-screen (neither).
;
; ⚠ TIMING: Kernel-time subroutine. Consumes scanlines for sprite positioning
;            via set_cloud_pos_x, then additional scanlines for the cloud body.
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   reg A                 -- cloud X position
;   CURRENT_CLOUD_X       -- cloud X position (used for visibility branching)
;   CURRENT_CLOUD_TOP_Y   -- Y coordinate of the cloud top
;   CLOUD_LAYER_SCANLINES -- number of scanlines to render
;
; -----------------------------------------------------------------------------
; Side effects:   GRP0, GRP1, HMOVE strobed each scanline
;
render_cloud_layer subroutine
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

; =============================================================================
; reset_star
; =============================================================================
;
; Resets the star to the right edge of the screen with a new random Y position
; in [6, 21]. Alternates between STAR_1_SPRITE and STAR_2_SPRITE on each call
; using the SKY_FLAG_STAR_SPRITE bit in SKY_FLAGS.
;
; -----------------------------------------------------------------------------
; Parameters:   none
;
; -----------------------------------------------------------------------------
; Side effects:
;
;   STAR_POS_X      -- set to MAX_MOON_AND_STAR_POS_X
;   STAR_POS_Y      -- set to a random value in [6, 21]
;   PARAM_SPRITE_Y  -- updated (alias for TEMP+1)
;   PTR_STAR_SPRITE -- updated to point to the selected star sprite
;   SKY_FLAGS       -- SKY_FLAG_STAR_SPRITE bit toggled
;
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

; =============================================================================
; reset_moon
; =============================================================================
;
; Resets the moon to the right edge of the screen and advances to the next
; moon phase. Delegates phase advancement and sprite pointer setup to
; change_moon_phase.
;
; -----------------------------------------------------------------------------
; Parameters:   none
;
; -----------------------------------------------------------------------------
; Side effects:
;
;   MOON_POS_X      -- set to MAX_MOON_AND_STAR_POS_X
;   PARAM_SPRITE_Y  -- set to MOON_POS_Y (alias for TEMP+1)
;   PTR_MOON_SPRITE -- updated by change_moon_phase
;   SKY_FLAGS       -- moon phase counter updated by change_moon_phase
;
reset_moon subroutine
  lda #MAX_MOON_AND_STAR_POS_X
  sta MOON_POS_X

  lda #MOON_POS_Y
  sta PARAM_SPRITE_Y

  jsr change_moon_phase
  rts

; =============================================================================
; change_moon_phase
; =============================================================================
;
; Advances the moon phase counter stored in the lower 2 bits of SKY_FLAGS and
; updates PTR_MOON_SPRITE to point to the appropriate sprite. The counter
; cycles through 3 states, wrapping at 3 back to 0:
;
;   counter 1  →  crescent phase
;   counter 2  →  full moon phase
;   counter 0  →  crescent phase  (after wrap from 3 → 0)
;
; ⚠ IMPORTANT: PARAM_SPRITE_Y must be set to the moon's Y position before
;               calling, as it is forwarded to set_sprite_data internally.
;
; -----------------------------------------------------------------------------
; Parameters:
;
;   PARAM_SPRITE_Y  -- moon Y coordinate (alias for TEMP+1); must be set by
;                      the caller before invoking this subroutine
;
; -----------------------------------------------------------------------------
; Side effects:
;
;   PTR_MOON_SPRITE -- updated to point to the phase-appropriate moon sprite
;   SKY_FLAGS       -- lower 2 bits (moon phase counter) incremented and
;                      wrapped at 3 → 0
;
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
;   reg Y  -- index into SCORE (or MAX_SCORE) identifying the digit pair byte.
;             The base address of the corresponding in-memory score sprite
;             buffer is computed internally as:
;
;               SCORE_DIGITS_10 + (Y * 6)
;
;             The mapping is:
;
;               Y=0  ->  SCORE[0]  ->  SCORE_DIGITS_10
;               Y=1  ->  SCORE[1]  ->  SCORE_DIGITS_32
;               Y=2  ->  SCORE[2]  ->  SCORE_DIGITS_54
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
;             Preserves the computed base address of the in-memory score sprite
;             buffer, so it can be restored when processing the second digit.
;
;   TEMP+2  (.SCORE_SPRITE_SCANLINE_COUNTER)
;             The scanline loop counter, initialised to 6 at the start of
;             each digit pass.
;
;   TEMP+3  (.TMP)
;             Used as a scratch register during the D*6 address calculations
;             and to temporarily preserve reg A during the scanline zeroing
;             in the lower digit pass.
;
.FLAGS = TEMP                  ; The 'lower digit' flag will be on the upper
.INDEX_SCORE_DIGIT_PAIR = TEMP ; bit, while the index on the lower bits
.PTR_MEM_SCORE_SPRITE = TEMP+1
.SCORE_SPRITE_SCANLINE_COUNTER = TEMP+2
.TMP = TEMP+3

  ; Compute the base address of the in-memory score sprite buffer for this
  ; digit pair. Each sprite buffer occupies 6 bytes, so the offset from
  ; SCORE_DIGITS_10 is Y * 6.
  tya
  jsr multiply_by_6
  clc
  adc #SCORE_DIGITS_10
  tax

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
  bmi .digit_in_lower_nibble

.digit_in_upper_nibble:
  ; The upper nibble holds the tens digit. Shift it down into the lower
  ; nibble so the same isolation logic applies to both cases.
  lsr                       ;
  lsr                       ; reg A >>= 4  (upper nibble -> lower nibble)
  lsr                       ;
  lsr                       ;

.digit_in_lower_nibble:
  ; Nothing to do

.isolate_digit:
  and #$0f

; -----------------------------------------------------------------------------
; ROM sprite address calculation
;
; Digit sprites are stored in ROM as redundant pairs (00, 11, 22, ...), with
; both nibbles of each byte carrying the same digit. Each sprite occupies
; 6 bytes. The base address of the sprite for digit D is computed as:
;
;   offset = D * 6
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
  jsr multiply_by_6

  tay                       ; Set the ROM offset in reg Y
  lda #6                    ; 6 scanlines per digit sprite
  sta .SCORE_SPRITE_SCANLINE_COUNTER

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

  inx  ; Advance to the next RAM scanline
  iny  ; Advance to the next ROM scanline

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
  sta .FLAGS
  tay
  jmp .process_digit

.finish:
  rts

; =============================================================================
; multiply_by_6
; =============================================================================
;
; Multiplies the value in reg A by 6 using only shifts and addition:
;
;   A * 6  =  A * 4  +  A * 2
;          =  A << 2 +  A << 1
;
; Parameters:
;   reg A  -- value to multiply (must be <= 42 to avoid overflow)
;
; Result:
;   reg A  -- reg A * 6
;
; Note: .TMP (TEMP+3) is used as a scratch register and is not
;       preserved across the call.
;
multiply_by_6 subroutine
.TMP = TEMP+3
  asl                       ; reg A <- 2 * A
  sta .TMP                  ; .TMP  <- 2 * A
  asl                       ; reg A <- 4 * A
  clc
  adc .TMP                  ; reg A <- 6 * A
  rts
