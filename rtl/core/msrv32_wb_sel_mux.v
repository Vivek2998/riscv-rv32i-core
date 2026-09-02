`timescale 1ns / 1ps

module msrv32_wb_sel_mux(alu_src_reg_in, wb_mux_sel_reg_in, alu_result_in, lu_output_in, imm_reg_in,
                              iadder_out_reg_in, csr_data_in, pc_plus_4_reg_in, rs2_reg_in, wb_mux_out,
                              alu_2nd_src_mux_out);

        // parameters for different wb_mux_in
        parameter WB_ALU        = 3'b000,
                  WB_LU         = 3'b001,
                  WB_IMM        = 3'b010,
                  WB_IADDER_OUT = 3'b011,
                  WB_CSR        = 3'b100,
                  WB_PC_PLUS    = 3'b101;

        // input/output port declaration
        input alu_src_reg_in;
        input [2:0]  wb_mux_sel_reg_in;
        input [31:0] alu_result_in, lu_output_in, imm_reg_in, iadder_out_reg_in, csr_data_in,
                     pc_plus_4_reg_in, rs2_reg_in;

        output reg [31:0] wb_mux_out, alu_2nd_src_mux_out;

        // logic to design wb_mux
        always @(*)
                begin
                        // logic to design wb_mux_out
                        case(wb_mux_sel_reg_in)
                                WB_ALU        : wb_mux_out = alu_result_in;     // ALU_O/P
                                WB_LU         : wb_mux_out = lu_output_in;      // Load_unit_O/P
                                WB_IMM        : wb_mux_out = imm_reg_in;        // Imm_gen_O/P
                                WB_IADDER_OUT : wb_mux_out = iadder_out_reg_in; // Iadder_out_O/P
                                WB_CSR        : wb_mux_out = csr_data_in;       // CSR_O/P
                                WB_PC_PLUS    : wb_mux_out = pc_plus_4_reg_in;  // Jump_Type_O/P
                                default       : wb_mux_out = alu_result_in;     // ALU_O/P
                        endcase

                        // logic to design alu_2nd_src_mux_out
                        // to select either rs2_in or imm_in
                        if(alu_src_reg_in)
                                alu_2nd_src_mux_out = rs2_reg_in; // rs2_in from R-Type
                        else
                                alu_2nd_src_mux_out = imm_reg_in; // imm_in from I-Type

                end

endmodule
