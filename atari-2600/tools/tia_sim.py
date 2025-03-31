def sim(x, tia_offset = 0):
    target_tia = x + 68
    reg_a = target_tia - tia_offset
    a_values = [reg_a]
    while reg_a >= 0:
        reg_a -= 15
        a_values.append(reg_a)
    # current tia x pos = initial sta HMOVE (3 cpu cycles / 9 TIA cycles) +
    #   + num loop iterations * 15 TIA cycles
    #   + last loop iteration (4 cpu cycles / 12 TIA cycles)
    #   + sta RESPx (3 cpu cycles / 9 TIA cycles)
    current_tia = 9 + (len(a_values) - 2) * 15 + 12 + 9
    error = target_tia - current_tia
    print(f"reg A values={a_values} current TIA={current_tia}, target TIA={target_tia}, e={error}")
