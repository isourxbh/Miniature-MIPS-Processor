#include "xil_printf.h"
#include "xil_io.h"
#include <stdio.h> // Required for scanf

// Define your processor's base address (Replace with your actual macro from xparameters.h)
#define base_addr YOUR_IP_BASE_ADDR 

int main() {
    unsigned reset = 1, ins_addr, ins, done_storing = 0, done, total_cycles, proc_cycles;
    unsigned waiting_for_input, input_value_valid = 0;
    int i, x, N, input_value;
    int out[4];
    unsigned flush_io_regs, done_copying_io_regs = 0, print_count, print_out_count = 1;

    // --- 1. Initialization ---
    Xil_Out32(base_addr, reset);
    Xil_Out32(base_addr+3, done_storing);
    Xil_Out32(base_addr+4, done_copying_io_regs);
    Xil_Out32(base_addr+6, input_value_valid);
    reset = 0;
    Xil_Out32(base_addr, reset);

    // --- 2. Input the translated instruction sequence ---
    // Machine code for the Lab 9 Assignment 1 program (with keyboard inputs)
    unsigned int instructions[] = {
        0x200403EC, // 0: addi $4, $0, 1004    ($4 = SYS_write)
        0x200503E9, // 1: addi $5, $0, 1001    ($5 = SYS_exit)
        0x200803EB, // 2: addi $8, $0, 1003    ($8 = SYS_read)
        
        0x0100080C, // 3: syscall $8, $1       (input x -> rs=8, rd=1)
        0x0100180C, // 4: syscall $8, $3       (input N -> rs=8, rd=3)
        0x20020000, // 5: addi $2, $0, 0       (i = 0)
        
        // --- Loop Start (PC = 6) ---
        0x0043302A, // 6: slt $6, $2, $3       ($6 = i < N)
        0x10C0000F, // 7: beq $6, $0, 15       (if $6==0 branch to ExitLoop PC=22)
        
        // --- If Condition: if ((i & 0x1) == 0) ---
        0x30470001, // 8: andi $7, $2, 1       ($7 = i & 1)
        0x14E00006, // 9: bne $7, $0, 6        (if $7!=0 branch to ElseBlock PC=15)
        
        // --- If Block: x += f(x,i) ---
        0x202A0000, // 10: addi $10, $1, 0     (arg1 = x)
        0x204B0000, // 11: addi $11, $2, 0     (arg2 = i)
        0x0C000017, // 12: jal 23              (jal Function_f at PC=23)
        0x002C0820, // 13: add $1, $1, $12     (x = x + ret)
        0x08000013, // 14: j 19                (jump to PrintBlock PC=19)
        
        // --- Else Block: x -= f(x,i) ---
        0x202A0000, // 15: addi $10, $1, 0     (arg1 = x)
        0x204B0000, // 16: addi $11, $2, 0     (arg2 = i)
        0x0C000017, // 17: jal 23              (jal Function_f at PC=23)
        0x002C0822, // 18: sub $1, $1, $12     (x = x - ret)
        
        // --- Print & Increment Block ---
        0x0081000C, // 19: SYSCALL             (print x. rs=$4(1004), rt=$1(x))
        0x20420001, // 20: addi $2, $2, 1      (i++)
        0x08000006, // 21: j 6                 (jump LoopStart PC=6)
        
        // --- Exit Loop ---
        0x00A0000C, // 22: SYSCALL             (exit. rs=$5(1001), rt=$0)
        
        // --- Function f(a,b) { return a+b; } ---
        0x014B6020, // 23: add $12, $10, $11   (ret = arg1 + arg2)
        0x03E00008  // 24: jr $31              (return to caller)
    };

    // Load instructions into hardware memory
    int num_instructions = sizeof(instructions) / sizeof(instructions[0]);
    for (ins_addr = 0; ins_addr < num_instructions; ins_addr++) {
        Xil_Out32(base_addr + 1, ins_addr);          
        Xil_Out32(base_addr + 2, instructions[ins_addr]); 
    }

    // --- 3. Start Execution ---
    done_storing = 1;
    Xil_Out32(base_addr+3, done_storing);

    // --- 4. Main Polling Loop ---
    while (1) {
        flush_io_regs = 0;
        done = 0;
        waiting_for_input = 0;
        
        // Poll status flags
        while (!flush_io_regs && !done && !waiting_for_input) {
            flush_io_regs = Xil_In32(base_addr+14);
            done = Xil_In32(base_addr+7);
            waiting_for_input = Xil_In32(base_addr+16);
        }

        // --- Handle Keyboard Input ---
        if (waiting_for_input) {
            xil_printf("Enter input:\n\r");
            scanf("%d", &input_value);
            
            // Send value to processor
            Xil_Out32(base_addr+5, input_value);
            
            // Toggle valid bit to tell processor it can read it
            input_value_valid = 1;
            Xil_Out32(base_addr+6, input_value_valid);
            input_value_valid = 0;
            Xil_Out32(base_addr+6, input_value_valid);
        }

        // --- Handle I/O Stalls (Buffer full) ---
        if (flush_io_regs) {
            out[0] = Xil_In32(base_addr+8);
            out[1] = Xil_In32(base_addr+9);
            out[2] = Xil_In32(base_addr+10);
            out[3] = Xil_In32(base_addr+11);
            
            done_copying_io_regs = 1;
            Xil_Out32(base_addr+4, done_copying_io_regs);
            done_copying_io_regs = 0;
            Xil_Out32(base_addr+4, done_copying_io_regs);
            
            for (int i = 0; i < 4; i++) {
                xil_printf("out%d=%d\n\r", print_out_count, out[i]);
                print_out_count++;
            }
        }

        // --- Handle Program Completion ---
        if (done) {
            print_count = Xil_In32(base_addr+15);
            int i = 8;
            
            while (print_count > 0) {
                out[0] = Xil_In32(base_addr+i);
                xil_printf("out%d=%d\n\r", print_out_count, out[0]);
                print_count--;
                print_out_count++;
                i++;
            }
            break; 
        }
    } 

    // --- 5. Print Cycle Statistics ---
    total_cycles = Xil_In32(base_addr+12);
    proc_cycles = Xil_In32(base_addr+13);
    
    xil_printf("Total cycles: %u, computation cycles: %u\n\r", total_cycles, proc_cycles);
    printf("Processor cycles per instruction (CPI): %f\n\r", ((float)proc_cycles)/(num_instructions));

    return 0;
}