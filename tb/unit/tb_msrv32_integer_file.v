`timescale 1ns / 1ps

// Register file: ordinary write/read, the write-to-read bypass that lets a result
// reach the next instruction, and x0 staying zero on both paths.

module tb_msrv32_integer_file;

    reg         clk = 1'b0, rst = 1'b1, wr_en = 1'b0;
    reg  [4:0]  rs1_addr = 5'd0, rs2_addr = 5'd0, rd_addr = 5'd0;
    reg  [31:0] rd_data = 32'd0;
    wire [31:0] rs1_data, rs2_data;
    integer errors = 0, i;

    msrv32_integer_file dut (
        .ms_riscv32_mp_clk_in(clk), .ms_riscv32_mp_rst_in(rst),
        .rs_1_addr_in(rs1_addr), .rs_2_addr_in(rs2_addr), .rd_addr_in(rd_addr),
        .wr_en_in(wr_en), .rd_in(rd_data), .rs_1_out(rs1_data), .rs_2_out(rs2_data));

    always #5 clk = ~clk;

    task check(input [255:0] name, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %08x, expected %08x", name, got, exp);
            end
        end
    endtask

    task write_reg(input [4:0] a, input [31:0] d);
        begin
            @(negedge clk); rd_addr = a; rd_data = d; wr_en = 1'b1;
            @(negedge clk); wr_en = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // every register reads back what was written
        for (i = 1; i < 32; i = i + 1) write_reg(i[4:0], 32'hDEAD_0000 + i);
        for (i = 1; i < 32; i = i + 1) begin
            rs1_addr = i[4:0]; rs2_addr = (31 - i); #1;
            check("readback rs1", rs1_data, 32'hDEAD_0000 + i);
        end

        // x0 is hard-wired to zero
        write_reg(5'd0, 32'h1234_5678);
        rs1_addr = 5'd0; #1;
        check("x0 after write", rs1_data, 32'h0);

        // the bypass hands a result to a read issued in the same cycle
        @(negedge clk);
        rd_addr = 5'd7; rd_data = 32'hCAFE_BABE; wr_en = 1'b1;
        rs1_addr = 5'd7; rs2_addr = 5'd7; #1;
        check("bypass rs1", rs1_data, 32'hCAFE_BABE);
        check("bypass rs2", rs2_data, 32'hCAFE_BABE);

        // ...but never for x0, which must stay zero even mid-write
        @(negedge clk);
        rd_addr = 5'd0; rd_data = 32'hFFFF_FFFF; wr_en = 1'b1;
        rs1_addr = 5'd0; rs2_addr = 5'd0; #1;
        check("bypass must not apply to x0 (rs1)", rs1_data, 32'h0);
        check("bypass must not apply to x0 (rs2)", rs2_data, 32'h0);
        @(negedge clk); wr_en = 1'b0;

        if (errors == 0) $display("PASS  tb_msrv32_integer_file");
        else             $display("FAIL  tb_msrv32_integer_file  (%0d mismatches)", errors);
        $finish;
    end

endmodule
