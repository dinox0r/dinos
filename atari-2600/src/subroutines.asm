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
  ; Assumes register A contains the new X integer position for the cloud.
  ; The value is stored into the appropriate cloud slot (indexed by X).
  sta CLOUD_1_X_INT,x

  jsr rnd8
  sta CLOUD_1_X_FRACT,x

  ; If X == 0, this resets the cloud for the single-cloud sky.
  ; If X >= 1, this is one of the two clouds in the double-cloud sky.
  cpx #0
  beq .single_cloud_layer

  ; For a double-cloud sky, restrict the random Y offset to 2 bits (0–3)
  ; using AND #3. The vertical range is narrower since each cloud is
  ; drawn smaller and must fit within the same number of #SKY_SCANLINES
  ; as the taller single-cloud variant.
  and #3

  ; Trick: if the branch above is not taken (X > 0), skip the AND #15
  ; by turning the next instruction (AND #15) into a harmless BIT.
  ; $2C is the opcode for BIT, which turns the next two bytes
  ; into an ignored address operand, effectively forming a 3-byte NOP.
  .byte $2C

.single_cloud_layer:
  ; For the single-cloud sky (X == 0), allow a larger random vertical
  ; placement by masking with AND #15 (i.e., range 0–15).
  and #15

  ; Add a base offset to the Y value, placing the cloud below the HUD
  ; or sky margin. The carry flag is not cleared, as the result doesn't
  ; need to be precise. Leaving the carry random adds slight variation.
  adc #CLOUD_HEIGHT+#2
  sta CLOUD_1_TOP_Y,x
  rts

set_cloud_pos_x subroutine
  ; The macro adds 27 cycles to current scanline, then ends it
  ; and consumes a whole new scanline for the positioning
  SET_STITCHED_SPRITE_X_POS #PLAYER_0_INDEX, #PLAYER_1_INDEX, #USE_SEAMLESS_STITCHING
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

