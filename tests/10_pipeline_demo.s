# Written for the pipeline visualiser: one of each interesting thing, in an
# order that reads well when you step through it a cycle at a time.
#
#   - an arithmetic result forwarded to the instruction right behind it
#   - a store, then a load of the same word
#   - a load feeding the very next instruction, which on a longer pipeline
#     would cost a stall and here does not
#   - a taken branch, resolved without a bubble
#   - a trap that vectors through mtvec and returns through mret
#
# It is a self-checking test like the rest: it stores 1 when everything passed.

    li   s1, 2
    li   s0, 0x800             # scratch pointer

    li   t0, 5
    li   t1, 7
    add  t2, t0, t1            # t1 arrives forwarded from the instruction before

    sw   t2, 0(s0)
    lw   t3, 0(s0)
    addi t4, t3, 1             # load-use: t3 comes straight out of stage 3

    li   t5, 13
    bne  t4, t5, fail          # 2  5 + 7, stored, reloaded, + 1 == 13

    addi s1, s1, 1
    la   a0, handler
    csrw mtvec, a0
    li   a1, 0
    ecall                      # traps; the handler resumes at the next instruction
    li   t6, 1
    bne  a1, t6, fail          # 3  the handler ran and mret came back here

    li   s1, 1
fail:
    li   a2, 0x1000
    sw   s1, 0(a2)
halt:
    j    halt

handler:
    csrr a3, mcause
    li   a4, 11                # environment call from M-mode
    bne  a3, a4, fail
    li   a1, 1
    csrr a5, mepc
    addi a5, a5, 4
    csrw mepc, a5
    mret
