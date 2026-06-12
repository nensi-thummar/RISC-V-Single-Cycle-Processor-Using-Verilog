//------------------------INSTRUCTION MEMORY--------------------------
module instr_mem(
    input rst,
    input [31:0] add,
    output [31:0] data
);
reg [31:0] mem [1023:0];
initial begin
    $readmemh("program.mem", mem);
end
assign data = (!rst) ? 32'd0 : mem[add[31:2]]; // word-aligned read
endmodule

//-------------------------PROGRAM COUNTER---------------------------
module pc(
    input clk,
    input rst,
    input [31:0] pcnext,
    output reg [31:0] pc
);
always @(posedge clk) begin
    if(!rst) 
      pc <= 32'd0;   
    else     
      pc <= pcnext;  
end
endmodule

//------------------------------REGISTER FILE--------------------------
module reg_file(
    input clk,
    input rst,
    input [4:0] a1,         // RS1
    input [4:0] a2,         // RS2
    input [4:0] a3,         // RD
    input [31:0] write_data,
    input write_en_reg,
    output [31:0] read_data1,
    output [31:0] read_data2
);
reg [31:0] registers [31:0];
integer i;
initial begin
    for(i=0; i<32; i=i+1)
        registers[i] = 32'd0; // initialize all registers to 0
end
assign read_data1 = (!rst) ? 32'd0 : registers[a1]; // read rs1
assign read_data2 = (!rst) ? 32'd0 : registers[a2]; // read rs2
always @(posedge clk) begin
    if(write_en_reg && (a3 != 0))
        registers[a3] <= write_data; 
end
endmodule

//-------------------------------PC PLUS-------------------------
module pcplus(
    input [31:0] a,
    input [31:0] b,
    output [31:0] c
);
assign c = a + b; 
endmodule

//-----------------------------PC TARGET-------------------------
module pctarget(
    input [31:0] pc,
    input [31:0] immext,
    output [31:0] pc_target
);
assign pc_target = pc + immext; // branch/jump target address
endmodule

//-----------------------------DATA MEMORY----------------------
module data_mem(
    input clk,
    input rst,
    input write_en_data,
    input [31:0] write_data,
    input [31:0] add,
    output [31:0] read_data
);
reg [31:0] d_mem [1023:0];
assign read_data = (!rst) ? 32'd0 : d_mem[add[31:2]]; // word-aligned read
always @(posedge clk) begin
    if(write_en_data)
        d_mem[add[31:2]] <= write_data; 
end
endmodule

//---------------------------------MAIN DECODER-------------------------
module maindecoder(
    input [6:0] opcode,
    input [2:0] fun3,
    input zero,
    input negative,
    output regwrite,
    output memwrite,
    output ALUsrc,
    output [1:0] resultsrc,
    output [1:0] pcsrc,
    output [1:0] ALUop,
    output [2:0] immsrc
);

wire beq, bne, blt, bge, bltu, bgeu, jal, jalr;

assign jal  = (opcode == 7'b1101111); // JAL opcode
assign jalr = (opcode == 7'b1100111); // JALR opcode

assign beq  = (opcode == 7'b1100011) && (fun3 == 3'b000); // BEQ
assign bne  = (opcode == 7'b1100011) && (fun3 == 3'b001); // BNE
assign blt  = (opcode == 7'b1100011) && (fun3 == 3'b100); // BLT (signed)
assign bge  = (opcode == 7'b1100011) && (fun3 == 3'b101); // BGE (signed)
assign bltu = (opcode == 7'b1100011) && (fun3 == 3'b110); // BLTU (unsigned)
assign bgeu = (opcode == 7'b1100011) && (fun3 == 3'b111); // BGEU (unsigned)

// regwrite: 1 for R, I, Load, JAL, JALR, LUI
assign regwrite =
    (opcode == 7'b0110011) || // R-type
    (opcode == 7'b0010011) || // I-type ALU
    (opcode == 7'b0000011) || // Load
    (opcode == 7'b1101111) || // JAL
    (opcode == 7'b1100111) || // JALR
    (opcode == 7'b0110111);   // LUI

assign memwrite = (opcode == 7'b0100011); // SW: enable memory write

assign ALUsrc =
    (opcode == 7'b0000011) || // Load
    (opcode == 7'b0100011) || // Store
    (opcode == 7'b0010011) || // I-type ALU
    (opcode == 7'b0110111) || // LUI
    (opcode == 7'b1100111);   // JALR

// resultsrc: selects what gets written back to register
assign resultsrc =
    (opcode == 7'b0000011) ? 2'b01 : // Load  -> memory data
    (opcode == 7'b1101111) ? 2'b10 : // JAL   -> PC+4 (return address)
    (opcode == 7'b1100111) ? 2'b10 : // JALR  -> PC+4 (return address)
    (opcode == 7'b0110111) ? 2'b11 : // LUI   -> immediate
                             2'b00;  // ALU result

assign ALUop =
    (opcode == 7'b0000011 || opcode == 7'b0100011) ? 2'b00 : // L/S -> ADD
    (opcode == 7'b1100011)                          ? 2'b01 : // Branch-> SUB
                                                      2'b10;  // R/I-type
assign immsrc =
    (opcode == 7'b0000011) ? 3'b000 : // I-type (Load)
    (opcode == 7'b0010011) ? 3'b000 : // I-type (ALU)
    (opcode == 7'b1100111) ? 3'b000 : // I-type (JALR)
    (opcode == 7'b0100011) ? 3'b001 : // S-type (Store)
    (opcode == 7'b1100011) ? 3'b010 : // B-type (Branch)
    (opcode == 7'b1101111) ? 3'b011 : // J-type (JAL)
    (opcode == 7'b0110111) ? 3'b100 : // U-type (LUI)
                             3'b000;

assign pcsrc =
    (beq  &&  zero)              ? 2'b01 : // BEQ 
    (bne  && !zero)              ? 2'b01 : // BNE
    (blt  &&  negative)          ? 2'b01 : // BLT
    (bge  && (!negative || zero))? 2'b01 : // BGE 
    (bltu &&  negative)          ? 2'b01 : // BLTU 
    (bgeu && (!negative || zero))? 2'b01 : // BGEU 
    (jal)                        ? 2'b01 : // JAL
    (jalr)                       ? 2'b10 : // JALR
                                   2'b00;  // default: PC+4
endmodule


module aludecoder(
    input [6:0] opcode,
    input [6:0] fun7,
    input [2:0] fun3,
    input [1:0] ALUop,
    output reg [3:0] ALUcontrol
);
always @(*) begin
    case(ALUop)
        2'b00: ALUcontrol = 4'b0000; // Load/Store -> ADD (address calc)
        2'b01: ALUcontrol = 4'b0001; // Branch     -> SUB (comparison)
        2'b10: begin
            case(fun3)
                3'b000: // ADD, SUB, ADDI
                    if(opcode == 7'b0110011 && fun7 == 7'b0100000)
                        ALUcontrol = 4'b0001; // SUB
                    else
                        ALUcontrol = 4'b0000; // ADD / ADDI
                3'b111: ALUcontrol = 4'b0010; // AND / ANDI
                3'b110: ALUcontrol = 4'b0011; // OR  / ORI
                3'b100: ALUcontrol = 4'b0100; // XOR / XORI
                3'b010: ALUcontrol = 4'b0101; // SLT / SLTI  (signed)
                3'b011: ALUcontrol = 4'b0110; // SLTU / SLTIU (unsigned)
                3'b001: ALUcontrol = 4'b1000; // SLL / SLLI (shift left logical)
                3'b101: // SRL/SRLI or SRA/SRAI
                    if(fun7 == 7'b0100000)
                        ALUcontrol = 4'b1001; // SRA / SRAI (arithmetic right shift)
                    else
                        ALUcontrol = 4'b0111; // SRL / SRLI (logical right shift)
                default: ALUcontrol = 4'b0000;
            endcase
        end
        default: ALUcontrol = 4'b0000;
    endcase
end
endmodule


module control_unit_top(
    input [6:0] opcode,
    input [6:0] fun7,
    input [2:0] fun3,
    input zero,
    input negative,
    output regwrite,
    output memwrite,
    output ALUsrc,
    output [1:0] resultsrc,
    output [1:0] pcsrc,
    output [2:0] immsrc,
    output [3:0] ALUcontrol
);
wire [1:0] ALUop;

maindecoder maindecoder(
    .opcode(opcode), .fun3(fun3),
    .zero(zero), .negative(negative),
    .regwrite(regwrite), .memwrite(memwrite), .ALUsrc(ALUsrc),
    .resultsrc(resultsrc), .pcsrc(pcsrc),
    .ALUop(ALUop), .immsrc(immsrc)
);

aludecoder aludecoder(
    .opcode(opcode), .fun7(fun7), .fun3(fun3),
    .ALUop(ALUop),
    .ALUcontrol(ALUcontrol)
);
endmodule


module extend(
    input [31:0] in,
    input [2:0] immsrc,
    output reg [31:0] immext
);
always @(*) begin
    case(immsrc)
        3'b000: immext = {{20{in[31]}}, in[31:20]};                                       // I-type: sign-extend bits[31:20]
        3'b001: immext = {{20{in[31]}}, in[31:25], in[11:7]};                             // S-type: sign-extend split immediate
        3'b010: immext = {{19{in[31]}}, in[31], in[7], in[30:25], in[11:8], 1'b0};       // B-type: branch offset (LSB=0)
        3'b011: immext = {{11{in[31]}}, in[31], in[19:12], in[20], in[30:21], 1'b0};     // J-type: jump offset (LSB=0)
        3'b100: immext = {in[31:12], 12'b0};                                               // U-type: upper 20 bits (LUI)
        default: immext = 32'd0;
    endcase
end
endmodule


module mux(
    input [31:0] a,
    input [31:0] b,
    input s,
    output [31:0] y
);
assign y = (s) ? b : a; // s=0: reg operand, s=1: immediate operand
endmodule


module mux4(
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [31:0] d,
    input [1:0] s,
    output [31:0] y
);
assign y =
    (s == 2'b00) ? a : // ALU result
    (s == 2'b01) ? b : // memory read data
    (s == 2'b10) ? c : // PC+4 (return address)
                   d;  // immediate (LUI)
endmodule


module ALU(
    input [31:0] a,
    input [31:0] b,
    input [3:0] alucontrol,
    output reg [31:0] result,
    output carry,
    output overflow,
    output zero,
    output negative
);
wire [31:0] not_b;
wire [31:0] mux1;
wire [32:0] sum;

assign not_b = ~b;                                          // bitwise invert b (for subtraction)
assign mux1  = (alucontrol == 4'b0001) ? not_b : b;        // select inverted b for SUB, normal b otherwise
assign sum   = a + mux1 + (alucontrol == 4'b0001);         // ADD: a+b, SUB: a+(~b)+1 = a-b

assign carry = sum[32]; // carry-out bit

always @(*) begin
    case(alucontrol)
        4'b0000: result = sum[31:0];                            // ADD / ADDI
        4'b0001: result = sum[31:0];                            // SUB
        4'b0010: result = a & b;                                // AND / ANDI
        4'b0011: result = a | b;                                // OR  / ORI
        4'b0100: result = a ^ b;                                // XOR / XORI
        4'b0101: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT  (signed compare)
        4'b0110: result = (a < b)                  ? 32'd1 : 32'd0; // SLTU (unsigned compare)
        4'b0111: result = a >> b[4:0];                          // SRL  (logical right shift)
        4'b1000: result = a << b[4:0];                          // SLL  (logical left shift)
        4'b1001: result = $signed(a) >>> b[4:0];               // SRA  (arithmetic right shift)
        default: result = 32'd0;
    endcase
end

assign zero     = (result == 32'd0); // zero flag: result is zero
assign negative =  result[31];       // negative flag: MSB of result (sign bit)

assign overflow =
    (alucontrol == 4'b0000) ? ((a[31] == b[31]) && (result[31] != a[31])) : // ADD overflow
    (alucontrol == 4'b0001) ? ((a[31] != b[31]) && (result[31] != a[31])) : // SUB overflow
    1'b0;
endmodule


module top(
    input clk,
    input rst
);

wire [31:0] pc_top, pcnext_top, pcplus_top, pc_target_top;
wire [31:0] instr_top;
wire [31:0] rd1_top, rd2_top;
wire [31:0] immext_top, srcb_top;
wire [31:0] alu_result_top, read_data_top, result_top;
wire regwrite_top, memwrite_top, ALUsrc_top;
wire [1:0] resultsrc_top, pcsrc_top;
wire [2:0] immsrc_top;
wire [3:0] ALUcontrol_top;
wire zero_top, negative_top;

pc pc(
    .clk(clk), .rst(rst),
    .pcnext(pcnext_top),
    .pc(pc_top)
);

pcplus pcplus(
    .a(pc_top), .b(32'd4),
    .c(pcplus_top)          // PC + 4
);

pctarget pctarget(
    .pc(pc_top), .immext(immext_top),
    .pc_target(pc_target_top) // branch/jump target
);

instr_mem instr_mem(
    .rst(rst), .add(pc_top),
    .data(instr_top)        // fetch instruction at PC
);

reg_file reg_file(
    .clk(clk), .rst(rst),
    .a1(instr_top[19:15]),  // rs1
    .a2(instr_top[24:20]),  // rs2
    .a3(instr_top[11:7]),   // rd
    .write_data(result_top),
    .write_en_reg(regwrite_top),
    .read_data1(rd1_top),
    .read_data2(rd2_top)
);

control_unit_top control_unit_top(
    .opcode(instr_top[6:0]),
    .fun7(instr_top[31:25]),
    .fun3(instr_top[14:12]),
    .zero(zero_top), .negative(negative_top),
    .regwrite(regwrite_top), .memwrite(memwrite_top), .ALUsrc(ALUsrc_top),
    .resultsrc(resultsrc_top), .pcsrc(pcsrc_top),
    .immsrc(immsrc_top), .ALUcontrol(ALUcontrol_top)
);

extend extend(
    .in(instr_top), .immsrc(immsrc_top),
    .immext(immext_top)     // sign-extended immediate
);

mux mux_alu(
    .a(rd2_top), .b(immext_top),
    .s(ALUsrc_top),
    .y(srcb_top)            // ALU B operand: reg or immediate
);

ALU ALU(
    .a(rd1_top), .b(srcb_top),
    .alucontrol(ALUcontrol_top),
    .result(alu_result_top),
    .carry(), .overflow(),
    .zero(zero_top), .negative(negative_top)
);

data_mem data_mem(
    .clk(clk), .rst(rst),
    .write_en_data(memwrite_top),
    .write_data(rd2_top),
    .add(alu_result_top),   // address from ALU
    .read_data(read_data_top)
);

mux4 result_mux(
    .a(alu_result_top),     // 00: R/I-type result
    .b(read_data_top),      // 01: Load data
    .c(pcplus_top),         // 10: JAL/JALR return address
    .d(immext_top),         // 11: LUI immediate
    .s(resultsrc_top),
    .y(result_top)          // writeback to register file
);

mux4 pc_mux(
    .a(pcplus_top),         // 00: PC+4 (sequential)
    .b(pc_target_top),      // 01: branch/JAL target
    .c(alu_result_top),     // 10: JALR target (rs1+imm)
    .d(32'd0),              // 11: unused
    .s(pcsrc_top),
    .y(pcnext_top)          // next PC
);

endmodule
