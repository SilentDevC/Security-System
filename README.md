# Security-System 🔒
A Verilog HDL implementation of a digital security system providing coded access control to a secured area.

![GitHub License](https://img.shields.io/github/license/SilentDevC/Security-System?style=for-the-badge&color=blue)
![GitHub Language](https://img.shields.io/github/languages/top/SilentDevC/Security-System?style=for-the-badge&color=orange)

## 📝 Description
This project presents a digital security system implemented in Verilog HDL. The system requires a user to enter a 4-digit code via a keypad to gain access to a secured area. It started as a port of a textbook VHDL reference design and evolved into a full redesign — more on that below.

## ⚠️ Design Evolution — Why I Rebuilt This

The original design, taken from a digital systems textbook, uses an **asynchronous timing-based approach**. The sequencing of operations is controlled entirely by one-shot timers — two of them chained together — instead of a proper controller. The idea is that each one-shot fires after a fixed pulse width, giving the downstream logic "enough time" to settle before the next stage latches data.

In practice, this turned out to be fragile. The timing between the one-shots and the data signals is not guaranteed — if the pulse width is too short, the shift registers latch garbage. If it's too long, the system is just slow for no reason. There's no way to formally verify that the timing is correct without running a simulation and eyeballing waveforms. That's not a great foundation for anything you'd want to call a security system.

After going through the full debugging cycle on the original design — tracking down race conditions, wrong clock edges, and uninitialized signals in simulation — I decided the right move was to rebuild it properly rather than keep patching a fundamentally awkward architecture.

The new version uses a **synchronous FSM/Datapath architecture**:

- A **control unit (FSM)** drives the sequencing explicitly through defined states
- A **datapath** handles all the data movement — BCD encoding, register latching, comparison, alarm shifting
- Everything is clocked on a single system clock — no one-shots, no asynchronous timing, no pulse widths to tune
- Behavior is deterministic and formally verifiable

This is how modern synchronous digital systems are designed, and it's a much cleaner fit for FPGA implementation. The FSM also makes the system easier to extend — adding a lockout after N wrong attempts, for example, is just a few extra states.

The original async implementation is preserved in the repo for reference, since going through it was genuinely useful for understanding why the synchronous approach is better.

## 🔄 System Flow

The system follows this sequence:

1. Initialize all registers
2. Wait for `#` (Enter) to be pressed — this loads the code selection logic
3. User enters a digit via keypad
4. The digit is BCD encoded and latched alongside the expected digit from the DIP switches
5. Comparator checks if they match
6. On a match: alarm shift register shifts by one, code selection advances to the next digit
7. On a mismatch: code selection resets, user must start over from digit 1
8. After 4 correct digits in sequence: alarm output goes high

## 📐 Architecture

### Original design (async, timing-based)
```
Keypad → BCD Encoder → Shift Reg A ──┐
                                      ├─→ Comparator → Shift Reg C → Alarm
Code Selection → Shift Reg B ─────────┘
     ↑                    ↑
  OR gate → OneShot A → OneShot B
                ↑
          External Clock
```

### Redesigned (FSM/Datapath)
```
              ┌─────────────────────────────┐
              │         Control Unit        │
              │            (FSM)            │
              │  IDLE → INIT → WAIT_KEY →   │
              │  ENCODE → LATCH → COMPARE → │
              │  ADVANCE / RESET → ALARM    │
              └────────────┬────────────────┘
                           │ control signals
              ┌────────────▼────────────────┐
              │           Datapath          │
              │  BCD Encoder                │
              │  Shift Reg A (key input)    │
              │  Shift Reg B (DIP code)     │
              │  Comparator                 │
              │  Code Selection Logic       │
              │  Shift Reg C (alarm)        │
              └─────────────────────────────┘
```

## 🌟 Features

- 4-digit coded access control via 10-key keypad
- DIP switch-settable secret code
- Full reset on wrong digit entry — no partial credit
- Synchronous single-clock design (FSM version)
- Alarm output via serial shift register
- Verified via ModelSim testbench simulation
- Synthesizable on Xilinx Spartan FPGA

## 💻 Tech Stack

- **Hardware Description Language**: Verilog HDL
- **Simulation**: ModelSim / Icarus Verilog + GTKWave
- **Target Hardware**: Xilinx Spartan FPGA (Vivado toolchain)

## 🚀 Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/SilentDevC/Security-System.git
    cd Security-System
    ```

2. Choose a toolchain:
    - **Icarus Verilog + GTKWave** — free, great for simulation
    - **ModelSim** — what this was developed and debugged on
    - **Vivado** — for synthesis and FPGA deployment

## 🛠️ How to Use

### Simulation (Icarus Verilog + GTKWave)

```bash
iverilog -o secsys_sim secsys.v secsys_tb.v
vvp secsys_sim
gtkwave dump.vcd
```

### Testbench structure

```verilog
module testsecuresys;
    reg [9:0] key;
    reg enter;
    reg clk;
    reg res;
    reg [3:0] dip1, dip2, dip3, dip4;
    wire sysout;

    secsys test (.key(key), .enter(enter), .clk(clk), .res(res),
                 .dip1(dip1), .dip2(dip2), .dip3(dip3), .dip4(dip4),
                 .sysout(sysout));

    localparam clockcycle = 10;
    always #(clockcycle/2) clk = ~clk;

    initial begin
        // set secret code via DIP switches
        dip1 = 4'h4; dip2 = 4'h5; dip3 = 4'h6; dip4 = 4'h7;

        res = 0; #20 res = 1;

        // press # to initialize
        #10 enter = 1; #10 enter = 0;

        // enter digits...
    end
endmodule
```

### Synthesis (Spartan FPGA via Vivado)

1. Add `secsys.v` as the top-level source
2. Create a constraints file (`.xdc`) for pin assignments and clock
3. Run synthesis → implementation → bitstream generation
4. Program the board and test with physical keypad and LEDs

## 📂 Project Structure

```
Security-System/
├── README.md
├── LICENSE
└── secsys.v        ← all modules + testbench
```

## 🚧 Current Status

The FSM/Datapath redesign is actively in progress. Right now I am working through:

- **Block diagram** — clean separation of datapath components and control signals, figuring out exactly what wires go where and which signals are combinational vs sequential
- **Moore FSM design** — state diagram with clearly defined states, transition conditions, and output signals (y1..yn) for each state
- **Schematic implementation** — drawing the full system schematic showing the FSM control unit, datapath components, and all interconnections

The async implementation in the repo is the reference point for what the system is supposed to do. The FSM version will replace it once the design is finalized and verified in simulation.

## 🤝 Contributing

Contributions welcome. Fork the repo, create a branch, make your changes, and open a pull request.

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
