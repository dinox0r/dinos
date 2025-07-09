Another train ride. I'm running late for work... Well, late for standup anyway...
Yesterday on the train home I started writing the kernel sub-sections table,
now reading the DASM documentation to find out how to do the part where 
the jump label is repeated n-lines. I can't find a nice way of doing that, 
but I'll just go with a REPEAT for the moment, maybe time for another macro?
:mmm:

Let's read about the REPEAT directive... 
... Wait, I just realised, I can simply use ds.w <num_lines>, value, #facepalm

Ok... It's time to run `dasm dino.asm -odino.bin -ldino.lst -f3 -v` #fingers_crossed... I'm sure there are going to be a **lot** of errors

Whaat, that actually assembled after fixing a couple of misspells... Now I'm 
scared x_x. 

I got an "invalid instruction" when running the rom `('_' ?)`. DAMN what 
I was trying to avoid the most, debugging weird stuff, argg..

I have no clue what's going on, the assembled ROM doesn't make any sense
to me! It seems that none of the instructions are there after the 
`jmp (CURRENT_KERNEL)` instruction

Ok, I figured out the problem, here, have a laugh:

```asm
  lda <#__score_kernel_setup
  sta <CURRENT_SUB_KERNEL
  lda >#__score_kernel_setup
  sta >CURRENT_SUB_KERNEL
```

If you're unexperience to all these like myself and you haven't still 
figured it out, then look at the fix below:

```asm
  lda <#__score_kernel_setup
  sta CURRENT_SUB_KERNEL
  lda >#__score_kernel_setup
  sta CURRENT_SUB_KERNEL+1
```

At least it works in the 8bitworkshop.com, now let's check Stella on Linux.

Black screen... And worse, it detected the ROM as PAL. Sigh

The problem was that on the last scanline, the code goes through each 
sub-kernel. Anyway, once fixed this is what I have to load the kernel 
sub-section at the start of each scanline:

```asm
  lda KERNEL_TABLE_BASE,y         ; 5
  sta CURRENT_SUB_KERNEL          ; 3
  lda KERNEL_TABLE_BASE+1,y       ; 5
  sta CURRENT_SUB_KERNEL+1        ; 3
  jmp (CURRENT_SUB_KERNEL)        ; 5 - 21 cycles just to start the line!!! NAH
```
21 cycles! Just to chose a kernel and start, that leaves 55 cycles left...
No way I can do anything with this! This is TERRIBLE. There must be a better
way..

But my bus is arriving so, will have to call it a day
