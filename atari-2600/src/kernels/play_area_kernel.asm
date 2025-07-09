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
  sta $2D       ; 3 (6)

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
; routines (or cases). Three of these cover situations where the obstacle is 
; partially or fully obscured by the left or right edges of the screen. 
; The third routine (case 3) handles most visible, on-screen placements but 
; cannot accommodate those edge cases.
;
; To simplify positioning logic and avoid signed arithmetic, obstacle_x values 
; are treated as unsigned integers in the range 0–168. The visible Atari 2600 
; screen is 160 pixels wide, with the first 8 pixels of each scanline obscured 
; by the HMOVE blanking interval.
;
; ┌ obstacle pos (obstacle_x)
; │┌ screen pixel
; ││                                           obstacle_x = screen_x + 8
; ││                                                      |
; │└→ -8 -7 ... -1 0     ...     8           ...          |  █    160 161 ...
; └──→ 0  1 ...  7 8     ...    16           ...          ↓  █ █  168 169 ...
;                ↓ ↓             ↓                         █ █ █   ↓ ↓
;      ____ ... __│▓▓▓ HMOVE ▓▓▓|_____       ...            ███_____│______
;                 │▓▓▓ black ▓▓▓|                            █      │
;                 │▓▓▓ area  ▓▓▓|                            █      │
;                 ↑                                                 ↑
;       left edge of the screen                        right edge of the screen
;
;  ┌→ │ 0 ≤ x ≤ 8 │  8 < x ≤ 16 │        16 < x ≤ 162        │ x > 162 │
;  │  ├───────────┼─────────────┼────────────────────────────┼─────────┤
;  │  │   case 1  │    case 2   │          case 3            │  case 4 │
;  │  └───────────┴─────────────┴────────────────────────────┴─────────┘
;  └─── "x" refers to obstacle position (obstacle_x)
_set_obstacle_x_position:
  sta HMCLR        ; 3 (Worst case scenario CPU count at this point is 37)

  ; Logic summary:
  ; if (obstacle_x ≤ 8) {
  ;   case 1: GRP1 is fully offscreen (to the left), M1 is partially visible
  ; } else if (obstacle_x ≤ 16) {
  ;   case 2: GRP1 is partially visible, M1 is fully visible
  ; } else if (obstacle_x > 162) {
  ;   case 4: GRP1 is partially offscreen (to the right), M1 is fully hidden
  ; } else {
  ;   setup logic before invoking case 3
  ;   case 3: both GRP1 and M1 are fully visible
  ; }
  lda OBSTACLE_X_INT                                   ; 3 (40)
  cmp #9                                               ; 2 (42)
  bcc _case_1__p1_fully_hidden_m1_partially_visible    ; 2/3 (44/45)
  cmp #17                                              ; 2 (46)
  bcc _case_2__p1_partially_visible_m1_fully_visible   ; 2/3 (48/49)
  cmp #163                                             ; 2 (50)
  bcs _case_4__p1_partially_visible_m1_fully_hidden    ; 2/3 (52/53)

_prepare_before_invoking_case_3:
  ; Based on results from tools/simulate-coarse-pos-loop.py:
  ; Starting with an input value of #45, the coarse positioning algorithm sets
  ; the object's coarse location and leaves a remainder in register A within 
  ; the range [-7, 7], suitable for HMOVE fine adjustment.
  ;
  ; The earliest screen position set by this routine is physical pixel 5 
  ; (the 6th pixel, zero-indexed). Earlier positions are handled by:
  ;   - Case 1: input x = 0 to 8 → offscreen (pixels -8 to 0)
  ;   - Case 2: input x = 9 to 16 → HMOVE blanking area (pixels 1 to 8)
  ;
  ; The latest valid position before requiring another scanline is pixel 154 
  ; (indexed as 153), which corresponds to input x = 162.
  ;
  ; Thus, Case 3 handles obstacle_x values from 16 (maps to screen pixel 8) 
  ; up to 162 (maps to pixel 153).
  ;
  ; To align with the algorithm's expected input range, obstacle_x = 16 must be
  ; translated to x = 3 (the value that places at pixel 8), so 13 is subtracted
  ; from the base input (#45).
  clc          ; 2 (52)
  adc #45-#13  ; 2 (54)

  sec      ; 2 (56) - Set carry to do subtraction. Remember SBC is
           ;          actually an ADC with A2 complement
           ;          A - B = A + ~B + 1
           ;                           ^this is the carry set by sec

  jmp _case_3__p1_and_m1_fully_visible ; 3 (59)

_case_1__p1_fully_hidden_m1_partially_visible:
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
  ;sta RESP1
  ; offset calculation
  sec
  sbc #15-#4
  jmp _end_of_cases_1_2_and_3

_case_2__p1_partially_visible_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline ================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  sta RESP1        ; 3 (6)

  ; Strobing RESP1 at this point places the GRP1 coarse position at screen
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

  pha      ; 12 (22) wait/waste 12 CPU cycles (in 4 bytes) until the CPU is at
  pla      ;         cycle 22 so strobing RESM1 leaves it 8px from where GRP1
  inc $2D  ;         was strobed

  sta RESM1        ; 3 (25)

  ; At cycle 25, M1 appears 7px to the right of GRP1 instead of 8px. To fix
  ; this 1px misalignment, here a slight nudge to the right is applied to M1
  ; using HMM1
  ldx #$F0         ; 2 (27) - 1px to the right
  stx HMM1         ; 3 (30)

  jmp _end_of_cases_1_2_and_3 ; 3 (33)

_case_4__p1_partially_visible_m1_fully_hidden:
  sta WSYNC        ; 3 (48)
  ; 3rd scanline (scenario C: obstacle_x ≥ 158) ==========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

  ; For case 4, RESP1 must be strobed at CPU cycle 71. The strobe completes
  ; at cycle 74, leaving just enough space for a 2-cycle instruction (like
  ; 'nop') before the scanline ends. There is no room for a 'sta WSYNC'.
  ;
  ; Theoretically, strobing RESP1 at CPU cycle 74 corresponds to TIA cycle 222
  ; (74 * 3), which should map to screen pixel 154 (222 - 68 cycles of HBLANK),
  ; but in practice, GRP1 appears at screen pixel 159... Go figure ¯\_(ツ)_/¯
  ;
  ; First, configure the fine offset. Then, delay until cycle 71 for RESP1.
  ;
  ; The rightmost position case 3 can handle without resorting to an extra 
  ; scanline is x=162 which maps to screen pixel 154, case 4 should continue
  ; from here, meaning the input x will be 163 onwards.
  ;
  ; For obstacle_x = 163, the obstacle should appear at screen pixel 155.
  ; However, the coarse position after strobing RESP1 at cycle 74 results in
  ; GRP1 being placed at screen pixel 159. This requires an offset of -4 pixels
  ; to correct the position. Similarly:
  ;   x = 164 → offset -3
  ;   x = 165 → offset -2
  ;   ...
  ;   x = 171 → offset +1

  sec             ; 2 (5)
  ; reg A contains x ∈ [163, 171]
  ; x needs to be mapped to index ∈ [3, 8] (offsets from -4 to +1)
  ; This is computed as: x - 160
  ; But A will later be shared with case 1, 2 and 3 logic, which subtract 15.
  sbc #160+#15        ; 2 (7)

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
  jmp _end_case_4

_case_3__p1_and_m1_fully_visible:
  sta WSYNC        ; 3 (42/48)
  ; 3rd scanline (scenario B: obstacle 9 ≤ x ≤ 157) ===========================
                   ; - (0)
  sta HMOVE        ; 3 (3)

__div_by_15_loop:      ; - (3)
  sbc #15              ; 2 (5) - Divide by 15 (sucessive subtractions)
  bcs __div_by_15_loop ; 2/3     (obstacle-x / 5 + 5)

  sta RESP1
  sta RESM1

_end_of_cases_1_2_and_3:
  sta WSYNC        ; if coming from scenario A, CPU count after this will be 33
                   ; if coming from scenario B, MAX CPU count will be 76
                   ; scenario A will jump past this 'sta WSYNC' and below's
                   ; 'sta HMOVE' (scenario A will take care of the HMOVE)
  ; 4th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)

_end_case_4:
  ; Clear reg X to make sure no graphics are drawn in the first scanline of
  ; the sky_kernel
  ldx #0           ; 2 (5) - Do the fine offset in the next scanline, I'm
                   ;         avoiding doing it in the

  pha              ; 4 (9) - Wait/waste 7 cycles (2 bytes)
  pla              ; 3 (12)

  ; Offsets the remainder from [-14, 0] to [0, 14]
  ; where A = 0 aligns with FINE_POSITION_OFFSET[0] = -7
  clc             ; 2 (14)
  adc #15         ; 2 (16)
  ;lda #7 ; DEBUG

  tay                         ; 2 (18)
  lda FINE_POSITION_OFFSET,y  ; 4 (22) - y should range between [-7, 7]
  ; Apply the fine offset to both the GRP1 and the BALL, these won't shift the
  ; coarse position set above until the next time HMOVE is strobed
  sta HMP1       ; 3 (25)
  sta HMM1       ; 3 (28)

  sta WSYNC      ; 3 (31)

_last_setup_scanline:
  ; 5th scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  ldy #PLAY_AREA_TOP_Y   ; 2 (5)

  lda #FLAG_DINO_CROUCHING   ; 2 (7)
  bit GAME_FLAGS             ; 3 (10)
  bne __assign_crouching_kernel  ; 2/3 (12/13)

  lda #<legs_and_floor_kernel      ; 2 (14)
  sta PTR_AFTER_PLAY_AREA_KERNEL   ; 3 (17)
  lda #>legs_and_floor_kernel      ; 2 (19)
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
  sec         ; 2 (32/30) Set the carry ahead of time for the next scanline

  ; Remove the fine offsets applied to the obstacles before going to the next 
  ; scanline, also leave the other motion registers in a clear state
  sta HMCLR   ; 3 (35/33) 

  ; We are assuming that reg A has the obstacle graphics, which go to GRP1
  ; and that reg X has the BALL state for the obstacle additional graphics, 
  ; so we have to 0 both before the first scanline of the sky kernel
  lda #0
  tax

  sta CXCLR  ; Clear all collisions

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
