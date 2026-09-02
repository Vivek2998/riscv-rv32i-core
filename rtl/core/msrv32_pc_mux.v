`timescale 1ns / 1ps

module msrv32_pc_mux(rst_in,
                 pc_src_in,
                 pc_in,
                 epc_in,
                 trap_address_in,
                 branch_taken_in,
                 iaddr_in,
                 misaligned_instr_out,
                 pc_mux_out,
                 pc_plus_4_out,
                 iaddr_out);

        // parameter assignment
        parameter BOOT_ADDRESS = 32'h0000_0000;

        // input port declaration
        input rst_in, branch_taken_in;
        input [1:0]  pc_src_in;
        input [31:0] pc_in, epc_in, trap_address_in;
        input [31:1] iaddr_in;

        // output port declaration
        output misaligned_instr_out;
        output [31:0] pc_mux_out, pc_plus_4_out, iaddr_out;

        // signal declaration
        reg [31:0] mux_out_in, next_pc;

        // functonality of mux which find pc_mux_out address
        always @(*)
                begin
                        case(pc_src_in)
                                2'b00   : mux_out_in = BOOT_ADDRESS;
                                2'b01   : mux_out_in = epc_in;
                                2'b10   : mux_out_in = trap_address_in;
                                2'b11   : mux_out_in = next_pc;
                                default : mux_out_in = next_pc;
                        endcase
                end

        // iaddr_out logic
        assign pc_mux_out = mux_out_in;
        assign iaddr_out  = (rst_in) ? BOOT_ADDRESS : mux_out_in;

        // pc_plus_4_out logic
        assign pc_plus_4_out = pc_in + 32'h0000_0004;

        // functionality of next_pc address logic
        always @(*)
                begin
                        if(branch_taken_in)
                                next_pc = {iaddr_in, 1'b0};
                        else
                                next_pc = pc_in + 32'h0000_0004;
                end

        // misaligned instruction check logic
        assign misaligned_instr_out = (next_pc[1] & branch_taken_in);

endmodule
