# RV32I Processor Core

A 32-bit RISC-V processor implementing the RV32I base integer ISA with machine-mode
trap handling, written in Verilog. Three-stage pipeline, Harvard memory interfaces,
and the machine-level CSR file: `mstatus`, `misa`, `mie`, `mip`, `mtvec`, `mepc`,
`mcause`, `mtval`, `mscratch`, `mcountinhibit` and the cycle/instret counters.

The whole design simulates under [Icarus Verilog](https://steveicarus.github.io/iverilog/).
No vendor tools and no RISC-V GCC are needed to build or test it:

```
make
```

```
lint: clean (29 files)

module-level testbenches
  PASS  tb_msrv32_alu  (4640 vectors)
  PASS  tb_msrv32_branch_unit
  PASS  tb_msrv32_decoder
  PASS  tb_msrv32_imm_gen
  PASS  tb_msrv32_integer_file
  PASS  tb_msrv32_load_store

programs on the core
  PASS  build/01_smoke.hex  (29 cycles)
  PASS  build/02_alu.hex  (117 cycles)
  PASS  build/03_branch.hex  (68 cycles)
  PASS  build/04_loadstore.hex  (75 cycles)
  PASS  build/05_jump.hex  (29 cycles)
  PASS  build/06_csr.hex  (47 cycles)
  PASS  build/07_trap.hex  (31 cycles)
  PASS  build/08_irq.hex  (45 cycles)
  PASS  build/09_counters.hex  (37 cycles)

all tests passed
```

The only dependency is `iverilog` (plus `python3`, which ships with most systems):

```
sudo apt install iverilog          # gtkwave too, if you want to look at traces
```

## The pipeline

```
   STAGE 1              STAGE 2                            STAGE 3
   fetch                decode / read / address            execute / write back

  pc_mux                instr_mux    decoder               alu
  reg_block             imm_gen      imm_adder             load_unit
                        integer_file branch_unit           wb_sel_mux
                        machine_ctrl csr_file
                        store_unit   wr_en_generator
                                         |
                                    reg_block_2
                                 (pipeline register)
```

Stage 1 picks the next program counter and registers it. Stage 2 splits the
instruction into fields, reads the register file, builds the immediate, resolves
branches, computes the load/store address, and drives the CSR file and the store
port. Stage 3 runs the ALU, formats load data, and selects what goes back to the
register file.

There are no stalls and no interlocks. A result written in stage 3 is forwarded to
the instruction reading its operands in stage 2 by a bypass inside the register
file, which is what makes back-to-back dependent instructions — including a load
feeding the very next instruction — work at one instruction per cycle.

[docs/architecture.md](docs/architecture.md) walks through every module, the control
signals between them, and how a trap is taken and returned from.

## What is covered

All 47 RV32I base instructions, plus the six Zicsr instructions:

| group | instructions |
|---|---|
| arithmetic | `add` `sub` `addi` `lui` `auipc` |
| logic | `and` `or` `xor` `andi` `ori` `xori` |
| shift | `sll` `srl` `sra` `slli` `srli` `srai` |
| compare | `slt` `sltu` `slti` `sltiu` |
| branch | `beq` `bne` `blt` `bge` `bltu` `bgeu` |
| jump | `jal` `jalr` |
| load | `lb` `lh` `lw` `lbu` `lhu` |
| store | `sb` `sh` `sw` |
| system | `ecall` `ebreak` `mret` |
| CSR | `csrrw` `csrrs` `csrrc` `csrrwi` `csrrsi` `csrrci` |

Traps: illegal instruction, misaligned instruction / load / store, environment call,
breakpoint, and machine-mode external, timer and software interrupts.

## Layout

```
rtl/           the design: msrv32_top.v, core/ (datapath and control), csr/ (CSR file)
sim/           msrv32_soc.v -- core plus a unified memory, for simulation
tb/            tb_msrv32_top.v runs programs; unit/ holds the module testbenches
tests/         RV32I test programs in assembly, and the assembler that builds them
docs/          architecture notes and the record of what was repaired
Makefile       lint, unit tests, program tests, waveforms
```

## Test programs

The programs in `tests/` are self-checking. Each one runs a numbered sequence of
checks and stores the result to a magic address: `1` means every check passed,
anything else is the number of the first check that did not. The testbench reports
that value, so a failure names the exact check rather than just going quiet.

`tests/assemble.py` is a small RV32I assembler — the reason this repo needs no
cross-compiler. It handles the base ISA, the Zicsr instructions, labels and the
usual pseudo-instructions:

```
python3 tests/assemble.py tests/02_alu.s build/02_alu.hex
```

To watch a program run:

```
make wave PROG=07_trap
```

## Known limitations

These are deviations from the RISC-V specification that remain in the design. They
are recorded rather than silently fixed, because closing them changes the
architecture rather than repairing a mistake in it.

- **`csrrs`/`csrrc` with `rs1 = x0` still write the CSR.** The specification says a
  read-only access must not write. Here the decoder raises `csr_wr_en` for any CSR
  opcode, because it has no view of `rs1`. Harmless for read/write CSRs — the value
  written back is the value just read — but it would matter for a CSR with side
  effects on write.
- **No `misa` write, no `mtval` for every trap case, no `wfi`.** `wfi` decodes as a
  NOP.
- **Machine mode only.** No user or supervisor mode, no virtual memory, no PMP.
- **No bus protocol.** The memory interfaces are plain address/data/mask ports; there
  is no AXI or AHB wrapper.

## Origin

The architecture comes from Maven Silicon's *RISC-V RV32I RTL Design using Verilog
HDL* course, which I worked through in 2021 while studying Electronics &
Communication at BIT Mesra; I went on to intern there as an RTL Design Engineer.
The RTL in this repository is my own implementation of that architecture, originally
built as around two dozen separate Xilinx Vivado projects.

Revisiting it in 2026, it turned out the core had never actually been exercised.
The Vivado project did elaborate, but only on the machine it was written on: it
pulled roughly half its modules in by absolute path from the sibling projects they
were built in. The simulator loaded the snapshot with `msrv32_top` itself as the
simulation top — no clock, no reset, no instruction stream, and not one testbench
file anywhere in the tree. The core was never synthesised either.

Consolidating it into a single portable design and giving it a real test suite
turned up six functional bugs. [docs/fixes.md](docs/fixes.md) lists each one, what
it broke, and the test that now catches it.
