dino_crouching_kernel: ;------------------>>> 31 2x scanlines <<<-----------------
_region_1:
  ;                 ████████ <-- this will be drawn by this region
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  sta WSYNC      ; 3 (from play_area_kernel: 58 -> 65)
                 ; 3 (from this kernel: 60 -> 63)

  ; 1st scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)

  ; Draw the obstacle first, then load the dino's crouching data to draw
  ; on the next scanline
  DRAW_OBSTACLE  ; 13 (16)

  lda #%00000101 ; 2 (18) - Set P0 2px size
  sta NUSIZ0     ; 3 (21)

  ;         0 0 0 0 1 1 1 1  <-- GRP0 data, P0 is configured as double width
  ;         ........████████
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  lda #%00001111 ; 2 (25) - GRP0 sprite data

  sta HMCLR

  sta WSYNC      ; 3 ()

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  sta GRP0       ; 3 (6) - Draw the dino sprite

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 29 (35)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #SET_CARRY, _region_1__end_of_2nd_scanline
_region_1__end_of_2nd_scanline:

  dey           ; 2 (59) - Keep decrementing the scanline counter
  sta WSYNC     ; 3 (62)

_region_2:
  ;                 ▒▒▒▒▒▒▒▒
  ;   █   ███████  ██ ███████ \__ this region will draw these 2 scanlines
  ;   ███████████████████████ /
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  DRAW_OBSTACLE ; 13 (16)

  lda FOREGROUND_COLOUR ; 3 (19)
  sta COLUPF            ; 3 (22)

  lda #$F0        ; 2 (24) - 24 CPU cycles has passed, it is safe to update the
                  ;           HMMx registers
  sta HMCLR       ; 3 (27) - First clear all obstacle's offsets
  sta HMP0        ; 3 (30)
  sta HMM0        ; 3 (33)
  lda #$10        ; 2 (35)
  sta HMBL        ; 3 (38)

  lda #%11010111  ; 2 (40) - GRP0 sprite data

  sec             ; 2 (42)
  sta WSYNC       ; 3 (45)

  ; 2nd scanline ==============================================================
                 ; - (0)
  sta HMOVE      ; 3 (3)
  sta GRP0       ; 3 (6) - Draw the dino sprite
  sta ENAM0      ; 3 (9) - GRP0 = (11010111)₂ so both bit 1 and 0 are alreay
  sta ENABL      ; 3 (12)  set. These bits enable M0 and the ball respectively
  lda #%10000000 ; 2 (14)
  sta PF1        ; 3 (17)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (45)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_2__end_of_2nd_scanline
_region_2__end_of_2nd_scanline:

  sta TEMP              ; 3 (48)
  ; COLUPF must be restored to the game background color between
  ; CPU cycle 39 (after PF1 is drawn by the TIA for the first time in the 
  ; scanline) and cycle 54 (just before PF1 is drawn again in the same scanline
  ; —if the playfield is not reflected).
  lda #0                ; 2 (50)
  sta PF1               ; 3 (53)

  lda TEMP              ; 3 (56)

  dey                   ; 2 (58) - Keep y (2x scanline counter) updated
  sta WSYNC             ; 3 (61)

  ; 3rd scanline ==============================================================
                    ; - (0)
  sta HMOVE         ; 3 (3)
  DRAW_OBSTACLE     ; 13 (16)

  lda #%10000000    ; 2 (18) - PF1 can be changed before CPU
  sta PF1           ; 3 (21)   hits cycle 28, and should be cleared before
                    ;          CPU cycle 54

  ; Preload the HyMx register values
  lda #$10          ; 2 (23) - Positioning P0 1px to the left and the ball
                    ;          6px to the right.
                    ;          P0 will remain static in this position for
                    ;          the rest of the region
  ldx #$A0          ; 2 (25)

  sta HMCLR         ; 3 (28)

  sta HMP0          ; 3 (31)
  stx HMBL          ; 3 (34)
                    ;          the sprite detail

  lda #%00110101    ; 2 (36) - Set missile 0 size to 8px while 
  sta NUSIZ0        ; 3 (39)   keeping P0 at 2x size

  sec               ; 2 (41) - Delaying changing PF1 until is displayed

  lda #0            ; 2 (42) - Reset PF1. PF1 rendering finishes by CPU
  sta PF1           ; 3 (45)   cycle 39

  lda #$ff          ; 2 (47) - GRP0 sprite data for next scanline

_region_3:

  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ███████████████████████ \
  ;    ██████████████████████ | This region will draw these scanlines
  ;    █████████████████      |
  ;     ██████████  ███████   /
  ;      ▒▒▒ ▒▒  ▒▒
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯

  sta WSYNC              ; 3 (50, 43 if is coming from the branch below)
  ; 1st scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  sta GRP0      ; 3 (6)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_3__end_of_1st_scanline
_region_3__end_of_1st_scanline:

  dey    ; 2 (35) - Update the 2x scanline counter here (1st scanline of this 
         ;          kernel) as the region started in the middle of a 2x scanline

  ; Last scanline of this region is one above the play area bottom Y, the
  ; remaining scanline is for region 4
  cpy #PLAY_AREA_BOTTOM_Y+#1 ; 2 (37)
  beq _region_4 ; 2/3 (39/40)

  sta WSYNC                 ; 3 (42)
  ; 2nd scanline ==============================================================
               ; - (0)
  sta HMOVE    ; 3 (3)
  DRAW_OBSTACLE ; 13 (16)

; REGION_3_OFFSET = -(-#CROUCHING_REGION_TOP_Y + #3 - #1) =
;                 = -(-#CROUCHING_REGION_TOP_Y + #2)
; 3 from the already drawn scanlines, and 1 to move the *_END label back
REGION_3_OFFSET = #CROUCHING_REGION_TOP_Y - #2
  lda DINO_CROUCHING_REGION_3_MISSILE_AND_BALL_CONF_END - #REGION_3_OFFSET,y ; 4 (20)
  ldx DINO_CROUCHING_REGION_3_SPRITE_END - #REGION_3_OFFSET,y ; 4 (24)

  sta HMCLR     ; 3 (27)
  sta HMM0      ; 3 (30)
  asl           ; 2 (32)
  asl           ; 2 (34)
  asl           ; 2 (36)
  asl           ; 2 (38)
  sta HMBL      ; 3 (41)
  txa           ; 2 (43)
  jmp _region_3 ; 3 (46)

_region_4:
  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ███ ██  ██ <- this region draws this scanline
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  sta WSYNC     ; 3 (49)

  ; 1st scanline ==============================================================
                   ; - (0)
  sta HMOVE        ; 3 (3)
  DRAW_OBSTACLE    ; 13 (16)

  lda ($80,x)      ; 6 (22) - Wait/waste 6 CPU cycles (2 bytes)

  sta HMCLR        ; 3 (25)

  lda #$F0         ; 2 (28) - Move M0 1px to the right
  sta HMM0         ; 3 (31)

  ldx #%00010000   ; 2 (33) - Set M0 to 2px and make P0 back to 1px size

  sec              ; 2 (35) - Set carry for next scanline and delay applying
                   ;          changes to NUSIZ0 and ENABL until the dino 
                   ;          finished drawing (around CPU cycle 42 for this
                   ;          scanline)

  lda #%10110011   ; 2 (37)

  stx NUSIZ0       ; 3 (40) - Update the NUSIZ0 configuration stored in reg X
                   ;          a few instructions ago
  stx ENABL        ; 3 (43) - Bit 0 of reg X is 0, so it can be used to turn
                   ;          the ball OFF

  ;                 ▒▒▒▒▒▒▒▒
  ;   ▒   ▒▒▒▒▒▒▒  ▒▒ ▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ;     ▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒
  ;      ▒▒█ ██  ██
  ;        10110011 <-- GRP0 sprite value
  ;      ▯▯   ▯▯
  ;      ▯
  ;      ▯▯
  sta WSYNC        ; 3 (46)

  ; 2nd scanline ==============================================================
                ; - (0)
  sta HMOVE     ; 3 (3)
  sta GRP0      ; 3 (6)

  ; ⚠ IMPORTANT:
  ; ------------
  ; Registers A and X hold obstacle sprite data after this macro and must not
  ; be modified until drawing is complete.
  ;
  ; This macro costs 27 (33)
  LOAD_OBSTACLE_GRAPHICS_IF_IN_RANGE #IGNORE_CARRY, _region_4__end_of_2nd_scanline
_region_4__end_of_2nd_scanline:

  ; Restore the dino's Y-position to standing after crouching is fully drawn.
  ; This prevents the standing sprite from being drawn prematurely during the
  ; crouch (which would result in overlapping graphics if both kernels render).
  ; Using Y = 0 during crouch suppresses standing sprite rendering. Restoring
  ; it here ensures normal leg drawing resumes, since both states share leg
  ; data.
  sta TEMP               ; 3 (36)
  lda #INIT_DINO_TOP_Y   ; 2 (38)
  sta DINO_TOP_Y_INT     ; 3 (41)
  lda TEMP               ; 3 (44)

  dey                    ; 2 (46)
