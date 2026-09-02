# Loads and stores at every byte lane, with sign- and zero-extension checked
# separately, and partial stores checked for not disturbing neighbouring bytes.

    li   s1, 2
    li   s0, 0x800             # scratch area, clear of both code and tohost

    li   t0, 0x12345678
    sw   t0, 0(s0)
    lw   t1, 0(s0)
    bne  t1, t0, fail          # 2  sw/lw round trip

    addi s1, s1, 1
    lbu  t1, 0(s0)
    li   t2, 0x78
    bne  t1, t2, fail          # 3  lbu lane 0 (little endian)

    addi s1, s1, 1
    lbu  t1, 1(s0)
    li   t2, 0x56
    bne  t1, t2, fail          # 4  lbu lane 1

    addi s1, s1, 1
    lbu  t1, 2(s0)
    li   t2, 0x34
    bne  t1, t2, fail          # 5  lbu lane 2

    addi s1, s1, 1
    lbu  t1, 3(s0)
    li   t2, 0x12
    bne  t1, t2, fail          # 6  lbu lane 3

    addi s1, s1, 1
    li   t0, 0x800000FF
    sw   t0, 4(s0)
    lb   t1, 4(s0)
    li   t2, -1
    bne  t1, t2, fail          # 7  lb sign-extends 0xFF

    addi s1, s1, 1
    lbu  t1, 4(s0)
    li   t2, 0xFF
    bne  t1, t2, fail          # 8  lbu zero-extends 0xFF

    addi s1, s1, 1
    lhu  t1, 6(s0)
    li   t2, 0x8000
    bne  t1, t2, fail          # 9  lhu upper half, zero-extended

    addi s1, s1, 1
    lh   t1, 6(s0)
    li   t2, -32768
    bne  t1, t2, fail          # 10 lh upper half, sign-extended

    addi s1, s1, 1
    li   t0, 0
    sw   t0, 8(s0)
    li   t0, 0xAB
    sb   t0, 9(s0)
    lw   t1, 8(s0)
    li   t2, 0xAB00
    bne  t1, t2, fail          # 11 sb touches only its own lane

    addi s1, s1, 1
    li   t0, 0
    sw   t0, 12(s0)
    li   t0, 0xBEEF
    sh   t0, 14(s0)
    lw   t1, 12(s0)
    li   t2, 0xBEEF0000
    bne  t1, t2, fail          # 12 sh touches only its own half

    addi s1, s1, 1
    li   t0, 0x0BADF00D
    sw   t0, 16(s0)
    lw   t1, 16(s0)
    addi t2, t1, 0
    bne  t2, t0, fail          # 13 a load feeding the very next instruction

    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
