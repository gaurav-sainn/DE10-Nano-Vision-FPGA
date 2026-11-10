`timescale 1ns / 1ps

module tb_de10_nano_vision_top;

    // -------------------------------------------------------------
    // Inputs to Top-Level
    // -------------------------------------------------------------
    reg        clk_50m;
    reg  [0:0] key_reset;

    // -------------------------------------------------------------
    // Inouts and Bidirectional Lines
    // -------------------------------------------------------------
    wire       hdmi_i2c_scl;
    wire       hdmi_i2c_sda;
    pullup(hdmi_i2c_sda); // Emulate external pull-up resistor on I2C SDA
    pullup(hdmi_i2c_scl);

    // -------------------------------------------------------------
    // Outputs from Top-Level
    // -------------------------------------------------------------
    wire [3:0]  led;
    wire        hdmi_clk;
    wire        hdmi_de;
    wire        hdmi_hs;
    wire        hdmi_vs;
    wire [23:0] hdmi_data;

    // -------------------------------------------------------------
    // Instantiate Top-Level Entity (Device Under Test)
    // -------------------------------------------------------------
    de10_nano_vision_top dut (
        .FPGA_CLK1_50(clk_50m),
        .KEY(key_reset),
        .LED(led),
        .HDMI_I2C_SCL(hdmi_i2c_scl),
        .HDMI_I2C_SDA(hdmi_i2c_sda),
        .HDMI_TX_CLK(hdmi_clk),
        .HDMI_TX_DE(hdmi_de),
        .HDMI_TX_HS(hdmi_hs),
        .HDMI_TX_VS(hdmi_vs),
        .HDMI_TX_D(hdmi_data)
    );

    // -------------------------------------------------------------
    // 50MHz System Clock Generation (Period = 20ns)
    // -------------------------------------------------------------
    initial clk_50m = 1'b0;
    always #10 clk_50m = ~clk_50m;

    // -------------------------------------------------------------
    // Simulation Stimulus & Sequence
    // -------------------------------------------------------------
    initial begin
        $display("=====================================================");
        $display(" Starting DE10-Nano Vision RTL Simulation (Questa)   ");
        $display("=====================================================");

        // 1. Assert Reset (Active-Low)
        key_reset = 1'b0;

        // 2. Hold reset for 200ns (10 clock cycles)
        #200;
        @(posedge clk_50m);
        key_reset = 1'b1; // Release reset
        $display("[Time %0t ns] Reset released. System running...", $time);

        // 3. Let the hardware pipeline run for several video scan lines
        // 1 video scanline (800 pixels @ 25MHz) takes ~32,000 ns (32 us)
        // 5 scanlines takes ~160,000 ns (160 us)
        #200000;

        $display("=====================================================");
        $display(" Simulation finished successfully!                   ");
        $display(" Signals and waveforms available in Wave window.     ");
        $display("=====================================================");
        $stop;
    end

    // -------------------------------------------------------------
    // Real-Time HDMI & Defect Output Logger
    // -------------------------------------------------------------
    always @(posedge hdmi_clk) begin
        if (hdmi_de && (hdmi_data == 24'hFF0000)) begin
            $display("[Time %0t ns] RED EDGE/DEFECT PIXEL on HDMI! Data = 0x%06X | LED[3] Defect Flag = %b", 
                     $time, hdmi_data, led[3]);
        end
    end

endmodule
