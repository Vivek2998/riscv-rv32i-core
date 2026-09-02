# Architecture

How the core is put together, module by module. Written to be readable without
the RTL open next to it.

## The shape of the machine

The core is a three-stage pipeline with separate instruction and data ports —
a Harvard arrangement, so a load or store never contends with instruction fetch.
It runs in machine mode only.

`msrv32_top` has these ports:

| port | dir | meaning |
|---|---|---|
| `clk_in`, `rst_in` | in | clock, synchronous reset |
| `imaddr_out` | out | instruction address |
| `instr_in` | in | the instruction word at that address |
| `dmaddr_out` | out | data address, always word aligned |
| `dmdata_in` | in | data read back |
| `dmadata_out` | out | data to write |
| `dmwr_mask_out` | out | which of the four bytes to write |
| `dmwr_req_out` | out | a write is requested this cycle |
| `rc_in` | in | 64-bit free-running real-time counter, feeds `time` |
| `eirq_in`, `tirq_in`, `sirq_in` | in | external, timer and software interrupt requests |

(The real port names are prefixed `ms_riscv32_mp_`; they are shortened here.)

Both memory ports expect a **registered read**: the address goes out in one cycle
and the data comes back in the next. `sim/msrv32_soc.v` models exactly that. The
reason is in the fetch path, below.

## Stage 1 — where the next instruction comes from

Two modules: `msrv32_pc_mux` and `msrv32_reg_block`.

`pc_mux` chooses the next PC from four sources, selected by `pc_src` from the
machine-control FSM:

| `pc_src` | source | when |
|---|---|---|
| `00` | `BOOT_ADDRESS` | reset |
| `01` | `mepc` | returning from a trap (`mret`) |
| `10` | `mtvec` trap address | taking a trap |
| `11` | `pc + 4`, or the branch target | normal execution |

The branch target comes from the immediate adder in stage 2 as `iaddr_in`, and
`branch_taken` from the branch unit, so a branch resolves in the same cycle it is
decoded — there is no branch predictor and no penalty beyond the flush.

`pc_mux` also raises `misaligned_instr_out` when a taken branch would land on an
address whose bit 1 is set, which is a trap on a machine without the compressed
extension.

`reg_block` is just the PC register.

Note what `imaddr_out` carries: it is the mux **output**, not the registered PC.
So the address on the bus in cycle N is the PC that the register will hold in
cycle N+1. Register the memory read and the fetched word lines up with the PC that
selected it. That is why the memory model is synchronous rather than
combinational — get this backwards and the core executes each instruction against
the wrong PC.

## Stage 2 — decode, read, address, branch

This is the wide stage. Everything below happens in one cycle.

**`msrv32_instr_mux`** splits the instruction into `opcode`, `funct3`, `funct7`,
`rs1_addr`, `rs2_addr`, `rd_addr`, `csr_addr` and the raw `instr[31:7]` the
immediate generator needs. When `flush_in` is asserted it substitutes
`0x00000013` — `addi x0, x0, 0`, a NOP — so the pipeline is drained by feeding it
an instruction that does nothing rather than by gating a dozen control signals.

**`msrv32_decoder`** turns the opcode and `funct3` into every control signal in
the machine. One-hot `is_*` flags are decoded from `opcode[6:2]` and then combined:

- `alu_opcode` = `{funct7[5] & imm_alu, funct3}`. The `funct7[5]` bit distinguishes
  `add`/`sub` and `srl`/`sra`, but it must be ignored for the immediate forms that
  do not carry it — `addi` has no `subi` — which is what `imm_alu` gates.
- `imm_type` tells the immediate generator which shape to build:
  `2` = S, `3` = B, `4` = U, `5` = J, `6` = CSR immediate, anything else = I.
- `wb_mux_sel` picks what is written back:
  `000` ALU, `001` load unit, `010` immediate, `011` address adder, `100` CSR,
  `101` PC+4.
- `alu_src` = `opcode[5]`, choosing `rs2` or the immediate as the ALU's second
  operand. `iadder_src` picks `rs1` instead of the PC as the address base, which is
  what loads, stores and `jalr` need.
- `rf_wr_en` and `csr_wr_en` say whether this instruction writes the register file
  and the CSR file.
- `illegal_instr_out` fires for an unimplemented opcode or one whose low two bits
  are not `11`. `misaligned_load_out` and `misaligned_store_out` compare the access
  size in `funct3[1:0]` against the low bits of the computed address.
- `mem_wr_req_out` is a store that is neither misaligned nor happening while a trap
  is being taken — a faulting instruction must not reach memory.

**`msrv32_imm_gen`** assembles the immediate. RISC-V scatters immediate bits across
the instruction word specifically so that each bit lands in as few different places
as possible across formats; this module is the multiplexer that undoes that.

**`msrv32_imm_adder`** computes `(rs1 or pc) + imm`. One adder serves three
purposes: the load/store address, the `jalr` target, and the `auipc` result.

**`msrv32_integer_file`** is the 32×32 register file, two read ports and one write
port, with `x0` hard-wired to zero — the write is suppressed for `rd = x0`, and so
is the bypass described below.

**`msrv32_branch_unit`** evaluates the branch condition. `blt`/`bge` are signed and
`bltu`/`bgeu` are not, which is the whole difficulty of the module; it also reports
"taken" unconditionally for `jal` and for `jalr` with `funct3 = 0`.

**`msrv32_store`** places the bytes of `rs2` into the right lanes of the write data
and builds the four-bit write mask, so a `sb` to address 2 writes only byte 2.

**`msrv32_wr_en_generator`** gates the register-file and CSR write enables with
`flush`, so an instruction killed by a trap does not commit.

**`msrv32_reg_block_2`** is the pipeline register between stages 2 and 3, carrying
operands, the immediate, the address, and the control signals stage 3 needs.

## Stage 3 — execute and write back

**`msrv32_alu`** does the ten RV32I operations. `sra` is the one that needs care:
Verilog's `>>>` is only an arithmetic shift when its operand is declared signed, so
the module copies the operand into a `reg signed` first.

**`msrv32_load`** takes the word the memory returned and extracts the addressed
byte or halfword, extending it with either the sign bit or zeros depending on
whether the instruction was `lb`/`lh` or `lbu`/`lhu`.

**`msrv32_wb_sel_mux`** selects the writeback value from the six candidates, and
also selects the ALU's second operand.

## Why there are no stalls

A three-stage pipeline has instruction N in stage 3 while N+1 is in stage 2. N
writes its result to the register file at the edge that ends stage 3 — the same
edge at which N+1 latches operands it read combinationally during that cycle. So
N+1 would read the old value.

The register file solves this with a bypass on its read ports: if a read address
matches the write address while the write is enabled, it returns the incoming write
data instead of the stored word. Instructions two apart need nothing, because by
then the write has landed.

This covers the load-use case too, which usually forces a stall on a five-stage
machine. Here the load data arrives in stage 3, in the same cycle the dependent
instruction is reading its operands, so the same bypass carries it.

The bypass must not apply to `x0`: an instruction writing `x0` still asserts
`rf_wr_en`, and without a guard the discarded value would be forwarded to a reader
of `x0` in the next cycle. That was one of the bugs found in 2026 — see
[fixes.md](fixes.md).

## Traps

`msrv32_machine_control` is a four-state machine:

```
   RESET ──> OPERATING ──trap──> TRAP_TAKEN ──┐
               ^   │                          │
               │   └────mret──> TRAP_RETURN ──┤
               └──────────────────────────────┘
```

A trap is taken when `(mstatus.MIE & pending_enabled_interrupt) | exception |
ecall | ebreak`. Exceptions are illegal instruction and the three misalignment
cases; interrupts are external, timer and software, each gated by its own bit in
`mie` and visible in `mip`.

In `TRAP_TAKEN` the FSM drives `pc_src = mtvec`, flushes stage 2, and pulses
`set_epc`, `set_cause` and `mie_clear`. In `TRAP_RETURN` it drives
`pc_src = mepc`, flushes, and pulses `mie_set`.

Two details worth remembering:

- **`mepc` gets the stage-3 PC, not the stage-2 PC.** The trap is detected while the
  offending instruction is in stage 2, but the FSM does not reach `TRAP_TAKEN` until
  the next cycle, by which time that instruction has moved to stage 3. So sampling
  the stage-3 PC copy is what records the right address.
- **`mepc` points at the trapping instruction, not past it.** A handler returning
  from `ecall` must add 4 itself, or it will execute the same `ecall` forever. An
  interrupt handler generally should not, since the interrupted instruction never
  ran.

The cause is latched in `OPERATING`, the only state in which a trap is detected,
and read out by the CSR file on the way into `TRAP_TAKEN`.

## The CSR file

`msrv32_csr_file` is a container: each CSR is its own small module, and two
multiplexers tie them together.

- `csr_data_mux_unit` is the read path — a case over the CSR address returning the
  right register. Unmapped addresses read zero.
- `data_wr_mux_unit` is the write path. `csr_op[1:0]` selects write (`csrrw`),
  set (`csrrs`, old `|` new) or clear (`csrrc`, old `& ~`new). `misa_and_pre_data`
  supplies the operand, choosing `rs1` or the 5-bit immediate from `funct3[2]`.

The registers themselves: `mstatus_reg` (holds `MIE`/`MPIE` and the save-restore
behaviour on trap entry and `mret`), `mie_reg`, `mip_reg`, `mtvec_reg` (with direct
and vectored modes), `mepc_and_mscratch_reg`, `mcause_reg`, `mtval_reg`,
`machine_counter` (`mcycle`, `minstret`, `mtime`) and `machine_counter_setup`
(`mcountinhibit`, whose bit 0 freezes `mcycle` and bit 2 freezes `minstret`).

`mcause` is `{interrupt, 27'b0, cause[3:0]}` — bit 31 set means an interrupt, so a
machine external interrupt reads `0x8000000B` while an environment call from
machine mode reads `0x0000000B`.
