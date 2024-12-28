#/usr/env/bin python3
x = int(input("x-position? (0-160) "))
# tia_cycles = x + 68
tia_cycles = x + 68 - 9 - 9 - 12 # 9 from sta HMOVE, 9 from sta RESP1, 12 from last div cycle
A = tia_cycles
print(f"lda #{A} ; A will be loaded with {tia_cycles} in the prev scanline")
print("sta WSYNC ; start of new scanline")
print(f"sta HMOVE (3 cpu / 9 tia) (TIA target: {tia_cycles} - 9 = {tia_cycles - 9})")
tia_cycles -= 9
loop_counter = 0
print("\ndivision by 15 loop:")
while A - 15 > 0:
  A -= 15
  print(f"sbc #15 (2 cpu / 6 tia) (TIA target: {tia_cycles} - 6 = {tia_cycles - 6}) A = {A}")
  tia_cycles -= 6
  print(f"bcs     (3 cpu / 9 tia) (TIA target: {tia_cycles} - 9 = {tia_cycles - 9})")
  tia_cycles -= 9
  loop_counter += 1

print("-----------")
print(f"num iterations={loop_counter}")
print("-----------")
print("last cycle:")
A -= 15
print(f"sbc #15 (2 cpu / 6 tia) (TIA target: {tia_cycles} - 6 = {tia_cycles - 6}) A = {A} carry set!")
tia_cycles -= 6
print(f"bcs     (2 cpu / 6 tia) (TIA target: {tia_cycles} - 6 = {tia_cycles - 6})")
tia_cycles -= 6
print(f"sta RESP1 (3 cpu / 9 tia) (TIA target: {tia_cycles} - 9 = {tia_cycles - 9})")
tia_cycles -= 9

print(f"\nTIA target = {tia_cycles}")
