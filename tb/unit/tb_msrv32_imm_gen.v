`timescale 1ns / 1ps

// Immediate generator against the field layouts in the RV32I spec. Random
// instruction words are fed through every immediate type.

module tb_msrv32_imm_gen;

    reg  [31:0] instr;
    reg  [2:0]  imm_type;
    wire [31:0] imm;
    integer errors = 0, i, t;

    msrv32_imm_gen dut (.instr_in(instr[31:7]), .imm_type_in(imm_type), .imm_out(imm));

    function [31:0] ref_imm(input [31:0] w, input [2:0] ty);
        case (ty)
            3'd2:    ref_imm = {{20{w[31]}}, w[31:25], w[11:7]};                        // S
            3'd3:    ref_imm = {{19{w[31]}}, w[31], w[7], w[30:25], w[11:8], 1'b0};     // B
            3'd4:    ref_imm = {w[31:12], 12'b0};                                       // U
            3'd5:    ref_imm = {{11{w[31]}}, w[31], w[19:12], w[20], w[30:21], 1'b0};   // J
            3'd6:    ref_imm = {27'b0, w[19:15]};                                       // CSR uimm
            default: ref_imm = {{20{w[31]}}, w[31:20]};                                 // I
        endcase
    endfunction

    initial begin
        for (t = 0; t < 8; t = t + 1)
            for (i = 0; i < 500; i = i + 1) begin
                instr = $random; imm_type = t[2:0]; #1;
                if (imm !== ref_imm(instr, t[2:0])) begin
                    errors = errors + 1;
                    if (errors <= 10)
                        $display("  FAIL type=%0d instr=%08x -> %08x, expected %08x",
                                 t, instr, imm, ref_imm(instr, t[2:0]));
                end
            end

        if (errors == 0) $display("PASS  tb_msrv32_imm_gen");
        else             $display("FAIL  tb_msrv32_imm_gen  (%0d mismatches)", errors);
        $finish;
    end

endmodule
