`timescale 1ns / 1ps

module msrv32_integer_file(ms_riscv32_mp_clk_in, ms_riscv32_mp_rst_in, rs_1_addr_in, rs_2_addr_in,
                           rd_addr_in, wr_en_in, rd_in, rs_1_out, rs_2_out);

        // parameter declaration
        parameter reg_file_width     = 32,
                  reg_file_depth     = 32,
                  reg_file_addr_size = 5;

        // input/output port declaration
        input ms_riscv32_mp_clk_in, ms_riscv32_mp_rst_in;
        input wr_en_in;
        input [(reg_file_addr_size-1):0] rs_1_addr_in, rs_2_addr_in;
        input [(reg_file_addr_size-1):0] rd_addr_in;
        input [(reg_file_width-1):0] rd_in;

        output [(reg_file_width-1):0] rs_1_out, rs_2_out;

        // register file declaration
        reg [(reg_file_width-1):0] reg_file [0:(reg_file_depth-1)];
        integer j;

        // Integer file logic implementation
        always @(posedge ms_riscv32_mp_clk_in or posedge ms_riscv32_mp_rst_in)
        begin
                // initialize the reg_file if asynchronous rst_in is high
                // else do write operation
                if(ms_riscv32_mp_rst_in)
                begin
                        for(j=0; j<reg_file_depth; j=j+1)
                                reg_file[j] <= 0;
                end

                else
                begin
                        if(wr_en_in && rd_addr_in != 0)
                                reg_file[rd_addr_in] <= rd_in;
                end
		  // read operation and bypassing the data

    end

       assign rs_1_out = ((rs_1_addr_in == rd_addr_in) && wr_en_in && rd_addr_in != 0) ?
                         rd_in : reg_file[rs_1_addr_in];
        assign rs_2_out = ((rs_2_addr_in == rd_addr_in) && wr_en_in && rd_addr_in != 0) ?
                         rd_in : reg_file[rs_2_addr_in];

endmodule
