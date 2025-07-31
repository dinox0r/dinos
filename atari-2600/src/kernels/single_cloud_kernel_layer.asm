single_cloud_kernel_setup:; - (12)
  lda #SKY_SCANLINES
  sta CLOUD_LAYER_SCANLINES
  lda CLOUD_1_TOP_Y
  sta CURRENT_CLOUD_TOP_Y
  lda CLOUD_1_X_INT
  sta CURRENT_CLOUD_X
  jsr set_cloud_pos_x

  sta WSYNC
  sta HMOVE           ; 3 (3)

  lda #0              ; 2 (5)
  tax                 ; 2 (7)
  sta GRP0            ; 3 (10)
  sta GRP1            ; 3 (13)

  ldy #SKY_SCANLINES  ; 2 (15)

  lda CURRENT_CLOUD_X ; 3 (18)
  cmp #9              ; 2 (20)
  bcc single_cloud_kernel__only_show_grp1
  cmp #161
  bcs single_cloud_kernel__only_show_grp0
  jmp single_cloud_kernel__show_both_grp0_and_grp1

  ; 3rd scanline ==============================================================
single_cloud_kernel__only_show_grp0:
  lda #0
  sta HMCLR           ; 3 (23)
  CLOUD_KERNEL_2 #USE_GRP0, #IGNORE_GRP1
  jmp end_of_single_cloud_kernel

single_cloud_kernel__only_show_grp1:
  lda #0
  sta HMCLR           ; 3 (23)
  CLOUD_KERNEL_2 #IGNORE_GRP0, #USE_GRP1
  jmp end_of_single_cloud_kernel

single_cloud_kernel__show_both_grp0_and_grp1:
  lda #0
  sta HMCLR           ; 3 (23)
  CLOUD_KERNEL_2 #USE_GRP0, #USE_GRP1

end_of_single_cloud_kernel:
