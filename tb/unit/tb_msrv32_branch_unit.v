`timescale 1ns / 1ps

// Branch unit against a reference model. The interesting part is that BLT/BGE are
// signed while BLTU/BGEU are not, so the random sweep is seeded with values that
// straddle 0x8000_0000.

module tb_msrv32_branch_unit;

    reg  [31:0] rs1, rs2;
    reg  [6:2]  opcode;
    reg  [2:0]  funct3;
    wire        taken;
    integer errors = 0, i, f, o;
    reg  [31:0] corners [0:5];
    reg  [6:2]  opcodes [0:3];

    msrv32_branch_unit dut (.rs1_in(rs1), .rs2_in(rs2), .opcode_in(opcode),
                            .funct3_in(funct3), .branch_taken_out(taken));

    function ref_branch(input [31:0] x, input [31:0] y, input [6:2] opc, input [2:0] f3);
        case (opc)
            5'b11000: case (f3)                       // BRANCH
                          3'b000:  ref_branch = (x == y);
                          3'b001:  ref_branch = (x != y);
                          3'b100:  ref_branch = ($signed(x) <  $signed(y));
                          3'b101:  ref_branch = ($signed(x) >= $signed(y));
                          3'b110:  ref_branch = (x <  y);
                          3'b111:  ref_branch = (x >= y);
                          default: ref_branch = 1'b0;
                      endcase
            5'b11011: ref_branch = 1'b1;              // JAL is always taken
            5'b11001: ref_branch = (f3 == 3'b000);    // JALR
            default:  ref_branch = 1'b0;
        endcase
    endfunction

    task apply(input [31:0] x, input [31:0] y, input [6:2] opc, input [2:0] f3);
        begin
            rs1 = x; rs2 = y; opcode = opc; funct3 = f3; #1;
            if (taken !== ref_branch(x, y, opc, f3)) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL opcode=%b funct3=%b rs1=%08x rs2=%08x -> %b, expected %b",
                             opc, f3, x, y, taken, ref_branch(x, y, opc, f3));
            end
        end
    endtask

    initial begin
        corners[0] = 32'h0000_0000; corners[1] = 32'h0000_0001;
        corners[2] = 32'hFFFF_FFFF; corners[3] = 32'h7FFF_FFFF;
        corners[4] = 32'h8000_0000; corners[5] = 32'h0000_0005;
        opcodes[0] = 5'b11000; opcodes[1] = 5'b11011;
        opcodes[2] = 5'b11001; opcodes[3] = 5'b00100;   // not a branch at all

        for (o = 0; o < 4; o = o + 1)
            for (f = 0; f < 8; f = f + 1) begin
                for (i = 0; i < 6; i = i + 1) begin
                    apply(corners[i], corners[(i+1) % 6], opcodes[o], f[2:0]);
                    apply(corners[i], corners[i],         opcodes[o], f[2:0]);
                end
                for (i = 0; i < 200; i = i + 1)
                    apply($random, $random, opcodes[o], f[2:0]);
            end

        if (errors == 0) $display("PASS  tb_msrv32_branch_unit");
        else             $display("FAIL  tb_msrv32_branch_unit  (%0d mismatches)", errors);
        $finish;
    end

endmodule
