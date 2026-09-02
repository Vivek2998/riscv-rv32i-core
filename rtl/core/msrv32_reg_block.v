`timescale 1ns / 1ps

module msrv32_reg_block(pc_mux_in, ms_riscv32_mp_clk_in, ms_riscv32_mp_rst_in, pc_out);

        // inpu/output port declaration
        input [31:0] pc_mux_in;
        input ms_riscv32_mp_clk_in, ms_riscv32_mp_rst_in;
        output reg [31:0] pc_out;

        // logic for reg_block_1
        always @(posedge ms_riscv32_mp_clk_in)
                begin
                        if(ms_riscv32_mp_rst_in)
                                pc_out <= 32'h0;
                        else
                                pc_out <= pc_mux_in;
                end

endmodule
