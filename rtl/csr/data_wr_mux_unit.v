`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 06.03.2021 00:53:28
// Design Name:
// Module Name: data_wr_mux_unit
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module data_wr_mux_unit ( input      [1:0] csr_op_1_0_in,
                          input      [31:0] csr_data_out_in,pre_data_in,
                          output reg [31:0] data_wr_out
);

   parameter CSR_NOP = 2'b00;
   parameter CSR_RW  = 2'b01;
   parameter CSR_RS  = 2'b10;
   parameter CSR_RC  = 2'b11;

   always @*
   begin
      case(csr_op_1_0_in)
         CSR_RW: data_wr_out <= pre_data_in;
         CSR_RS: data_wr_out <= csr_data_out_in | pre_data_in;
         CSR_RC: data_wr_out <= csr_data_out_in & ~pre_data_in;
         CSR_NOP: data_wr_out <= csr_data_out_in;
      endcase
   end

endmodule
