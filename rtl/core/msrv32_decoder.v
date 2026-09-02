`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05.03.2021 11:57:22
// Design Name:
// Module Name: msrv32_decoder
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


module msrv32_decoder(trap_taken_in, funct7_5_in, opcode_in, funct3_in, iadder_out_1_to_0_in,
                      wb_mux_sel_out, imm_type_out, csr_op_out, mem_wr_req_out, alu_opcode_out,
                      load_size_out, load_unsigned_out, alu_src_out, iadder_src_out, csr_wr_en_out,
                      rf_wr_en_out, illegal_instr_out, misaligned_load_out, misaligned_store_out);


        parameter branch = 5'b11000,
                  jal    = 5'b11011,
                  jalr   = 5'b11001,
                  auipc  = 5'b00101,
                  lui    = 5'b01101,
                  op     = 5'b01100,
                  op_imm = 5'b00100,
                  load   = 5'b00000,
                  store  = 5'b01000,
                  system = 5'b11100;


        input trap_taken_in, funct7_5_in;
        input [6:0] opcode_in;
        input [2:0] funct3_in;
        input [1:0] iadder_out_1_to_0_in;


        output [2:0] wb_mux_sel_out, imm_type_out, csr_op_out;
        output [3:0] alu_opcode_out;
        output [1:0] load_size_out;
        output mem_wr_req_out, load_unsigned_out, alu_src_out, iadder_src_out, csr_wr_en_out, rf_wr_en_out,
               illegal_instr_out, misaligned_load_out, misaligned_store_out;


        reg is_branch, is_jal, is_jalr, is_auipc, is_lui, is_op, is_op_imm, is_load, is_store, is_system;

        always @(opcode_in[6:2])
                begin
                        case(opcode_in[6:2])
                                branch   : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b1000000000;
 jal      : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0100000000;

                                jalr     : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0010000000;

                                auipc    : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0001000000;

                                lui      : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000100000;

                                op       : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000010000;

                                op_imm   : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000001000;

                                load     : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000000100;

                                store    : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000000010;

                                system   : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000000001;

                                default  : {is_branch,is_jal,is_jalr,is_auipc,is_lui,is_op,is_op_imm,is_load,
                                            is_store,is_system} = 10'b0000000000;
                        endcase
                end


       reg addi, slti, sltiu, andi, ori, xori;
        wire is_addi, is_slti, is_sltiu, is_andi, is_ori, is_xori;
        wire imm_alu_out;

        always @(funct3_in)
                begin
                        case(funct3_in)
                                3'b000 : {addi, slti, sltiu, andi, ori, xori} = 6'b100000;
                                3'b010 : {addi, slti, sltiu, andi, ori, xori} = 6'b010000;
                                3'b011 : {addi, slti, sltiu, andi, ori, xori} = 6'b001000;
                                3'b111 : {addi, slti, sltiu, andi, ori, xori} = 6'b000100;
                                3'b110 : {addi, slti, sltiu, andi, ori, xori} = 6'b000010;
                                3'b100 : {addi, slti, sltiu, andi, ori, xori} = 6'b000001;
                                default: {addi, slti, sltiu, andi, ori, xori} = 6'b000000;
                        endcase
                end

        assign is_addi  = addi  & is_op_imm;
        assign is_slti  = slti  & is_op_imm;
        assign is_sltiu = sltiu & is_op_imm;
        assign is_andi  = andi  & is_op_imm;
        assign is_ori   = ori   & is_op_imm;
assign is_xori  = xori  & is_op_imm;

        assign imm_alu_out    = ~(is_addi | is_slti | is_sltiu | is_andi | is_ori | is_xori);
        assign alu_opcode_out = {(funct7_5_in & imm_alu_out), funct3_in};


        wire is_csr;
        assign is_csr        = (|funct3_in) & is_system;
        assign csr_wr_en_out = is_csr;
        assign csr_op_out    = funct3_in;



        wire is_implemented_instr;
        reg  is_misaligned;

        assign is_implemented_instr = (is_branch | is_jal | is_jalr | is_auipc | is_lui | is_op | is_op_imm|
                                       is_load | is_store | is_csr | is_system);

        assign illegal_instr_out    = (~is_implemented_instr | ~opcode_in[1] | ~opcode_in[0]); // illegal

        always @(*)
        begin
                if(funct3_in[1:0] == 2'b10)
                        begin
                        if(iadder_out_1_to_0_in == 2'b00)
                                is_misaligned = 1'b0;
                        else
                                is_misaligned = 1'b1;
                        end
                else if(funct3_in[1:0] == 2'b01)
                        begin
                        if(iadder_out_1_to_0_in[0] == 1'b0)
                                is_misaligned = 1'b0;
                        else
                                is_misaligned = 1'b1;
                        end
                else
                        is_misaligned = 1'b0;
        end
        assign misaligned_load_out  = is_load  & is_misaligned;
        assign misaligned_store_out = is_store & is_misaligned;


        assign load_unsigned_out = funct3_in[2];
        assign load_size_out     = funct3_in[1:0];


        assign iadder_src_out = (is_load | is_store | is_jalr);
        assign alu_src_out    = opcode_in[5];


        assign imm_type_out[2] = (is_lui | is_auipc | is_jal | is_csr | is_jalr | is_load | is_op_imm);
        assign imm_type_out[1] = (is_store | is_branch | is_csr | is_jalr | is_load | is_op_imm);
        assign imm_type_out[0] = (is_jalr | is_load | is_op_imm | is_jal | is_branch);


        assign wb_mux_sel_out[2] = (is_csr | is_jal | is_jalr);
        assign wb_mux_sel_out[1] = (is_lui | is_auipc);
        assign wb_mux_sel_out[0] = (is_load | is_auipc | is_jal | is_jalr);


        assign mem_wr_req_out = (is_store & ~is_misaligned & ~trap_taken_in);


        assign rf_wr_en_out = (is_op | is_op_imm | is_load | is_jal | is_jalr | is_lui | is_auipc | is_csr);

endmodule
