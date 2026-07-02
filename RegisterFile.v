

module RegisterFile (
    input [4:0] read_addr1, read_addr2, output [31:0] read_data1, read_data2,
    input [4:0] write_addr, input [31:0] write_data, input write_enable, input clk
);
    reg [31:0] regfile [0:31];
    assign read_data1 = regfile[read_addr1];
    assign read_data2 = regfile[read_addr2];

    always @ (negedge clk) begin
        if (write_enable && (write_addr != 5'b0)) regfile[write_addr] <= write_data;
    end
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regfile[i] = 32'b0;
    end
endmodule