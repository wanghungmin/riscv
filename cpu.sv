`include "opcodes-rv32i.sv"
`include "struct_def.sv"
module cpu
(
input clk,
input rst,
output logic IM_CS,
output logic [13:0] IM_A,
input  [31:0] IM_DO,

output logic DM_OE,
output logic [3:0] DM_WEB,
output logic [13:0] DM_A,
output logic [31:0] DM_DI,
input [31:0] DM_DO

);


Address		PC;
Address 	nPC;
Data		RF	[`RF_NUM-1:0];
Instruction im_inst;


PipelineReg0 pipe0;
PipelineReg1 pipe1;
PipelineReg2 pipe2;
PipelineReg3 pipe3;

logic pc_stall;
logic pipe0_stall;

logic 	flush0;
logic 	flush1;
logic 	flush2;
logic 	flush3;

Data 	rf_in;		//register file input
Data 	fw1;		//forwarding input 1
Data 	fw2;		//forwarding input 2

assign fw1 = pipe2.result;
assign fw2 = rf_in;




//IF stage
assign IM_A = PC[15:2];
assign im_inst = IM_DO;
//always@* pipe0.inst = im_inst ;

always_ff@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	unique if(rst)begin
		pipe0 <= '0;
		pipe0.inst_valid <= 1'b0;
	end
	else if(pipe0_stall) pipe0.pc <= pipe0.pc;
	else begin
		pipe0.pc <= PC;
		pipe0.inst_valid <=  flush0 ? '0: 1'b1 ;
		//pipe0.inst <= im_inst;
	end
end

//DE stage
logic load_stall;
//assign load_stall = (pipe1.mem_load & ((pipe1.rd == pipe0.inst[`RS1])|(pipe1.rd == pipe0.inst[`RS2])))? 1'b1:1'b0;
assign load_stall = pipe1.mem_load;
PipelineReg1 next_pipe1;
Data imm;
Data s2;
ALU1_SEL alu1_sel;
ALU2_SEL alu2_sel;
ADD1_SEL add1_sel;
ADD2_SEL add2_sel;
always_comb begin
	//imm setting
	unique if(`IS_I_TYPE(im_inst)) 	imm = `IMM_I_TYPE(im_inst);
	else if(`IS_B_TYPE(im_inst))	imm = `IMM_B_TYPE(im_inst);
	else if(`IS_S_TYPE(im_inst))	imm = `IMM_S_TYPE(im_inst);
	else if(`IS_U_TYPE(im_inst))	imm = `IMM_U_TYPE(im_inst);
	else if(`IS_J_TYPE(im_inst))	imm = `IMM_J_TYPE(im_inst);
	else imm = 'x;
	
	s2 = RF[im_inst[`RS2]];
	next_pipe1.rd = im_inst[`RD];
	//alu1_sel
	unique case(im_inst[`OPCODE])
	`OPCODE_JAL		:alu1_sel = ALU1_SEL_PC;
	`OPCODE_JALR	:alu1_sel = ALU1_SEL_PC;
	`OPCODE_AUIPC	:alu1_sel = ALU1_SEL_PC;
	`OPCODE_LUI		:alu1_sel = ALU1_SEL_0;
	default			:alu1_sel = ALU1_SEL_S1;
	endcase
	unique case(alu1_sel)
	ALU1_SEL_S1 	:next_pipe1.alu1 = RF[im_inst[`RS1]];
	ALU1_SEL_PC 	:next_pipe1.alu1 = pipe0.pc;
	ALU1_SEL_0		:next_pipe1.alu1 = '0;
	default			:next_pipe1.alu1 = 'x;
	endcase
	//alu2_sel
	unique case(im_inst[`OPCODE])
	`OPCODE_JAL		:alu2_sel = ALU2_SEL_4;
	`OPCODE_JALR	:alu2_sel = ALU2_SEL_4;
	`OPCODE_AUIPC	:alu2_sel = ALU2_SEL_IMM;
	`OPCODE_LUI		:alu2_sel = ALU2_SEL_IMM;
	`OPCODE_OPIMM	:alu2_sel = ALU2_SEL_IMM;
	`OPCODE_LOAD	:alu2_sel = ALU2_SEL_IMM;
	`OPCODE_STORE	:alu2_sel = ALU2_SEL_IMM;
	default			:alu2_sel = ALU2_SEL_S2;
	endcase                     
	unique case(alu2_sel)
	ALU2_SEL_S2 	:next_pipe1.alu2 = RF[im_inst[`RS2]];
	ALU2_SEL_IMM 	:next_pipe1.alu2 = imm;
	ALU2_SEL_4		:next_pipe1.alu2 = 'd4;
	default			:next_pipe1.alu2 = 'x;
	endcase
	//add1_sel
	unique case(im_inst[`OPCODE])
	`OPCODE_JALR	:add1_sel = ADD1_SEL_S1;
	default			:add1_sel = ADD1_SEL_PC;
	endcase
	unique case(add1_sel)
	ADD1_SEL_S1 	:next_pipe1.add1 = RF[im_inst[`RS1]];
	ADD1_SEL_PC 	:next_pipe1.add1 = pipe0.pc;
	default			:next_pipe1.add1 = 'x;
	endcase
	
	//add2_sel
	unique case(im_inst[`OPCODE])
	`OPCODE_STORE	:add2_sel = ADD2_SEL_S2;
	default			:add2_sel = ADD2_SEL_IMM;
	endcase
	unique case(add2_sel)
	ADD2_SEL_S2 	:next_pipe1.add2 = RF[im_inst[`RS2]];
	ADD2_SEL_IMM 	:next_pipe1.add2 = imm;
	default			:next_pipe1.add2 = 'x;
	endcase
	
	//mem_load
	unique if(im_inst[`OPCODE] == `OPCODE_LOAD) next_pipe1.mem_load=1'b1;
	else  next_pipe1.mem_load=1'b0;
	
	unique if(im_inst[`OPCODE] == `OPCODE_STORE) next_pipe1.mem_store=1'b1;
	else  next_pipe1.mem_store=1'b0;
	
	//jalr_sel setting
	unique case(im_inst[`OPCODE])
	`OPCODE_JALR 	:next_pipe1.jalr_sel =1'b1;
	default			:next_pipe1.jalr_sel =1'b0;
	endcase
	
	//jump_sel setting
	unique case(im_inst[`OPCODE])
	`OPCODE_JALR 	:next_pipe1.jump_sel =1'b1;
	`OPCODE_JAL 	:next_pipe1.jump_sel =1'b1;
	default			:next_pipe1.jump_sel =1'b0;
	endcase
	
	
	
	
	//rf_data_sel setting
	unique case(im_inst[`OPCODE])
	`OPCODE_LOAD 	:next_pipe1.rf_data_sel =1'b1;
	default			:next_pipe1.rf_data_sel =1'b0;
	endcase
	
	//rf_write setting
	unique if(`IS_B_TYPE(im_inst)) next_pipe1.rf_write = 1'b0;
	else if(`IS_S_TYPE(im_inst)) next_pipe1.rf_write = 1'b0;
	else next_pipe1.rf_write = 1'b1;
	
	//alu_op setting
	unique case(im_inst[`OPCODE])
	`OPCODE_BRANCH 	:begin
		unique case(im_inst[`FUNCT3])
		`FUNCT3_BEQ		: next_pipe1.alu_op = ALU_OP_BEQ;
		`FUNCT3_BNE		: next_pipe1.alu_op = ALU_OP_BNE;
		`FUNCT3_BLT		: next_pipe1.alu_op = ALU_OP_BLT;	
		`FUNCT3_BGE		: next_pipe1.alu_op = ALU_OP_BGE;
		`FUNCT3_BLTU	: next_pipe1.alu_op = ALU_OP_BLTU;
		`FUNCT3_BGEU	: next_pipe1.alu_op = ALU_OP_BGEU;
		default			: next_pipe1.alu_op = ALU_OP_NOP;
		endcase
	end
	`OPCODE_OP 		:begin
		unique case(`FUNCT_OP(im_inst))
		`FUNCT_OP_ADD	: next_pipe1.alu_op = ALU_OP_ADD;
		`FUNCT_OP_SUB	: next_pipe1.alu_op = ALU_OP_SUB;
		`FUNCT_OP_SLL	: next_pipe1.alu_op = ALU_OP_SLL;
		`FUNCT_OP_SLT	: next_pipe1.alu_op = ALU_OP_SLT;
		`FUNCT_OP_SLTU	: next_pipe1.alu_op = ALU_OP_SLTU;
		`FUNCT_OP_XOR	: next_pipe1.alu_op = ALU_OP_XOR;
		`FUNCT_OP_SRL	: next_pipe1.alu_op = ALU_OP_SRL;
		`FUNCT_OP_SRA	: next_pipe1.alu_op = ALU_OP_SRA;
		`FUNCT_OP_OR 	: next_pipe1.alu_op = ALU_OP_OR ;
		`FUNCT_OP_AND	: next_pipe1.alu_op = ALU_OP_AND;
		default			: next_pipe1.alu_op = ALU_OP_NOP;
		endcase
	end
	`OPCODE_OPIMM 	:begin
		unique case(im_inst[`FUNCT3])
		`FUNCT3_ADDI	: next_pipe1.alu_op = ALU_OP_ADD;
		`FUNCT3_SLLI	: begin
			unique case(im_inst[`FUNCT7])
			`FUNCT7_SLLI: next_pipe1.alu_op = ALU_OP_SLL;
			default		: next_pipe1.alu_op = ALU_OP_NOP;
			endcase
		end
		`FUNCT3_SLTI	: next_pipe1.alu_op = ALU_OP_SLT;
		`FUNCT3_SLTIU 	: next_pipe1.alu_op = ALU_OP_SLTU;
		`FUNCT3_XORI	: next_pipe1.alu_op = ALU_OP_XOR;
		3'd5			: begin
			unique case(im_inst[`FUNCT7])
			`FUNCT7_SRLI: next_pipe1.alu_op = ALU_OP_SRL;
			`FUNCT7_SRAI: next_pipe1.alu_op = ALU_OP_SRA;
			default		: next_pipe1.alu_op = ALU_OP_NOP;
			endcase
		end
		`FUNCT3_ORI		: next_pipe1.alu_op = ALU_OP_OR ;
		`FUNCT3_ANDI	: next_pipe1.alu_op = ALU_OP_AND;
		default			: next_pipe1.alu_op = ALU_OP_NOP;
		endcase
	end
	`OPCODE_LOAD 	: next_pipe1.alu_op = ALU_OP_ADD;
	`OPCODE_STORE 	: next_pipe1.alu_op = ALU_OP_ADD;
	`OPCODE_AUIPC 	: next_pipe1.alu_op = ALU_OP_ADD;
	`OPCODE_JAL 	: next_pipe1.alu_op = ALU_OP_ADD;
	`OPCODE_JALR 	: next_pipe1.alu_op = ALU_OP_ADD;
	`OPCODE_LUI 	: next_pipe1.alu_op = ALU_OP_ADD;
	default			: next_pipe1.alu_op = ALU_OP_NOP;
	endcase

	//mem_op setting
	unique case(im_inst[`OPCODE])
	`OPCODE_LOAD 	: begin
		unique if		(im_inst[`FUNCT3]==`FUNCT3_LW) 	next_pipe1.mem_op = MEM_OP_LW;
		else if	(im_inst[`FUNCT3]==`FUNCT3_LB) 	next_pipe1.mem_op = MEM_OP_LB;
		else 										next_pipe1.mem_op = MEM_OP_NOP;
	end 
	`OPCODE_STORE 	: begin
		unique if		(im_inst[`FUNCT3]==`FUNCT3_LW) 	next_pipe1.mem_op = MEM_OP_SW;
		else if	(im_inst[`FUNCT3]==`FUNCT3_LB) 	next_pipe1.mem_op = MEM_OP_SB;
		else 										next_pipe1.mem_op = MEM_OP_NOP;
	end 
	default			: next_pipe1.mem_op = MEM_OP_NOP;
	endcase
	
	
	if (flush1|!pipe0.inst_valid)begin
		next_pipe1.mem_store = '0;
		next_pipe1.mem_load = '0;
		next_pipe1.alu_op = ALU_OP_NOP;
		next_pipe1.mem_op = MEM_OP_NOP;
		next_pipe1.rf_write = '0;
		next_pipe1.jump_sel = '0;
		next_pipe1.jalr_sel = '0;
		
	end
	

end

always_ff@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	unique if(rst)begin
		pipe1 <= '0;
	end 
	else begin
		pipe1 <= next_pipe1;
		
	end
end

//-----------------EX stage--------------------------------------
FW_SEL 	fws_alu1; 		
FW_SEL 	fws_alu2;
FW_SEL 	fws_add1; 	
FW_SEL 	fws_data_in; 	 		
//Data 	fs1;		//after forwarding mux s1 
//Data 	fs2;		//after forwarding mux s2 
Data 	alu_opnd1;	//alu operand 1 
Data 	alu_opnd2;	//alu operand 2 
Data 	add_opnd1;	//add operand 1 
Data 	add_opnd2;	//add operand 2 
Data	alu_result;
Data	data_in;
logic	branch_taken;
Address branch_target;
Data	add_result;

always_comb begin
	unique case(fws_alu1)
	FW_SEL_FW1	:	alu_opnd1 = fw1;
	FW_SEL_FW2	:	alu_opnd1 = fw2;
	default:		alu_opnd1 = pipe1.alu1;
	endcase
	unique case(fws_alu2)
	FW_SEL_FW1	:	alu_opnd2 = fw1;
	FW_SEL_FW2	:	alu_opnd2 = fw2;
	default:		alu_opnd2 = pipe1.alu2;
	endcase
	unique case(fws_add1)
	FW_SEL_FW1	:	add_opnd1 = fw1;
	FW_SEL_FW2	:	add_opnd1 = fw2;
	default:		add_opnd1 = pipe1.add1;
	endcase
	unique case(fws_data_in)
	FW_SEL_FW1	:	data_in = fw1;
	FW_SEL_FW2	:	data_in = fw2;
	default:		data_in = pipe1.add2;
	endcase
	add_opnd2 = pipe1.add2;
	add_result = ($signed(add_opnd1)+$signed(add_opnd2));
	branch_target[31:1] =  add_result[31:1];
	branch_target[0] =  add_result[0] & (~pipe1.jalr_sel);
	unique case(pipe1.alu_op)
	ALU_OP_ADD	:	alu_result = $signed(alu_opnd1) + $signed(alu_opnd2);
	ALU_OP_SUB	:	alu_result = $signed(alu_opnd1) - $signed(alu_opnd2);
	ALU_OP_SLL	:	alu_result = $signed(alu_opnd1) << alu_opnd2[4:0];
	ALU_OP_SLT	:	alu_result = ($signed(alu_opnd1) < $signed(alu_opnd2)) ? 32'h0000_0001 :'0;
	ALU_OP_SLTU	:	alu_result = ($unsigned(alu_opnd1) < $unsigned(alu_opnd2)) ? 32'h0000_0001 :'0;
	ALU_OP_XOR	:	alu_result = alu_opnd1 ^ alu_opnd2;
	ALU_OP_SRL	:	alu_result = $unsigned(alu_opnd1) >> alu_opnd2[4:0];
	ALU_OP_SRA	:	alu_result = $signed(alu_opnd1) >>> alu_opnd2[4:0];
	ALU_OP_OR	:	alu_result = alu_opnd1 | alu_opnd2;
	ALU_OP_AND	:	alu_result = alu_opnd1 & alu_opnd2;
	default		:	alu_result = 'dx;
	endcase
	unique case(pipe1.alu_op)
	ALU_OP_BEQ	:	branch_taken = alu_opnd1 == alu_opnd2;
	ALU_OP_BNE	:	branch_taken = alu_opnd1 != alu_opnd2;
	ALU_OP_BLT	:	branch_taken = $signed(alu_opnd1) < $signed(alu_opnd2);
	ALU_OP_BGE	:	branch_taken = $signed(alu_opnd1) >= $signed(alu_opnd2);
	ALU_OP_BLTU	: 	branch_taken = $unsigned(alu_opnd1) < $unsigned(alu_opnd2);
	ALU_OP_BGEU	:	branch_taken = $unsigned(alu_opnd1) >= $unsigned(alu_opnd2);
	default		:	branch_taken = 1'b0;
	endcase
end 
always_ff@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	unique if(rst)begin
		pipe2 <= '0;
	end
	else if(flush2) pipe2 <= '0;
	else begin
	pipe2.mem_load<=pipe1.mem_load;
	pipe2.mem_store<=pipe1.mem_store;
	pipe2.rd <= pipe1.rd;
	pipe2.rf_write <= pipe1.rf_write;
	pipe2.rf_data_sel <= pipe1.rf_data_sel;
	pipe2.mem_op <= pipe1.mem_op;
	pipe2.data_in <= data_in;
	
	pipe2.result <=alu_result;
	end
end
///////////////////////////////////////////////////////////////////////////////////////////

//MEM stage

Data dm_out;
always_comb begin
	/*
	case(pipe2.mem_op)
	MEM_OP_LW	:	DM_OE = 1'b1;
	MEM_OP_LB	:	DM_OE = 1'b1;
	default		:	DM_OE = 1'b0;
	endcase
	*/
	DM_OE = pipe3.rf_data_sel;  
	
	
	
	unique case(pipe2.mem_op)
	MEM_OP_SW	:	DM_WEB = 4'b0000; //active low
	MEM_OP_SB	: 	begin	
	//handle the memory is byte address problem
		unique case (pipe2.result[1:0])
		2'd0	:	DM_WEB = 4'b1110;
		2'd1	:	DM_WEB = 4'b1101;
		2'd2	:	DM_WEB = 4'b1011;
		2'd3	:	DM_WEB = 4'b0111;
		default	:	DM_WEB = 4'b1111;
		endcase
	end
	default		:	DM_WEB = 4'b1111;
	endcase
	
	//DM_A = pipe2.result[13:0];
	DM_A = pipe2.result[15:2];
	/*
	case(pipe1.mem_op)
	MEM_OP_SW	:	DM_WEB = 4'b0000; //active low
	MEM_OP_SB	:	DM_WEB = 4'b1110;
	default		:	DM_WEB = 4'b1111;
	endcase
	case(pipe1.mem_op)
	MEM_OP_SW	:	DM_A = alu_result[13:0];
	MEM_OP_SB	:	DM_A = alu_result[13:0];
	default		:	DM_A = pipe2.result[13:0];
	endcase
	*/
	//DM_DI = pipe2.data_in;
	unique case(pipe2.mem_op)
	MEM_OP_SW	:	DM_DI = pipe2.data_in;
	MEM_OP_SB	: 	begin	
		//handle the memory is byte address problem
		unique case (pipe2.result[1:0])
		2'd0	:	DM_DI = {24'h000000,pipe2.data_in[7:0]};
		2'd1	:	DM_DI = {16'h0000,pipe2.data_in[7:0],8'h00};
		2'd2	:	DM_DI = {8'h00,pipe2.data_in[7:0],16'h0000};
		2'd3	:	DM_DI = {pipe2.data_in[7:0],24'h000000};
		default	:	DM_DI = pipe2.data_in;
		endcase
	end
	default		:	DM_DI = pipe2.data_in;
	endcase
	
	dm_out = DM_DO;
	
end
always_ff@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	unique if(rst)begin
		pipe3 <= '0;
	end
	else begin
		pipe3.rd <= pipe2.rd;
		//pipe3.data_out <= DM_DO;
		pipe3.result <= pipe2.result;
		pipe3.rf_write <= pipe2.rf_write;
		pipe3.rf_data_sel <= pipe2.rf_data_sel;
		pipe3.mem_op <= pipe2.mem_op;
	end
end

//WB stage
Data final_data_out;
always_comb begin
	unique if(pipe3.mem_op == MEM_OP_LB) final_data_out = {{24{dm_out[7]}},dm_out[7:0]};
	else final_data_out = dm_out;
end
assign rf_in = pipe3.rf_data_sel ? final_data_out : pipe3.result;
//assign RF[0] = 0;
always_latch begin
	RF[0] <= 0;
	if(clk) begin
		if(pipe3.rf_write&&(pipe3.rd!='0))begin
			RF[pipe3.rd]<=rf_in;
		end
	end
end
/*
always_ff@(`RF_CLK_EGDE clk or posedge rst) begin
	unique if(rst)begin
		for(int i = 0;i<`RF_NUM;i=i+1) 
			RF[i]<= '0;
	end
	else begin
		if(pipe3.rf_write&&pipe3.rd!='0)begin
			RF[pipe3.rd]<=rf_in;
		end
	end
end
*/
//update PC
logic jump_branch;
assign jump_branch = branch_taken | pipe1.jump_sel;

always_comb begin
	unique if(pc_stall) nPC=PC;
	else nPC=jump_branch ? branch_target : (PC+4);
end
always_ff@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	unique if(rst) PC<='0;
	else begin
		PC<=nPC;
	end
end

//controller

assign pc_stall = load_stall;
always_comb begin
	unique if(rst)begin
	IM_CS = 1'b1;
	end
	else begin
		IM_CS = load_stall ? 1'b0 : 1'b1;
	end
end
assign pipe0_stall = load_stall;
assign flush0 = jump_branch;
assign flush1 = load_stall | jump_branch;
//forwarding unit
always_ff@(`PIPELINE_CLK_EGDE clk ) begin
	if(alu1_sel == ALU1_SEL_S1)begin
		if	(im_inst[`RS1]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fws_alu1 <= FW_SEL_FW1;
		else if (im_inst[`RS1]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fws_alu1 <= FW_SEL_FW2;
		else 	fws_alu1<=FW_SEL_DEFAULT;
	end
	else fws_alu1<=FW_SEL_DEFAULT;
	
	if(alu2_sel == ALU2_SEL_S2)begin
		if	(im_inst[`RS2]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fws_alu2 <= FW_SEL_FW1;
		else if (im_inst[`RS2]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fws_alu2 <= FW_SEL_FW2;
		else 	fws_alu2<=FW_SEL_DEFAULT;
	end
	else fws_alu2<=FW_SEL_DEFAULT;
	
	if(add1_sel == ADD1_SEL_S1)begin
		if	(im_inst[`RS1]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fws_add1 <= FW_SEL_FW1;
		else if (im_inst[`RS1]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fws_add1 <= FW_SEL_FW2;
		else 	fws_add1<=FW_SEL_DEFAULT;
	end
	else fws_add1<=FW_SEL_DEFAULT;
	

	if	(im_inst[`RS2]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fws_data_in <= FW_SEL_FW1;
	else if (im_inst[`RS2]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fws_data_in <= FW_SEL_FW2;
	else 	fws_data_in<=FW_SEL_DEFAULT;

	
end

endmodule