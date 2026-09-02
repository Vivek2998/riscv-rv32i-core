# jal / jalr / auipc / lui, including a call that has to come back through ra.

    li   s1, 2
    li   s2, 0
    jal  ra, sub1
    li   t0, 7
    bne  s2, t0, fail          # 2  jal called sub1 and ra brought us back

    addi s1, s1, 1
here:
    auipc t0, 0
    la    t1, here
    bne   t0, t1, fail         # 3  auipc 0 yields its own PC

    addi s1, s1, 1
    la   t0, jtgt
    jalr x0, 0(t0)
    j    fail                  # 4  jalr must skip this
jtgt:
    addi s1, s1, 1
    lui  t0, 0xABCDE
    li   t1, 0xABCDE000
    bne  t0, t1, fail          # 5  lui

    addi s1, s1, 1
    jal  x0, jtgt2
    j    fail                  # 6  jal with x0 as link is a plain jump
jtgt2:
    li   s1, 1
fail:
    li   t1, 0x1000
    sw   s1, 0(t1)
halt:
    j    halt

sub1:
    li   s2, 7
    ret
