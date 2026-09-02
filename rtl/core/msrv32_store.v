`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 15.03.2021 15:26:28
// Design Name:
// Module Name: msrv32_store
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


module msrv32_store(funct3_in, iadder_out_in, rs2_in, mem_wr_req_in, ms_riscv32_mp_dmdata_out,
                         ms_riscv32_mp_dmaddr_out, ms_riscv32_mp_dmwr_mask_out, ms_riscv32_mp_dmwr_req_out);

        // parameter definition
        parameter store_byte = 2'b00,
                  half_word  = 2'b01,
                  full_word  = 2'b10;

        // input/output port declaration
        input [1:0]  funct3_in;
        input [31:0] iadder_out_in, rs2_in;
        input mem_wr_req_in;

        output [31:0] ms_riscv32_mp_dmaddr_out;
        output reg [31:0] ms_riscv32_mp_dmdata_out;
        output reg [3:0]  ms_riscv32_mp_dmwr_mask_out;
        output ms_riscv32_mp_dmwr_req_out;

        // logic to design store unit
        always @(funct3_in, iadder_out_in[1:0], mem_wr_req_in, rs2_in)
                begin
                        case(funct3_in)
                                store_byte: begin
                                                if(iadder_out_in[1:0] == 2'b11)
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {rs2_in[7:0], 8'b0, 8'b0, 8'b0};
                                                        ms_riscv32_mp_dmwr_mask_out = {mem_wr_req_in, 3'b0};
                                                        end
                                                else if(iadder_out_in[1:0] == 2'b10)
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {8'b0, rs2_in[7:0], 8'b0, 8'b0};
                                                        ms_riscv32_mp_dmwr_mask_out = {1'b0, mem_wr_req_in, 2'b0};
                                                        end
                                                else if(iadder_out_in[1:0] == 2'b01)
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {8'b0, 8'b0, rs2_in[7:0], 8'b0};
                                                        ms_riscv32_mp_dmwr_mask_out = {2'b0, mem_wr_req_in, 1'b0};
                                                        end
  else
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {8'b0, 8'b0, 8'b0, rs2_in[7:0]};
                                                        ms_riscv32_mp_dmwr_mask_out = {3'b0, mem_wr_req_in};
                                                        end
                                              end
                                half_word : begin
                                                if(iadder_out_in[1] == 1'b1)
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {rs2_in[15:0], 16'b0};
                                                        ms_riscv32_mp_dmwr_mask_out = {{2{mem_wr_req_in}}, 2'b0};
                                                        end
                                                else
                                                        begin
                                                        ms_riscv32_mp_dmdata_out    = {16'b0, rs2_in[15:0]};
                                                        ms_riscv32_mp_dmwr_mask_out = {2'b0, {2{mem_wr_req_in}}};
                                                        end
                                            end
                                full_word : begin
                                                ms_riscv32_mp_dmdata_out    = rs2_in;
                                                ms_riscv32_mp_dmwr_mask_out = {4{mem_wr_req_in}};
                                            end
                                default   : begin
                                                ms_riscv32_mp_dmdata_out    = rs2_in;
                                                ms_riscv32_mp_dmwr_mask_out = {4{mem_wr_req_in}};
                                            end
                        endcase
                end

        assign ms_riscv32_mp_dmaddr_out   = {iadder_out_in[31:2], 2'b00};
        assign ms_riscv32_mp_dmwr_req_out = mem_wr_req_in;

endmodule
