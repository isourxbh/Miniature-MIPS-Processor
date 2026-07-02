`timescale 1ns / 1ps

// --- LAB 9 MACROS ---
`define SYS_read 32'd1003

// --- ASSIGNMENT 2 MACROS (From Lab 8) ---
`define OP_BLTZ_BGEZ 6'h01
`define OP_J         6'h02
`define OP_JAL       6'h03
`define OP_BEQ       6'h04
`define OP_BNE       6'h05
`define OP_BLEZ      6'h06
`define OP_BGTZ      6'h07
`define OP_SLTI      6'h0a
`define OP_SLTIU     6'h0b

`define FUNC_JR      6'h08
`define FUNC_JALR    6'h09
`define FUNC_SLT     6'h2a
`define FUNC_SLTU    6'h2b

// --- ASSIGNMENT 1 MACROS (From Lab 8) ---
`define OP_REG 6'h0
`define OP_ADDI 6'h8
`define OP_ANDI 6'hc
`define OP_ORI 6'hd
`define OP_XORI 6'he

`define FUNC_SLL 6'h0
`define FUNC_SRL 6'h2
`define FUNC_SRA 6'h3
`define FUNC_SLLV 6'h4
`define FUNC_SRLV 6'h6
`define FUNC_SRAV 6'h7
`define FUNC_SYSCALL 6'hc
`define FUNC_ADD 6'h20
`define FUNC_SUB 6'h22
`define FUNC_AND 6'h24
`define FUNC_OR 6'h25
`define FUNC_XOR 6'h26
`define FUNC_NOR 6'h27

`define READ_COMMAND 1'b0
`define WRITE_COMMAND 1'b1
`define SYS_exit 32'd1001
`define SYS_write 32'd1004