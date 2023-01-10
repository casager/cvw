///////////////////////////////////////////
// regfile_p2r1w1bwen
//
// Written: Ross Thompson September 18, 2021
// Modified: 2 port register file with 1 read and 1 write
//
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module regfile_p2r1w1bwen #(parameter integer DEPTH = 10, parameter integer WIDTH = 4)
  (input logic 		clk,
   input logic 		    we1,
   input logic [WIDTH-1:0]  we1bit,
   input logic [DEPTH-1:0]  ra1,
   output logic [WIDTH-1:0] rd1,
   input logic [DEPTH-1:0]  wa1,
   input logic [WIDTH-1:0]  wd1);
  
  logic [WIDTH-1:0] 	    regs [2**DEPTH-1:0];
  integer 		    i;
  
  always_ff @(posedge clk) begin
    if(we1) begin
      for (i=0; i < WIDTH; i++) begin
	if(we1bit[i]) begin
	  regs[wa1][i] <= wd1[i];
	end
      end
    end
  end

  assign rd1 = regs[ra1];

endmodule
