# Miniature MIPS Processor

> **CS220 — Computer Organization · IIT Kanpur**
> Course project under **Prof. Mainak Chaudhuri** (March – April 2025)

A 32-bit, 3-cycle MIPS processor implemented in synthesisable Verilog, capable of executing cross-compiled C programs on an FPGA with full keyboard input and display output support.

---

## Objective

Design and verify a multi-cycle MIPS processor in Verilog that:

- Executes a rich subset of the MIPS ISA natively in hardware.
- Handles peripheral I/O (keyboard input via `SYS_read`, display output via `SYS_write`) through a syscall interface.
- Runs cross-compiled C programs end-to-end on a Xilinx FPGA while meeting synchronisation compliance.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Computer (Top)                      │
│                                                         │
│   ┌──────────┐     ┌────────────┐     ┌─────────────┐  │
│   │  Memory   │────▶│  Processor │◀───▶│ Register    │  │
│   │ (256×32)  │     │  (3-cycle  │     │   File      │  │
│   │           │     │  FSM)      │     │ (32×32)     │  │
│   └──────────┘     │            │     └─────────────┘  │
│                     │    ┌───┐   │                      │
│                     │    │ALU│   │                      │
│                     │    └───┘   │                      │
│                     └────────────┘                      │
│           ▲               │  ▲                          │
│           │          I/O  │  │  Keyboard                │
│     Instruction      Regs │  │  Input                   │
│       Loading        ─────▼  │                          │
│                     Testbench / FPGA Host (main.c)      │
└─────────────────────────────────────────────────────────┘
```

The processor uses a **3-cycle datapath** with the following stages:

| Cycle | Stage | Description |
|-------|-------|-------------|
| 1 | **FETCH** | Reads the instruction from memory; decodes fields and latches operands from the register file into pipeline registers. |
| 2 | **EXECUTE** | The ALU computes the result (arithmetic / branch target / comparison). Syscalls are dispatched here, potentially stalling for I/O. |
| 3 | **WRITEBACK** | The ALU result is written back to the register file; the PC is updated (sequential / branch / jump). |

Additional FSM states handle I/O synchronisation:

| State | Purpose |
|-------|---------|
| `STALL_ACK` | Waits for the environment to copy a full 4-register I/O buffer before accepting more print data. |
| `STALL_DEACK` | Waits for the environment to de-assert the copy acknowledgement. |
| `WAIT_INPUT` | Stalls the processor until the environment supplies a valid keyboard input value. |
| `WAIT_INPUT_DONE` | Waits for the valid flag to be de-asserted before resuming execution. |

---

## Supported ISA

### R-Type (opcode `0x00`)

| Instruction | Function Code | Operation |
|-------------|--------------|-----------|
| `ADD` | `0x20` | `rd = rs + rt` |
| `SUB` | `0x22` | `rd = rs − rt` |
| `AND` | `0x24` | `rd = rs & rt` |
| `OR` | `0x25` | `rd = rs \| rt` |
| `XOR` | `0x26` | `rd = rs ^ rt` |
| `NOR` | `0x27` | `rd = ~(rs \| rt)` |
| `SLT` | `0x2A` | `rd = (rs < rt) ? 1 : 0` (signed) |
| `SLTU` | `0x2B` | `rd = (rs < rt) ? 1 : 0` (unsigned) |
| `SLL` | `0x00` | `rd = rt << shamt` |
| `SRL` | `0x02` | `rd = rt >> shamt` (logical) |
| `SRA` | `0x03` | `rd = rt >>> shamt` (arithmetic) |
| `SLLV` | `0x04` | `rd = rt << rs[4:0]` |
| `SRLV` | `0x06` | `rd = rt >> rs[4:0]` |
| `SRAV` | `0x07` | `rd = rt >>> rs[4:0]` |
| `JR` | `0x08` | `PC = rs` |
| `JALR` | `0x09` | `$31 = PC+1; PC = rs` |
| `SYSCALL` | `0x0C` | System call (see below) |

### I-Type

| Instruction | Opcode | Operation |
|-------------|--------|-----------|
| `ADDI` | `0x08` | `rt = rs + sign_ext(imm)` |
| `ANDI` | `0x0C` | `rt = rs & zero_ext(imm)` |
| `ORI` | `0x0D` | `rt = rs \| zero_ext(imm)` |
| `XORI` | `0x0E` | `rt = rs ^ zero_ext(imm)` |
| `SLTI` | `0x0A` | `rt = (rs < sign_ext(imm)) ? 1 : 0` (signed) |
| `SLTIU` | `0x0B` | `rt = (rs < sign_ext(imm)) ? 1 : 0` (unsigned) |
| `BEQ` | `0x04` | Branch if `rs == rt` |
| `BNE` | `0x05` | Branch if `rs != rt` |
| `BLEZ` | `0x06` | Branch if `rs <= 0` |
| `BGTZ` | `0x07` | Branch if `rs > 0` |
| `BLTZ` | `0x01` (`rt=0`) | Branch if `rs < 0` |
| `BGEZ` | `0x01` (`rt=1`) | Branch if `rs >= 0` |

### J-Type

| Instruction | Opcode | Operation |
|-------------|--------|-----------|
| `J` | `0x02` | `PC = target` |
| `JAL` | `0x03` | `$31 = PC+1; PC = target` |

### Syscalls

| Syscall | Code | Behaviour |
|---------|------|-----------|
| `SYS_exit` | `1001` | Halts the processor. |
| `SYS_read` | `1003` | Stalls the processor and waits for keyboard input; the supplied value is written to `rd`. |
| `SYS_write` | `1004` | Buffers `regfile[rt]` into a 4-register I/O window for display output. |

---

## Project Structure

```
.
├── defs.vh           # Opcode / function-code macros and global defines
├── ALU.v             # Combinational ALU — arithmetic, logic, shifts, branches
├── RegisterFile.v    # 32×32-bit register file (read on posedge, write on negedge)
├── Memory.v          # 256×32-bit single-port instruction memory
├── Processor.v       # 3-cycle FSM datapath with I/O stall logic
├── Computer.v        # Top-level wrapper — connects Memory ↔ Processor, tracks cycle counts
├── Test.v            # Simulation testbench with environment I/O modelling
├── main.c            # FPGA host driver (Xilinx SDK) — instruction loading, I/O polling, UART output
└── test_out          # Simulation waveform / output dump
```

---

## Module Descriptions

### `ALU` — [ALU.v](ALU.v)
Purely combinational module that computes the result for every supported instruction in a single cycle. Outputs include the 32-bit result, a validity flag, and a branch-taken signal.

### `RegisterFile` — [RegisterFile.v](RegisterFile.v)
Dual-read, single-write register file. Reads are asynchronous (combinational); writes occur on the **negative clock edge** to avoid read-after-write hazards within the same cycle. Register `$0` is hardwired to zero.

### `Memory` — [Memory.v](Memory.v)
256-entry, 32-bit wide synchronous memory. During the loading phase it accepts instruction writes from the testbench/host; after `done_storing` is asserted it serves instruction fetches to the processor.

### `Processor` — [Processor.v](Processor.v)
The core FSM implementing the 3-cycle datapath (Fetch → Execute → Writeback) plus I/O stall states. Handles:
- Instruction decoding and operand multiplexing (sign/zero extension, immediate selection).
- Branch and jump target computation.
- Syscall dispatch for `SYS_read`, `SYS_write`, and `SYS_exit`.
- A 4-register I/O buffer with stall/acknowledge handshaking for display output.
- A separate stall path for blocking keyboard input.

### `Computer` — [Computer.v](Computer.v)
Top-level module that instantiates Memory and Processor, multiplexes the memory bus between instruction loading and fetch phases, and maintains two cycle counters:
- **Total cycles** — wall-clock cycles from start to halt.
- **Computation cycles** — excludes I/O stalls and input waits.

### `Test` — [Test.v](Test.v)
Behavioural testbench that:
1. Loads a hand-assembled instruction sequence (`input x; input y; z = x+y; print z; exit`).
2. Monitors the `waiting_for_input` and `io_stall` signals to model keyboard and display I/O.
3. Prints results and cycle statistics on completion.

### `main.c` — [main.c](main.c)
Bare-metal C driver for Xilinx SDK / Vitis targeting an FPGA. Loads a more complex program (loop with function calls, conditional branches, and multiple prints) into the hardware processor via memory-mapped registers, polls for I/O events, and reports output over UART.

---

## How It Works

### Instruction Loading
Instructions are loaded into `Memory` word-by-word through the testbench (simulation) or via `Xil_Out32` (FPGA). Once loading is complete, `done_storing` is asserted and the processor begins execution from `PC = 0`.

### Display Output (`SYS_write`)
The processor buffers print values into a 4-register I/O window. When the buffer is full, it asserts `io_stall` and waits for the environment to read and acknowledge the data before continuing.

### Keyboard Input (`SYS_read`)
On a `SYS_read` syscall the processor asserts `waiting_for_input` and stalls. The environment places the input value on `input_value` and pulses `input_value_valid`. The processor latches the value into the destination register and resumes execution.

### Cycle Accounting
Two counters track performance:
- **Total cycles** — incremented every clock while the processor has not halted.
- **Computation cycles** — paused during I/O stalls and input waits, giving a measure of pure computation time.

---

## Simulation

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) or any IEEE 1364-compliant simulator.
- (Optional) [GTKWave](http://gtkwave.sourceforge.net/) for waveform viewing.

### Run
```bash
# Compile
iverilog -o test_out ALU.v Memory.v RegisterFile.v Processor.v Computer.v Test.v

# Execute
vvp test_out
```

### Expected Output
```
[ENV] Keyboard Input Requested!
      -> Supplying x = 15

[ENV] Keyboard Input Requested!
      -> Supplying y = 27

[ENV] Execution Done! Checking residual registers...
OUT1 (z): 42

Total cycles: <N>, Computation cycles: <M>
```

---

## FPGA Deployment

1. **Synthesise** the design (excluding `Test.v`) in Vivado targeting your Xilinx FPGA board.
2. **Package** the processor as a custom AXI IP and connect it to the Zynq PS via an AXI interconnect.
3. **Export** the hardware and launch Vitis / Xilinx SDK.
4. **Build** the `main.c` driver as a bare-metal application.
5. **Program** the FPGA and run — interact via UART terminal for keyboard input and display output.

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **3-cycle FSM** (not pipelined) | Simplifies hazard handling; sufficient for the project scope. |
| **Negative-edge register writes** | Enables same-cycle read-then-write without forwarding logic. |
| **4-register I/O buffer** | Amortises the cost of slow UART output by batching print values. |
| **Separate `SYS_read` stall path** | Cleanly decouples asynchronous keyboard input from the synchronous datapath. |
| **8-bit PC** | Addresses up to 256 instructions — adequate for lab-scale programs. |

---

## Acknowledgements

- **Prof. Mainak Chaudhuri** — course instructor, CS220, IIT Kanpur.
- Lab infrastructure and FPGA boards provided by the CS220 course staff.
