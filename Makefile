# RV32I core - simulation flow.
#
# Everything here runs on Icarus Verilog; no vendor tools and no RISC-V GCC are
# needed. The test programs are assembled by tests/assemble.py.
#
#   make          build and run everything
#   make unit     module-level testbenches only
#   make prog     program-level tests only
#   make lint     elaborate the RTL and fail on any warning
#   make wave PROG=02_alu    re-run one program and open the trace
#   make clean

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave
PYTHON   ?= python3

RTL     := $(sort $(wildcard rtl/*.v rtl/core/*.v rtl/csr/*.v))
SOC     := sim/msrv32_soc.v
SYS_TB  := tb/tb_msrv32_top.v
UNIT_TB := $(sort $(wildcard tb/unit/*.v))
UNITS   := $(notdir $(basename $(UNIT_TB)))

BUILD   := build
ASM     := $(sort $(wildcard tests/*.s))
HEX     := $(ASM:tests/%.s=$(BUILD)/%.hex)

IVFLAGS := -g2005 -Wall
CYCLES  ?= 20000
PROG    ?= 01_smoke

.PHONY: all test unit prog lint wave clean

all: test

test: lint unit prog
	@echo "" && echo "all tests passed"

$(BUILD):
	@mkdir -p $(BUILD)

# ---------------------------------------------------------------- lint

lint: | $(BUILD)
	@$(IVERILOG) $(IVFLAGS) -s msrv32_top -o $(BUILD)/lint.vvp $(RTL) 2>$(BUILD)/lint.log; \
	 if [ -s $(BUILD)/lint.log ]; then \
	   echo "lint: warnings"; cat $(BUILD)/lint.log; exit 1; \
	 else echo "lint: clean ($(words $(RTL)) files)"; fi

# ---------------------------------------------------------------- unit tests

unit: | $(BUILD)
	@echo "" && echo "module-level testbenches"
	@fail=0; for tb in $(UNITS); do \
	   $(IVERILOG) $(IVFLAGS) -s $$tb -o $(BUILD)/$$tb.vvp $(RTL) tb/unit/$$tb.v || { fail=1; continue; }; \
	   out=$$($(VVP) $(BUILD)/$$tb.vvp); echo "  $$out"; \
	   case "$$out" in *PASS*) ;; *) fail=1 ;; esac; \
	 done; exit $$fail

# ---------------------------------------------------------------- program tests

$(BUILD)/%.hex: tests/%.s tests/assemble.py | $(BUILD)
	@$(PYTHON) tests/assemble.py $< $@ > /dev/null

$(BUILD)/system.vvp: $(RTL) $(SOC) $(SYS_TB) | $(BUILD)
	@$(IVERILOG) $(IVFLAGS) -s tb_msrv32_top -o $@ $(RTL) $(SOC) $(SYS_TB)

prog: $(BUILD)/system.vvp $(HEX)
	@echo "" && echo "programs on the core"
	@fail=0; for h in $(HEX); do \
	   out=$$($(VVP) $(BUILD)/system.vvp +PROG=$$h +MAXCYCLES=$(CYCLES)); echo "  $$out"; \
	   case "$$out" in *PASS*) ;; *) fail=1 ;; esac; \
	 done; exit $$fail

# ---------------------------------------------------------------- waveform

wave: $(BUILD)/system.vvp $(BUILD)/$(PROG).hex
	@$(VVP) $(BUILD)/system.vvp +PROG=$(BUILD)/$(PROG).hex +MAXCYCLES=$(CYCLES) \
	        +VCD=$(BUILD)/$(PROG).vcd
	@$(GTKWAVE) $(BUILD)/$(PROG).vcd >/dev/null 2>&1 &

clean:
	@rm -rf $(BUILD)
