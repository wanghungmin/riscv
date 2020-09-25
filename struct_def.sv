`define RF_WIDTH		32
`define RF_NUM			32
`define RF_TAG_WIDTH	5
`define DATA_MEM_DATA_WIDTH	32
`define INST_MEM_DATA_WIDTH	32


typedef enum{
	ALU_OP_NOP,
	ALU_OP_ADD,
	ALU_OP_SUB,
	ALU_OP_SLL,
	ALU_OP_SLT,
	ALU_OP_SLTU,
	ALU_OP_XOR,
	ALU_OP_SRL,
	ALU_OP_SRA,
	ALU_OP_OR,
	ALU_OP_AND,
	ALU_OP_BEQ,
	ALU_OP_BNE,
	ALU_OP_BLT,
	ALU_OP_BGE,
	ALU_OP_BLTU,
	ALU_OP_BGEU
} ALU_OP;

typedef enum{
	MEM_OP_NOP,
	MEM_OP_LW,
	MEM_OP_LB,
	MEM_OP_SW,
	MEM_OP_SB
} MEM_OP;


typedef enum {
	ALU1_SEL_S1,
	ALU1_SEL_PC,
	ALU1_SEL_0
}ALU1_SEL;

typedef enum {
	ALU2_SEL_S2,
	ALU2_SEL_IMM,
	ALU2_SEL_4
}ALU2_SEL;
typedef enum {
	ADD1_SEL_PC,
	ADD1_SEL_S1
}ADD1_SEL;
typedef enum {
	ADD2_SEL_IMM,
	ADD2_SEL_S2
}ADD2_SEL;

typedef enum {
	FW_SEL_DEFAULT,
	FW_SEL_FW1,
	FW_SEL_FW2
}FW_SEL;


typedef logic [`ADDR_WIDTH-1:0] 	Address;
typedef logic [`DATA_WIDTH-1:0] 	Data;
typedef logic [`INST_WIDTH-1:0] 	Instruction;
typedef logic [`RF_TAG_WIDTH-1:0] 	RFTag;


typedef struct packed {
	//Instruction 	inst;
	logic			inst_valid;
	Address			pc;
} PipelineReg0;


typedef struct packed{
	ALU_OP 		alu_op;
	MEM_OP 		mem_op;
	Data		add1;
	Data		add2;
	Data		alu1;
	Data		alu2;
	//Data		s1;
	//Data		s2;
	//Data		imm;
	//Address		pc;
	RFTag		rd;
	//OPND1_SEL	opnd1_sel;
	//OPND2_SEL	opnd2_sel;
	logic		mem_load;
	logic		mem_store;
	logic 		jalr_sel;
	logic 		jump_sel;
	logic		rf_write;
	logic		rf_data_sel;
} PipelineReg1;

typedef struct packed {
	MEM_OP 		mem_op;
	RFTag		rd;
	Data		data_in;
	Data		result;
	logic		mem_load;
	logic		mem_store;
	logic		rf_write;
	logic		rf_data_sel;
} PipelineReg2;

typedef struct packed {
	MEM_OP 		mem_op;
	RFTag		rd;
	Data		data_out;
	Data		result;
	logic		rf_write;
	logic		rf_data_sel;
} PipelineReg3;
/*
`define PIPELINE_CLK_EGDE negedge
`define RF_CLK_EGDE posedge
*/
`define PIPELINE_CLK_EGDE posedge
`define RF_CLK_EGDE negedge
