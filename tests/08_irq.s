# External interrupt. First that the request reaches mip at all, then that with
# mstatus.MIE and mie.MEIE set it vectors through mtvec carrying the interrupt
# bit in mcause, and that mret resumes the interrupted code.

    la    t0, handler
    csrw  mtvec, t0
    li    s1, 2
    li    s2, 0

    li    t1, 0x1004           # raise the external interrupt line
    li    t2, 1
    sw    t2, 0(t1)
    nop
    nop
    nop

    csrr  t1, mip
    li    t2, 0x800            # mip.MEIP is bit 11
    and   t1, t1, t2
    beq   t1, t2, ok2
    j     fail                 # 2  the request reached mip

ok2:
    addi  s1, s1, 1
    li    t0, 0x800            # mie.MEIE
    csrw  mie, t0
    li    t0, 0x8              # mstatus.MIE - the trap fires from here on
    csrw  mstatus, t0

    li    t3, 100              # bounded spin, so a missed interrupt fails cleanly
spin:
    li    t0, 1
    beq   s2, t0, took
    addi  t3, t3, -1
    bne   t3, x0, spin
    j     fail                 # 3  the interrupt was never taken

took:
    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt

handler:
    csrr  t1, mcause
    li    t2, 0x8000000B       # interrupt bit set, cause 11 = machine external
    bne   t1, t2, fail         # wrong cause latched
    li    t4, 0x1004           # drop the request so it does not fire again
    sw    x0, 0(t4)
    li    s2, 1
    mret
