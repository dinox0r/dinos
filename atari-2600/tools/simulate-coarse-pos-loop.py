#!/usr/bin/env python3
import getopt, sys

tia_offset = -1
verbose = False
x_pos = -1
reg_a = 0

def debug(s: str):
  if verbose:
    print(s)

def usage():
  print("\n------------------------------------------------------------------")
  print("Simulates the coarse position")
  print("Usage:")
  print(f"{sys.argv[0]} [-v] [-x | --xpos=] [-t | --tia-offset=]")
  print("--xpos=, -x target x position")
  print("--tia-ofsset=, -t starting TIA position")
  print("--help, -h  Print this message")

try:
  opts, args = getopt.getopt(sys.argv[1:], "hx:t:v", ["help", "xpos=", "tia-offset=", "-verbose"])
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
    x_pos = int(a)
  elif o in ("-t", "--tia-offset"):
    tia_offset = int(a)
  else:
    assert False, "unhandled option"

if x_pos < 0:
  x_pos = int(input("x-position? (0-160) "))

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
  debug(f"  total: {tia_offset} ({hex(tia_offset)})")

tia_cycles = x_pos + tia_offset
reg_a = tia_cycles

debug(f"\nTarget TIA: {x_pos + 68} (X cc + 68 cc of HBLANK). TIA cycles to spend in the 'divide by 15' loop: {tia_cycles}")

debug(f"\nlda #{reg_a}     ; A will be loaded with {tia_cycles} in the prev scanline")
debug(   "sta WSYNC    ; start of new scanline - 0 cpu / 0 tia cycles")

cpu = 3
debug(f"\n\nsta HMOVE    ; 3 ({cpu} cpu / {3 * cpu} tia) TIA target: {tia_cycles} - 9 = {tia_cycles - 9}")
tia_cycles -= 9
loop_counter = 0

while reg_a - 15 >= 0:
  debug("\n_div_by_15:")
  reg_a -= 15
  cpu += 2
  debug(f"sbc #15         ; 2 ({cpu} cpu / {3 * cpu} tia)")
  tia_cycles -= 6
  cpu += 3
  debug(f"bcs _div_by_15  ; 3 ({cpu} cpu / {3 * cpu} tia)")
  debug(f"                ; A = {reg_a}\n")
  tia_cycles -= 9
  loop_counter += 1

debug(f"""
;-----------
;num iterations = {loop_counter}
;-----------
;
; LAST ITERATION:
;
""")

reg_a -= 15
cpu += 2
debug(f"sbc #15   ; A = {reg_a} >> CARRY SET! <<  2 ({cpu} cpu / {3 * cpu} tia) ")
tia_cycles -= 6
cpu += 2
debug(f"bcs       ; >> BRANCH NOT TAKEN <<   2 ({cpu} cpu / {3 * cpu} tia)\n")

if cpu < 23:
  print(f"\033[33mWARNING: RESPx will be strobed before CPU reaches 23 cycles (cpu = {cpu})\033[0m")

cpu += 3
tia_cycles -= 9
debug(f"sta RESPx ; 3 ({cpu} cpu / {3 * cpu} tia)\n")

current_tia = cpu * 3

print(f"Coarse position:")
print(f"RESPx was strobed when cpu/tia was at: {cpu - 3}/{(cpu - 3) * 3}. Remember input x-pos was {x_pos}")
print(f"\033[36mCurrent TIA: {current_tia}\033[0m. Target TIA: {x_pos + 68}")

print(f"")
print(f"Offset adjustment (fine positioning):")
print(f"remainder (reg A) = {reg_a}")

fine_offset_table_entry_index = reg_a + 15
fine_offsets_table = [ 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00, 0xF0, 0xE0, 0xD0, 0xC0, 0xB0, 0xA0, 0x90, 0x80]
fine_offset_entry = fine_offsets_table[fine_offset_table_entry_index]

fine_offset = x_pos + 68 - current_tia
hex_offset = ((~fine_offset + 1) << 4) & 0xf0

print(f"Fine offset adjustment needed after setting coarse position (target TIA - current TIA) = {fine_offset}")
print(f"Fine offset entry index = {fine_offset_table_entry_index}")
print(f"Fine entry = {fine_offset_entry} ({fine_offset_entry:X})")

decoded_fine_offset_entry = ~(((fine_offset_entry >> 4) & 0x0f) - 1)
if decoded_fine_offset_entry != fine_offset:
  print(f"\033[31mERROR: fine_offset ({fine_offset}) ≠ offset entry ({decoded_fine_offset_entry}, {fine_offset_entry}/{fine_offset_entry:X})\033[0m\n")

if not (-7 <= fine_offset <= 8):
  print("\033[31mERROR: fine offset outside range [-7, 8]\033[0m\n")

debug("""
       For reference (HM__ values):
       LEFT  <---------------------------------------------------------> RIGHT
offset (px)  | -7  -6  -5  -4  -3  -2  -1  0  +1  +2  +3  +4  +5  +6  +7  +8
value in hex | 70  60  50  40  30  20  10 00  F0  E0  D0  C0  B0  A0  90  80
""")

print(f"  fine offset: {fine_offset}px ({hex_offset:X}) (min -7, to left / max 8, to right)")
