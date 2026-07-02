

// ==========================================
// MEMORY & REGISTER FILE
// ==========================================
module Memory(
    input write_enable, input clk, input command, input [7:0] address, 
    input [31:0] word_in, output [31:0] word_out
);
    reg [31:0] Mem [0:255];
    assign word_out = (command == `READ_COMMAND) ? Mem[address] : 32'b0;
    always @ (posedge clk) begin
        if ((command == `WRITE_COMMAND) && (write_enable == 1'b1)) Mem[address] <= word_in;
    end
endmodule
