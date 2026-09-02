`timescale 1ns / 1ps

// Simulation system: the core plus one unified memory.
//
// Both core ports are registered-read, which is what the pipeline expects:
//
//   * the instruction port is addressed with imaddr_out, which pc_mux drives with the
//     *next* PC. Registering the read lines the fetched word up with pc_out one cycle
//     later, so stage 2 decodes the instruction belonging to the PC it holds.
//   * the data port takes its address from the store unit in stage 2 and returns read
//     data to the load unit in stage 3, so it is registered for the same reason.
//
// Two addresses are intercepted rather than stored. A write to TOHOST ends the run and
// hands the value to the testbench -- 1 means the program passed, anything else names the
// check that failed. A write to IRQCTL drives the three interrupt request lines from bits
// 0/1/2, so an interrupt test can raise and drop its own request.

module msrv32_soc #(
    parameter MEM_WORDS = 4096,           // 16 KiB, word addressed
    parameter TOHOST    = 32'h0000_1000,
    parameter IRQCTL    = 32'h0000_1004
)(
    input             clk,
    input             rst,
    input             e_irq,
    input             t_irq,
    input             s_irq,
    output [31:0]     imaddr,
    output [31:0]     dmaddr,
    output [31:0]     dmdata_w,
    output [3:0]      dmwr_mask,
    output            dmwr_req,
    output            tohost_we,
    output [31:0]     tohost_data,
    output            irqctl_we,
    output [31:0]     irqctl_data
);

    localparam AW = $clog2(MEM_WORDS);

    reg  [31:0] mem [0:MEM_WORDS-1];
    reg  [31:0] instr_r;
    reg  [31:0] dmdata_r;
    reg  [63:0] rc;

    wire [AW-1:0] iidx = imaddr[AW+1:2];
    wire [AW-1:0] didx = dmaddr[AW+1:2];

    assign tohost_we   = dmwr_req && (dmaddr == TOHOST);
    assign tohost_data = dmdata_w;
    assign irqctl_we   = dmwr_req && (dmaddr == IRQCTL);
    assign irqctl_data = dmdata_w;

    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1) mem[i] = 32'h0;
        instr_r  = 32'h0000_0013;   // NOP until the first fetch lands
        dmdata_r = 32'h0;
        rc       = 64'h0;
    end

    always @(posedge clk) begin
        rc <= rc + 64'd1;

        if (dmwr_req && !tohost_we && !irqctl_we) begin
            if (dmwr_mask[0]) mem[didx][7:0]   <= dmdata_w[7:0];
            if (dmwr_mask[1]) mem[didx][15:8]  <= dmdata_w[15:8];
            if (dmwr_mask[2]) mem[didx][23:16] <= dmdata_w[23:16];
            if (dmwr_mask[3]) mem[didx][31:24] <= dmdata_w[31:24];
        end

        instr_r  <= mem[iidx];
        dmdata_r <= mem[didx];
    end

    msrv32_top core (
        .ms_riscv32_mp_clk_in       (clk),
        .ms_riscv32_mp_rst_in       (rst),
        .ms_riscv32_mp_instr_in     (instr_r),
        .ms_riscv32_mp_dmdata_in    (dmdata_r),
        .ms_riscv32_mp_rc_in        (rc),
        .ms_riscv32_mp_eirq_in      (e_irq),
        .ms_riscv32_mp_tirq_in      (t_irq),
        .ms_riscv32_mp_sirq_in      (s_irq),
        .ms_riscv32_mp_imaddr_out   (imaddr),
        .ms_riscv32_mp_dmaddr_out   (dmaddr),
        .ms_riscv32_mp_dmadata_out  (dmdata_w),
        .ms_riscv32_mp_dmwr_mask_out(dmwr_mask),
        .ms_riscv32_mp_dmwr_req_out (dmwr_req)
    );

endmodule
