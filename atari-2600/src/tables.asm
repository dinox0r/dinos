FINE_POSITION_OFFSET:
  .byte $70  ; offset -7
  .byte $60  ; offset -6
  .byte $50  ; offset -5
  .byte $40  ; offset -4
  .byte $30  ; offset -3
  .byte $20  ; offset -2
  .byte $10  ; offset -1
  .byte $00  ; offset  0
  .byte $F0  ; offset  1
  .byte $E0  ; offset  2
  .byte $D0  ; offset  3
  .byte $C0  ; offset  4
  .byte $B0  ; offset  5
  .byte $A0  ; offset  6
  .byte $90  ; offset  7
  .byte $80  ; offset  8

POWERS_OF_2_NEGATED:
  .byte #%11111110
  .byte #%11111101
  .byte #%11111011
  .byte #%11110111
  .byte #%11101111
  .byte #%11011111
  .byte #%10111111
  .byte #%01111111

; The ptero obstacle has 4 predetermined vertical positions
; it could appear at, high in the sky, midway in the sky (close enough to
; the ground to force the player into crouching) and close to the graound
PTERO_Y_POS:
  .byte #PLAY_AREA_TOP_Y-#8
  ; This forces the player to crouch (although, they can also jump)
  .byte #CACTUS_Y+(#PTERO_HEIGHT/2)+#3
  ; This one is to confuse the player a bit, the player might think that they
  ; don't need to crouch for this, but they have to
  .byte #CACTUS_Y+(#PTERO_HEIGHT/2)+#8
  ; The player needs to jump for this one
  .byte #CACTUS_Y+#1
