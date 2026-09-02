# Smoke test: does the core fetch, decode and retire a straight line of
# instructions, and can it reach the tohost store at all?
#
# s1 holds the number of the check being run. Reaching the end sets it to 1,
# so a stored 1 means everything passed and anything else names the check
# that did not.

    li   s1, 2
    li   t0, 5
    li   t1, 7
    add  t2, t0, t1
    li   t3, 12
    bne  t2, t3, fail          # check 2: 5 + 7 == 12

    addi s1, s1, 1
    sub  t2, t3, t0
    li   t4, 7
    bne  t2, t4, fail          # check 3: 12 - 5 == 7

    addi s1, s1, 1
    addi t5, x0, -1
    li   t6, -1
    bne  t5, t6, fail          # check 4: addi with a negative immediate

    addi s1, s1, 1
    add  t0, x0, x0
    bne  t0, x0, fail          # check 5: x0 reads as zero

    addi s1, s1, 1
    li   t1, 0
    addi x0, x0, 99            # writes to x0 must be discarded...
    add  t0, x0, t1            # ...including on the write-to-read bypass path
    bne  t0, x0, fail          # check 6: x0 still reads zero one cycle later

    li   s1, 1                 # every check passed
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt
