`timescale 1ns / 1ps

module msrv32_top(ms_riscv32_mp_clk_in,
                     ms_riscv32_mp_rst_in,
                     ms_riscv32_mp_dmdata_in,
                     ms_riscv32_mp_instr_in,
                     ms_riscv32_mp_rc_in,
                     ms_riscv32_mp_eirq_in,
                     ms_riscv32_mp_tirq_in,
                     ms_riscv32_mp_sirq_in,
                     ms_riscv32_mp_dmwr_req_out,
                     ms_riscv32_mp_imaddr_out,
                     ms_riscv32_mp_dmaddr_out,
                     ms_riscv32_mp_dmadata_out,
                     ms_riscv32_mp_dmwr_mask_out);

        // Input port declaration of top module
        input ms_riscv32_mp_clk_in, ms_riscv32_mp_rst_in;
        input [31:0] ms_riscv32_mp_dmdata_in, ms_riscv32_mp_instr_in;
        input [63:0] ms_riscv32_mp_rc_in;
        input ms_riscv32_mp_eirq_in, ms_riscv32_mp_tirq_in, ms_riscv32_mp_sirq_in;

        // output port declaration of top module
        output ms_riscv32_mp_dmwr_req_out;
        output [31:0] ms_riscv32_mp_imaddr_out, ms_riscv32_mp_dmaddr_out, ms_riscv32_mp_dmadata_out;
        output [3:0]  ms_riscv32_mp_dmwr_mask_out;

        /* ============================================================================================
        ***************************** Instantiating pipeline stage 1 **********************************
         ************************* Instantiating pc_mux & reg_block 1 ********************************
          ==========================================================================================*/

        // wire declaration for pipeline stage 1
        wire [1:0]  pc_src_out_in;
        wire [31:0] epc_out_in, trap_address_out_in, iaddr_out_in, pc_plus_4_out_in, pc_mux_out_in;
        wire branch_taken_out_in, misaligned_instr_out_in;
        wire [31:0] pc_out_in;

        // Instantiating pc_mux module
        msrv32_pc_mux PC1(.rst_in(ms_riscv32_mp_rst_in),
                      .pc_src_in(pc_src_out_in),
                      .pc_in(pc_out_in),
                      .epc_in(epc_out_in),
                      .trap_address_in(trap_address_out_in),
                      .branch_taken_in(branch_taken_out_in),
                      .iaddr_in(iaddr_out_in[31:1]),
                      .misaligned_instr_out(misaligned_instr_out_in),
                      .pc_mux_out(pc_mux_out_in),
                      .pc_plus_4_out(pc_plus_4_out_in),
                      .iaddr_out(ms_riscv32_mp_imaddr_out));

        // Instantiating reg_block_1 module
        msrv32_reg_block REG1(.pc_mux_in(pc_mux_out_in),
                                .ms_riscv32_mp_clk_in(ms_riscv32_mp_clk_in),
                                .ms_riscv32_mp_rst_in(ms_riscv32_mp_rst_in),
                                .pc_out(pc_out_in));

        /* ===========================================================================================
        ***************************** Instantiating pipeline stage 2 *********************************
         ******* imm_generator/imm_adder/instr_mux/integer_file/wr_en_gen/branch_unit/decoder *******
          ******************* machine_control/csr_file/reg_block_2/store_unit **********************
        ==========================================================================================*/

        // Instantiating imm_generator module
        wire [31:7] instr_out_in;
        wire [2:0]  imm_type_out_in;
        wire [31:0] imm_out_in;

        msrv32_imm_gen IMG1(.instr_in(instr_out_in),
                                  .imm_type_in(imm_type_out_in),
                                  .imm_out(imm_out_in));

        // Instantiating imm_adder module
        wire iadder_src_out_in;
        wire [31:0] rs1_out_in;

        msrv32_imm_adder IMA1(.pc_in(pc_out_in),
                                    .rs1_in(rs1_out_in),
                                    .iadder_src_in(iadder_src_out_in),
                                    .imm_in(imm_out_in),
                                    .iadder_out(iaddr_out_in));
 // Instantiating instr_mux module
        wire flush_out_in;
        wire [6:0] opcode_out_in, funct7_out_in;
        wire [2:0] funct3_out_in;
        wire [4:0] rs1_addr_out_in, rs2_addr_out_in, rd_addr_out_in;
        wire [11:0] csr_addr_out_in;

        msrv32_instr_mux IM1(.flush_in(flush_out_in),
                                   .ms_riscv32_mp_instr_in(ms_riscv32_mp_instr_in),
                                   .opcode_out(opcode_out_in),
                                   .funct3_out(funct3_out_in),
                                   .funct7_out(funct7_out_in),
                                   .rs1_addr_out(rs1_addr_out_in),
                                   .rs2_addr_out(rs2_addr_out_in),
                                   .rd_addr_out(rd_addr_out_in),
                                   .csr_addr_out(csr_addr_out_in),
                                   .instr_31to7_out(instr_out_in));

        // Instantiating integer_file module
        wire int_wr_en_out_in; // to integer file
        wire [4:0] rd_addr_reg_out_in;
        wire [31:0] wb_mux_out_in, rs2_out_in;

        msrv32_integer_file IRF(.ms_riscv32_mp_clk_in(ms_riscv32_mp_clk_in),
                                .ms_riscv32_mp_rst_in(ms_riscv32_mp_rst_in),
                                .rs_1_addr_in(rs1_addr_out_in),
                                .rs_2_addr_in(rs2_addr_out_in),
                                .rd_addr_in(rd_addr_reg_out_in),
                                .wr_en_in(int_wr_en_out_in),
                                .rd_in(wb_mux_out_in),
                                .rs_1_out(rs1_out_in),
                                .rs_2_out(rs2_out_in));

        // Instantiating wr_en_gen module
        wire rf_wr_en_reg_out_in, csr_wr_en_reg_out_in; // from reg_block_2
        wire csr_wr_en_out_in; // to csr file

        msrv32_wr_en_generator WEG1(.flush_in(flush_out_in),
                             .rf_wr_en_reg_in(rf_wr_en_reg_out_in),
                             .csr_wr_en_reg_in(csr_wr_en_reg_out_in),
 .wr_en_integer_file_out(int_wr_en_out_in),
                             .wr_en_csr_file_out(csr_wr_en_out_in));

        // Instantiating branch_unit module
        msrv32_branch_unit BU1(.rs1_in(rs1_out_in),
                               .rs2_in(rs2_out_in),
                               .opcode_in(opcode_out_in[6:2]),
                               .funct3_in(funct3_out_in),
                               .branch_taken_out(branch_taken_out_in));

        // Instantiating decoder module
        wire trap_taken_out_in, mem_wr_req_out_in;
        wire [2:0] wb_mux_sel_out_in, csr_op_out_in;
        wire [3:0] alu_opcode_out_in;
        wire [1:0] load_size_out_in;
        wire load_unsigned_out_in, alu_src_out_in, illegal_instr_out_in, misaligned_load_out_in,
             misaligned_store_out_in;
        wire csr_wr_en_to_reg, rf_wr_en_to_reg; // to reg_block_2

        msrv32_decoder DCOD1(.trap_taken_in(trap_taken_out_in),
                             .funct7_5_in(funct7_out_in[5]),
                             .opcode_in(opcode_out_in),
                             .funct3_in(funct3_out_in),
                             .iadder_out_1_to_0_in(iaddr_out_in[1:0]),
                             .wb_mux_sel_out(wb_mux_sel_out_in),
                             .imm_type_out(imm_type_out_in),
                             .csr_op_out(csr_op_out_in),
                             .mem_wr_req_out(mem_wr_req_out_in),
                             .alu_opcode_out(alu_opcode_out_in),
                             .load_size_out(load_size_out_in),
                             .load_unsigned_out(load_unsigned_out_in),
                             .alu_src_out(alu_src_out_in),
                             .iadder_src_out(iadder_src_out_in),
                             .csr_wr_en_out(csr_wr_en_to_reg),
                             .rf_wr_en_out(rf_wr_en_to_reg),
                             .illegal_instr_out(illegal_instr_out_in),
                             .misaligned_load_out(misaligned_load_out_in),
                             .misaligned_store_out(misaligned_store_out_in));
// Instantiating Machine_Control module
        wire mie_out_in, meie_out_in, mtie_out_in, msie_out_in, meip_out_in, mtip_out_in, msip_out_in;
        wire i_or_e_out_in, set_epc_out_in, set_cause_out_in;
        wire [3:0] cause_out_in;
        wire instret_inc_out_in, mie_clear_out_in, mie_set_out_in, misaligned_exception_out_in;

        msrv32_machine_control MC1(.clk_in(ms_riscv32_mp_clk_in),
                                   .reset_in(ms_riscv32_mp_rst_in),
                                   .illegal_instr_in(illegal_instr_out_in),
                                   .misaligned_load_in(misaligned_load_out_in),
                                   .misaligned_store_in(misaligned_store_out_in),
                                   .misaligned_instr_in(misaligned_instr_out_in),
                                   .opcode_6_to_2_in(opcode_out_in[6:2]),
                                   .funct3_in(funct3_out_in),
                                   .funct7_in(funct7_out_in),
                                   .rs1_addr_in(rs1_addr_out_in),
                                   .rs2_addr_in(rs2_addr_out_in),
                                   .rd_addr_in(rd_addr_out_in),
                                   .e_irq_in(ms_riscv32_mp_eirq_in),
                                   .t_irq_in(ms_riscv32_mp_tirq_in),
                                   .s_irq_in(ms_riscv32_mp_sirq_in),
                                   .mie_in(mie_out_in),
                                   .meie_in(meie_out_in),
                                   .mtie_in(mtie_out_in),
                                   .msie_in(msie_out_in),
                                   .meip_in(meip_out_in),
                                   .mtip_in(mtip_out_in),
                                   .msip_in(msip_out_in),
                                   .i_or_e_out(i_or_e_out_in),
                                   .set_epc_out(set_epc_out_in),
                                   .set_cause_out(set_cause_out_in),
                                   .cause_out(cause_out_in),
                                   .instret_inc_out(instret_inc_out_in),
                                   .mie_clear_out(mie_clear_out_in),
                                   .mie_set_out(mie_set_out_in),
                                   .misaligned_exception_out(misaligned_exception_out_in),
                                   .pc_src_out(pc_src_out_in),
                                   .flush_out(flush_out_in),
                                   .trap_taken_out(trap_taken_out_in));

 //Instantiating CSR File module
        wire [11:0] csr_addr_reg_out_in;
        wire [31:0] rs1_reg_out_in, pc_reg_out_in, imm_reg_out_in, iadder_out_reg_out_in, csr_data_out_in;
        wire [2:0]  csr_op_reg_out_in;

        msrv32_csr_file CSR1(.clk_in(ms_riscv32_mp_clk_in),
                             .rst_in(ms_riscv32_mp_rst_in),
                             .wr_en_in(csr_wr_en_out_in),
                             .csr_addr_in(csr_addr_reg_out_in),
                             .csr_op_in(csr_op_reg_out_in),
                             .csr_uimm_in(imm_reg_out_in[4:0]),
                             .csr_data_in(rs1_reg_out_in),
                             .pc_in(pc_reg_out_in),
                             .iadder_in(iadder_out_reg_out_in),
                             .e_irq_in(ms_riscv32_mp_eirq_in),
                             .s_irq_in(ms_riscv32_mp_sirq_in),
                             .t_irq_in(ms_riscv32_mp_tirq_in),
                             .i_or_e_in(i_or_e_out_in),
                             .set_cause_in(set_cause_out_in),
                             .set_epc_in(set_epc_out_in),
                             .instret_inc_in(instret_inc_out_in),
                             .mie_clear_in(mie_clear_out_in),
                             .mie_set_in(mie_set_out_in),
                             .cause_in(cause_out_in),
                             .real_time_in(ms_riscv32_mp_rc_in),
                             .misaligned_exception_in(misaligned_exception_out_in),
                             .csr_data_out(csr_data_out_in),
                             .mie_out(mie_out_in),
                             .epc_out(epc_out_in),
                             .trap_address_out(trap_address_out_in),
                             .meie_out(meie_out_in),
                             .mtie_out(mtie_out_in),
                             .msie_out(msie_out_in),
                             .meip_out(meip_out_in),
                             .mtip_out(mtip_out_in),
                             .msip_out(msip_out_in));
 // Instantiating reg_block_2 module
        wire load_unsigned_reg_out_in, alu_src_reg_out_in;
        wire [31:0] rs2_reg_out_in, pc_plus_4_reg_out_in;
        wire [3:0]  alu_opcode_reg_out_in;
        wire [1:0]  load_size_reg_out_in;
        wire [2:0]  wb_mux_sel_reg_out_in;

        msrv32_reg_block_2 RB2(.rd_addr_in(rd_addr_out_in),
                               .csr_addr_in(csr_addr_out_in),
                               .rs1_in(rs1_out_in),
                               .rs2_in(rs2_out_in),
                               .pc_in(pc_out_in),
                               .pc_plus_4_in(pc_plus_4_out_in),
                               .alu_opcode_in(alu_opcode_out_in),
                               .load_size_in(load_size_out_in),
                               .load_unsigned_in(load_unsigned_out_in),
                               .alu_src_in(alu_src_out_in),
                               .csr_wr_en_in(csr_wr_en_to_reg),
                               .rf_wr_en_in(rf_wr_en_to_reg),
                               .clk_in(ms_riscv32_mp_clk_in),
                               .wb_mux_sel_in(wb_mux_sel_out_in),
                               .csr_op_in(csr_op_out_in),
                               .imm_in(imm_out_in),
                               .iadder_out_in(iaddr_out_in),
                               .branch_taken_in(branch_taken_out_in),
                               .reset_in(ms_riscv32_mp_rst_in),
                               .rd_addr_reg_out(rd_addr_reg_out_in),
                               .csr_addr_reg_out(csr_addr_reg_out_in),
                               .rs1_reg_out(rs1_reg_out_in),
                               .rs2_reg_out(rs2_reg_out_in),
                               .pc_reg_out(pc_reg_out_in),
                               .pc_plus_4_reg_out(pc_plus_4_reg_out_in),
                               .alu_opcode_reg_out(alu_opcode_reg_out_in),
                               .load_size_reg_out(load_size_reg_out_in),
                               .load_unsigned_reg_out(load_unsigned_reg_out_in),
                               .alu_src_reg_out(alu_src_reg_out_in),
                               .csr_wr_en_reg_out(csr_wr_en_reg_out_in),
                               .rf_wr_en_reg_out(rf_wr_en_reg_out_in),
                               .wb_mux_sel_reg_out(wb_mux_sel_reg_out_in),
                               .csr_op_reg_out(csr_op_reg_out_in),
                               .imm_reg_out(imm_reg_out_in),
 .iadder_out_reg_out(iadder_out_reg_out_in));

        // Instantiating store unit module
        msrv32_store SU1(.funct3_in(funct3_out_in[1:0]),
                              .iadder_out_in(iaddr_out_in),
                              .rs2_in(rs2_out_in),
                              .mem_wr_req_in(mem_wr_req_out_in),
                              .ms_riscv32_mp_dmdata_out(ms_riscv32_mp_dmadata_out),
                              .ms_riscv32_mp_dmaddr_out(ms_riscv32_mp_dmaddr_out),
                              .ms_riscv32_mp_dmwr_mask_out(ms_riscv32_mp_dmwr_mask_out),
                              .ms_riscv32_mp_dmwr_req_out(ms_riscv32_mp_dmwr_req_out));

        /* ===========================================================================================
        ***************************** Instantiating pipeline stage 3 *********************************
         *************************** load_unit, ALU & wb_mux_sel_unit *******************************
        ===========================================================================================*/

        // Instantiating load_unit module
        wire [31:0] lu_output_out_in;

        msrv32_load LU1(.ms_riscv32_mp_dmdata_in(ms_riscv32_mp_dmdata_in),
                             .iadder_out_1_to_0_in(iadder_out_reg_out_in[1:0]),
                             .load_unsigned_in(load_unsigned_reg_out_in),
                             .load_size_in(load_size_reg_out_in),
                             .lu_output_out(lu_output_out_in));

        // Instantiating ALU module
        wire [31:0] alu_2nd_src_mux_out_in, alu_result_out_in;

        msrv32_alu ALU1(.op_1_in(rs1_reg_out_in),
                        .op_2_in(alu_2nd_src_mux_out_in),
                        .opcode_in(alu_opcode_reg_out_in),
                        .result_out(alu_result_out_in));

        // Instantiating wb_mux_sel_unit module

        msrv32_wb_sel_mux WBU1(.alu_src_reg_in(alu_src_reg_out_in),
 				    .wb_mux_sel_reg_in(wb_mux_sel_reg_out_in),
                                    .alu_result_in(alu_result_out_in),
                                    .lu_output_in(lu_output_out_in),
                                    .imm_reg_in(imm_reg_out_in),
                                    .iadder_out_reg_in(iadder_out_reg_out_in),
                                    .csr_data_in(csr_data_out_in),
                                    .pc_plus_4_reg_in(pc_plus_4_reg_out_in),
                                    .rs2_reg_in(rs2_reg_out_in),
                                    .wb_mux_out(wb_mux_out_in),
                                    .alu_2nd_src_mux_out(alu_2nd_src_mux_out_in));


endmodule
