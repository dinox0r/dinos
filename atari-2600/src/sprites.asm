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
  ;      + Also enable the ball when this bit is ON (used for the blinking)
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

DINO_CROUCHING_MISSILE_0:
  ;                                          offset           size
  ;                                    HMM0 bits 7,6,5,4   NUSIZE0 bits 5,4
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
  ; Missile pos (cycle 22)   M0/GRP0 position (cycle 25)

DINO_CROUCHING_MISSILE_1:
  ;                                          offset           size
  ;                                    HMM1 bits 7,6,5,4  NUSIZE1 bits 5,4
  ;   Enable M1 bit ⏐   ▯▯    ⏐
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
  ;  Missile size   Missile pos (cycle 22)

  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile 0 pixels
  ;    ░ missile 1 pixels
  ;    X overlapping pixels
  ;    ▯ Non drawn by the current kernel

PTERO_WINGS_OPEN_SPRITE:
  ; Sprite drawn as a combinatio
  ; of GRP1 and the BALL (after applying offsets)
  ;    "unpacked" GRP1 and BALL
  ;                                    "packed" GRP1
  ;  |        ⏐         |                ⏐        ⏐
  ;  |       █⏐         |                ⏐       █⏐
  ;  |       █⏐█        |                ⏐      ██⏐
  ;  |        ⏐██       |                ⏐      ██⏐
  ;  |     ██ ⏐███      |                ⏐  ██ ███⏐
  ;  |    ███ ⏐▓▓▓▓     |                ⏐    ███ ⏐
  ;  |   █████⏐█▓▓▓▓    |                ⏐  ██████⏐
  ;  |  ████XX⏐▓▓▓▓▓▓   |                ⏐  ██████⏐
  ;  |       █⏐███▓▓▓▓▓▓|▓▓              ⏐    ████⏐
  ;  |        ⏐███████  |                ⏐ ███████⏐
  ;  |        ⏐ █████▓▓▓|▓               ⏐   █████⏐
  ;  |        ⏐  ████   |                ⏐   ████ ⏐
  ;  |        ⏐         |                ⏐        ⏐
  ;  |        ⏐         |                ⏐        ⏐
  ;  |        ⏐         |                ⏐        ⏐
  ;  |        ⏐         |                ⏐        ⏐
  ;  |        ⏐         |                ⏐        ⏐

  ;  |        ⏐        |               ⏐        ⏐
  ;  |     █  ⏐        |               ⏐       █⏐
  ;  |     ██ ⏐        |               ⏐      ██⏐
  ;  |      ██⏐        |               ⏐      ██⏐
  ;  |   ██ ██⏐▓       |               ⏐  ██ ███⏐
  ;  |  ███ ██⏐▓▓      |               ⏐    ███ ⏐
  ;  | ██████X⏐▓▓▓     |               ⏐  ██████⏐
  ;  |████████⏐▓▓▓▓    |               ⏐  ██████⏐
  ;  |     ███⏐▓▓▓▓▓▓▓▓|               ⏐    ████⏐
  ;  |      ▓▓|▓▓▓▓▓▓  |               ⏐ ███████⏐
  ;  |       ▓⏐▓▓▓▓▓▓▓ |               ⏐   █████⏐
  ;  |        ⏐▓▓▓▓    |               ⏐   ████ ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐▓▓▓▓    |               ⏐   ████ ⏐
  ;  |       ▓⏐▓▓▓▓▓▓▓ |               ⏐   █████⏐
  ;  |      ▓▓|▓▓▓▓▓▓  |               ⏐ ███████⏐
  ;  |     ███⏐▓▓▓▓▓▓▓▓|               ⏐    ████⏐
  ;  |████████⏐▓▓▓▓    |               ⏐  ██████⏐
  ;  | ██████X⏐▓▓▓     |               ⏐  ██████⏐
  ;  |  ███ ██⏐▓▓      |               ⏐    ███ ⏐
  ;  |   ██ ██⏐▓       |               ⏐  ██ ███⏐
  ;  |      ██⏐        |               ⏐      ██⏐
  ;  |     ██ ⏐        |               ⏐      ██⏐
  ;  |     █  ⏐        |               ⏐       █⏐
  ;  |        ⏐        |               ⏐        ⏐

  ; Legend:
  ;    █ GRP1 pixels
  ;    ▒ BALL pixels
  ;    X overlapping pixels (between GRP1 and BALL)

  .ds 1            ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000111  ;⏐     ███⏐
  .byte %11111111  ;⏐████████⏐
  .byte %01111111  ;⏐ ███████⏐
  .byte %00111011  ;⏐  ███ ██⏐
  .byte %00011011  ;⏐   ██ ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000110  ;⏐     ██ ⏐
  .byte %00000100  ;⏐     █  ⏐
  .ds 1            ;⏐        ⏐
PTERO_WINGS_OPEN_SPRITE_END = *

; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
PTERO_WINGS_OPEN_BALL:
  ;                                    HMM0 bits 7,6,5,4   NUSIZE bits 5,4
  ; Enable BALL bit 
  ;             ⏐
  .ds 1 ;       ↓   |        ⏐        |
  .byte %00000000 ; |        ⏐        |         0              0
  .byte %00000000 ; |        ⏐        |         0              0
  .byte %00000000 ; |        ⏐        |         0              0
  .byte %00000000 ; |        ⏐        |         0              0
  .byte %11111001 ; |        ⏐▓▓▓▓    |         0              0
  .byte %11111101 ; |       ▓⏐▓▓▓▓▓▓▓ |        +3              4 (10)
  .byte %00101101 ; |      ▓▓|▓▓▓▓▓▓  |         0              0
  .byte %11111101 ; |     ███⏐▓▓▓▓▓▓▓▓|        +5              8 (11)
  .byte %11111001 ; |████████⏐▓▓▓▓    |        -4              8 (11)
  .byte %00011001 ; | ██████X⏐▓▓▓     |        +1              4 (10)
  .byte %00000101 ; |  ███ ██⏐▓▓      |        -1              4 (10)
  .byte %00010001 ; |   ██ ██⏐▓       |         0              0
  .byte %00000000 ; |      ██⏐        |         0              0
  .byte %00000000 ; |     ██ ⏐        |         0              0
  .byte %00000000 ; |     █  ⏐        |         0              0
  .ds 1           ; |        ⏐        |
  ;                          ↑↑
  ;                 end GRP1/  \-- BALL position
PTERO_WINGS_OPEN_BALL_END = *

PTERO_WINGS_CLOSED_SPRITE:
  ; Sprite drawn as a combination
  ; of GRP1 and the BALL (after applying offsets)
  ;    "unpacked" GRP1 and BALL
  ;                                  /- GRP1 -\
  ;        ⏐         |                ⏐        ⏐
  ;        ⏐         |                ⏐        ⏐
  ;        ⏐         |                ⏐        ⏐
  ;        ⏐         |                ⏐        ⏐
  ;     ██ ⏐         |                ⏐     ██ ⏐
  ;    ███ ⏐         |                ⏐    ███ ⏐
  ;   █████⏐         |                ⏐   █████⏐
  ;  ██████⏐██▓▓▓▓   |                ⏐████████⏐
  ;       █⏐███▓▓▓▓▓▓|▓▓              ⏐    ████⏐
  ;        ⏐████████ |                ⏐████████⏐
  ;        ⏐██████▓▓▓|▓               ⏐  ██████⏐
  ;        ⏐███████  |                ⏐ ███████⏐
  ;        ⏐███      |                ⏐     ███⏐
  ;        ⏐██       |                ⏐      ██⏐
  ;        ⏐██       |                ⏐      ██⏐
  ;        ⏐█        |                ⏐       █⏐
  ;        ⏐         |                ⏐        ⏐

  ;           12345678
  ; |        ⏐        |
  ; |      █ ⏐        |
  ; |      ██⏐        |
  ; |      ██⏐        |
  ; |      ██⏐▓       |
  ; |      ██⏐▓▓▓▓    |
  ; |      █X⏐▓▓▓▓▓▓▓ |
  ; |      XX⏐▓▓▓▓▓▓  |
  ; |     ███⏐▓▓▓▓▓▓▓▓|
  ; |████████⏐▓▓▓▓    |
  ; | █████  ⏐        |
  ; |  ███   ⏐        |
  ; |   ██   ⏐        |
  ; |        ⏐        |
  ; |        ⏐        |
  ; |        ⏐        |
  ; |        ⏐        |

  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile 0 pixels
  ;    X overlapping pixels

  ;  |        ⏐        |               ⏐        ⏐
  ;  |     █  ⏐        |               ⏐       █⏐
  ;  |     ██ ⏐        |               ⏐      ██⏐
  ;  |      ██⏐        |               ⏐      ██⏐
  ;  |   ██ ██⏐▓       |               ⏐  ██ ███⏐
  ;  |  ███ ██⏐▓▓      |               ⏐    ███ ⏐
  ;  | ██████X⏐▓▓▓     |               ⏐  ██████⏐
  ;  |████████⏐▓▓▓▓    |               ⏐  ██████⏐
  ;  |     ███⏐▓▓▓▓▓▓▓▓|               ⏐    ████⏐
  ;  |      ▓▓|▓▓▓▓▓▓  |               ⏐ ███████⏐
  ;  |       ▓⏐▓▓▓▓▓▓▓ |               ⏐   █████⏐
  ;  |        ⏐▓▓▓▓    |               ⏐   ████ ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  ;  |        ⏐        |               ⏐        ⏐
  .ds 1            ;⏐        ⏐
  .byte %00000010  ;⏐      █ ⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000011  ;⏐      ██⏐
  .byte %00000111  ;⏐     ███⏐
  .byte %11111111  ;⏐████████⏐
  .byte %01111100  ;⏐ █████  ⏐
  .byte %00111000  ;⏐  ███   ⏐
  .byte %00011000  ;⏐   ██   ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .byte %00000000  ;⏐        ⏐
  .ds 1            ;⏐        ⏐
PTERO_WINGS_CLOSED_SPRITE_END = *

PTERO_WINGS_CLOSED_BALL:
; Again, for reference:
;       LEFT  <---------------------------------------------------------> RIGHT
;offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
;value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80

  ;                                    HMM0 bits 7,6,5,4   NUSIZE bits 5,4
  ; Enable BALL bit 
  ;             ⏐
  .ds 1 ;       ↓   ⏐        ⏐        |
  .byte %00000000 ; ⏐      █ ⏐        |         0              0
  .byte %00000000 ; ⏐      ██⏐        |         0              0
  .byte %00000000 ; ⏐      ██⏐        |         0              0
  .byte %00000001 ; ⏐      ██⏐▓       |         0              0
  .byte %11111001 ; ⏐      ██⏐▓▓▓▓    |         0              0
  .byte %11111101 ; ⏐      █X⏐▓▓▓▓▓▓▓ |        +3              4
  .byte %00101101 ; ⏐      XX⏐▓▓▓▓▓▓  |         0              0
  .byte %11111101 ; ⏐     ███⏐▓▓▓▓▓▓▓▓|        +1              8
  .byte %00011001 ; ⏐████████⏐▓▓▓▓    |        +1              4
  .byte %00000000 ; ⏐ █████  ⏐        |         0              0
  .byte %00000000 ; ⏐  ███   ⏐        |         0              0
  .byte %00000000 ; ⏐   ██   ⏐        |         0              0
  .byte %00000000 ; ⏐        ⏐        |         0              0
  .byte %00000000 ; ⏐        ⏐        |         0              0
  .byte %00000000 ; ⏐        ⏐        |         0              0
  .ds 1           ; ⏐        ⏐        |
  ;                           ↑
  ;                   initial BALL position (cycle 25)
PTERO_WINGS_CLOSED_BALL_END = *

  ;
  ; Legend:
  ;    █ GRP0 pixels
  ;    ▒ missile pixels
  ;    ░ ball
  ;    X overlapping pixels
  ;    ▯ Non drawn by the current kernel


;             -4               2
;    ██       +8               4
;    ██       +2               8
;  ██████      0               8
; █  █████     0               8
; █  ██  █    +2               8
;    ██  █    -5               8
;    ██        0               0

