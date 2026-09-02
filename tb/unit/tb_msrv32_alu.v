`timescale 1ns / 1ps

// ALU checked against a reference written from the RV32I definitions rather than
// from the RTL, over the sign-boundary corners and then a sweep of random operands.

module tb_msrv32_alu;

    reg  [31:0] a, b;
    reg  [3:0]  op;
    wire [31:0] result;
    integer errors = 0, i, j, k;
    reg  [31:0] corners [0:7];
    reg  [3:0]  ops [0:9];

    msrv32_alu dut (.op_1_in(a), .op_2_in(b), .opcode_in(op), .result_out(result));

    function [31:0] ref_alu(input [31:0] x, input [31:0] y, input [3:0] o);
        case (o)
            4'b0000: ref_alu = x + y;                                  // ADD
            4'b1000: ref_alu = x - y;                                  // SUB
            4'b0010: ref_alu = ($signed(x) < $signed(y)) ? 32'd1 : 32'd0;   // SLT
            4'b0011: ref_alu = (x < y) ? 32'd1 : 32'd0;                // SLTU
            4'b0111: ref_alu = x & y;                                  // AND
            4'b0110: ref_alu = x | y;                                  // OR
            4'b0100: ref_alu = x ^ y;                                  // XOR
            4'b0001: ref_alu = x << y[4:0];                            // SLL
            4'b0101: ref_alu = x >> y[4:0];                            // SRL
            4'b1101: ref_alu = $signed(x) >>> y[4:0];                  // SRA
            default: ref_alu = 32'h0;
        endcase
    endfunction

    task apply(input [31:0] x, input [31:0] y, input [3:0] o);
        begin
            a = x; b = y; op = o; #1;
            if (result !== ref_alu(x, y, o)) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL op=%b a=%08x b=%08x -> %08x, expected %08x",
                             o, x, y, result, ref_alu(x, y, o));
            end
        end
    endtask

    initial begin
        corners[0] = 32'h0000_0000; corners[1] = 32'h0000_0001;
        corners[2] = 32'hFFFF_FFFF; corners[3] = 32'h7FFF_FFFF;
        corners[4] = 32'h8000_0000; corners[5] = 32'h0000_001F;
        corners[6] = 32'hFFFF_FFF0; corners[7] = 32'h1234_5678;
        ops[0]=4'b0000; ops[1]=4'b1000; ops[2]=4'b0010; ops[3]=4'b0011; ops[4]=4'b0111;
        ops[5]=4'b0110; ops[6]=4'b0100; ops[7]=4'b0001; ops[8]=4'b0101; ops[9]=4'b1101;

        for (k = 0; k < 10; k = k + 1)
            for (i = 0; i < 8; i = i + 1)
                for (j = 0; j < 8; j = j + 1)
                    apply(corners[i], corners[j], ops[k]);

        for (k = 0; k < 10; k = k + 1)
            for (i = 0; i < 400; i = i + 1)
                apply($random, $random, ops[k]);

        if (errors == 0) $display("PASS  tb_msrv32_alu  (%0d vectors)", 10*64 + 10*400);
        else             $display("FAIL  tb_msrv32_alu  (%0d mismatches)", errors);
        $finish;
    end

endmodule
