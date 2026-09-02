`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 15.03.2021 15:20:17
// Design Name:
// Module Name: msrv32_alu
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module msrv32_alu(op_1_in, op_2_in, opcode_in, result_out);

        // parameters for differrnt alu operation
        parameter ALU_ADD  = 4'b0000,
                  ALU_SUB  = 4'b1000,
                  ALU_SLT  = 4'b0010,
                  ALU_SLTU = 4'b0011,
                  ALU_AND  = 4'b0111,
                  ALU_OR   = 4'b0110,
                  ALU_XOR  = 4'b0100,
                  ALU_SLL  = 4'b0001,
                  ALU_SRL  = 4'b0101,
                  ALU_SRA  = 4'b1101;

        // input/output port declaration
        input [31:0] op_1_in, op_2_in;
        input [3:0]  opcode_in;
        output reg [31:0] result_out;

        reg signed [31:0] op_1;

        // logic to design ALU
        always @(*)
                begin
                        op_1 = 32'h0;
                        case(opcode_in)
                                ALU_ADD  : result_out = (op_1_in + op_2_in);  // addition
                                ALU_SUB  : result_out = (op_1_in - op_2_in); // subtraction
                                ALU_SLT  : result_out = (op_1_in[31] ^ op_2_in[31]) ? (op_1_in[31]) :
                                                        (op_1_in[30:0] < op_2_in[30:0]);    // signed operation
                                ALU_SLTU : result_out = (op_1_in < op_2_in) ? 1'b1 : 1'b0; // unsigned operation
                                ALU_AND  : result_out = (op_1_in & op_2_in);              // bitwise_and
                                ALU_OR   : result_out = (op_1_in | op_2_in);             // bitwise_or
                                ALU_XOR  : result_out = (op_1_in ^ op_2_in);            // bitwise_xor
                                ALU_SLL  : result_out = (op_1_in <<  op_2_in[4:0]);    // shift_left_logical
                                ALU_SRL  : result_out = (op_1_in >>  op_2_in[4:0]);   // shift_right_logical
                                ALU_SRA  : begin
                                           op_1 = op_1_in;
                                           result_out = (op_1 >>> op_2_in[4:0]); // shift_right_arithmetic
                                           end
                              default  : result_out = 32'h0;
                        endcase
                end

endmodule
