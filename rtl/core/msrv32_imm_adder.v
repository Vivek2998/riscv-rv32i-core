`timescale 1ns / 1ps

module msrv32_imm_adder(pc_in, rs1_in, iadder_src_in, imm_in, iadder_out);

        // port declaration
        input [31:0] pc_in, rs1_in;
        input iadder_src_in;
        input [31:0]  imm_in;
        output [31:0] iadder_out;

        reg [31:0] next_address;

        // next_address logic
        always @(iadder_src_in, pc_in, rs1_in)
        begin
                if(iadder_src_in)
                        next_address = rs1_in;
                else
                        next_address = pc_in;
        end

        // iadder_out logic
        assign iadder_out = imm_in + next_address;

endmodule
