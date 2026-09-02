# The Zicsr instructions against mscratch, which is a plain read/write CSR, plus
# a read/write of mepc. These only pass if the decoder recognises funct3 != 0 as
# a CSR access and the result is actually written back to rd.

    li   s1, 2
    li   t0, 0x5A5
    csrrw t1, mscratch, t0
    bne   t1, x0, fail         # 2  csrrw returns the previous value (0)

    addi s1, s1, 1
    csrrs t2, mscratch, x0
    li    t3, 0x5A5
    bne   t2, t3, fail         # 3  csrrw stored the new value

    addi s1, s1, 1
    li    t0, 0x0F0
    csrrs t1, mscratch, t0
    csrrs t2, mscratch, x0
    li    t3, 0x5F5
    bne   t2, t3, fail         # 4  csrrs sets bits

    addi s1, s1, 1
    li    t0, 0x0F0
    csrrc t1, mscratch, t0
    csrrs t2, mscratch, x0
    li    t3, 0x505
    bne   t2, t3, fail         # 5  csrrc clears bits

    addi s1, s1, 1
    csrrwi t1, mscratch, 31
    csrrs  t2, mscratch, x0
    li     t3, 31
    bne    t2, t3, fail        # 6  csrrwi takes a 5-bit immediate

    addi s1, s1, 1
    csrrsi t1, mscratch, 1
    csrrs  t2, mscratch, x0
    li     t3, 31
    bne    t2, t3, fail        # 7  csrrsi

    addi s1, s1, 1
    csrrci t1, mscratch, 1
    csrrs  t2, mscratch, x0
    li     t3, 30
    bne    t2, t3, fail        # 8  csrrci

    addi s1, s1, 1
    li    t0, 0x40
    csrw  mepc, t0
    csrr  t1, mepc
    bne   t1, t0, fail         # 9  mepc is readable and writable

    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
