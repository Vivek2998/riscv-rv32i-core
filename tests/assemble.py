#!/usr/bin/env python3
"""Minimal RV32I assembler.

Turns a .s file into the 32-bit-hex-per-line format that $readmemh expects, so the
test programs in this repo can be rebuilt without a riscv-gnu-toolchain install.
Supports the full RV32I base integer set plus the Zicsr instructions the core
implements, labels, and a handful of the usual pseudo-instructions.

    ./assemble.py prog.s prog.hex
"""

import re
import sys

OPC = {
    "op": 0b0110011, "op_imm": 0b0010011, "load": 0b0000011, "store": 0b0100011,
    "branch": 0b1100011, "jal": 0b1101111, "jalr": 0b1100111, "lui": 0b0110111,
    "auipc": 0b0010111, "system": 0b1110011,
}

# name -> (format, opcode, funct3, funct7)
R = {n: ("R", OPC["op"], f3, f7) for n, f3, f7 in [
    ("add", 0b000, 0b0000000), ("sub", 0b000, 0b0100000), ("sll", 0b001, 0b0000000),
    ("slt", 0b010, 0b0000000), ("sltu", 0b011, 0b0000000), ("xor", 0b100, 0b0000000),
    ("srl", 0b101, 0b0000000), ("sra", 0b101, 0b0100000), ("or", 0b110, 0b0000000),
    ("and", 0b111, 0b0000000)]}
I = {n: ("I", OPC["op_imm"], f3, None) for n, f3 in [
    ("addi", 0b000), ("slti", 0b010), ("sltiu", 0b011), ("xori", 0b100),
    ("ori", 0b110), ("andi", 0b111)]}
SH = {n: ("SH", OPC["op_imm"], f3, f7) for n, f3, f7 in [
    ("slli", 0b001, 0b0000000), ("srli", 0b101, 0b0000000), ("srai", 0b101, 0b0100000)]}
LD = {n: ("I", OPC["load"], f3, None) for n, f3 in [
    ("lb", 0b000), ("lh", 0b001), ("lw", 0b010), ("lbu", 0b100), ("lhu", 0b101)]}
ST = {n: ("S", OPC["store"], f3, None) for n, f3 in [
    ("sb", 0b000), ("sh", 0b001), ("sw", 0b010)]}
BR = {n: ("B", OPC["branch"], f3, None) for n, f3 in [
    ("beq", 0b000), ("bne", 0b001), ("blt", 0b100), ("bge", 0b101),
    ("bltu", 0b110), ("bgeu", 0b111)]}
CSR = {n: ("CSR", OPC["system"], f3, None) for n, f3 in [
    ("csrrw", 0b001), ("csrrs", 0b010), ("csrrc", 0b011)]}
CSRI = {n: ("CSRI", OPC["system"], f3, None) for n, f3 in [
    ("csrrwi", 0b101), ("csrrsi", 0b110), ("csrrci", 0b111)]}

TABLE = {**R, **I, **SH, **LD, **ST, **BR, **CSR, **CSRI,
         "lui": ("U", OPC["lui"], None, None),
         "auipc": ("U", OPC["auipc"], None, None),
         "jal": ("J", OPC["jal"], None, None),
         "jalr": ("I", OPC["jalr"], 0b000, None)}

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1",
       "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
       "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
       "t3", "t4", "t5", "t6"]
REGS = {f"x{i}": i for i in range(32)}
REGS.update({n: i for i, n in enumerate(ABI)})
REGS["fp"] = 8

CSR_NAMES = {"mstatus": 0x300, "misa": 0x301, "mie": 0x304, "mtvec": 0x305,
             "mscratch": 0x340, "mepc": 0x341, "mcause": 0x342, "mtval": 0x343,
             "mip": 0x344, "mcycle": 0xB00, "minstret": 0xB02,
             "mcountinhibit": 0x320, "cycle": 0xC00, "time": 0xC01,
             "instret": 0xC02}


class AsmError(Exception):
    pass


def reg(tok):
    t = tok.strip().lower()
    if t not in REGS:
        raise AsmError(f"unknown register {tok!r}")
    return REGS[t]


def const(tok, labels, pc):
    t = tok.strip()
    if t in labels:
        return labels[t]
    m = re.fullmatch(r"%(hi|lo)\((.+)\)", t)
    if m:
        v = const(m.group(2), labels, pc)
        return (v + 0x800) >> 12 if m.group(1) == "hi" else sign(v & 0xFFF, 12)
    try:
        return int(t, 0)
    except ValueError:
        raise AsmError(f"cannot resolve {t!r}")


def sign(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


def fits(v, bits, what):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not lo <= v <= hi:
        raise AsmError(f"{what} {v} does not fit in {bits} signed bits")
    return v & ((1 << bits) - 1)


def split_mem(tok):
    """`off(reg)` -> (off, reg)."""
    m = re.fullmatch(r"\s*(-?[\w%()+-]*?)\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"expected off(reg), got {tok!r}")
    return (m.group(1) or "0"), m.group(2)


PSEUDO_SIZE = {"li": None, "la": None}


def expand(mnem, args):
    """Pseudo-instructions -> real ones. Returns a list of (mnem, args)."""
    if mnem == "nop":
        return [("addi", ["x0", "x0", "0"])]
    if mnem == "mv":
        return [("addi", [args[0], args[1], "0"])]
    if mnem == "not":
        return [("xori", [args[0], args[1], "-1"])]
    if mnem == "neg":
        return [("sub", [args[0], "x0", args[1]])]
    if mnem == "seqz":
        return [("sltiu", [args[0], args[1], "1"])]
    if mnem == "snez":
        return [("sltu", [args[0], "x0", args[1]])]
    if mnem == "j":
        return [("jal", ["x0", args[0]])]
    if mnem == "jr":
        return [("jalr", ["x0", f"0({args[0]})"])]
    if mnem == "ret":
        return [("jalr", ["x0", "0(ra)"])]
    if mnem == "call":
        return [("jal", ["ra", args[0]])]
    if mnem == "beqz":
        return [("beq", [args[0], "x0", args[1]])]
    if mnem == "bnez":
        return [("bne", [args[0], "x0", args[1]])]
    if mnem == "la":
        return [("lui", [args[0], f"%hi({args[1]})"]),
                ("addi", [args[0], args[0], f"%lo({args[1]})"])]
    if mnem == "csrr":
        return [("csrrs", [args[0], args[1], "x0"])]
    if mnem == "csrw":
        return [("csrrw", ["x0", args[0], args[1]])]
    return [(mnem, args)]


def li_parts(rd, value):
    """`li` becomes one addi when it fits, otherwise lui+addi."""
    v = value & 0xFFFFFFFF
    v = v - (1 << 32) if v & 0x80000000 else v
    if -2048 <= v <= 2047:
        return [("addi", [rd, "x0", str(v)])]
    hi = (v + 0x800) >> 12
    lo = sign(v & 0xFFF, 12)
    out = [("lui", [rd, str(hi & 0xFFFFF)])]
    if lo:
        out.append(("addi", [rd, rd, str(lo)]))
    return out


def parse(src):
    """First pass: strip comments, expand pseudo-ops, record label addresses."""
    items, labels, pc = [], {}, 0
    for lineno, raw in enumerate(src.splitlines(), 1):
        line = raw.split("#")[0].split("//")[0].strip()
        while line:
            m = re.match(r"^([.\w]+):\s*", line)
            if not m:
                break
            labels[m.group(1)] = pc
            line = line[m.end():].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        mnem = parts[0].lower()
        args = [a.strip() for a in parts[1].split(",")] if len(parts) > 1 else []
        try:
            if mnem in (".word", ".dword"):
                for a in args:
                    items.append((pc, lineno, ".word", [a]))
                    pc += 4
                continue
            if mnem == "li":
                try:
                    exp = li_parts(args[0], int(args[1], 0))
                except ValueError:
                    exp = expand("la", args)   # a label: always lui+addi
            elif mnem in ("ecall", "ebreak", "mret", "wfi"):
                exp = [(mnem, [])]
            else:
                exp = expand(mnem, args)
            for e in exp:
                items.append((pc, lineno, e[0], e[1]))
                pc += 4
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}")
    return items, labels


def encode(pc, mnem, args, labels):
    if mnem == ".word":
        return const(args[0], labels, pc) & 0xFFFFFFFF
    if mnem == "ecall":
        return (0 << 20) | OPC["system"]
    if mnem == "ebreak":
        return (1 << 20) | OPC["system"]
    if mnem == "mret":
        return (0b0011000 << 25) | (0b00010 << 20) | OPC["system"]
    if mnem == "wfi":
        return (0b0001000 << 25) | (0b00101 << 20) | OPC["system"]
    if mnem not in TABLE:
        raise AsmError(f"unknown instruction {mnem!r}")
    fmt, opc, f3, f7 = TABLE[mnem]

    if fmt == "R":
        rd, rs1, rs2 = reg(args[0]), reg(args[1]), reg(args[2])
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == "SH":
        rd, rs1 = reg(args[0]), reg(args[1])
        sh = const(args[2], labels, pc) & 0x1F
        return (f7 << 25) | (sh << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == "I":
        rd = reg(args[0])
        if opc in (OPC["load"], OPC["jalr"]) and "(" in args[1]:
            off, rs1n = split_mem(args[1])
            rs1, imm = reg(rs1n), const(off, labels, pc)
        else:
            rs1, imm = reg(args[1]), const(args[2], labels, pc)
        imm = fits(imm, 12, "immediate")
        return (imm << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == "S":
        rs2 = reg(args[0])
        off, rs1n = split_mem(args[1])
        rs1, imm = reg(rs1n), fits(const(off, labels, pc), 12, "offset")
        return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | \
               (f3 << 12) | ((imm & 0x1F) << 7) | opc
    if fmt == "B":
        rs1, rs2 = reg(args[0]), reg(args[1])
        off = const(args[2], labels, pc) - pc
        if off & 1:
            raise AsmError("branch target must be 2-byte aligned")
        imm = fits(off, 13, "branch offset")
        return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | \
               (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | \
               (((imm >> 11) & 1) << 7) | opc
    if fmt == "U":
        rd = reg(args[0])
        return ((const(args[1], labels, pc) & 0xFFFFF) << 12) | (rd << 7) | opc
    if fmt == "J":
        rd = reg(args[0])
        off = const(args[1], labels, pc) - pc
        imm = fits(off, 21, "jump offset")
        return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | \
               (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | opc
    if fmt in ("CSR", "CSRI"):
        rd = reg(args[0])
        name = args[1].strip().lower()
        csr = CSR_NAMES.get(name)
        if csr is None:
            csr = const(args[1], labels, pc)
        src = reg(args[2]) if fmt == "CSR" else (const(args[2], labels, pc) & 0x1F)
        return ((csr & 0xFFF) << 20) | (src << 15) | (f3 << 12) | (rd << 7) | opc
    raise AsmError(f"unhandled format {fmt}")


def assemble(src):
    items, labels = parse(src)
    words = []
    for pc, lineno, mnem, args in items:
        try:
            words.append(encode(pc, mnem, args, labels))
        except AsmError as e:
            raise AsmError(f"line {lineno}: {mnem} {' '.join(args)}: {e}")
    return words


def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <input.s> <output.hex>")
    with open(sys.argv[1]) as f:
        src = f.read()
    try:
        words = assemble(src)
    except AsmError as e:
        sys.exit(f"{sys.argv[1]}: {e}")
    with open(sys.argv[2], "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")
    print(f"{sys.argv[1]}: {len(words)} instructions -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
