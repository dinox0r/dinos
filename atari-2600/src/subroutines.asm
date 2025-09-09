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
; set_obstacle_data: Computes a ROM address offset by OBSTACLE_Y and
;                    stores the result in a zero-page pointer.
;
; Description:
;   This subroutine adjusts a given ROM address by subtracting OBSTACLE_Y
;   and stores the resulting address in a zero-page pointer.
;
;   The operation is equivalent to:
;
;      sec                     ; Set carry for subtraction
;      lda #<SOME_ROM_ADDRESS   ; Load low byte of base address
;      sbc OBSTACLE_Y           ; Subtract Y offset
;      sta ZERO_PAGE_ADDRESS    ; Store low byte of result
;      lda #>SOME_ROM_ADDRESS   ; Load high byte of base address
;      sbc #0                   ; Subtract carry (propagating from low byte)
;      sta ZERO_PAGE_ADDRESS+1  ; Store high byte of result
;
; Parameters:
;   A  - Low byte of SOME_ROM_ADDRESS
;   Y  - High byte of SOME_ROM_ADDRESS
;   X  - Zero-page pointer location (i.e., ZERO_PAGE_ADDRESS)
;
; Result:
;   (X)   = Low byte of adjusted address
;   (X+1) = High byte of adjusted address
;
; Example:
;   If SOME_ROM_ADDRESS = $F252 and OBSTACLE_Y = 10:
;     Adjusted address = $F252 - 10 = $F248
;     ZERO_PAGE_ADDRESS (at X) now holds $F248.
;
set_obstacle_data subroutine
  sec             ; 2 (2) Ensure subtraction works correctly
  sbc OBSTACLE_Y  ; 3 (5) Subtract Y offset from low byte
  sta $00,x       ; 4 (9) Store adjusted low byte at pointer X
  tya             ; 2 (11) Load high byte of original address
  sbc #0          ; 2 (13) Subtract carry from high byte
  sta $01,x       ; 4 (17) Store adjusted high byte at pointer X+1
  rts             ; 6 (23) Return from subroutine

spawn_obstacle subroutine
  jsr rnd8
  sta OBSTACLE_X_FRACT
  lda #161
  sta OBSTACLE_X_INT

  jsr rnd8
  and #3 ; equivalent to RND % 4
  sta OBSTACLE_TYPE
  bne .set_y_pos
  ; If is the obstacle type 0 (no obstacle or invisible obstacle)
  ; then overwrite its x coordinate to a value between [0, 127], this is
  ; to give a breather to the player but not for too long
  jsr rnd8
  and #127
  sta OBSTACLE_X_INT

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
  sta CLOUD_1_X_INT,x
  jsr rnd8
  and #15
  ; Add a small x random offset
  adc CLOUD_1_X_INT,x
  sta CLOUD_1_X_INT,x

  jsr rnd8
  sta CLOUD_1_X_FRACT,x

  ; If X == 0, this resets the cloud for the single-cloud sky.
  ; If X >= 1, this is one of the two clouds in the double-cloud sky.
  cpx #0
  beq .end_reset_cloud

  ; For the single-cloud sky (reg X == 0), allow a random vertical
  ; placement by masking with AND #15 (i.e., range 0–15).
  jsr rnd8
  and #15
  ; Add a base offset to the Y value, placing the cloud below the HUD
  ; or sky margin. The carry flag is not cleared, as the result doesn't
  ; need to be precise. Leaving the carry random adds slight variation.
  adc #CLOUD_HEIGHT+#2
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
  jsr set_cloud_pos_x       ; 6 for jsr + 27 of the subroutine (+33)
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

set_stitched_sprite_x_pos subroutine
  ; sta HMOVE                      ; 3 
  ; ldx something                  ; 3 (6) - x index object 1
  ; ldy something-else             ; 3 (9) - y index object 2
  ; jsr set_stitched_sprite_x_pos  ; 6 (15)
  ; 1st (current) scanline ==================================================

  ; Save copies of the object indexes
  stx TEMP        ; 3 (18 or more depending the caller state)
  sty TEMP+1      ; 3 (21+)
  ;
  ; ⚠ IMPORTANT: This assumes the sprite X position is already in reg A
  ;
  ; Logic summary:
  ; if (reg A ≤ 8) {
  ;   case 1: object1 is fully offscreen (to the left), object2 is partially
  ;   visible
  ; } else if (reg A ≤ 16) {
  ;   case 2: object1 is partially visible, object2 is fully visible
  ; } else if (reg A > 162) {
  ;   case 4: object1 is partially offscreen (to the right), object2 is fully
  ;   hidden
  ; } else if (reg A > 170) {
  ;   case 5: both objects are fully hidden, strobe their registers
  ;   on HBLANK so to make sure they stay out of screen (hidden behind the
  ;   the HMOVE black curtain
  ; } else {
  ;   setup logic before invoking case 3
  ;   case 3: both object1 and object2 are fully visible
  ; }
  cmp #8                                                  ; 2 (5)
  bcc .case_1__obj1_fully_hidden_obj2_partially_visible   ; 2/3 (7/8)
  cmp #17                                                 ; 2 (9)
  bcc .case_2__obj1_partially_visible_obj2_fully_visible  ; 2/3 (11/12)
  cmp #171
  bcs .case_5__both_obj1_and_obj2_fully_hidden
  cmp #163                                                ; 2 (13)
  bcs .case_4__obj1_partially_visible_obj2_fully_hidden   ; 2/3 (15/16)

.prepare_before_invoking_case_3: ; - (15)
    ; Based on results from tools/simulate-coarse-pos-loop.py: Starting with an
    ; input value of #45, the coarse positioning algorithm sets the object's
    ; coarse location and leaves a remainder in register A within the range
    ; [-7, 7], suitable for HMOVE fine adjustment.
    ;
    ; The earliest screen position set by this routine is physical pixel 5 (the
    ; 6th pixel, zero-indexed). Earlier positions are handled by: 
    ; - Case 1: input x = 0 to 8 → offscreen (pixels -8 to 0)
    ; - Case 2: input x = 9 to 16 → HMOVE blanking area (pixels 1 to 8)
    ;
    ; The latest valid position before requiring another scanline is pixel 154
    ; (indexed as 153), which corresponds to input x = 162.
    ;
    ; Thus, Case 3 handles obstacle_x values from 16 (maps to screen pixel 8)
    ; up to 162 (maps to pixel 153).
    ;
    ; To align with the algorithm's expected input range, obstacle_x = 16 must
    ; be translated to x = 3 (the value that places at pixel 8), so 13 is
    ; subtracted from the base input (#45).
    clc          ; 2 (17)
    adc #45-#13  ; 2 (19)

    sec   ; 2 (21) - Set carry to do subtraction. Remember SBC is
          ;          actually an ADC with A2 complement
          ;          A - B = A + ~B + 1
          ;                           ^this is the carry set by sec

    jmp .case_3__obj1_and_obj2_fully_visible       ; 3 (24)

.case_1__obj1_fully_hidden_obj2_partially_visible: ; - (8)
    sta WSYNC      ; 3 (11)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)
    ; Strobing M1 after HMOVE set the missile coarse position on screen pixel 
    ; 3 (the fourth pixel starting from pixel 0). This was found after testing
    ; taking screenshots in Stella. The offset needs to be adjusted for those
    ; 4 pixels by doing a -4 fine adjustment with HMM1. GRP1 position doesn't 
    ; matter as it will be zero (as it's offscreen)
    sta RESP0,y        ; 4 (7)
    ; This doesn't matter, as it should have 0 as value (is not visible)
    ;sta OBJECT_1
    ; offset calculation
    sec
    sbc #15-#4
    jmp .end_of_cases_1_2_and_3

.case_2__obj1_partially_visible_obj2_fully_visible: ; - (12)
    sta WSYNC      ; 3 (15)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)
    sta RESP0,x    ; 4 (7)

    ; Strobing RESPx at this point places the GRP1 coarse position at screen
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

    pha      ; 3 (13) wait/waste 12 CPU cycles (in 4 bytes) until the CPU is at
    pla      ; 4 (17) cycle 22 so strobing RESM1 leaves it 8px from where GRP1
    nop      ; 2 (19)
    lda #$F0 ; 2 (21)

    ; Strobing RESP0,y at CPU cycle 25 works well regardless
    ; y index refers to a GRPx or a MISSILE
    sta RESP0,y   ; 4 (25)

    ; At cycle 25, M1 appears 7px to the right of GRP1 instead of 8px. To fix
    ; this 1px misalignment, here a slight nudge to the right is applied to M1
    ; using HMM1

    ;--------------------------------------------------------------------------
    ; [!] ROM space potential savings
    ;--------------------------------------------------------------------------
    ; Once ROM becomes critical, this offset code can be removed. In that
    ; case, the 12-cycle setup before strobing RESP0,y could be
    ; replaced with a cheaper 'inc $2D' instruction.
    ;
    ; Side effect: When the stitched sprite exits the screen on the left edge,
    ; a small visual artifact will appear. The glitch is noticeable but minor,
    ; and may be an acceptable trade-off for the ROM savings.
    ;--------------------------------------------------------------------------
    sta HMP0,y    ; 4 (29)

    jmp .end_of_cases_1_2_and_3 ; 3 (32)

.case_4__obj1_partially_visible_obj2_fully_hidden: ; - (16)
    sta WSYNC      ; 3 (19)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)


    ; reg A now holds the correct offset index to be used later during
    ; the 4th scanline. The CPU is currently at cycle 7 and must reach cycle 71,
    ; leaving 64 cycles to waste.
    ;
    ; The following loop consumes 59 cycles:
    ;   - 11 iterations × 5 cycles (DEY + BNE) = 55 cycles
    ;   - Final iteration (DEY + BNE fails) = 4 cycles
    ldy #12         ; 2 (5)
.wait_until_cpu_is_at_cycle_68:         ; - (5) \
    dey                                 ; 2      > total: 59 cycles
    bne .wait_until_cpu_is_at_cycle_68  ; 2/3   /

    ; For case 4, RESP1 will be strobed at CPU cycle 70. The strobe completes
    ; at cycle 73.
    ;
    ; Theoretically, strobing RESP1 at CPU cycle 73 corresponds to TIA cycle 219
    ; (73 * 3), which should map to screen pixel 151 (219 - 68 cycles of HBLANK),
    ; but in practice, GRP1 appears at screen pixel 156... Go figure ¯\_(ツ)_/¯
    ;
    ; First, configure the fine offset. Then, delay until cycle 70 for RESP1.
    ;
    ; The rightmost position case 3 can handle without resorting to an extra 
    ; scanline is x=162 which maps to screen pixel 154, case 4 should continue
    ; from here, meaning the input x will be 163 onwards.
    ;
    ; For obstacle_x = 163, the obstacle should appear at screen pixel 155.
    ; However, the coarse position after strobing RESP1 at cycle 73 results in
    ; GRP1 being placed at screen pixel 156. This requires an offset of -1 pixels
    ; to correct the position. Similarly:
    ;   x = 164 → offset -2
    ;   x = 165 → offset -3
    ;   ...
    ;   x = 171 → offset +4
    sec             ; 2 (64 -> 66)
    ; reg A contains x ∈ [163, 171]
    ; x needs to be mapped to index ∈ [6, 11] (offsets from -1 to 4)
    ; This is computed as: x - 157
    ; But A will later be shared with case 1, 2 and 3 logic, which subtract 15.
    sbc #157+#15        ; 2 (68)

    ; The CPU is now at cycle 68
    sta RESP0,x     ; 4 (72)

    jmp .end_case_4               ; 3 (75)

.case_5__both_obj1_and_obj2_fully_hidden:
    sta WSYNC      ; 3 (?)
    ; 2nd scanline ============================================================
    sta HMOVE      ; 3 (3)
    sta RESP0,x
    sta RESP1,y
    sta WSYNC
    sta HMOVE
    jmp .end_case_5


.case_3__obj1_and_obj2_fully_visible: ; - (24)
    sta WSYNC      ; 3 (27)
    ; 2nd scanline ============================================================
                   ; - (0)
    sta HMOVE      ; 3 (3)

.div_by_15_loop:        ; - (3)
    sbc #15             ; 2 (5) - Divide by 15 (sucessive subtractions)
    bcs .div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)

    sta RESP0,x
    sta RESP0,y

.end_of_cases_1_2_and_3:
    sta WSYNC      ; if coming from scenario A, CPU count after this will be 33
                   ; if coming from scenario B, MAX CPU count will be 76
                   ; scenario A will jump past this 'sta WSYNC' and below's
                   ; 'sta HMOVE' (scenario A will take care of the HMOVE)
    ; 3rd scanline ============================================================
.end_case_4:
                   ; - (0)
    sta HMOVE      ; 3 (3)

    ; Offsets the remainder from [-14, 0] to [0, 14]
    ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
    clc            ; 2 (5)
    adc #15        ; 2 (7)

    ;lda #7        ; For DEBUGing, overrides the offset entry index to the 0 offset

    tay            ; 2 (9)


    LAX FINE_POSITION_OFFSET,y  ; 4 (13) - y should range between [-7, 7]

    ; Instead of using the same offset for both, use a +1 offset for 
    ; object1, this will move it 1px to the right, stitching both objects
    ; without a seam
    iny                         ; 2 (15)

    lda FINE_POSITION_OFFSET,y  ; 4 (19) - y should range between [-7, 7]

    ; At this point, reg X has the offset for object1, and reg A has
    ; the offset for object2
    ldy TEMP+1                  ; 3 (22) - Load in reg Y the index of obj2
    sta HMP0,y                  ; 4 (26) - Store object2's offset
    ldy TEMP                    ; 3 (29) - Now load in reg Y the index of obj1
    stx HMP0,y                  ; 4 (33) - Store object1's offset
.end_case_5:
    ;❗ IMPORTANT: Caller is responsible of invoking 'sta WSYNC' / 'sta HMOVE'
    rts           ; 6 (39)
