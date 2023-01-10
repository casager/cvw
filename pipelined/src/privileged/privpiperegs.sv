///////////////////////////////////////////
// privpiperegs.sv
//
// Written: David_Harris@hmc.edu 12 May 2022
// Modified: 
//
// Purpose: Pipeline registers for early exceptions
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

module privpiperegs (
  input  logic         clk, reset,
  input  logic         StallD, StallE, StallM,
  input  logic         FlushD, FlushE, FlushM,
  input  logic         InstrPageFaultF, InstrAccessFaultF,
  input  logic         IllegalIEUInstrFaultD,
  output logic         InstrPageFaultM, InstrAccessFaultM,
  output logic         IllegalIEUInstrFaultM
);

  logic InstrPageFaultD, InstrAccessFaultD;
  logic InstrPageFaultE, InstrAccessFaultE;
  logic IllegalIEUInstrFaultE; 

  // pipeline fault signals
  flopenrc #(2) faultregD(clk, reset, FlushD, ~StallD,
                  {InstrPageFaultF, InstrAccessFaultF},
                  {InstrPageFaultD, InstrAccessFaultD});
  flopenrc #(3) faultregE(clk, reset, FlushE, ~StallE,
                  {IllegalIEUInstrFaultD, InstrPageFaultD, InstrAccessFaultD}, 
                  {IllegalIEUInstrFaultE, InstrPageFaultE, InstrAccessFaultE});
  flopenrc #(3) faultregM(clk, reset, FlushM, ~StallM,
                  {IllegalIEUInstrFaultE, InstrPageFaultE, InstrAccessFaultE},
                  {IllegalIEUInstrFaultM, InstrPageFaultM, InstrAccessFaultM});
endmodule