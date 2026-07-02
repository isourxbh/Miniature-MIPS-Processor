// ==========================================
// TESTBENCH - LAB 9 ASSIGNMENT 1
// ==========================================
module tb_lab8;
    reg clk, reset, done_storing, copied_io_regs;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    
    // --- New Lab 9 TB Variables ---
    reg [31:0] input_value;
    reg input_value_valid;
    wire waiting_for_input;

    wire done, io_stall;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4, total_cycles, proc_cycles, io_regs_index;

    Computer comp (
        .reset(reset), .ins_addr(ins_addr), .ins(ins), .clk(clk), .done_storing(done_storing), .done(done),
        .out_reg1(out_reg1), .out_reg2(out_reg2), .out_reg3(out_reg3), .out_reg4(out_reg4),
        .total_cycles(total_cycles), .proc_cycles(proc_cycles),
        .copied_io_regs(copied_io_regs), .io_stall(io_stall), .io_regs_index(io_regs_index),
        .waiting_for_input(waiting_for_input), .input_value(input_value), .input_value_valid(input_value_valid)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        reset = 1; done_storing = 0; copied_io_regs = 0;
        input_value = 0; input_value_valid = 0;
        #10 reset = 0;
        
        // =========================================================
        // TRANSLATED C-PROGRAM FROM LAB 9 SLIDE 6
        // int x, y, z;
        // input x; input y; z = x + y; print z; exit();
        // =========================================================
        
        // 1. Setup SYS_read (1003) -> addi $1, $0, 1003
        ins_addr = 0;  ins = 32'h200103EB; #10; 
        
        // 2. input x -> syscall $1, $2  (rs=$1, rd=$2. $2 will hold x)
        ins_addr = 1;  ins = 32'h0020100C; #10; 

        // 3. input y -> syscall $1, $3  (rs=$1, rd=$3. $3 will hold y)
        ins_addr = 2;  ins = 32'h0020180C; #10; 

        // 4. z = x + y -> add $4, $2, $3 
        ins_addr = 3;  ins = 32'h00432020; #10; 

        // 5. Setup SYS_write (1004) -> addi $1, $0, 1004
        ins_addr = 4;  ins = 32'h200103EC; #10; 

        // 6. print z -> syscall $1, $4  (rs=$1, rt=$4)
        // Wait, for print, rt is used. SYS_write uses regfile[rt]. So rs=$1, rt=$4.
        ins_addr = 5;  ins = 32'h0024000C; #10; 

        // 7. exit(); Setup SYS_exit (1001) -> addi $1, $0, 1001
        ins_addr = 6;  ins = 32'h200103E9; #10; 

        // 8. SYSCALL (exit)
        ins_addr = 7;  ins = 32'h0020000C; #10; 

        done_storing = 1;

        // --- Environment Monitor (Inputs & Outputs) ---
        while (!done) begin
            @(posedge clk);
            
            // Handle Keyboard Input Request
            if (waiting_for_input && !input_value_valid) begin
                $display("\n[ENV] Keyboard Input Requested!");
                // Simulating typing a number... Let's use 15 for 'x', and 27 for 'y'
                if (input_value == 0) begin
                    input_value = 15; // Provide 'x'
                    $display("      -> Supplying x = 15");
                end else begin
                    input_value = 27; // Provide 'y'
                    $display("      -> Supplying y = 27");
                end
                
                input_value_valid = 1;
                wait(!waiting_for_input);
                @(posedge clk);
                input_value_valid = 0;
            end

            // Handle Print Stall (Not expected in this short program, but good practice)
            if (io_stall) begin
                $display("\n[ENV] Processor stalled! Reading captured I/O registers...");
                copied_io_regs = 1;
                wait(!io_stall);
                @(posedge clk);
                copied_io_regs = 0;
            end
        end

        $display("\n[ENV] Execution Done! Checking residual registers...");
        if (io_regs_index > 0) $display("OUT1 (z): %0d", $signed(out_reg1));
        if (io_regs_index > 1) $display("OUT2: %0d", $signed(out_reg2));
        $display("\nTotal cycles: %0d, Computation cycles: %0d", total_cycles, proc_cycles);

        $finish;
    end
endmodule