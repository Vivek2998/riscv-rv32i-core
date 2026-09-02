`timescale 1ns / 1ps

module msrv32_load(ms_riscv32_mp_dmdata_in, iadder_out_1_to_0_in, load_unsigned_in, load_size_in, lu_output_out);

        // parameter declaration
        parameter load_byte = 2'b00,
                  load_half = 2'b01,
                  load_word = 2'b10;

        // input/output port declaration
        input [31:0] ms_riscv32_mp_dmdata_in;
        input [1:0]  iadder_out_1_to_0_in, load_size_in;
        input load_unsigned_in;

        output reg [31:0] lu_output_out;

        // logic to implement load unit
        always @(*)
        begin
                case(load_size_in)
                        load_byte : begin
                                        // load byte unsigned operation
                                        if(load_unsigned_in)
                                        begin
                                                if(iadder_out_1_to_0_in == 2'b00)
                                                begin
                                                        lu_output_out = {24'b0, ms_riscv32_mp_dmdata_in[7:0]};
                                                end
                                                else if(iadder_out_1_to_0_in == 2'b01)
                                                begin
                                                        lu_output_out = {24'b0, ms_riscv32_mp_dmdata_in[15:8]};
                                                end
                                                else if(iadder_out_1_to_0_in == 2'b10)
                                                begin
                                                        lu_output_out = {24'b0, ms_riscv32_mp_dmdata_in[23:16]};
                                                end
                                                else
                                                begin
                                                        lu_output_out = {24'b0, ms_riscv32_mp_dmdata_in[31:24]};
                                                end
 end
                                        // load byte signed operation
                                        else
                                        begin
                                                if(iadder_out_1_to_0_in == 2'b00)
                                                begin
                                                        lu_output_out = {{24{ms_riscv32_mp_dmdata_in[7]}},
                                                                             ms_riscv32_mp_dmdata_in[7:0]};
                                                end
                                                else if(iadder_out_1_to_0_in == 2'b01)
                                                begin
                                                        lu_output_out = {{24{ms_riscv32_mp_dmdata_in[15]}},
                                                                             ms_riscv32_mp_dmdata_in[15:8]};
                                                end
                                                else if(iadder_out_1_to_0_in == 2'b10)
                                                begin
                                                        lu_output_out = {{24{ms_riscv32_mp_dmdata_in[23]}},
                                                                             ms_riscv32_mp_dmdata_in[23:16]};
                                                end
                                                else
                                                begin
                                                        lu_output_out = {{24{ms_riscv32_mp_dmdata_in[31]}},
                                                                             ms_riscv32_mp_dmdata_in[31:24]};
                                                end
                                        end
                                    end

                        load_half : begin
                                        // load half word unsigned operation
                                        if(load_unsigned_in)
                                        begin
                                                if(iadder_out_1_to_0_in[1])
                                                begin
                                                        lu_output_out = {16'b0, ms_riscv32_mp_dmdata_in[31:16]};
                                                end
                                                else
                                                begin
                                                        lu_output_out = {16'b0, ms_riscv32_mp_dmdata_in[15:0]};
                                                end
                                        end
 else
                                        begin
                                                if(iadder_out_1_to_0_in[1])
                                                begin
                                                        lu_output_out = {{16{ms_riscv32_mp_dmdata_in[31]}},
                                                                             ms_riscv32_mp_dmdata_in[31:16]};
                                                end
                                                else
                                                begin
                                                        lu_output_out = {{16{ms_riscv32_mp_dmdata_in[15]}},
                                                                             ms_riscv32_mp_dmdata_in[15:0]};
                                                end
                                        end
                                    end

                        load_word : lu_output_out = ms_riscv32_mp_dmdata_in; // load word operation

                        default   : lu_output_out = ms_riscv32_mp_dmdata_in; // other combinations
                endcase
        end

endmodule
