#!/usr/bin/env python3
import sys
if len(sys.argv) > 1:
  x = int(sys.argv[1])
else:
  x = int(input("x-position? (0-160) "))
tia_cycles = x + 68 - 9 - 9 - 12 # 9 from sta HMOVE, 9 from sta RESP1, 12 from last div cycle
#tia_cycles = x + 68 - 9 - 12 # 9 from sta HMOVE, 9 12 from last div cycle
A = tia_cycles
print(f"\nlda #{A}      ; A will be loaded with {tia_cycles} in the prev scanline")
print("sta WSYNC    ; start of new scanline - 0 cpu / 0 tia cycles")
cpu = 3
print(f"\n\nsta HMOVE    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
tia_cycles -= 9
loop_counter = 0
print("\n; division by 15 loop:")
while A - 15 > 0:
  A -= 15
  cpu += 2
  print(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}")
  tia_cycles -= 6
  cpu += 3
  print(f"bcs          ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
  print(f"             ; A = {A}\n")
  tia_cycles -= 9
  loop_counter += 1

print(";-----------")
print(f"; num iterations = {loop_counter}")
print(";-----------")
print("; last cycle:")
A -= 15
cpu += 2
print(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6} A = {A} carry set!")
tia_cycles -= 6
cpu += 2
print(f"bcs          ; NOT TAKEN ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}\n")
tia_cycles -= 6
cpu += 3
print(f"sta RESP1    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
cpu += 3
tia_cycles -= 9

tia_x = cpu * 3 - 68
print(f"cpu/tia: {cpu}/{cpu * 3}")
print(f"Target TIA: {x + 68}. Target visible TIA: {x}. *Current* TIA {cpu * 3}. *Current* visible TIA: (TIA - 68): {tia_x}")
print(f"  fine offset: {x - tia_x} (max 8 to left / 7 right)")
