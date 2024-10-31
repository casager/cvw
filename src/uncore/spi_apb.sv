///////////////////////////////////////////
// spi_apb.sv
//
// Written: Naiche Whyte-Aguayo nwhyteaguayo@g.hmc.edu 11/16/2022
//
// Purpose: SPI peripheral
//
// SPI module is written to the specifications described in FU540-C000-v1.0. At the top level, it is consists of synchronous 8 byte transmit and recieve FIFOs connected to shift registers. 
// The FIFOs are connected to WALLY by an apb control register interface, which includes various control registers for modifying the SPI transmission along with registers for writing
// to the transmit FIFO and reading from the receive FIFO. The transmissions themselves are then controlled by a finite state machine. The SPI module uses 4 tristate pins for SPI input/output, 
// along with a 4 bit Chip Select signal, a clock signal, and an interrupt signal to WALLY.
// Current limitations: Flash read sequencer mode not implemented, dual and quad mode not supported
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

module spi_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [7:0]          PADDR,
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic                PREADY,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                SPIOut,
  input  logic                SPIIn,
  output logic [3:0]          SPICS,
  output logic                SPIIntr,
  output logic                SPICLK
);

    // register map
  localparam SPI_SCKDIV =  8'h00;
  localparam SPI_SCKMODE = 8'h04;
  localparam SPI_CSID =    8'h10;
  localparam SPI_CSDEF =   8'h14;
  localparam SPI_CSMODE =  8'h18;
  localparam SPI_DELAY0 =  8'h28;
  localparam SPI_DELAY1 =  8'h2C;
  localparam SPI_FMT =     8'h40;
  localparam SPI_TXDATA =  8'h48;
  localparam SPI_RXDATA =  8'h4C;
  localparam SPI_TXMARK =  8'h50;
  localparam SPI_RXMARK =  8'h54;
  localparam SPI_IE =      8'h70;
  localparam SPI_IP =      8'h74;
  
  // SPI control registers. Refer to SiFive FU540-C000 manual 
  logic [11:0] SckDiv;
  logic [1:0]  SckMode;
  logic [1:0]  ChipSelectID;
  logic [3:0]  ChipSelectDef; 
  logic [1:0]  ChipSelectMode;
  logic [15:0] Delay0, Delay1;
  logic [4:0]  Format;
  logic [7:0]  ReceiveData;
  logic [8:0]  TransmitData;
  logic [2:0]  TransmitWatermark, ReceiveWatermark;
  logic [1:0]  InterruptEnable, InterruptPending;

  // Bus interface signals
  logic [7:0]  Entry;
  logic        Memwrite;
  logic [31:0] Din,  Dout;

  // SPI Controller signals
  logic        SCLKenable;
  logic        EndOfFrame;
  logic        EndOfFrameDelay;
  logic        Transmitting;
  logic        InactiveState;
  logic [3:0]  FrameLength;  

  logic        ResetSCLKenable;
  logic        TransmitStart;
  logic        TransmitStartD;

  // Transmit Start State Machine Variables
  typedef enum logic [1:0] {READY, START, WAIT} txState;
  txState CurrState, NextState;
  
  // FIFO FSM signals
  // Watermark signals - TransmitReadMark = ip[0], ReceiveWriteMark = ip[1]
  logic        TransmitWriteMark, TransmitReadMark, RecieveWriteMark, RecieveReadMark; 
  logic        TransmitFIFOWriteFull, TransmitFIFOReadEmpty;
  logic        TransmitFIFOWriteIncrement;
  logic [7:0]  TransmitFIFOReadData;

  logic        ReceiveFIFOWriteInc;
  logic        ReceiveFIFOReadIncrement;
  logic        ReceiveFIFOWriteFull, ReceiveFIFOReadEmpty;
  
  /* verilator lint_off UNDRIVEN */
  logic [2:0]  TransmitWriteWatermarkLevel, ReceiveReadWatermarkLevel; // unused generic FIFO outputs
  /* verilator lint_off UNDRIVEN */
  logic [7:0]  ReceiveShiftRegEndian;              // Reverses ReceiveShiftReg if Format[2] set (little endian transmission)

  // Shift reg signals
  logic        ShiftEdge;                                // Determines which edge of sck to shift from TransmitReg
  logic        SampleEdge;                               // Determines which edge of sck to sample from ReceiveShiftReg
  logic [7:0]  TransmitReg;                       // Transmit shift register
  logic [7:0]  ReceiveShiftReg;                    // Receive shift register
  logic [7:0]  TransmitDataEndian;                 // Reverses TransmitData from txFIFO if littleendian, since TransmitReg always shifts MSB
  logic        TransmitLoad;                     // Determines when to load TransmitReg
  logic        TransmitFIFOReadIncrement;                // Increments Tx FIFO read ptr 1 cycle after Tx FIFO is read

  // Shift stuff due to Format register?
  logic        ShiftIn;                                  // Determines whether to shift from SPIIn or SPIOut (if SPI_LOOPBACK_TEST)  
  logic [3:0]  LeftShiftAmount;                    // Determines left shift amount to left-align data when little endian              
  logic [7:0]  ASR;                                // AlignedReceiveShiftReg   

  // CS signals
  logic [3:0]  ChipSelectAuto;                     // Assigns ChipSelect value to selected CS signal based on CS ID
  logic [3:0]  ChipSelectInternal;                 // Defines what each ChipSelect signal should be based on transmission status and ChipSelectDef

  // APB access
  assign Entry = {PADDR[7:2],2'b00};  //  32-bit word-aligned accesses
  assign Memwrite = PWRITE & PENABLE & PSEL;  // Only write in access phase
  // assign PREADY = Entry == SPI_TXDATA | Entry == SPI_RXDATA | Entry == SPI_IP;
  assign PREADY = 1'b1;
  
  // Account for subword read/write circuitry
  // -- Note SPI registers are 32 bits no matter what; access them with LW SW.
  
  assign Din = PWDATA[31:0]; 
  if (P.XLEN == 64) assign PRDATA = { Dout,  Dout}; 
  else              assign PRDATA =  Dout;  
  
  // Register access  
  always_ff@(posedge PCLK)
    if (~PRESETn) begin 
      SckDiv <= 12'd3;
      SckMode <= 2'b0;
      ChipSelectID <= 2'b0;
      ChipSelectDef <= 4'b1111;
      ChipSelectMode <= 2'b0;
      Delay0 <= {8'b1,8'b1};
      Delay1 <= {8'b0,8'b1};
      Format <= {5'b10000};
      TransmitData <= 9'b0;
      TransmitWatermark <= 3'b0;
      ReceiveWatermark <= 3'b0;
      InterruptEnable <= 2'b0;
      InterruptPending <= 2'b0;
    end else begin // writes
            /* verilator lint_off CASEINCOMPLETE */
      if (Memwrite)
        case(Entry) // flop to sample inputs
          SPI_SCKDIV:  SckDiv <= Din[11:0];
          SPI_SCKMODE: SckMode <= Din[1:0];
          SPI_CSID:    ChipSelectID <= Din[1:0];
          SPI_CSDEF:   ChipSelectDef <= Din[3:0];
          SPI_CSMODE:  ChipSelectMode <= Din[1:0];
          SPI_DELAY0:  Delay0 <= {Din[23:16], Din[7:0]};
          SPI_DELAY1:  Delay1 <= {Din[23:16], Din[7:0]};
          SPI_FMT:     Format <= {Din[19:16], Din[2]};                    
          SPI_TXMARK:  TransmitWatermark <= Din[2:0];
          SPI_RXMARK:  ReceiveWatermark <= Din[2:0];
          SPI_IE:      InterruptEnable <= Din[1:0];
        endcase

      if (Memwrite)
        case(Entry)
          SPI_TXDATA:  if (~TransmitFIFOWriteFull) TransmitData[7:0] <= Din[7:0];
        endcase
      /* verilator lint_off CASEINCOMPLETE */
      
      // According to FU540 spec: Once interrupt is pending, it will remain set until number 
      // of entries in tx/rx fifo is strictly more/less than tx/rxmark
      InterruptPending[0] <= TransmitReadMark;
      InterruptPending[1] <= RecieveWriteMark;  
      
      case(Entry) // Flop to sample inputs
        SPI_SCKDIV:  Dout <= {20'b0, SckDiv};
        SPI_SCKMODE: Dout <= {30'b0, SckMode};
        SPI_CSID:    Dout <= {30'b0, ChipSelectID};
        SPI_CSDEF:   Dout <= {28'b0, ChipSelectDef};
        SPI_CSMODE:  Dout <= {30'b0, ChipSelectMode};
        SPI_DELAY0:  Dout <= {8'b0, Delay0[15:8], 8'b0, Delay0[7:0]};
        SPI_DELAY1:  Dout <= {8'b0, Delay1[15:8], 8'b0, Delay1[7:0]};
        SPI_FMT:     Dout <= {12'b0, Format[4:1], 13'b0, Format[0], 2'b0};
        SPI_TXDATA:  Dout <= {TransmitFIFOWriteFull, 23'b0, 8'b0};
        SPI_RXDATA:  Dout <= {ReceiveFIFOReadEmpty, 23'b0, ReceiveData[7:0]};
        SPI_TXMARK:  Dout <= {29'b0, TransmitWatermark};
        SPI_RXMARK:  Dout <= {29'b0, ReceiveWatermark};
        SPI_IE:      Dout <= {30'b0, InterruptEnable};
        SPI_IP:      Dout <= {30'b0, InterruptPending};
        default:     Dout <= 32'b0;
      endcase
    end

  // SPI enable generation, where SCLK = PCLK/(2*(SckDiv + 1))
  // Asserts SCLKenable at the rising and falling edge of SCLK by counting from 0 to SckDiv
  // Active at 2x SCLK frequency to account for implicit half cycle delays and actions on both clock edges depending on phase
  // When SckDiv is 0, count doesn't work and SCLKenable is simply PCLK  *** dh 10/26/24: this logic is seriously broken.  SCLK is not scaled to PCLK/(2*(SckDiv + 1)).

  // SPI Controller module -------------------------------------------
  // This module controls state and timing signals that drive the rest of this module
  assign ResetSCLKenable = Memwrite & (Entry == SPI_SCKDIV);
  assign FrameLength = Format[4:1];
  
  spi_controller controller(PCLK, PRESETn,
                            // Transmit Signals
                            TransmitStart, TransmitStartD, ResetSCLKenable,
                            // Register Inputs
                            SckDiv, SckMode, ChipSelectMode, Delay0, Delay1, FrameLength,
                            // txFIFO stuff
                            TransmitFIFOReadEmpty,
                            // Timing
                            SCLKenable, ShiftEdge, SampleEdge, EndOfFrame, EndOfFrameDelay,
                            // State stuff
                            Transmitting, InactiveState,
                            // Outputs
                            SPICLK);
  
  // Transmit FIFO ---------------------------------------------------
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      TransmitFIFOWriteIncrement <= 1'b0;
    end else begin
      TransmitFIFOWriteIncrement <= (Memwrite & (Entry == SPI_TXDATA) & ~TransmitFIFOWriteFull);
    end

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      TransmitFIFOReadIncrement <= 1'b0;
    end else if (SCLKenable) begin
      TransmitFIFOReadIncrement <= TransmitStartD | (EndOfFrameDelay & ~TransmitFIFOReadEmpty) ;
  end

  // Check whether TransmitReg has been loaded.
  // We use this signal to prevent returning to the Ready state for TransmitStart
  logic TransmitRegLoaded;
  always_ff @(posedge PCLK) begin
    if (~PRESETn) begin
      TransmitRegLoaded <= 1'b0;
    end else if (TransmitLoad) begin
      TransmitRegLoaded <= 1'b1;
    end else if (ShiftEdge | EndOfFrameDelay) begin
      TransmitRegLoaded <= 1'b0;  
    end
  end

  // Setup TransmitStart state machine
  always_ff @(posedge PCLK) begin
    if (~PRESETn) begin
      CurrState <= READY;
    end else begin
      CurrState <= NextState;
    end
  end
  
  // State machine for starting transmissions
  always_comb begin
    case (CurrState)
      READY: if (~TransmitFIFOReadEmpty & ~Transmitting) NextState = START;
             else NextState = READY;
      START: NextState = WAIT;
      WAIT: if (TransmitFIFOReadEmpty & ~Transmitting & ~TransmitRegLoaded) NextState = READY;
            else NextState = WAIT;
    endcase
  end

  assign TransmitStart = (CurrState == START);
  always_ff @(posedge PCLK)
    if (~PRESETn) TransmitStartD <= 1'b0;
    else if (TransmitStart) TransmitStartD <= 1'b1;
    else if (SCLKenable) TransmitStartD <= 1'b0;
  
  spi_fifo #(3,8) txFIFO(PCLK, 1'b1, SCLKenable, PRESETn,
                         TransmitFIFOWriteIncrement, TransmitFIFOReadIncrement,
                         TransmitData[7:0],
                         TransmitWriteWatermarkLevel, TransmitWatermark[2:0],
                         TransmitFIFOReadData[7:0],
                         TransmitFIFOWriteFull,
                         TransmitFIFOReadEmpty,
                         TransmitWriteMark, TransmitReadMark);


  // Receive FIFO ----------------------------------------------------
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      ReceiveFIFOReadIncrement <= 1'b0;
    end else begin
      ReceiveFIFOReadIncrement <= ((Entry == SPI_RXDATA) & ~ReceiveFIFOReadEmpty & PSEL & ~ReceiveFIFOReadIncrement);
    end

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      ReceiveFIFOWriteInc <= 1'b0;
    end else if (SCLKenable) begin
      ReceiveFIFOWriteInc <= EndOfFrameDelay;
    end

  spi_fifo #(3,8) rxFIFO(PCLK, SCLKenable, 1'b1, PRESETn,
                         ReceiveFIFOWriteInc, ReceiveFIFOReadIncrement,
                         ReceiveShiftRegEndian, ReceiveWatermark[2:0],
                         ReceiveReadWatermarkLevel, 
                         ReceiveData[7:0],
                         ReceiveFIFOWriteFull,
                         ReceiveFIFOReadEmpty,
                         RecieveWriteMark, RecieveReadMark);

  // Transmit shift register
  assign TransmitLoad = TransmitStart | (EndOfFrameDelay & ~TransmitFIFOReadEmpty);
  assign TransmitDataEndian = Format[0] ? {<<{TransmitFIFOReadData[7:0]}} : TransmitFIFOReadData[7:0];
  always_ff @(posedge PCLK)
    if(~PRESETn)            TransmitReg <= 8'b0;
    else if (TransmitLoad)  TransmitReg <= TransmitDataEndian;
    else if (ShiftEdge)     TransmitReg <= {TransmitReg[6:0], TransmitReg[0]};

  assign SPIOut = TransmitReg[7];
  
  // If in loopback mode, receive shift register is connected directly
  // to module's output pins. Else, connected to SPIIn. There are no
  // setup/hold time issues because transmit shift register and receive
  // shift register always shift/sample on opposite edges
  assign ShiftIn = P.SPI_LOOPBACK_TEST ? SPIOut : SPIIn;
  
  // Receive shift register
  always_ff @(posedge PCLK)
    if(~PRESETn)  ReceiveShiftReg <= 8'b0;
    else if (SampleEdge) begin
      if (~Transmitting) ReceiveShiftReg <= 8'b0;
      else               ReceiveShiftReg <= {ReceiveShiftReg[6:0], ShiftIn};
    end

  // Aligns received data and reverses if little-endian
  assign LeftShiftAmount = 4'h8 - Format[4:1];
  assign ASR = ReceiveShiftReg << LeftShiftAmount[2:0];
  assign ReceiveShiftRegEndian = Format[0] ? {<<{ASR[7:0]}} : ASR[7:0];

  // Interrupt logic: raise interrupt if any enabled interrupts are pending
  assign SPIIntr = |(InterruptPending & InterruptEnable);

  // Chip select logic
  assign ChipSelectInternal = InactiveState ? ChipSelectDef : ~ChipSelectDef;
  always_comb
    case(ChipSelectID[1:0])
      2'b00: ChipSelectAuto = {ChipSelectDef[3], ChipSelectDef[2], ChipSelectDef[1], ChipSelectInternal[0]};
      2'b01: ChipSelectAuto = {ChipSelectDef[3],ChipSelectDef[2], ChipSelectInternal[1], ChipSelectDef[0]};
      2'b10: ChipSelectAuto = {ChipSelectDef[3],ChipSelectInternal[2], ChipSelectDef[1], ChipSelectDef[0]};
      2'b11: ChipSelectAuto = {ChipSelectInternal[3],ChipSelectDef[2], ChipSelectDef[1], ChipSelectDef[0]};
    endcase
  assign SPICS = ChipSelectMode[0] ? ChipSelectDef : ChipSelectAuto;
  
endmodule
