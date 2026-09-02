# The machine counters. mcountinhibit is the interesting one: bit 0 inhibits
# mcycle and bit 2 inhibits minstret, so the write path and the read-back have
# to agree on which bit is which.

    li   s1, 2
    csrr t0, mcycle
    nop
    nop
    csrr t1, mcycle
    bltu t0, t1, ok2
    j    fail                  # 2  mcycle counts up
ok2:
    addi s1, s1, 1
    csrr t0, minstret
    nop
    nop
    csrr t1, minstret
    bltu t0, t1, ok3
    j    fail                  # 3  minstret counts up
ok3:
    addi s1, s1, 1
    li   t0, 1                 # inhibit mcycle only
    csrw mcountinhibit, t0
    csrr t1, mcountinhibit
    beq  t1, t0, ok4
    j    fail                  # 4  mcountinhibit reads back what was written
ok4:
    addi s1, s1, 1
    csrr t0, mcycle
    nop
    nop
    nop
    csrr t1, mcycle
    beq  t0, t1, ok5
    j    fail                  # 5  mcycle is frozen while inhibited
ok5:
    addi s1, s1, 1
    csrr t0, minstret
    nop
    nop
    csrr t1, minstret
    bltu t0, t1, ok6
    j    fail                  # 6  minstret keeps counting when only CY is inhibited
ok6:
    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
