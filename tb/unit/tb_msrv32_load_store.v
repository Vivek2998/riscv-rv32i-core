`timescale 1ns / 1ps

// Load and store units against reference models: every byte lane, every access
// size, sign- and zero-extension, and the byte mask a partial store must produce.

module tb_msrv32_load_store;

    // load unit
    reg  [31:0] ldata;
    reg  [1:0]  laddr, lsize;
    reg         luns;
    wire [31:0] lout;

    // store unit
    reg  [1:0]  sfunct3;
    reg  [31:0] saddr, srs2;
    reg         sreq;
    wire [31:0] sdata, sdaddr;
    wire [3:0]  smask;
    wire        sdreq;

    integer errors = 0, i, a, s, u;

    msrv32_load lu (.ms_riscv32_mp_dmdata_in(ldata), .iadder_out_1_to_0_in(laddr),
                    .load_unsigned_in(luns), .load_size_in(lsize), .lu_output_out(lout));

    msrv32_store su (.funct3_in(sfunct3), .iadder_out_in(saddr), .rs2_in(srs2),
                     .mem_wr_req_in(sreq), .ms_riscv32_mp_dmdata_out(sdata),
                     .ms_riscv32_mp_dmaddr_out(sdaddr), .ms_riscv32_mp_dmwr_mask_out(smask),
                     .ms_riscv32_mp_dmwr_req_out(sdreq));

    function [31:0] ref_load(input [31:0] d, input [1:0] ad, input un, input [1:0] sz);
        reg [7:0]  bsel;
        reg [15:0] hsel;
        begin
            case (ad)
                2'b00: bsel = d[7:0];
                2'b01: bsel = d[15:8];
                2'b10: bsel = d[23:16];
                2'b11: bsel = d[31:24];
            endcase
            hsel = ad[1] ? d[31:16] : d[15:0];
            case (sz)
                2'b00:   ref_load = un ? {24'b0, bsel} : {{24{bsel[7]}},  bsel};
                2'b01:   ref_load = un ? {16'b0, hsel} : {{16{hsel[15]}}, hsel};
                default: ref_load = d;
            endcase
        end
    endfunction

    function [31:0] ref_store_data(input [31:0] r, input [1:0] ad, input [1:0] sz);
        case (sz)
            2'b00:   ref_store_data = {24'b0, r[7:0]}  << (8 * ad);
            2'b01:   ref_store_data = {16'b0, r[15:0]} << (16 * ad[1]);
            default: ref_store_data = r;
        endcase
    endfunction

    function [3:0] ref_store_mask(input [1:0] ad, input [1:0] sz, input rq);
        case (sz)
            2'b00:   ref_store_mask = rq ? (4'b0001 << ad) : 4'b0000;
            2'b01:   ref_store_mask = rq ? (ad[1] ? 4'b1100 : 4'b0011) : 4'b0000;
            default: ref_store_mask = {4{rq}};
        endcase
    endfunction

    initial begin
        // load unit
        for (i = 0; i < 300; i = i + 1)
            for (a = 0; a < 4; a = a + 1)
                for (s = 0; s < 3; s = s + 1)
                    for (u = 0; u < 2; u = u + 1) begin
                        ldata = $random; laddr = a[1:0]; lsize = s[1:0]; luns = u[0]; #1;
                        if (lout !== ref_load(ldata, laddr, luns, lsize)) begin
                            errors = errors + 1;
                            if (errors <= 10)
                                $display("  FAIL load data=%08x addr=%b size=%b uns=%b -> %08x, expected %08x",
                                         ldata, laddr, lsize, luns, lout,
                                         ref_load(ldata, laddr, luns, lsize));
                        end
                    end

        // store unit
        for (i = 0; i < 300; i = i + 1)
            for (a = 0; a < 4; a = a + 1)
                for (s = 0; s < 3; s = s + 1)
                    for (u = 0; u < 2; u = u + 1) begin
                        srs2 = $random; saddr = {$random, a[1:0]};
                        sfunct3 = s[1:0]; sreq = u[0]; #1;
                        if (sdata !== ref_store_data(srs2, saddr[1:0], sfunct3) ||
                            smask !== ref_store_mask(saddr[1:0], sfunct3, sreq) ||
                            sdaddr !== {saddr[31:2], 2'b00} || sdreq !== sreq) begin
                            errors = errors + 1;
                            if (errors <= 10)
                                $display("  FAIL store rs2=%08x addr=%08x size=%b req=%b -> data %08x mask %b, expected data %08x mask %b",
                                         srs2, saddr, sfunct3, sreq, sdata, smask,
                                         ref_store_data(srs2, saddr[1:0], sfunct3),
                                         ref_store_mask(saddr[1:0], sfunct3, sreq));
                        end
                    end

        if (errors == 0) $display("PASS  tb_msrv32_load_store");
        else             $display("FAIL  tb_msrv32_load_store  (%0d mismatches)", errors);
        $finish;
    end

endmodule
