`timescale 1ns / 1ps

// Decoder control signals per opcode, checked against what the datapath needs:
// which unit drives writeback, whether the register file and CSR file are written,
// which immediate shape to build, and the misaligned/illegal detection.

module tb_msrv32_decoder;

    reg         trap_taken = 1'b0, funct7_5 = 1'b0;
    reg  [6:0]  opcode;
    reg  [2:0]  funct3;
    reg  [1:0]  iadder_lsb = 2'b00;

    wire [2:0]  wb_mux_sel, imm_type, csr_op;
    wire [3:0]  alu_opcode;
    wire [1:0]  load_size;
    wire        mem_wr_req, load_unsigned, alu_src, iadder_src,
                csr_wr_en, rf_wr_en, illegal, mis_load, mis_store;

    integer errors = 0;

    msrv32_decoder dut (
        .trap_taken_in(trap_taken), .funct7_5_in(funct7_5), .opcode_in(opcode),
        .funct3_in(funct3), .iadder_out_1_to_0_in(iadder_lsb),
        .wb_mux_sel_out(wb_mux_sel), .imm_type_out(imm_type), .csr_op_out(csr_op),
        .mem_wr_req_out(mem_wr_req), .alu_opcode_out(alu_opcode),
        .load_size_out(load_size), .load_unsigned_out(load_unsigned),
        .alu_src_out(alu_src), .iadder_src_out(iadder_src), .csr_wr_en_out(csr_wr_en),
        .rf_wr_en_out(rf_wr_en), .illegal_instr_out(illegal),
        .misaligned_load_out(mis_load), .misaligned_store_out(mis_store));

    task check(input [255:0] name, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %0d, expected %0d", name, got, exp);
            end
        end
    endtask

    // opcode, funct3, then the signals the datapath keys off
    task decode(input [6:0] opc, input [2:0] f3);
        begin opcode = opc; funct3 = f3; #1; end
    endtask

    initial begin
        // OP: register-register arithmetic
        decode(7'b0110011, 3'b000);
        check("OP rf_wr_en",     rf_wr_en,   1);
        check("OP csr_wr_en",    csr_wr_en,  0);
        check("OP mem_wr_req",   mem_wr_req, 0);
        check("OP alu_src(rs2)", alu_src,    1);
        check("OP wb_mux_sel",   wb_mux_sel, 3'b000);   // ALU
        check("OP illegal",      illegal,    0);

        // OP-IMM
        decode(7'b0010011, 3'b000);
        check("OP_IMM rf_wr_en",     rf_wr_en,   1);
        check("OP_IMM alu_src(imm)", alu_src,    0);
        check("OP_IMM imm_type",     imm_type,   3'd7); // I
        check("OP_IMM wb_mux_sel",   wb_mux_sel, 3'b000);

        // LOAD
        decode(7'b0000011, 3'b010);
        check("LOAD rf_wr_en",   rf_wr_en,   1);
        check("LOAD iadder_src", iadder_src, 1);
        check("LOAD wb_mux_sel", wb_mux_sel, 3'b001);   // load unit
        check("LOAD imm_type",   imm_type,   3'd7);

        // STORE
        decode(7'b0100011, 3'b010);
        check("STORE rf_wr_en",   rf_wr_en,   0);
        check("STORE mem_wr_req", mem_wr_req, 1);
        check("STORE iadder_src", iadder_src, 1);
        check("STORE imm_type",   imm_type,   3'd2);    // S

        // BRANCH
        decode(7'b1100011, 3'b000);
        check("BRANCH rf_wr_en",   rf_wr_en,   0);
        check("BRANCH mem_wr_req", mem_wr_req, 0);
        check("BRANCH imm_type",   imm_type,   3'd3);   // B

        // JAL / JALR
        decode(7'b1101111, 3'b000);
        check("JAL rf_wr_en",   rf_wr_en,   1);
        check("JAL wb_mux_sel", wb_mux_sel, 3'b101);    // pc + 4
        check("JAL imm_type",   imm_type,   3'd5);      // J
        decode(7'b1100111, 3'b000);
        check("JALR rf_wr_en",   rf_wr_en,   1);
        check("JALR iadder_src", iadder_src, 1);
        check("JALR wb_mux_sel", wb_mux_sel, 3'b101);

        // LUI / AUIPC
        decode(7'b0110111, 3'b000);
        check("LUI rf_wr_en",   rf_wr_en,   1);
        check("LUI wb_mux_sel", wb_mux_sel, 3'b010);    // immediate
        check("LUI imm_type",   imm_type,   3'd4);      // U
        decode(7'b0010111, 3'b000);
        check("AUIPC rf_wr_en",   rf_wr_en,   1);
        check("AUIPC wb_mux_sel", wb_mux_sel, 3'b011);  // iadder output
        check("AUIPC imm_type",   imm_type,   3'd4);

        // SYSTEM: funct3 != 0 is a CSR access, funct3 == 0 is ECALL/EBREAK/MRET
        decode(7'b1110011, 3'b001);
        check("CSRRW csr_wr_en",  csr_wr_en,  1);
        check("CSRRW rf_wr_en",   rf_wr_en,   1);
        check("CSRRW wb_mux_sel", wb_mux_sel, 3'b100);  // CSR
        check("CSRRW imm_type",   imm_type,   3'd6);
        check("CSRRW csr_op",     csr_op,     3'b001);
        decode(7'b1110011, 3'b101);
        check("CSRRWI csr_wr_en", csr_wr_en,  1);
        check("CSRRWI rf_wr_en",  rf_wr_en,   1);
        decode(7'b1110011, 3'b000);
        check("ECALL csr_wr_en",  csr_wr_en,  0);
        check("ECALL rf_wr_en",   rf_wr_en,   0);
        check("ECALL illegal",    illegal,    0);

        // illegal encodings
        decode(7'b0000000, 3'b000);
        check("opcode 0 illegal", illegal, 1);
        decode(7'b0110001, 3'b000);                     // low bits not 11
        check("non-32bit opcode illegal", illegal, 1);

        // misalignment is reported per access size
        opcode = 7'b0000011; funct3 = 3'b010; iadder_lsb = 2'b01; #1;
        check("lw at +1 misaligned",  mis_load,  1);
        iadder_lsb = 2'b00; #1;
        check("lw at +0 aligned",     mis_load,  0);
        opcode = 7'b0100011; funct3 = 3'b001; iadder_lsb = 2'b01; #1;
        check("sh at +1 misaligned",  mis_store, 1);
        iadder_lsb = 2'b10; #1;
        check("sh at +2 aligned",     mis_store, 0);
        opcode = 7'b0000011; funct3 = 3'b000; iadder_lsb = 2'b11; #1;
        check("lb at any offset ok",  mis_load,  0);

        // a store must not reach memory while a trap is being taken
        opcode = 7'b0100011; funct3 = 3'b010; iadder_lsb = 2'b00; trap_taken = 1'b1; #1;
        check("store suppressed during trap", mem_wr_req, 0);

        if (errors == 0) $display("PASS  tb_msrv32_decoder");
        else             $display("FAIL  tb_msrv32_decoder  (%0d mismatches)", errors);
        $finish;
    end

endmodule
