#!/usr/bin/env python3
import getopt, sys

tia_offset = -1
output = None
verbose = False
x = -1

def debug(s: str):
  if verbose:
    print(s)

def usage():
  print("\n------------------------------------------------------------------")
  print("Simulates the coarse position")
  print("Usage:")
  print(f"{sys.argv[0]} [-v] [-x | --xpos=] [-t | --tia-offset=]")
  print("--xpos=, -x target x position")
  print("--tia--ofsset=, -t starting TIA position")
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
  debug("Using default TIA offset:")
  hblank = 68
  debug(f"* 68 from HBLANK")
  first_sta_hmove = -9
  debug(f"* {first_sta_hmove} from scanline first sta HMOVE")
  respx = -9
  debug(f"* {respx} from sta RESPx")
  last_iteration = -12
  debug(f"* {last_iteration} from last 'sbc #15 (2 CPU cycles), bne (2 CPU cycles)' iteration")
  range_offset = -2
  debug(f"* {range_offset} to offset range")
  tia_offset = hblank + first_sta_hmove + respx + last_iteration + range_offset
  debug(f"  total: {tia_offset}")

tia_cycles = x + tia_offset

debug(f"\nTarget TIA: {x + 68} (X cc + 68 cc of HBLANK). TIA cycles to spend in the 'divide by 15' loop: {tia_cycles}")
#tia_cycles = x + 68 - 9 - 12 # 9 from sta HMOVE, 9 12 from last div cycle
A = tia_cycles
debug(f"\nlda #{A}     ; A will be loaded with {tia_cycles} in the prev scanline")
debug("sta WSYNC    ; start of new scanline - 0 cpu / 0 tia cycles")
cpu = 3
debug(f"\n\nsta HMOVE    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
tia_cycles -= 9
loop_counter = 0
debug("\n; division by 15 loop:")
while A - 15 >= 0:
  A -= 15
  cpu += 2
  debug(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}")
  tia_cycles -= 6
  cpu += 3
  debug(f"bcs          ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
  debug(f"             ; A = {A}\n")
  tia_cycles -= 9
  loop_counter += 1

debug(";-----------")
debug(f"; num iterations = {loop_counter}")
debug(";-----------")
debug("; last cycle:")
A -= 15
cpu += 2
debug(f"sbc #15      ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6} A = {A} carry set!")
tia_cycles -= 6
cpu += 2
debug(f"bcs          ; NOT TAKEN ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 6 = {tia_cycles - 6}\n")
tia_cycles -= 6
cpu += 3
debug(f"sta RESPx    ; ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}\n")

print(f"Coarse position:")
print(f"RESPx will be strobed at cpu/tia: {cpu}/{cpu * 3}. Remember input x-pos is {x}")
if cpu < 23:
  print("\033[33mWARNING: RESPx will be strobed before 23 CPU cycles\033[0m")
cpu += 3
tia_cycles -= 9

tia_x = cpu * 3 - 68
print(f"")
print(f"Offset adjustment (fine positioning):")
print(f"remainder (reg A) = {A}")
print(f"*Current* TIA {cpu * 3}. TIA after HBLANK (visible x-pos): (TIA - 68): {tia_x}")

debug("""
       For reference:
       LEFT  <---------------------------------------------------------> RIGHT
offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
      """)
fine_offset = x - tia_x
if not (-7 <= fine_offset <= 8):
  print("\033[31mERROR: fine offset outside range [-7, 8]\033[0m")
print(f"  fine offset: {fine_offset} (min -7, to left / max 8, to right)")
