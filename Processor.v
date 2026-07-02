// ==========================================
// PROCESSOR MODULE
// ==========================================
module Processor(
    input clk, 
    output halt, 
    input reset, 
    output reg [7:0] pc,
    input [31:0] ins, 
    output [31:0] io_reg1, 
    output [31:0] io_reg2, 
    output [31:0] io_reg3, 
    output [31:0] io_reg4,
    input copied_io_regs,
    output reg io_stall,
    output [31:0] io_regs_index,
    // --- New Lab 9 Assignment 1 Ports ---
    output reg waiting_for_input,
    input [31:0] input_value,
    input input_value_valid
);

    reg [2:0] state;
    localparam STATE_FETCH         = 3'b000;
    localparam STATE_EXECUTE       = 3'b001;
    localparam STATE_WRITEBACK     = 3'b010;
    localparam STATE_STALL_ACK     = 3'b011;
    localparam STATE_STALL_DEACK   = 3'b100;
    localparam STATE_WAIT_INPUT    = 3'b101; // New state for SYS_read
    localparam STATE_WAIT_INPUT_DONE = 3'b110; // New state for SYS_read completion

    // Pipeline Registers
    reg [5:0]  pipe_opcode, pipe_func;
    reg [4:0]  pipe_shamt, pipe_dest_addr, pipe_rt;
    reg [7:0]  pipe_pc;
    reg [25:0] pipe_jump_target;
    reg [31:0] pipe_src1, pipe_src2;
    reg [15:0] pipe_imm; 
    reg [31:0] pipe_write_data;
    reg [4:0]  pipe_write_addr_final;
    reg        pipe_write_enable;

    wire [5:0] opcode = ins[31:26];
    wire [4:0] rs     = ins[25:21];
    wire [4:0] rt     = ins[20:16];
    wire [4:0] rd     = ins[15:11];
    wire [4:0] shamt  = ins[10:6];
    wire [5:0] func   = ins[5:0];
    wire [15:0] imm   = ins[15:0];
    wire [25:0] jump_target = ins[25:0];

    wire [31:0] src1_data, src2_data, alu_out;
    wire alu_out_valid, branch_taken;
    reg fetched;
    reg [31:0] io_reg [0:3];
    reg [2:0] io_reg_index; 
    
    assign io_regs_index = {29'b0, io_reg_index};

    wire [31:0] sign_ext_imm = {{16{pipe_imm[15]}}, pipe_imm};
    wire [31:0] zero_ext_imm = {16'b0, pipe_imm};
    
    wire [31:0] branch_offset_in = (pipe_opcode == `OP_J || pipe_opcode == `OP_JAL) ? 
                                   {6'b0, pipe_jump_target} : sign_ext_imm;
                                   
    wire [31:0] alu_in2 = (pipe_opcode == `OP_REG || pipe_opcode == `OP_BEQ || pipe_opcode == `OP_BNE) ? pipe_src2 : 
                          (pipe_opcode == `OP_ANDI || pipe_opcode == `OP_ORI || pipe_opcode == `OP_XORI) ? zero_ext_imm :
                          sign_ext_imm; 

    RegisterFile rf (
        .read_addr1(rs), .read_addr2(rt), 
        .read_data1(src1_data), .read_data2(src2_data), 
        .write_addr(pipe_write_addr_final), 
        .write_data(pipe_write_data), 
        .write_enable(pipe_write_enable && (state == STATE_WRITEBACK)),
        .clk(clk)
    );

    ALU alu (
        .src1(pipe_src1), 
        .src2(alu_in2), 
        .shift_amount(pipe_shamt), 
        .opcode(pipe_opcode), 
        .func(pipe_func), 
        .pc(pipe_pc),                     
        .branch_offset(branch_offset_in), 
        .rt_field(pipe_rt),               
        .dest(alu_out), 
        .dest_valid(alu_out_valid),
        .branch_taken(branch_taken)       
    );

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'b0;
            state <= STATE_FETCH;
            fetched <= 1'b0;
            io_reg_index <= 3'b0;
            pipe_write_enable <= 1'b0;
            io_stall <= 1'b0;
            waiting_for_input <= 1'b0;
            io_reg[0] <= 32'b0; io_reg[1] <= 32'b0; 
            io_reg[2] <= 32'b0; io_reg[3] <= 32'b0;
        end else begin
            case (state)
                STATE_FETCH: begin 
                    pipe_opcode <= opcode;
                    pipe_func   <= func;
                    pipe_shamt  <= shamt;
                    pipe_src1   <= src1_data;
                    pipe_src2   <= src2_data; 
                    pipe_imm    <= imm;       
                    pipe_pc     <= pc; 
                    pipe_jump_target <= jump_target;
                    pipe_rt     <= rt;

                    if (opcode == `OP_JAL || (opcode == `OP_REG && func == `FUNC_JALR))
                        pipe_dest_addr <= 5'd31;
                    else
                        pipe_dest_addr <= (opcode == `OP_REG) ? rd : rt;
                        
                    state <= STATE_EXECUTE;
                    fetched <= 1'b1;
                end
                STATE_EXECUTE: begin 
                    if (pipe_opcode == `OP_REG && pipe_func == `FUNC_SYSCALL) begin
                        if (pipe_src1 == `SYS_write) begin
                            // Print Output Logic
                            if (io_reg_index == 3'd4) begin
                                io_stall <= 1'b1;
                                state <= STATE_STALL_ACK;
                            end else begin
                                io_reg[io_reg_index[1:0]] <= pipe_src2; // pipe_src2 is regfile[rt]
                                io_reg_index <= io_reg_index + 3'd1;
                                pipe_write_data <= alu_out;
                                pipe_write_addr_final <= pipe_dest_addr;
                                pipe_write_enable <= alu_out_valid;
                                state <= STATE_WRITEBACK;
                            end
                        end else if (pipe_src1 == `SYS_read) begin
                            // --- NEW LAB 9: Keyboard Input Logic ---
                            waiting_for_input <= 1'b1; // Signal environment
                            state <= STATE_WAIT_INPUT; // Stall processor
                        end else begin
                            // SYS_exit or other syscall
                            pipe_write_data <= alu_out;
                            pipe_write_addr_final <= pipe_dest_addr;
                            pipe_write_enable <= alu_out_valid;
                            state <= STATE_WRITEBACK;
                        end
                    end else begin
                        pipe_write_data <= alu_out;
                        pipe_write_addr_final <= pipe_dest_addr;
                        pipe_write_enable <= alu_out_valid;
                        state <= STATE_WRITEBACK;
                    end
                end
                STATE_WRITEBACK: begin 
                    if (halt) begin
                        pc <= pc;
                    end else if (branch_taken) begin
                        if (pipe_opcode == `OP_JAL)
                            pc <= pipe_jump_target[7:0];
                        else if (pipe_opcode == `OP_REG && pipe_func == `FUNC_JALR)
                            pc <= pipe_src1[7:0];
                        else
                            pc <= alu_out[7:0]; 
                    end else begin
                        pc <= pc + 8'd1;
                    end
                    state <= STATE_FETCH;
                end
                STATE_STALL_ACK: begin
                    if (copied_io_regs) begin
                        io_stall <= 1'b0;
                        io_reg_index <= 3'd0;
                        state <= STATE_STALL_DEACK;
                    end
                end
                STATE_STALL_DEACK: begin
                    if (!copied_io_regs) begin
                        io_reg[0] <= pipe_src2;
                        io_reg_index <= 3'd1;
                        pipe_write_data <= alu_out;
                        pipe_write_addr_final <= pipe_dest_addr;
                        pipe_write_enable <= alu_out_valid;
                        state <= STATE_WRITEBACK;
                    end
                end
                // --- NEW LAB 9 STATES ---
                STATE_WAIT_INPUT: begin
                    if (input_value_valid) begin
                        waiting_for_input <= 1'b0; // De-assert flag when valid is seen
                        // Save the incoming value immediately
                        pipe_write_data <= input_value;
                        pipe_write_addr_final <= pipe_dest_addr; // rd field for syscall
                        pipe_write_enable <= 1'b1;               // Force write-enable to true
                        state <= STATE_WAIT_INPUT_DONE;
                    end
                end
                STATE_WAIT_INPUT_DONE: begin
                    if (!input_value_valid) begin
                        // Resume and write to register file
                        state <= STATE_WRITEBACK;
                    end
                end
            endcase
        end
    end

    assign halt = (reset || !fetched) ? 1'b0 : 
                  ((pipe_opcode == `OP_REG && pipe_func == `FUNC_SYSCALL && pipe_src1 == `SYS_exit) ? 1'b1 : 1'b0);

    assign io_reg1 = io_reg[0]; assign io_reg2 = io_reg[1];
    assign io_reg3 = io_reg[2]; assign io_reg4 = io_reg[3];
endmodule