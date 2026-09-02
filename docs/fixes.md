# What was repaired

The RTL was written in 2021 as around two dozen separate Vivado projects, one per
module, and was never simulated as a whole. This is the record of what had to
change to get it running, and how each change was shown to be a real fix rather
than a guess.

## The state it was in

- **The design only existed on one machine.** The Vivado project that assembled the
  core held about half the sources itself; the rest — the decoder, the machine-control
  FSM, the CSR file and its sub-registers — were pulled in by absolute path from the
  sibling projects they were written in (`C:/Users/ASUS/Machine_control/...`). It
  elaborated there and nowhere else. A stray zero-byte `msrv32_machine_control.v` sat
  unused inside the project folder next to the reference to the real one.
- **Nothing had ever been run.** The 2021 logs show the snapshot building and the
  simulator loading it — with `msrv32_top` itself as the simulation top, so there was
  no clock, no reset and no instruction stream driving any of it. `simulate.log` is
  empty, and the only `.v` files under any `sim_1` directory are Vivado's own
  `glbl.v`. There is no testbench anywhere in the tree.
- **Never synthesised, and no constraints.** The core has no `.xdc` and no synthesis
  run; the only ones in the tree belong to two small side experiments.
- `csr_demo.v` was a byte-for-byte duplicate of `msrv32_csr_file.v`, so compiling
  both would collide on the module name.
- Two files were named after something other than the module inside them
  (`mtvac_reg.v` held `mtval_reg`; `msrv32_wr_en_generator.v` held
  `wr_en_generator`), and two modules did not follow the `msrv32_` prefix the rest
  of the design used.
- Mixed CRLF and LF line endings, and a `timescale` on some files but not others,
  which makes the simulation time unit depend on compile order.

Once the missing modules were put in one place, the design elaborated cleanly.
Nothing in the datapath was structurally wrong — it had simply never been
assembled.

## Functional bugs

Six defects that change what the hardware does. Each is listed with the test that
fails if the fix is reverted.

### 1. Interrupt requests never reached `mip`

`msrv32_csr_file` instantiated `mip_reg` with `.e_irq_in(e_irq)`, `.t_irq_in(t_irq)`
and `.s_irq_in(s_irq)` — but the file's ports are `e_irq_in`, `t_irq_in`,
`s_irq_in`. The unsuffixed names were not declared anywhere, so Verilog's implicit
net rule created three undriven wires and connected those instead.

Effect: `mip` never set `MEIP`, `MTIP` or `MSIP`, so **no interrupt could ever be
taken** — external, timer or software. Silent, because implicit nets are legal.

Caught by `08_irq`.

### 2. `machine_counter_setup` never drove its output

The module ends with `assign mcountinhibit = {...}` — assigning to another implicit
net rather than to its actual output port `mcountinhibit_out`. The port was left
undriven, so the CSR file read `x` for `mcountinhibit`.

Caught by `09_counters`.

### 3. CSR decode was inverted

`assign is_csr = (~|funct3_in) & is_system;`

`~|funct3` is true when `funct3` is zero — which is `ecall`, `ebreak` and `mret`.
The CSR instructions are exactly the ones with `funct3 != 0`. The condition was
backwards, so no CSR instruction was recognised as one, and `ecall`/`ebreak` were
treated as CSR accesses instead.

Caught by `06_csr`, `07_trap`, `08_irq`, `09_counters` and `tb_msrv32_decoder`.

### 4. CSR reads were never written back to `rd`

`rf_wr_en_out` listed every instruction format that writes a register except the
CSR ones. `wb_mux_sel` had a dedicated `WB_CSR` encoding routing CSR data to the
writeback mux, and nothing ever committed it — the entire path was dead.

Caught by the same tests as above.

### 5. The trap cause was latched in the wrong state

In `msrv32_machine_control`, the `always` block that latches `cause_out` read:

```verilog
else if(curr_state == STATE_OPERATING)
begin
   if(mie_in & eip)
   begin
      cause_out <= 4'b1011;
      i_or_e_out <= 1'b1;
   end
end
else if(mie_in & sip)
...
```

Only the external interrupt was inside the `STATE_OPERATING` branch. Every other
cause — timer and software interrupts, illegal instruction, misalignment, `ecall`,
`ebreak` — hung off the state test as `else if`, so they could only be latched in a
state that is *not* `OPERATING`. But `OPERATING` is the only state in which a trap
is ever detected, and by the time the machine reaches `TRAP_TAKEN` the pipeline has
been flushed to a NOP, so none of those conditions still hold.

Effect: `mcause` recorded 0 instead of the real cause for every exception. An
`ecall` handler could not tell why it had been entered.

The block was rewritten so the whole chain nests inside `STATE_OPERATING`.

Caught by `07_trap`.

### 6. `x0` was corrupted by the write-to-read bypass

The register file forwards a result being written to a read issued in the same
cycle. The write itself was correctly suppressed for `rd = x0`, but the bypass was
not:

```verilog
assign rs_1_out = ((rs_1_addr_in == rd_addr_in) && wr_en_in) ? rd_in : reg_file[...];
```

Any instruction targeting `x0` — which is how `jalr x0`, `ret` and a canonical NOP
are encoded — would forward its discarded result to a reader of `x0` one cycle
later. `x0` must always read as zero.

Caught by `01_smoke`, `05_jump` and `tb_msrv32_integer_file`.

### 7. `mcountinhibit` write and read bits were crossed

Reading returns `{29'b0, IR, 1'b0, CY}`, so bit 0 is the cycle counter and bit 2 is
the instruction counter, matching the specification. The write path had them the
other way round:

```verilog
mcountinhibit_cy_out <= data_wr_2_in;
mcountinhibit_ir_out <= data_wr_0_in;
```

Writing `1` to inhibit `mcycle` inhibited `minstret` instead, and reading back gave
`4`. Writing `5` masked the bug, which is presumably why it survived.

Caught by `09_counters`.

## Cleanups that change no behaviour

- `msrv32_decoder` had the `load` case item written **twice**; the second copy was
  unreachable. Removed.
- `msrv32_machine_control` computed `FUNCT7_wfi` and `rs2_addr_wfi` into undeclared
  implicit nets and then never read them. `wfi` is not implemented, so they were
  removed rather than wired up.
- `timescale` added to the twelve files that lacked one; CRLF endings normalised;
  trailing whitespace stripped.
- `Decoder` renamed to `msrv32_decoder` and `wr_en_generator` to
  `msrv32_wr_en_generator`, so every module matches its filename and the `msrv32_`
  prefix.

With all of this in place the design elaborates under `iverilog -Wall` with no
warnings at all.

## How the fixes were verified

Passing tests only prove something if they are capable of failing. Each fix was
reverted one at a time, the suite re-run, and the tests that noticed recorded:

| defect re-introduced | tests that catch it |
|---|---|
| interrupt lines never reached `mip` | `08_irq` |
| `mcountinhibit_out` left undriven | `09_counters` |
| `is_csr` decode inverted | `06_csr`, `07_trap`, `08_irq`, `09_counters`, `tb_msrv32_decoder` |
| CSR result not written back to `rd` | `06_csr`, `07_trap`, `08_irq`, `09_counters`, `tb_msrv32_decoder` |
| trap cause latched in the wrong state | `07_trap` |
| `x0` corrupted by the bypass | `01_smoke`, `05_jump`, `tb_msrv32_integer_file` |
| `mcountinhibit` write bits crossed | `09_counters` |
| duplicate `load` case item | *nothing — confirming it was dead code, not a bug* |

Every functional defect is caught by at least one test. The duplicate case item
changes no behaviour, which is exactly why it is listed as a cleanup above rather
than as a bug.
