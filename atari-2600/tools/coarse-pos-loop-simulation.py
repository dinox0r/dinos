#!/usr/bin/env python3
import getopt, sys

tia_offset = -1
output = None
verbose = False
x = -1

def aprint(s: str):
  if verbose:
    print(s)

def usage():
  print("\n------------------------------------------------------------------")
  print("Simulates the coarse position")
  print("Usage:")
  print(f"{sys.argv[0]} -x<TARGET X POSITION> [optional: starting TIA cycles]")
  print("--help, -h  Print this message")

try:
  opts, args = getopt.getopt(sys.argv[1:], "hx:t:v", ["help", "xpos=", "tia-start=", "-verbose"])
except getopt.GetoptError as err:
  # print help information and exit:
  print(err)  # will print something like "option -a not recognized"
  usage()
  sys.exit(2)

for o, a in opts:
  if o == "-v":
    verbose = True
  elif o in ("-h", "--help"):
    usage()
    sys.exit()
  elif o in ("-x", "--xpos"):
    x = int(a)
  elif o in ("-t", "--tia-offset"):
    tia_offset = int(a)
  else:
    assert False, "unhandled option"

if x < 0:
  x = int(input("x-position? (0-160) "))
if tia_offset < 0:
  aprint("Using default TIA offset:")
  hblank = 68
  aprint(f"* 68 from HBLANK")
  first_sta_hmove = -9
  aprint(f"* {first_sta_hmove} from scanline first sta HMOVE")
  respx = -9
  aprint(f"* {respx} from sta RESPx")
  last_iteration = -12
  aprint(f"* {last_iteration} from last 'sbc #15 (2 CPU cycles), bne (2 CPU cycles)' iteration")
  range_offset = -2
  aprint(f"* {range_offset} to offset range")
  tia_offset = hblank + first_sta_hmove + respx + last_iteration + range_offset
  aprint(f"  total: {tia_offset}")

tia_cycles = x + tia_offset

aprint(f"\nTarget TIA cycles {tia_cycles} to position RESPx on x = {x}:")
#tia_cycles = x + 68 - 9 - 12 # 9 from sta HMOVE, 9 12 from last div cycle
A = tia_cycles
aprint(f"\nlda #{A}     ; A will be loaded with {tia_cycles} in the prev scanline")
aprint("sta WSYNC    ; start of new scanline - 0 cpu / 0 tia cycles")
cpu = 3
aprint(f"\n\nsta HMOVE    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
tia_cycles -= 9
loop_counter = 0
aprint("\n; division by 15 loop:")
while A - 15 >= 0:
  A -= 15
  cpu += 2
  aprint(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}")
  tia_cycles -= 6
  cpu += 3
  aprint(f"bcs          ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
  aprint(f"             ; A = {A}\n")
  tia_cycles -= 9
  loop_counter += 1

aprint(";-----------")
aprint(f"; num iterations = {loop_counter}")
aprint(";-----------")
aprint("; last cycle:")
A -= 15
cpu += 2
aprint(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6} A = {A} carry set!")
tia_cycles -= 6
cpu += 2
aprint(f"bcs          ; NOT TAKEN ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}\n")
tia_cycles -= 6
cpu += 3
aprint(f"sta RESPx    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
cpu += 3
tia_cycles -= 9

print(f"strobing RESPx at x = {3 * cpu}, input x-pos={x}")

tia_x = cpu * 3 - 68
print(f"cpu/tia: {cpu}/{cpu * 3}")
print(f"remainder (reg A) = {A}")
print(f"Target TIA: {x + 68}. Target visible TIA (x-pos): {x}. *Current* TIA {cpu * 3}. *Current* visible TIA (x-pos): (TIA - 68): {tia_x}")

aprint("""
       For reference:
       LEFT  <---------------------------------------------------------> RIGHT
offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
      """)
fine_offset = x - tia_x
if not (-7 <= fine_offset <= 8):
  print("\033[31mWARNING: fine offset outside range [-7, 8]\033[0m")
print(f"  fine offset: {fine_offset} (min -7, to left / max 8, to right)")
