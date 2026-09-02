`timescale 1ns / 1ps

module msrv32_instr_mux(flush_in, ms_riscv32_mp_instr_in, opcode_out, funct3_out, funct7_out,
                         rs1_addr_out, rs2_addr_out, rd_addr_out, csr_addr_out, instr_31to7_out);

        // parameter declaration for flush instruction
        parameter flush_instr_in = 32'h0000_0013;

        // input/output port declaration
        input flush_in;
        input [31:0] ms_riscv32_mp_instr_in;

        output reg [6:0]  opcode_out;
        output reg [2:0]  funct3_out;
        output reg [6:0]  funct7_out;
        output reg [4:0]  rs1_addr_out, rs2_addr_out, rd_addr_out;
        output reg [11:0] csr_addr_out;
        output reg [31:7] instr_31to7_out;

        // if flush is high use 32'h0000_0013 to provide the output fields
        // else use instr_in(core_instruction) to provide the output fields
        always @(*)
                begin
                if(flush_in)
                        begin
                                opcode_out      = flush_instr_in[6:0];
                                funct3_out      = flush_instr_in[14:12];
                                funct7_out      = flush_instr_in[31:25];
                                rs1_addr_out    = flush_instr_in[19:15];
                                rs2_addr_out    = flush_instr_in[24:20];
                                rd_addr_out     = flush_instr_in[11:7];
                                csr_addr_out    = flush_instr_in[31:20];
                                instr_31to7_out = flush_instr_in[31:7];
                        end
                else
                        begin
                                opcode_out      = ms_riscv32_mp_instr_in[6:0];
                                funct3_out      = ms_riscv32_mp_instr_in[14:12];
                                funct7_out      = ms_riscv32_mp_instr_in[31:25];
                                rs1_addr_out    = ms_riscv32_mp_instr_in[19:15];
                                rs2_addr_out    = ms_riscv32_mp_instr_in[24:20];
                                rd_addr_out     = ms_riscv32_mp_instr_in[11:7];
                                csr_addr_out    = ms_riscv32_mp_instr_in[31:20];
                                instr_31to7_out = ms_riscv32_mp_instr_in[31:7];
                        end
                end

endmodule
