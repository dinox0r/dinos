; Each sound effect note is encoded using 4 bytes (wasteful, yes)
; byte 1: The duration in frames
; byte 2: The tone
; byte 3: Frequency
; byte 4: Volume
GAME_OVER_SOUND:
  ; Channel 0 data only

  ; 1st note
  ; Duration in frames / Tone / Frequency / Volume (max 15)
  byte #3, #$0E, #3, #3

  ; 2nd note
  byte #2, #0, #0, #0

  ; 3rd note
  byte #4, #$0E, #3, #3

  ; 4th note
  byte #2, #$0E, #2, #1

  ; end of the sound
  .ds 1

JUMP_SOUND:
  ; Duration in frames / Tone / Frequency / Volume (max 15)
  byte #3, #$0D, #10, #1

  ; end of the sound
  .ds 1
