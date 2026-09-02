`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 06.03.2021 00:44:41
// Design Name:
// Module Name: mtvac_reg
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


module mtval_reg( input             clk_in,rst_in,wr_en_in,set_cause_in,misaligned_exception_in,
                  input      [31:0] iadder_in,data_wr_in,
                  input      [11:0] csr_addr_in,
                  output reg [31:0] mtval_out
);

   parameter MTVAL = 12'h343;

   always @(posedge clk_in)
   begin
      if(rst_in)
         mtval_out <= 32'b0;
      else if(set_cause_in)
      begin
         if(misaligned_exception_in)
             mtval_out <= iadder_in;
         else
             mtval_out <= 32'b0;
      end
      else if(csr_addr_in == MTVAL && wr_en_in)
         mtval_out <= data_wr_in;
   end


endmodule
