# Take a trap and return from it: ecall must vector through mtvec, record cause 11
# and the faulting PC, and mret must resume where the handler points mepc.

    la    t0, handler
    csrw  mtvec, t0
    li    s1, 2
    li    s2, 0

ecall_site:
    ecall                  # traps; the handler resumes at the next instruction

    li    t0, 1
    bne   s2, t0, fail         # 2  handler ran and mret returned here

    addi  s1, s1, 1
    csrr  t1, mepc
    la    t2, ecall_site
    addi  t2, t2, 4
    bne   t1, t2, fail         # 3  mepc pointed at the ecall, handler advanced it

    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt

handler:
    csrr  t1, mcause
    li    t2, 11               # environment call from M-mode
    bne   t1, t2, fail         # wrong cause latched
    li    s2, 1
    csrr  t3, mepc
    addi  t3, t3, 4
    csrw  mepc, t3
    mret
