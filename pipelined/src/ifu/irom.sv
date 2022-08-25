///////////////////////////////////////////
// irom.sv
//
// Written: Ross Thompson ross1728@gmail.com January 30, 2022
// Modified: 
//
// Purpose: simple instruction ROM
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module irom(
  input logic               clk, reset,
  input logic [1:0]         LSURWM,
  input logic [`XLEN-1:0]   IEUAdrE,
  input logic               TrapM, 
  output logic [`LLEN-1:0]  ReadDataWordM
);

 
//  localparam ADDR_WDITH = $clog2(`IROM_RAM_RANGE/8);  // *** replace with tihs when  defined
  localparam ADDR_WDITH = $clog2(`UNCORE_RAM_RANGE/8); // *** this is the wrong size
  localparam OFFSET = $clog2(`LLEN/8);

  brom1p1rw #(`LLEN/8, 8, ADDR_WDITH) 
    rom(.clk, .addr(IEUAdrE[ADDR_WDITH+OFFSET-1:OFFSET]), .dout(ReadDataWordM));
endmodule  
  