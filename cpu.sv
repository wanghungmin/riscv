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

always@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	if(rst)begin
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
always@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	if(rst)begin
		pipe1 <= '0;
	end 
	else if (flush1|!pipe0.inst_valid)begin
		pipe1.mem_store <= '0;
		pipe1.mem_load <= '0;
		pipe1.alu_op <= ALU_OP_NOP;
		pipe1.mem_op <= MEM_OP_NOP;
		pipe1.rf_write <= '0;
		pipe1.jump_sel <= '0;
		pipe1.jalr_sel <= '0;
		
	end
	else begin
		pipe1.pc <= pipe0.pc;
		pipe1.s1 <= RF[im_inst[`RS1]];
		pipe1.s2 <= RF[im_inst[`RS2]];
		pipe1.rd <= im_inst[`RD];
		
		
		if(im_inst[`OPCODE] == `OPCODE_LOAD) pipe1.mem_load<=1'b1;
		else  pipe1.mem_load<=1'b0;
		if(im_inst[`OPCODE] == `OPCODE_STORE) pipe1.mem_store<=1'b1;
		else  pipe1.mem_store<=1'b0;
		
		//jalr_sel setting
		case(im_inst[`OPCODE])
		`OPCODE_JALR 	:pipe1.jalr_sel <=1'b1;
		default			:pipe1.jalr_sel <=1'b0;
		endcase
		
		//jump_sel setting
		case(im_inst[`OPCODE])
		`OPCODE_JALR 	:pipe1.jump_sel <=1'b1;
		`OPCODE_JAL 	:pipe1.jump_sel <=1'b1;
		default			:pipe1.jump_sel <=1'b0;
		endcase
		
		//opnd1_sel setting
		case(im_inst[`OPCODE])
		`OPCODE_JAL		:pipe1.opnd1_sel <=OPND1_SEL_PC;
		`OPCODE_JALR	:pipe1.opnd1_sel <=OPND1_SEL_PC;
		`OPCODE_AUIPC	:pipe1.opnd1_sel <=OPND1_SEL_PC;
		`OPCODE_LUI		:pipe1.opnd1_sel <=OPND1_SEL_0;
		default			:pipe1.opnd1_sel <=OPND1_SEL_S1;
		endcase
		//opnd2_sel setting
		case(im_inst[`OPCODE])
		`OPCODE_JAL		:pipe1.opnd2_sel <=OPND2_SEL_4;
		`OPCODE_JALR	:pipe1.opnd2_sel <=OPND2_SEL_4;
		`OPCODE_AUIPC	:pipe1.opnd2_sel <=OPND2_SEL_IMM;
		`OPCODE_LUI		:pipe1.opnd2_sel <=OPND2_SEL_IMM;
		`OPCODE_OPIMM	:pipe1.opnd2_sel <=OPND2_SEL_IMM;
		`OPCODE_LOAD	:pipe1.opnd2_sel <=OPND2_SEL_IMM;
		`OPCODE_STORE	:pipe1.opnd2_sel <=OPND2_SEL_IMM;
		default			:pipe1.opnd2_sel <=OPND2_SEL_S2;
		endcase
		
		
		//imm setting
		if(`IS_I_TYPE(im_inst)) 		pipe1.imm <= `IMM_I_TYPE(im_inst);
		else if(`IS_B_TYPE(im_inst))	pipe1.imm <= `IMM_B_TYPE(im_inst);
		else if(`IS_S_TYPE(im_inst))	pipe1.imm <= `IMM_S_TYPE(im_inst);
		else if(`IS_U_TYPE(im_inst))	pipe1.imm <= `IMM_U_TYPE(im_inst);
		else if(`IS_J_TYPE(im_inst))	pipe1.imm <= `IMM_J_TYPE(im_inst);
		else pipe1.imm <= '0;
		
		//rf_data_sel setting
		case(im_inst[`OPCODE])
		`OPCODE_LOAD 	:pipe1.rf_data_sel <=1'b1;
		default			:pipe1.rf_data_sel <=1'b0;
		endcase
		
		//rf_write setting
		if(`IS_B_TYPE(im_inst)) pipe1.rf_write <= 1'b0;
		else if(`IS_S_TYPE(im_inst)) pipe1.rf_write <= 1'b0;
		else pipe1.rf_write <= 1'b1;
		
		//alu_op setting
		case(im_inst[`OPCODE])
		`OPCODE_BRANCH 	:begin
			case(im_inst[`FUNCT3])
			`FUNCT3_BEQ		: pipe1.alu_op <= ALU_OP_BEQ;
			`FUNCT3_BNE		: pipe1.alu_op <= ALU_OP_BNE;
			`FUNCT3_BLT		: pipe1.alu_op <= ALU_OP_BLT;	
			`FUNCT3_BGE		: pipe1.alu_op <= ALU_OP_BGE;
			`FUNCT3_BLTU	: pipe1.alu_op <= ALU_OP_BLTU;
			`FUNCT3_BGEU	: pipe1.alu_op <= ALU_OP_BGEU;
			default			: pipe1.alu_op <= ALU_OP_NOP;
			endcase
		end
		`OPCODE_OP 		:begin
			case(`FUNCT_OP(im_inst))
			`FUNCT_OP_ADD	: pipe1.alu_op <= ALU_OP_ADD;
			`FUNCT_OP_SUB	: pipe1.alu_op <= ALU_OP_SUB;
			`FUNCT_OP_SLL	: pipe1.alu_op <= ALU_OP_SLL;
			`FUNCT_OP_SLT	: pipe1.alu_op <= ALU_OP_SLT;
			`FUNCT_OP_SLTU	: pipe1.alu_op <= ALU_OP_SLTU;
			`FUNCT_OP_XOR	: pipe1.alu_op <= ALU_OP_XOR;
			`FUNCT_OP_SRL	: pipe1.alu_op <= ALU_OP_SRL;
			`FUNCT_OP_SRA	: pipe1.alu_op <= ALU_OP_SRA;
			`FUNCT_OP_OR 	: pipe1.alu_op <= ALU_OP_OR ;
			`FUNCT_OP_AND	: pipe1.alu_op <= ALU_OP_AND;
			default			: pipe1.alu_op <= ALU_OP_NOP;
			endcase
		end
		`OPCODE_OPIMM 	:begin
			case(im_inst[`FUNCT3])
			`FUNCT3_ADDI	: pipe1.alu_op <= ALU_OP_ADD;
			`FUNCT3_SLLI	: begin
				case(im_inst[`FUNCT7])
				`FUNCT7_SLLI: pipe1.alu_op <= ALU_OP_SLL;
				default		: pipe1.alu_op <= ALU_OP_NOP;
				endcase
			end
			`FUNCT3_SLTI	: pipe1.alu_op <= ALU_OP_SLT;
			`FUNCT3_SLTIU 	: pipe1.alu_op <= ALU_OP_SLTU;
			`FUNCT3_XORI	: pipe1.alu_op <= ALU_OP_XOR;
			3'd5			: begin
				case(im_inst[`FUNCT7])
				`FUNCT7_SRLI: pipe1.alu_op <= ALU_OP_SRL;
				`FUNCT7_SRAI: pipe1.alu_op <= ALU_OP_SRA;
				default		: pipe1.alu_op <= ALU_OP_NOP;
				endcase
			end
			`FUNCT3_ORI		: pipe1.alu_op <= ALU_OP_OR ;
			`FUNCT3_ANDI	: pipe1.alu_op <= ALU_OP_AND;
			default			: pipe1.alu_op <= ALU_OP_NOP;
			endcase
		end
		`OPCODE_LOAD 	: pipe1.alu_op <= ALU_OP_ADD;
		`OPCODE_STORE 	: pipe1.alu_op <= ALU_OP_ADD;
		`OPCODE_AUIPC 	: pipe1.alu_op <= ALU_OP_ADD;
		`OPCODE_JAL 	: pipe1.alu_op <= ALU_OP_ADD;
		`OPCODE_JALR 	: pipe1.alu_op <= ALU_OP_ADD;
		`OPCODE_LUI 	: pipe1.alu_op <= ALU_OP_ADD;
		default			: pipe1.alu_op <= ALU_OP_NOP;
		endcase
	
		//mem_op setting
		case(im_inst[`OPCODE])
		`OPCODE_LOAD 	: begin
			if		(im_inst[`FUNCT3]==`FUNCT3_LW) 	pipe1.mem_op <= MEM_OP_LW;
			else if	(im_inst[`FUNCT3]==`FUNCT3_LB) 	pipe1.mem_op <= MEM_OP_LB;
			else 										pipe1.mem_op <= MEM_OP_NOP;
		end 
		`OPCODE_STORE 	: begin
			if		(im_inst[`FUNCT3]==`FUNCT3_LW) 	pipe1.mem_op <= MEM_OP_SW;
			else if	(im_inst[`FUNCT3]==`FUNCT3_LB) 	pipe1.mem_op <= MEM_OP_SB;
			else 										pipe1.mem_op <= MEM_OP_NOP;
		end 
		default			: pipe1.mem_op <= MEM_OP_NOP;
		endcase
		
	end
end

//-----------------EX stage--------------------------------------
FW_SEL 	fw_s1; 		//forwarding mux sel 1
FW_SEL 	fw_s2; 		//forwarding mux sel 2
Data 	fs1;		//after forwarding mux s1 
Data 	fs2;		//after forwarding mux s2 
Data 	alu_opnd1;	//alu operand 1 
Data 	alu_opnd2;	//alu operand 2 
Data 	add_opnd1;	//add operand 1 
Data 	add_opnd2;	//add operand 2 
Data	alu_result;
logic	branch_taken;
Address branch_target;
Data	add_result;

always@*begin
	//fs1
	case(fw_s1)
	FW_SEL_FW1	:	fs1 = fw1;
	FW_SEL_FW2	:	fs1 = fw2;
	default:		fs1 = pipe1.s1;
	endcase
	//fs2
	case(fw_s2)
	FW_SEL_FW1	:	fs2 = fw1;
	FW_SEL_FW2	:	fs2 = fw2;
	default:		fs2 = pipe1.s2;
	endcase
	//alu_opnd1
	case(pipe1.opnd1_sel)
	OPND1_SEL_S1:	alu_opnd1 = fs1;
	OPND1_SEL_PC:	alu_opnd1 = pipe1.pc;
	OPND1_SEL_0	:	alu_opnd1 = '0;
	default		:	alu_opnd1 = fs1;
	endcase
	//alu_opnd2
	case(pipe1.opnd2_sel)
	OPND2_SEL_S2	:	alu_opnd2 = fs2;
	OPND2_SEL_IMM	:	alu_opnd2 = pipe1.imm;
	OPND2_SEL_4		:	alu_opnd2 = 4;
	default			:	alu_opnd2 = fs2;
	endcase
	add_opnd1 = pipe1.jalr_sel ? fs1 : pipe1.pc;
	add_opnd2 = pipe1.imm;
	add_result = ($signed(add_opnd1)+$signed(add_opnd2));
	branch_target[31:1] =  add_result[31:1];
	branch_target[0] =  add_result[0] & (~pipe1.jalr_sel);
	case(pipe1.alu_op)
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
	case(pipe1.alu_op)
	ALU_OP_BEQ	:	branch_taken = alu_opnd1 == alu_opnd2;
	ALU_OP_BNE	:	branch_taken = alu_opnd1 != alu_opnd2;
	ALU_OP_BLT	:	branch_taken = $signed(alu_opnd1) < $signed(alu_opnd2);
	ALU_OP_BGE	:	branch_taken = $signed(alu_opnd1) >= $signed(alu_opnd2);
	ALU_OP_BLTU	: 	branch_taken = $unsigned(alu_opnd1) < $unsigned(alu_opnd2);
	ALU_OP_BGEU	:	branch_taken = $unsigned(alu_opnd1) >= $unsigned(alu_opnd2);
	default		:	branch_taken = 1'b0;
	endcase
end 
always@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	if(rst)begin
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
	pipe2.data_in <= fs2;
	
	pipe2.result <=alu_result;
	end
end
///////////////////////////////////////////////////////////////////////////////////////////

//MEM stage

Data dm_out;
always@*begin
	/*
	case(pipe2.mem_op)
	MEM_OP_LW	:	DM_OE = 1'b1;
	MEM_OP_LB	:	DM_OE = 1'b1;
	default		:	DM_OE = 1'b0;
	endcase
	*/
	DM_OE = pipe3.rf_data_sel;  
	
	
	
	case(pipe2.mem_op)
	MEM_OP_SW	:	DM_WEB = 4'b0000; //active low
	MEM_OP_SB	: 	begin	
	//handle the memory is byte address problem
	case (pipe2.result[1:0])
	2'd0		:	DM_WEB = 4'b1110;
	2'd1		:	DM_WEB = 4'b1101;
	2'd2		:	DM_WEB = 4'b1011;
	2'd3		:	DM_WEB = 4'b0111;
	default		:	DM_WEB = 4'b1111;
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
	case(pipe2.mem_op)
	MEM_OP_SW	:	DM_DI = pipe2.data_in;
	MEM_OP_SB	: 	begin	
	//handle the memory is byte address problem
	case (pipe2.result[1:0])
	2'd0		:	DM_DI = {24'h000000,pipe2.data_in[7:0]};
	2'd1		:	DM_DI = {16'h0000,pipe2.data_in[7:0],8'h00};
	2'd2		:	DM_DI = {8'h00,pipe2.data_in[7:0],16'h0000};
	2'd3		:	DM_DI = {pipe2.data_in[7:0],24'h000000};
	default		:	DM_DI = pipe2.data_in;
	endcase
	end
	default		:	DM_DI = pipe2.data_in;
	endcase
	
	dm_out = DM_DO;
	
end
always@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	if(rst)begin
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
always@* begin
	if(pipe3.mem_op == MEM_OP_LB) final_data_out = {{24{dm_out[7]}},dm_out[7:0]};
	else final_data_out = dm_out;
end
assign rf_in = pipe3.rf_data_sel ? final_data_out : pipe3.result;
//assign RF[0] = 0;
always@(`RF_CLK_EGDE clk or posedge rst) begin
	if(rst)begin
		for(int i = 0;i<`RF_NUM;i=i+1) 
			RF[i]<= '0;
	end
	else begin
		if(pipe3.rf_write&&pipe3.rd!='0)begin
			RF[pipe3.rd]<=rf_in;
		end
	end
end

//update PC
logic jump_branch;
assign jump_branch = branch_taken | pipe1.jump_sel;

always@*begin
	if(pc_stall) nPC=PC;
	else nPC=jump_branch ? branch_target : (PC+4);
end
always@(`PIPELINE_CLK_EGDE clk or posedge rst) begin
	if(rst) PC<='0;
	else begin
		PC<=nPC;
	end
end

//controller

assign pc_stall = load_stall;
always@* begin
	if(rst)begin
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
always@(`PIPELINE_CLK_EGDE clk ) begin
	//if(rst) fw_s1<=FW_SEL_DEFAULT;
	if	(im_inst[`RS1]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fw_s1 <= FW_SEL_FW1;
	else if (im_inst[`RS1]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fw_s1 <= FW_SEL_FW2;
	else 	fw_s1<=FW_SEL_DEFAULT;
	
	//if(rst) fw_s2<=FW_SEL_DEFAULT;
	if	(im_inst[`RS2]==pipe1.rd && pipe1.rd!='0 && pipe1.rf_write && ~pipe1.mem_load) fw_s2 <= FW_SEL_FW1;
	else if (im_inst[`RS2]==pipe2.rd && pipe2.rd!='0 && pipe2.rf_write) fw_s2 <= FW_SEL_FW2;
	else 	fw_s2<=FW_SEL_DEFAULT;

end

endmodule