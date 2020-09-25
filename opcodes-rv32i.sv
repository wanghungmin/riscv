`define INST_WIDTH 32
`define ADDR_WIDTH 32
`define DATA_WIDTH 32


`define OPCODE			6:0
`define FUNCT3			14:12
`define FUNCT7			31:25
`define RS1				19:15
`define RS2				24:20
`define RD				11:7
`define SHAMT			24:20
`define IMM12			31:20
`define IMM20			31:12


`define OPCODE_BRANCH 	7'b1100011
`define OPCODE_JAL 		7'b1101111
`define OPCODE_JALR 	7'b1100111
`define OPCODE_OPIMM 	7'b0010011
`define OPCODE_OP 		7'b0110011
`define OPCODE_LOAD 	7'b0000011
`define OPCODE_STORE 	7'b0100011
`define OPCODE_LUI	 	7'b0110111
`define OPCODE_AUIPC 	7'b0010111


`define FUNCT_BRANCH(inst) 	inst[`FUNCT3]
`define FUNCT_BRANCH_BEQ	FUNCT3_BEQ
`define FUNCT_BRANCH_BNE	FUNCT3_BNE
`define FUNCT_BRANCH_BLT	FUNCT3_BLT
`define FUNCT_BRANCH_BGE	FUNCT3_BGE
`define FUNCT_BRANCH_BLTU	FUNCT3_BLTU
`define FUNCT_BRANCH_BGEU	FUNCT3_BGEU


`define FUNCT_OP(inst)		{inst[`FUNCT3]	,inst[`FUNCT7]	}
`define FUNCT_OP_ADD		{`FUNCT3_ADD   	,`FUNCT7_ADD 	}
`define FUNCT_OP_SUB		{`FUNCT3_SUB   	,`FUNCT7_SUB 	}
`define FUNCT_OP_SLL	    {`FUNCT3_SLL   	,`FUNCT7_SLL 	}
`define FUNCT_OP_SLT	    {`FUNCT3_SLT  	,`FUNCT7_SLT 	}
`define FUNCT_OP_SLTU	    {`FUNCT3_SLTU  	,`FUNCT7_SLTU	}
`define FUNCT_OP_XOR	    {`FUNCT3_XOR   	,`FUNCT7_XOR 	}	
`define FUNCT_OP_SRL	    {`FUNCT3_SRL   	,`FUNCT7_SRL 	}
`define FUNCT_OP_SRA	    {`FUNCT3_SRA   	,`FUNCT7_SRA 	}
`define FUNCT_OP_OR	        {`FUNCT3_OR	   	,`FUNCT7_OR		}
`define FUNCT_OP_AND	    {`FUNCT3_AND   	,`FUNCT7_AND 	}
				 
/*				 
`define FUNCT_OPIMM(inst)	{inst[`FUNCT3]	,inst[`FUNCT7]	}
`define FUNCT_OPIMM_ADDI	{`FUNCT3_ADDI	, 7'bxxxxxxx	}
`define FUNCT_OPIMM_SLLI	{`FUNCT3_SLLI	,`FUNCT7_SLLI	}
`define FUNCT_OPIMM_SLTI	{`FUNCT3_SLTI	, 7'bxxxxxxx	}
`define FUNCT_OPIMM_SLTIU   {`FUNCT3_SLTIU	, 7'bxxxxxxx	}
`define FUNCT_OPIMM_XORI	{`FUNCT3_XORI	, 7'bxxxxxxx	}
`define FUNCT_OPIMM_SRLI	{`FUNCT3_SRLI	,`FUNCT7_SRLI	}
`define FUNCT_OPIMM_SRAI	{`FUNCT3_SRAI	,`FUNCT7_SRAI	}
`define FUNCT_OPIMM_ORI	    {`FUNCT3_ORI	, 7'bxxxxxxx	}
`define FUNCT_OPIMM_ANDI	{`FUNCT3_ANDI	, 7'bxxxxxxx	}
*/

`define FUNCT3_BEQ		3'd0
`define FUNCT3_BNE		3'd1
`define FUNCT3_BLT		3'd4
`define FUNCT3_BGE		3'd5
`define FUNCT3_BLTU		3'd6
`define FUNCT3_BGEU		3'd7


`define FUNCT3_ADDI		3'd0
`define FUNCT3_SLLI		3'd1
`define FUNCT3_SLTI		3'd2
`define FUNCT3_SLTIU	3'd3
`define FUNCT3_XORI		3'd4
`define FUNCT3_SRLI		3'd5
`define FUNCT3_SRAI		3'd5
`define FUNCT3_ORI		3'd6
`define FUNCT3_ANDI		3'd7

`define FUNCT7_SLLI		7'b0000000
`define FUNCT7_SRLI		7'b0000000
`define FUNCT7_SRAI		7'b0100000

`define FUNCT3_ADD		3'd0
`define FUNCT3_SUB		3'd0
`define FUNCT3_SLL		3'd1
`define FUNCT3_SLT		3'd2
`define FUNCT3_SLTU		3'd3
`define FUNCT3_XOR		3'd4
`define FUNCT3_SRL		3'd5
`define FUNCT3_SRA		3'd5
`define FUNCT3_OR		3'd6
`define FUNCT3_AND		3'd7

`define FUNCT3_SW		3'b010
`define FUNCT3_SB		3'b000

`define FUNCT3_LW		3'b010
`define FUNCT3_LB		3'b000

`define FUNCT7_ADD		7'b0000000
`define FUNCT7_SUB		7'b0100000
`define FUNCT7_SLL		7'b0000000
`define FUNCT7_SLT		7'b0000000
`define FUNCT7_SLTU		7'b0000000
`define FUNCT7_XOR		7'b0000000
`define FUNCT7_SRL		7'b0000000
`define FUNCT7_SRA		7'b0100000
`define FUNCT7_OR		7'b0000000
`define FUNCT7_AND		7'b0000000

`define IMM_I_TYPE(inst) {{20{inst[31]}},inst[31:20]}
`define IMM_S_TYPE(inst) {{20{inst[31]}},inst[31:25],inst[11:8],inst[7]}
`define IMM_B_TYPE(inst) {{20{inst[31]}},inst[7],inst[31:25],inst[11:8],1'b0}
`define IMM_U_TYPE(inst) {inst[31:12],12'b0}
`define IMM_J_TYPE(inst) {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0}

`define IS_I_TYPE(inst)	(inst[`OPCODE]==`OPCODE_OPIMM) | (inst[`OPCODE]==`OPCODE_LOAD) | (inst[`OPCODE]==`OPCODE_JALR)
`define IS_S_TYPE(inst)	inst[`OPCODE]==`OPCODE_STORE
`define IS_B_TYPE(inst)	inst[`OPCODE]==`OPCODE_BRANCH
`define IS_U_TYPE(inst)	(inst[`OPCODE]==`OPCODE_AUIPC) | (inst[`OPCODE]==`OPCODE_LUI)
`define IS_J_TYPE(inst)	inst[`OPCODE]==`OPCODE_JAL
//https://github.com/riscv/riscv-opcodes/blob/master/opcodes-rv32i