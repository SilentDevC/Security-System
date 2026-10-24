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
//input res,
output reg [3:0]out
);
    always @( negedge clk) begin 
	//if ( !res ) out <= 4'b1111;//the dip values are always 0-9 so they cant be 1111
        out <= in ; 
    end 
endmodule

module four_bit_mag_comparator (
input [3:0]op_a , op_b,
output reg out
);
    integer i;
    reg val;
    always @( op_a, op_b ) begin 
        val = 1'b1;
        for ( i = 0 ; i < 4 ; i = i + 1)  begin 
            val = val && (op_a[i] == op_b[i]); 
        end 
        out = val ;
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

module oneshot(
    input trig,
    input clk,
    input res,
    output reg q,
    output wire q_comp
);
parameter pulse_width = 5'h85;

integer count = pulse_width;
always @ ( posedge clk or negedge res ) begin  
    if ( !res ) begin 
        count = pulse_width;
        q = 0;
    end 
    else begin 
      if ( trig ) begin 
        if ( count != 0 ) begin 
            count = count - 1 ; 
            q = 1'b1;
         end 
        else if ( count == 0 ) begin 
        q = 1'b0;
	count = pulse_width;
	end 
       end 
      end
end 
assign q_comp = ~q;
endmodule

module CodeSelection (
    input ShiftIn,      // serial input (tied to 0)
    input clk,          // # key (enter) - also the shift clock
    input [3:0] dip1,   // DIP switch code digit 1
    input [3:0] dip2,   // DIP switch code digit 2
    input [3:0] dip3,   // DIP switch code digit 3
    input [3:0] dip4,   // DIP switch code digit 4
    output [3:0] Bout   // BCD out to security code logic
);

    reg [3:0] sel = 4'b1000;

    always @(posedge clk) begin
        if (ShiftIn)        // first # press: load 0001
          sel <= {sel[2:0], ShiftIn};
    end

    // AND + OR gate logic
    assign Bout = ({4{sel[0]}} & dip1) |
                  ({4{sel[1]}} & dip2) |
                  ({4{sel[2]}} & dip3) |
                  ({4{sel[3]}} & dip4);

endmodule


module secsyspr(
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
    wire timeouta; // clk1 
    wire timeoutb; // clk2 
    wire compout;
    wire [3:0] bcd;
    wire regcout;
    wire orgate;
    wire signal;
    assign orgate = |key;
    assign signal = orgate | enter;
    wire qcompa;
    wire qcompb;

    
    BCDencoder bcdenc (.in(key) , .BCDout(BCDout) );
    
    oneshot oshota( .trig(signal) , .clk(clk) 
                      , .res(res) , .q(timeouta) , .q_comp(qcompa));
                      
    CodeSelection selector (.ShiftIn(compout) , .clk(enter) 
                   , .dip1(dip1) ,.dip2(dip2) , 
                    .dip3(dip3) ,.dip4(dip4) , .Bout(bcd) );
                    
    fourbitPIPOshiftreg rega( .clk(timeouta) , .in(BCDout) , 
                                .out(PIPOouta));
                                
    fourbitPIPOshiftreg regb( .clk(timeouta) , .in(bcd) , 
                                .out(PIPOoutb));
                                
   // four_bit_mag_comparator comp (.op_a(PIPOouta) 
     //                       , .op_b(PIPOoutb) , .out(compout));
     
    magcomp localcomp(.opa(PIPOouta) , .opb(PIPOoutb) , .comp_eq(compout)) ;   

    oneshot oshotb( .trig(timeouta) , .clk(clk) , 
                                .res(res) , .q(timeoutb) , .q_comp(qcompb));
                                
    eight_bit_PISOshift_reg regc ( .in(8'b00010000) 
            ,.clk(timeoutb) , .SH_LD(compout) ,.out(regcout));
    assign sysout = regcout;
endmodule

module testsecsyspr;
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
