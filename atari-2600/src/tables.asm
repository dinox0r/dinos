FINE_POSITION_OFFSET:
  .byte $70  ; offset -7 - index 0
  .byte $60  ; offset -6 - index 1
  .byte $50  ; offset -5 - index 2
  .byte $40  ; offset -4 - index 3
  .byte $30  ; offset -3 - index 4
  .byte $20  ; offset -2 - index 5
  .byte $10  ; offset -1 - index 6
  .byte $00  ; offset  0 - index 7
  .byte $F0  ; offset  1 - index 8
  .byte $E0  ; offset  2 - index 9
  .byte $D0  ; offset  3 - index 10
  .byte $C0  ; offset  4 - index 11
  .byte $B0  ; offset  5 - index 12
  .byte $A0  ; offset  6 - index 13
  .byte $90  ; offset  7 - index 14
  .byte $80  ; offset  8 - index 15

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
