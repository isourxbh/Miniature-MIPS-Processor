`include "defs.vh"
// ==========================================
// COMPUTER MODULE
// ==========================================
module Computer(
    input reset, input [7:0] ins_addr, input [31:0] ins, input clk, 
    input done_storing, output reg done, 
    output [31:0] out_reg1, out_reg2, out_reg3, out_reg4,
    output [31:0] total_cycles, output [31:0] proc_cycles,
    input copied_io_regs, output io_stall, output [31:0] io_regs_index,
    // --- New Lab 9 Assignment 1 Ports ---
    output waiting_for_input,
    input [31:0] input_value,
    input input_value_valid
);
    wire [7:0] pc;
    wire [31:0] ins_fetched;
    wire ins_mem_command, halt;
    reg [31:0] counter_total, counter_proc;

    Memory mem(.write_enable(~reset & ~done_storing), .clk(clk), .command(ins_mem_command), 
               .address(done_storing ? pc : ins_addr), .word_in(ins), .word_out(ins_fetched));
               
    Processor proc(.clk(clk), .halt(halt), .reset(~done_storing), .pc(pc), .ins(ins_fetched), 
                   .io_reg1(out_reg1), .io_reg2(out_reg2), .io_reg3(out_reg3), .io_reg4(out_reg4),
                   .copied_io_regs(copied_io_regs), .io_stall(io_stall), .io_regs_index(io_regs_index),
                   .waiting_for_input(waiting_for_input), .input_value(input_value), .input_value_valid(input_value_valid));

    assign ins_mem_command = done_storing ? `READ_COMMAND : `WRITE_COMMAND;
    assign total_cycles = counter_total;
    assign proc_cycles = counter_proc;

    always @(posedge clk) begin
        if (reset) begin
            counter_total <= 32'b0; counter_proc <= 32'b0; done <= 1'b0;
        end else begin
            if (!done) counter_total <= counter_total + 1;
            // Freeze computation cycle counter if halted, stalling for IO, or waiting for keyboard input
            if (done_storing && !halt && !done && !io_stall && !waiting_for_input) counter_proc <= counter_proc + 1;
            if (halt) done <= 1'b1;
        end
    end
endmodule