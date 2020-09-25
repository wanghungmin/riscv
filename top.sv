`include "cpu.sv"
`include "SRAM_wrapper.sv"
module top
(
input clk,
input rst
);



logic [13:0]	im_a;
logic 			im_cs;
Data 			im_do;
logic 			dm_oe;
logic [3:0] 	dm_web;
logic [13:0]	dm_a;
Data 			dm_di;
Data 			dm_do;

SRAM_wrapper IM1(
	.CK			(clk),
	.CS			(im_cs),
	.OE			(1'b1),
	.WEB		(4'b1111),
	.A			(im_a),
	.DI			(0),
	.DO			(im_do)
);

SRAM_wrapper DM1(
	.CK			(clk),
	.CS			(1'b1),
	.OE			(dm_oe),
	.WEB		(dm_web),
	.A			(dm_a),
	.DI			(dm_di),
	.DO			(dm_do)
);


cpu u0( 
	.clk		(clk),
	.rst		(rst),
	.IM_A		(im_a),
	.IM_CS		(im_cs),
	.IM_DO		(im_do),
	.DM_OE		(dm_oe),
	.DM_WEB		(dm_web),
	.DM_A		(dm_a),
	.DM_DI		(dm_di),
	.DM_DO		(dm_do)
);


endmodule