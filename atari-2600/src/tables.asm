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
