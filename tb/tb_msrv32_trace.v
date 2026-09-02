`timescale 1ns / 1ps

// Records what every pipeline stage is holding, cycle by cycle, while a program runs.
//
//   vvp trace.vvp +PROG=prog.hex +TRACE=prog.tsv [+MAXCYCLES=n]
//
// One tab-separated line per cycle, all values hex. tools/trace.py turns it into
// something readable by joining it against the assembler's listing. The design is
// sampled on the negative edge, so every combinational path has settled and each
// line describes one whole cycle.

module tb_msrv32_trace;

    reg clk = 1'b0, rst = 1'b1;
    reg e_irq = 1'b0, t_irq = 1'b0, s_irq = 1'b0;

    wire [31:0] imaddr, dmaddr, dmdata_w, tohost_data, irqctl_data;
    wire [3:0]  dmwr_mask;
    wire        dmwr_req, tohost_we, irqctl_we;

    integer maxcycles = 20000, cycles = 0, fd = 0, tf = 0, words = 0;
    reg [1023:0] prog, tracefile, line;

    msrv32_soc dut (
        .clk(clk), .rst(rst), .e_irq(e_irq), .t_irq(t_irq), .s_irq(s_irq),
        .imaddr(imaddr), .dmaddr(dmaddr), .dmdata_w(dmdata_w),
        .dmwr_mask(dmwr_mask), .dmwr_req(dmwr_req),
        .tohost_we(tohost_we), .tohost_data(tohost_data),
        .irqctl_we(irqctl_we), .irqctl_data(irqctl_data));

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (irqctl_we) begin
            e_irq <= irqctl_data[0];
            t_irq <= irqctl_data[1];
            s_irq <= irqctl_data[2];
        end
    end

    // Shorthands for the parts of the core the trace reports on.
    wire [4:0]  s2_rs1  = dut.core.rs1_addr_out_in;
    wire [4:0]  s2_rs2  = dut.core.rs2_addr_out_in;
    wire [4:0]  s3_rd   = dut.core.rd_addr_reg_out_in;
    wire        s3_we   = dut.core.int_wr_en_out_in;

    // The register file forwards a result to a read issued in the same cycle;
    // this is the condition that makes it fire, reported per source operand.
    wire byp1 = s3_we && (s2_rs1 == s3_rd) && (s3_rd != 5'd0);
    wire byp2 = s3_we && (s2_rs2 == s3_rd) && (s3_rd != 5'd0);

    initial begin
        if (!$value$plusargs("PROG=%s", prog)) begin
            $display("FATAL: no +PROG=<file.hex> given");
            $finish;
        end
        fd = $fopen(prog, "r");
        if (fd == 0) begin $display("FATAL: cannot open %0s", prog); $finish; end
        while ($fgets(line, fd)) words = words + 1;
        $fclose(fd);
        $readmemh(prog, dut.mem, 0, words - 1);

        if ($value$plusargs("MAXCYCLES=%d", maxcycles)) ;
        if ($value$plusargs("TRACE=%s", tracefile)) begin
            tf = $fopen(tracefile, "w");
            $fwrite(tf, "cycle\tstate\tflush\ts1pc\ts2pc\ts2ir\ts2rs1\ts2rs1v\ts2rs2\ts2rs2v");
            $fwrite(tf, "\ts2rd\ts2imm\ts2iadder\ts2br\tbyp1\tbyp2\ts3pc\ts3rd\ts3alu\ts3lu");
            $fwrite(tf, "\ts3wb\ts3we\tmreq\tmaddr\tmwdata\tmmask\tmrdata\ttrap\tcause\n");
        end

        repeat (4) @(posedge clk);
        rst <= 1'b0;
    end

    // Sampled on the negative edge: the whole cycle's combinational state is stable.
    always @(negedge clk) begin
        if (tf != 0 && cycles <= maxcycles) begin
            $fwrite(tf, "%0d\t%0d\t%0d\t%08x\t%08x\t%08x\t%0d\t%08x\t%0d\t%08x",
                    cycles, dut.core.MC1.curr_state, dut.core.flush_out_in,
                    imaddr, dut.core.REG1.pc_out, dut.instr_r,
                    s2_rs1, dut.core.rs1_out_in, s2_rs2, dut.core.rs2_out_in);
            $fwrite(tf, "\t%0d\t%08x\t%08x\t%0d\t%0d\t%0d",
                    dut.core.rd_addr_out_in, dut.core.imm_out_in,
                    dut.core.iaddr_out_in, dut.core.branch_taken_out_in, byp1, byp2);
            $fwrite(tf, "\t%08x\t%0d\t%08x\t%08x\t%08x\t%0d",
                    dut.core.pc_reg_out_in, s3_rd, dut.core.alu_result_out_in,
                    dut.core.lu_output_out_in, dut.core.wb_mux_out_in, s3_we);
            $fwrite(tf, "\t%0d\t%08x\t%08x\t%0d\t%08x\t%0d\t%0d\n",
                    dmwr_req, dmaddr, dmdata_w, dmwr_mask, dut.dmdata_r,
                    dut.core.trap_taken_out_in, dut.core.cause_out_in);
        end
    end

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (tohost_we) begin
            $display("%0s: %0d cycles, tohost=%0d (%0s)", prog, cycles, tohost_data,
                     tohost_data == 32'd1 ? "pass" : "FAIL");
            if (tf != 0) $fclose(tf);
            $finish;
        end
        if (cycles > maxcycles) begin
            $display("%0s: stopped at the %0d cycle limit", prog, cycles);
            if (tf != 0) $fclose(tf);
            $finish;
        end
    end

endmodule
