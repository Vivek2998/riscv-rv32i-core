`timescale 1ns / 1ps

// Runs a RV32I program on the core and reports the value it stores to TOHOST.
//
//   iverilog ... -o run.vvp && vvp run.vvp +PROG=prog.hex [+MAXCYCLES=n] [+VCD=out.vcd]
//
// The programs are self-checking: each writes 1 to TOHOST when every check passed, or
// the number of the first check that failed. Anything else -- no store at all, a jump
// into the weeds -- shows up as a timeout, which is also a failure.

module tb_msrv32_top;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg e_irq = 1'b0, t_irq = 1'b0, s_irq = 1'b0;

    wire [31:0] imaddr, dmaddr, dmdata_w, tohost_data, irqctl_data;
    wire [3:0]  dmwr_mask;
    wire        dmwr_req, tohost_we, irqctl_we;

    integer maxcycles = 20000;
    integer cycles    = 0;
    integer fd, words;
    reg [1023:0] line;
    reg [1023:0] prog;
    reg [1023:0] vcd;

    msrv32_soc dut (
        .clk(clk), .rst(rst), .e_irq(e_irq), .t_irq(t_irq), .s_irq(s_irq),
        .imaddr(imaddr), .dmaddr(dmaddr), .dmdata_w(dmdata_w),
        .dmwr_mask(dmwr_mask), .dmwr_req(dmwr_req),
        .tohost_we(tohost_we), .tohost_data(tohost_data),
        .irqctl_we(irqctl_we), .irqctl_data(irqctl_data)
    );

    // the program under test drives its own interrupt requests through IRQCTL
    always @(posedge clk) begin
        if (irqctl_we) begin
            e_irq <= irqctl_data[0];
            t_irq <= irqctl_data[1];
            s_irq <= irqctl_data[2];
        end
    end

    always #5 clk = ~clk;   // 100 MHz

    integer i;

    task dump_regs;
        begin
            $display("  register file:");
            for (i = 0; i < 32; i = i + 1)
                if (dut.core.IRF.reg_file[i] !== 32'h0)
                    $display("    x%0d = 0x%08x (%0d)", i,
                             dut.core.IRF.reg_file[i], $signed(dut.core.IRF.reg_file[i]));
        end
    endtask

    initial begin
        if (!$value$plusargs("PROG=%s", prog)) begin
            $display("FATAL: no +PROG=<file.hex> given");
            $finish;
        end
        fd = $fopen(prog, "r");
        if (fd == 0) begin
            $display("FATAL: cannot open %0s", prog);
            $finish;
        end
        words = 0;
        while ($fgets(line, fd)) words = words + 1;
        $fclose(fd);
        $readmemh(prog, dut.mem, 0, words - 1);
        if ($value$plusargs("MAXCYCLES=%d", maxcycles)) ; // optional override
        if ($value$plusargs("VCD=%s", vcd)) begin
            $dumpfile(vcd);
            $dumpvars(0, tb_msrv32_top);
        end

        repeat (4) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        cycles <= cycles + 1;

        if (tohost_we) begin
            if (tohost_data == 32'd1) begin
                $display("PASS  %0s  (%0d cycles)", prog, cycles);
            end else begin
                $display("FAIL  %0s  check %0d failed after %0d cycles",
                         prog, tohost_data, cycles);
                dump_regs;
            end
            $finish;
        end

        if (cycles > maxcycles) begin
            $display("FAIL  %0s  timed out after %0d cycles (pc=0x%08x)",
                     prog, cycles, dut.core.REG1.pc_out);
            dump_regs;
            $finish;
        end
    end

endmodule
