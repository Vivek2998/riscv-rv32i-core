`timescale 1ns / 1ps

// Design branch unit...it decides if a branch instruction must be taken or not
// based on opcode and funct3 instruction fields, decides branch and jump instruction

module msrv32_branch_unit(rs1_in, rs2_in, opcode_in, funct3_in, branch_taken_out);

        // input/output port declaration
        input [31:0] rs1_in, rs2_in;
        input [6:2] opcode_in;
        input [2:0] funct3_in;

        output reg branch_taken_out;

        // design logic for branch_unit
        always @(*)
        begin
        case(opcode_in)
        5'b110_00 : begin : branch_block
                        case(funct3_in)
                                3'b000 : begin : beq
                                         if(rs1_in == rs2_in)
                                                branch_taken_out = 1'b1;
                                         else
                                                branch_taken_out = 1'b0;
                                         end

                                3'b001 : begin : bnq
                                         if(rs1_in != rs2_in)
                                                branch_taken_out = 1'b1;
                                         else
                                                branch_taken_out = 1'b0;
                                         end

                                3'b100 : begin : blt
                                                branch_taken_out = (rs1_in[31] ^ rs2_in[31]) ?  rs1_in[31] : (rs1_in[30:0] < rs2_in[30:0]);
                                         end

                                3'b101 : begin : bge
                                                branch_taken_out = (rs1_in[31] ^ rs2_in[31]) ? rs2_in[31] : (rs1_in[30:0] >= rs2_in[30:0]);
                                         end

                                3'b110 : begin : bltu
                                         if(rs1_in < rs2_in)
  branch_taken_out = 1'b1;
                                         else
                                                branch_taken_out = 1'b0;
                                         end

                                3'b111 : begin : bgeu
                                         if(rs1_in >= rs2_in)
                                                branch_taken_out = 1'b1;
                                         else
                                                branch_taken_out = 1'b0;
                                         end

                                default: branch_taken_out = 1'b0;
                        endcase
                end

        5'b110_11 : begin : jal_block
                        branch_taken_out = 1'b1;
                    end

        5'b110_01 : begin : jalr_block
                        if(funct3_in == 3'b000)
                                branch_taken_out = 1'b1;
                        else
                                branch_taken_out = 1'b0;
                    end

        default   : branch_taken_out = 1'b0;
        endcase
        end

endmodule
