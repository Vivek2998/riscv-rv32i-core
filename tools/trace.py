#!/usr/bin/env python3
"""Render a cycle-by-cycle trace of the core running a program.

`tb/tb_msrv32_trace.v` writes one tab-separated line per cycle; `assemble.py`
writes a listing mapping each address to the instruction there. This joins the
two and prints what each pipeline stage was holding, or emits the same thing as
JSON.

    ./trace.py build/03_branch.tsv build/03_branch.json
    ./trace.py build/03_branch.tsv build/03_branch.json --json out.json
"""

import argparse
import json
import sys

STATES = {1: "reset", 2: "run", 4: "trap", 8: "mret"}
CAUSES = {0: "misaligned instruction", 2: "illegal instruction",
          3: "breakpoint", 4: "misaligned load", 6: "misaligned store",
          7: "timer interrupt", 11: "ecall / external interrupt"}
ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1",
       "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
       "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
       "t3", "t4", "t5", "t6"]

NOP = 0x00000013

OP, OP_IMM, LOAD, STORE = 0x33, 0x13, 0x03, 0x23
BRANCH, JAL, JALR, LUI, AUIPC, SYSTEM = 0x63, 0x6F, 0x67, 0x37, 0x17, 0x73


def operands(word):
    """Which register fields this encoding actually reads.

    rs1 and rs2 sit at fixed positions, so an I-type instruction still has bits
    where rs2 would be -- they are immediate bits. Reporting them as a register
    read is what the trace would otherwise show.
    """
    opcode = word & 0x7F
    funct3 = (word >> 12) & 0x7
    rs1 = opcode not in (LUI, AUIPC, JAL) and not (opcode == SYSTEM and funct3 & 0b100)
    rs2 = opcode in (OP, STORE, BRANCH)
    return rs1, rs2


def read_trace(path):
    with open(path) as f:
        head = f.readline().rstrip("\n").split("\t")
        rows = []
        for raw in f:
            cells = raw.rstrip("\n").split("\t")
            if len(cells) != len(head):
                continue
            row = {}
            for k, v in zip(head, cells):
                row[k] = None if "x" in v.lower() and k != "cycle" else int(v, 16 if len(v) == 8 else 10)
            rows.append(row)
    return rows


def cycles(trace, listing):
    """One record per cycle, with each stage resolved to an instruction."""
    out = []
    prev_live = False
    for i, r in enumerate(trace):
        flushed = bool(r["flush"])
        s2_pc, s3_pc = r["s2pc"], r["s3pc"]
        s2 = listing.get(str(s2_pc))
        s3 = listing.get(str(s3_pc))
        state = STATES.get(r["state"], "?")

        # Stage 2 is only holding a real instruction when it is not being flushed
        # and the fetched word matches what the program has at that address.
        live2 = (not flushed) and s2 is not None and r["s2ir"] == s2["word"]

        # Stage 3 holds an instruction only if stage 2 held one last cycle. Without
        # this the reset value of the stage-2/3 register reads as "the instruction
        # at address 0", which it is not.
        live3 = prev_live and s3 is not None
        prev_live = live2

        rec = {
            "cycle": r["cycle"],
            "state": state,
            "flush": flushed,
            "fetch": r["s1pc"],
            "s2": None,
            "s3": None,
            "mem": None,
            "trap": None,
        }
        if live2:
            uses1, uses2 = operands(s2["word"])
            rec["s2"] = {
                "pc": s2_pc, "asm": s2["asm"], "source": s2["source"],
                "rs1": r["s2rs1"] if uses1 else None,
                "rs1v": r["s2rs1v"], "byp1": bool(r["byp1"]) and uses1,
                "rs2": r["s2rs2"] if uses2 else None,
                "rs2v": r["s2rs2v"], "byp2": bool(r["byp2"]) and uses2,
                "rd": r["s2rd"], "imm": r["s2imm"], "iadder": r["s2iadder"],
                "branch": bool(r["s2br"]),
            }
        if live3:
            rec["s3"] = {
                "pc": s3_pc, "asm": s3["asm"],
                "rd": r["s3rd"], "value": r["s3wb"],
                "wrote": bool(r["s3we"]) and r["s3rd"] != 0,
                "alu": r["s3alu"],
            }
        if r["mreq"]:
            rec["mem"] = {"write": True, "addr": r["maddr"],
                          "data": r["mwdata"], "mask": r["mmask"]}
        if r["trap"]:
            # cause_out is registered: the trap is raised combinationally this
            # cycle and the cause lands at the edge that ends it, so the value
            # belonging to this trap is the one visible on the next line.
            nxt = trace[i + 1]["cause"] if i + 1 < len(trace) else r["cause"]
            rec["trap"] = {"cause": nxt,
                           "name": CAUSES.get(nxt, f"cause {nxt}")}
        out.append(rec)
    return out


def reg(n):
    return f"x{n}({ABI[n]})" if n else "x0"


def render(recs, limit=None, start=0):
    print(f"{'cyc':>4} {'st':<5} {'fetch':<8} | {'stage 2  decode / read':<52} | "
          f"{'stage 3  execute / write back':<34} | notes")
    print("-" * 128)
    for rec in recs[start: None if limit is None else start + limit]:
        s2, s3 = rec["s2"], rec["s3"]
        if s2:
            reads = []
            if s2["rs1"] is not None:
                reads.append(f"{ABI[s2['rs1']]}={s2['rs1v']:08x}" + ("*" if s2["byp1"] else ""))
            if s2["rs2"] is not None:
                reads.append(f"{ABI[s2['rs2']]}={s2['rs2v']:08x}" + ("*" if s2["byp2"] else ""))
            col2 = f"{s2['pc']:04x}  {s2['asm']:<22} {'  '.join(reads)}"
        else:
            col2 = "--  flushed" if rec["flush"] else "--"

        if s3 and s3["wrote"]:
            col3 = f"{s3['pc']:04x}  {ABI[s3['rd']]:<4} <= {s3['value']:08x}"
        elif s3:
            col3 = f"{s3['pc']:04x}  {s3['asm']:<22}"
        else:
            col3 = "--"

        notes = []
        if s2 and s2["branch"]:
            notes.append(f"branch taken -> {s2['iadder'] & ~1:04x}")
        if s2 and (s2["byp1"] or s2["byp2"]):
            notes.append("* forwarded from stage 3")
        if rec["mem"]:
            notes.append(f"store {rec['mem']['data']:08x} -> [{rec['mem']['addr']:04x}] mask {rec['mem']['mask']:04b}")
        if rec["trap"]:
            notes.append(f"TRAP: {rec['trap']['name']}")

        print(f"{rec['cycle']:>4} {rec['state']:<5} {rec['fetch']:04x}     | "
              f"{col2:<52} | {col3:<34} | {', '.join(notes)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("trace", help="the .tsv written by tb_msrv32_trace")
    ap.add_argument("listing", help="the .json written by assemble.py")
    ap.add_argument("--json", metavar="FILE", help="write the joined trace as JSON")
    ap.add_argument("--limit", type=int, help="only render this many cycles")
    ap.add_argument("--start", type=int, default=0, help="first cycle to render")
    args = ap.parse_args()

    with open(args.listing) as f:
        listing = json.load(f)
    recs = cycles(read_trace(args.trace), listing)

    if args.json:
        with open(args.json, "w") as f:
            json.dump({"cycles": recs, "listing": listing}, f, separators=(",", ":"))
        print(f"{len(recs)} cycles -> {args.json}", file=sys.stderr)
    else:
        render(recs, args.limit, args.start)


if __name__ == "__main__":
    main()
