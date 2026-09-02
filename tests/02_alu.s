# Every RV32I ALU operation, register-register and register-immediate. The
# sign-sensitive ones (SRA, SLT, SLTU) are checked against negative operands,
# since that is where a logical/arithmetic mix-up shows up.

    li   s1, 2
    li   t0, 100
    li   t1, 23

    add  t2, t0, t1
    li   t3, 123
    bne  t2, t3, fail          # 2  add

    addi s1, s1, 1
    sub  t2, t0, t1
    li   t3, 77
    bne  t2, t3, fail          # 3  sub

    addi s1, s1, 1
    sub  t2, t1, t0
    li   t3, -77
    bne  t2, t3, fail          # 4  sub crossing zero

    addi s1, s1, 1
    addi t2, t0, -130
    li   t3, -30
    bne  t2, t3, fail          # 5  addi, negative immediate

    addi s1, s1, 1
    li   t0, 0x0F0F0F0F
    li   t1, 0x00FF00FF
    and  t2, t0, t1
    li   t3, 0x000F000F
    bne  t2, t3, fail          # 6  and

    addi s1, s1, 1
    or   t2, t0, t1
    li   t3, 0x0FFF0FFF
    bne  t2, t3, fail          # 7  or

    addi s1, s1, 1
    xor  t2, t0, t1
    li   t3, 0x0FF00FF0
    bne  t2, t3, fail          # 8  xor

    addi s1, s1, 1
    andi t2, t0, 0xFF
    li   t3, 0x0F
    bne  t2, t3, fail          # 9  andi

    addi s1, s1, 1
    ori  t2, x0, 0x123
    li   t3, 0x123
    bne  t2, t3, fail          # 10 ori

    addi s1, s1, 1
    xori t2, t0, -1
    li   t3, 0xF0F0F0F0
    bne  t2, t3, fail          # 11 xori -1 is a bitwise not

    addi s1, s1, 1
    li   t0, 1
    li   t1, 31
    sll  t2, t0, t1
    li   t3, 0x80000000
    bne  t2, t3, fail          # 12 sll by 31

    addi s1, s1, 1
    li   t0, -1
    li   t1, 4
    srl  t2, t0, t1
    li   t3, 0x0FFFFFFF
    bne  t2, t3, fail          # 13 srl shifts in zeros

    addi s1, s1, 1
    sra  t2, t0, t1
    li   t3, -1
    bne  t2, t3, fail          # 14 sra replicates the sign bit

    addi s1, s1, 1
    li   t0, -16
    srai t2, t0, 2
    li   t3, -4
    bne  t2, t3, fail          # 15 srai

    addi s1, s1, 1
    li   t0, 3
    slli t2, t0, 4
    li   t3, 48
    bne  t2, t3, fail          # 16 slli

    addi s1, s1, 1
    li   t0, 0x80
    srli t2, t0, 3
    li   t3, 0x10
    bne  t2, t3, fail          # 17 srli

    addi s1, s1, 1
    li   t0, -1
    li   t1, 1
    slt  t2, t0, t1
    li   t3, 1
    bne  t2, t3, fail          # 18 slt: -1 < 1 signed

    addi s1, s1, 1
    sltu t2, t0, t1
    li   t3, 0
    bne  t2, t3, fail          # 19 sltu: 0xFFFFFFFF > 1 unsigned

    addi s1, s1, 1
    li   t0, -5
    li   t1, -7
    slt  t2, t0, t1
    li   t3, 0
    bne  t2, t3, fail          # 20 slt: -5 > -7, both negative

    addi s1, s1, 1
    slti t2, t0, -4
    li   t3, 1
    bne  t2, t3, fail          # 21 slti

    addi s1, s1, 1
    sltiu t2, t1, -1
    li    t3, 1
    bne   t2, t3, fail         # 22 sltiu sign-extends then compares unsigned

    addi s1, s1, 1
    lui  t0, 0x12345
    li   t3, 0x12345000
    bne  t0, t3, fail          # 23 lui

    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
