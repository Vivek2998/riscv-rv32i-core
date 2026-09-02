# All six branch conditions, each in both directions, plus a counted loop so a
# backward branch and a loop-carried dependency get exercised.

    li   s1, 2
    li   t0, 5
    li   t1, 5
    li   t2, 7

    beq  t0, t1, b1
    j    fail                  # 2  beq taken
b1:
    addi s1, s1, 1
    beq  t0, t2, fail          # 3  beq not taken

    addi s1, s1, 1
    bne  t0, t2, b2
    j    fail                  # 4  bne taken
b2:
    addi s1, s1, 1
    bne  t0, t1, fail          # 5  bne not taken

    addi s1, s1, 1
    li   t3, -1
    li   t4, 1
    blt  t3, t4, b3
    j    fail                  # 6  blt signed: -1 < 1
b3:
    addi s1, s1, 1
    bltu t3, t4, fail          # 7  bltu unsigned: 0xFFFFFFFF > 1

    addi s1, s1, 1
    bge  t4, t3, b4
    j    fail                  # 8  bge signed: 1 >= -1
b4:
    addi s1, s1, 1
    bgeu t3, t4, b5
    j    fail                  # 9  bgeu unsigned: 0xFFFFFFFF >= 1
b5:
    addi s1, s1, 1
    bge  t3, t4, fail          # 10 bge not taken

    addi s1, s1, 1
    beq  t0, t0, b6
    j    fail                  # 11 beq on equal registers
b6:
    addi s1, s1, 1
    li   t0, 0                 # accumulator
    li   t1, 1                 # i
    li   t2, 11
loop:
    add  t0, t0, t1
    addi t1, t1, 1
    bne  t1, t2, loop
    li   t3, 55
    bne  t0, t3, fail          # 12 backward branch: sum 1..10 == 55

    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
