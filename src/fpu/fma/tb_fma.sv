`include "config.vh"
import cvw::*;
`include "parameter-defs.vh"

module stimulus;

    logic clk;
    logic rst;

    logic                         Xs, Ys, Zs;             // input's signs
    logic [P.NE-1:0]              Xe, Ye, Ze;             // input's biased exponents in B(NE.0) format
    logic [P.NF:0]                Xm, Ym, Zm;             // input's significands in U(0.NF) format
    logic                         XZero, YZero, ZZero;    // is the input zero
    logic [2:0]                   OpCtrl;                 // operation control
    logic                         ASticky;                // sticky bit that is calculated during alignment
    logic [P.FMALEN-1:0]          Sm;                     // the positive sum's significand
    logic                         InvA;                   // Was A inverted for effective subtraction (P-A or -P+A)
    logic                         As;                     // the aligned addend's sign (modified Z sign for other operations)
    logic                         Ps;                     // the product's sign
    logic                         Ss;                     // the sum's sign
    logic [P.NE+1:0]              Se;                     // the sum's exponent
    logic [$clog2(P.FMALEN+1)-1:0] SCnt;                    // normalization shift count

    fma #(P) dut (
        .Xs(Xs), .Ys(Ys), .Zs(Zs),
        .Xe(Xe), .Ye(Ye), .Ze(Ze),
        .Xm(Xm), .Ym(Ym), .Zm(Zm),
        .XZero(XZero), .YZero(YZero), .ZZero(ZZero),
        .OpCtrl(OpCtrl), 
        .ASticky(ASticky), 
        .Sm(Sm),
        .InvA(InvA),
        .As(As),
        .Ps(Ps),
        .Ss(Ss),
        .Se(Se),
        .SCnt(SCnt)

    );

    initial
        begin
            clk = 1'b1;
            forever #10 clk = ~clk;
        end

    initial 
        begin
        
        #20     Xs = 1'b0;
        #0      Ys = 1'b0;
        #0      Zs = 1'b0;

        #0      Xe = 11'b100_0000_0000;
        #0      Ye = 11'b100_0000_0000;
        #0      Ze = 11'b100_0000_0000;

        #0      Xm = 53'hA000_0000_0000_0;
        #0      Ym = 53'hB000_0000_0000_0;
        #0      Zm = 53'hC000_0000_0000_0;

        #0      XZero = 1'b0; 
        #0      YZero = 1'b0; 
        #0      ZZero = 1'b0;

        #0      OpCtrl = 3'b000;


        end


endmodule //stimulus
