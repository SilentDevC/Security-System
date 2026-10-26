`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/01/2026 12:00:51 AM
// Design Name: 
// Module Name: secsys
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

module BCDencoder ( 
input [9:0]in , 
output reg [3:0]BCDout
);
always @(*) begin 
    case (in) 
        10'b0000000001: BCDout = 4'd0;
        10'b0000000010: BCDout = 4'd1;
        10'b0000000100: BCDout = 4'd2;
        10'b0000001000: BCDout = 4'd3;
        10'b0000010000: BCDout = 4'd4;
        10'b0000100000: BCDout = 4'd5;
        10'b0001000000: BCDout = 4'd6;
        10'b0010000000: BCDout = 4'd7;
        10'b0100000000: BCDout = 4'd8;
        10'b1000000000: BCDout = 4'd9;
        default:        BCDout = 4'bxxxx;
    endcase 
   end 
endmodule
 
module fourbitPIPOshiftreg (
input [3:0]in ,
input clk,
output reg [3:0]out
);
always @( posedge clk) begin 
        out <= in ; 
end 
endmodule

module magcomp (
input [3:0]opa , opb,
output comp_eq
);
assign comp_eq = (opa == opb);
endmodule 

module eight_bit_PISOshift_reg( 
    input [7:0]in,
    input clk,
    input SH_LD,
    output reg out
);
    reg [7:0]mem;
    always @(posedge clk) begin 
    if (!SH_LD) begin 
        mem <= in;
    end 
    else begin
        out <= mem[0]; 
        mem <= { 1'b0 , mem[7:1] };
    end
   end
endmodule

module CodeSelection (
    input ShiftIn,      
    input clk,          
    input sh_ld,
    input [3:0] dip1,   // DIP switch code digit 1
    input [3:0] dip2,   // DIP switch code digit 2
    input [3:0] dip3,   // DIP switch code digit 3
    input [3:0] dip4,   // DIP switch code digit 4
    output [3:0] Bout   // BCD out to security code logic
);

    reg [3:0] sel;

    always @(posedge clk) begin
        if (!sh_ld) begin
          sel <= 4'b1000;
        end                 
        else begin
          sel <= {sel[2:0], ShiftIn};
        end     
    end

    // AND + OR gate logic
    assign Bout = ({4{sel[0]}} & dip1) |
                  ({4{sel[1]}} & dip2) |
                  ({4{sel[2]}} & dip3) |
                  ({4{sel[3]}} & dip4);
endmodule

module FSM ( 
    input clk ,reset ,
    input x1,x2,x3,x4,
    output y1,y2,y3,y4,y5,
    output init
);
parameter S0 = 4'd0, S1 = 4'd1 , S2 = 4'd2 , S3 = 4'd3 , S4 = 4'd4 ,S5 = 4'd5 ;
reg [3:0] state,next_state;

always @(posedge clk or negedge reset) begin
    if (!reset) state = S0;
    else state = next_state;
end

always @(state or x1 or x2 or x3 or x4) begin
    case (state)
    S0 : next_state = S1;
    S1 : begin        
        if (!x1) next_state = S1 ;
        else if (x1) next_state = S2 ;
    end
    S2 : begin 
        if (!x2) next_state = S2 ;
        else if (x2) next_state = S3;
    end
    S3 : begin 
        if (x3) next_state = S5 ; 
        else if (!x3) next_state = S4 ;
    end
    S4 : next_state = S2 ;
    S5 : begin 
        if (!x4) next_state = S2 ;
        else if (x4) next_state = S0 ;
    end
    endcase
end

assign y1 = (state == S1) ;
assign y2 = (state == S2) ;
assign y3 = (state == S3) ; 
assign y4 = (state == S4) ;
assign y5 = (state == S5) ;

//control signal of the initializing process
assign init = (state == S1) ;

endmodule

module secsys_datapath (
    input clk ,
    input y1,y2,y3,y4,y5,
    input [9:0]key,
    input [3:0]dip1,
    input [3:0]dip2,
    input [3:0]dip3,
    input [3:0]dip4, 
    input enter,
    input [3:0]PIPOouta,PIPOoutb,
    input init,
    output x1,x2,x3,x4,
    output reg done,
    output [3:0]codeselectorout
);
wire control;
wire sh_ld;
assign control = x3?y5:~y4;
assign sh_ld = control & ~init;

CodeSelection selector (.ShiftIn(sh_ld), .clk(clk), .dip1(dip1), .dip2(dip2), .dip3(dip3), .dip4(dip4), .Bout(codeselectorout));

assign x1 = enter;
assign x2 = |key;
magcomp localcomp(.opa(PIPOouta) , .opb(PIPOoutb) , .comp_eq(x3)) ;   
eight_bit_PISOshift_reg regc ( .in(8'b00010000) ,.clk(clk) , .SH_LD(sh_ld) ,.out(x4));

always @(posedge clk) begin
    if (y5 && x4) begin
      done <= 1'b1;
    end
end

endmodule 

module secsys(
    input [9:0] key,
    input enter,
    input clk , 
    input res ,
    input [3:0]dip1,
    input [3:0]dip2,
    input [3:0]dip3,
    input [3:0]dip4,
    output sysout
);

    wire [3:0]BCDout;
    wire [3:0]PIPOouta;
    wire [3:0]PIPOoutb;
    wire [3:0]codeselectorout;
    wire init;
    reg done;
    wire y1,y2,y3,y4,y5;
    wire x1,x2,x3,x4;

 BCDencoder bcdenc (.in(key) , .BCDout(BCDout) );
 fourbitPIPOshiftreg rega(.clk(clk), .in(BCDout), .out(PIPOouta));                    
 fourbitPIPOshiftreg regb(.clk(clk), .in(codeselectorout), .out(PIPOoutb));
 FSM fsm (.clk(clk) , .reset(res) , .y1(y1) , .y2(y2) , .y3(y3) , .y4(y4) , .y5(y5), .x1(x1) , .x2(x2) , .x3(x3) , .x4(x4) , .init(init));
 secsys_datapath datapath (.clk(clk), .enter(enter), .dip1(dip1), .dip2(dip2), .dip3(dip3), .dip4(dip4), .key(key)
                        , .PIPOouta(PIPOouta) , .PIPOoutb(PIPOoutb) , .done(done), .codeselectorout(codeselectorout) , .init(init) ,
                        .y1(y1) , .y2(y2) , .y3(y3) , .y4(y4) , .y5(y5), .x1(x1) , .x2(x2) , .x3(x3) , .x4(x4));
assign sysout = x4;
   
endmodule

module testsecuresys;
    reg [9:0] key;
    reg enter;
    reg clk;
    reg res;
    reg [3:0] dip1, dip2, dip3, dip4;
    wire sysout;

    secsys test (.key(key), .enter(enter), .clk(clk), .res(res),
                 .dip1(dip1), .dip2(dip2), .dip3(dip3), .dip4(dip4),
                 .sysout(sysout));

    localparam clockcycle = 10 ; 
    always #(clockcycle/2) clk =~clk; 

    $dumpfile("wave.vcd");
    $dumpvars(0, testsecuresys);

    initial begin

	#(clockcycle*3) res<=1;
  	#(clockcycle*3) res<=0;clk<=0;

        // set DIP switches first (secret code = 4,5,6,7)
        dip1 = 4'h4;
        dip2 = 4'h5;
        dip3 = 4'h6;
        dip4 = 4'h7;

        // reset
        res = 0;
        #20 res = 1;
	
        // enter digit 1 = 4
        #50 key = 10'b0000010000; // key[4]
        enter = 1;
        #5 enter = 0;
        //#10 key = 0;

        // enter digit 2 = 5
        #10 key = 10'b0000100000; // key[5]
         enter = 1;
        #5 enter = 0;
        //#10 key = 0;

        // enter digit 3 = 10 (a)
        #10 key = 10'b0001000000; // no key for a, need rethink
         enter = 1;
        #5 enter = 0;
        //#10 key = 0;

        // enter digit 4 = 14 (e)
        #10 key = 10'b0010000000; // no key for e, need rethink
         enter = 1;
        #5 enter = 0;
        //#10 key = 0;

        #1000 $finish;
    end
endmodule