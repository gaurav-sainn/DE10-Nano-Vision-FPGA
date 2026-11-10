`timescale 1ns / 1ps

module i2c_adv7513_config (
    input  wire clk,         // 50MHz System Clock (PIN_V11)
    input  wire rst_n,       // Active-Low Reset (KEY[0])
    output reg  i2c_scl,     // I2C Clock to ADV7513 (PIN_U10)
    inout  wire i2c_sda,     // I2C Data to ADV7513  (PIN_AA4)
    output reg  config_done, // High when all registers are written
    output reg  ack_error    // High if ADV7513 failed to ACK
);

    // -------------------------------------------------------------
    // 1. 200ms Power-On Stabilization Delay
    // 10,000,000 cycles at 50MHz = 200ms
    // -------------------------------------------------------------
    reg [23:0] delay_cnt;
    reg        delay_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt  <= 24'd0;
            delay_done <= 1'b0;
        end else if (delay_cnt == 24'd10_000_000) begin
            delay_done <= 1'b1;
        end else begin
            delay_cnt  <= delay_cnt + 1'b1;
        end
    end

    // -------------------------------------------------------------
    // 2. 100kHz I2C Clock Divider (500 cycles of 50MHz per bit)
    // -------------------------------------------------------------
    reg [8:0] tick;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 9'd0;
        end else if (delay_done && !config_done) begin
            if (tick == 9'd499)
                tick <= 9'd0;
            else
                tick <= tick + 1'b1;
        end else begin
            tick <= 9'd0;
        end
    end

    wire t_0   = (tick == 9'd0);   // Change data while SCL is LOW
    wire t_125 = (tick == 9'd125); // SCL rises HIGH
    wire t_250 = (tick == 9'd250); // Sample data while SCL is HIGH
    wire t_375 = (tick == 9'd375); // SCL falls LOW

    // -------------------------------------------------------------
    // 3. Synthesizable Lookup Table (Case Statement)
    // Analog Devices AN-1270 & Terasic Mandatory ADV7513 Registers
    // -------------------------------------------------------------
    localparam TOTAL_COMMANDS = 16;
    reg [4:0]  cmd_idx;
    reg [15:0] rom_data;

    always @(*) begin
        case (cmd_idx)
            5'd0:  rom_data = 16'h15_00; // 24-bit RGB 4:4:4
            5'd1:  rom_data = 16'h16_30; // 8-bit RGB 4:4:4, Style 1 (Active)
            5'd2:  rom_data = 16'h18_46; // CSC Disable
            5'd3:  rom_data = 16'h40_80; // General control
            5'd4:  rom_data = 16'h41_10; // Power up transmitter (clear power-down bit 6)
            5'd5:  rom_data = 16'h48_08; // Video format: standard
            5'd6:  rom_data = 16'h55_00; // Set RGB in AVI InfoFrame
            5'd7:  rom_data = 16'h56_08; // Active format aspect ratio
            5'd8:  rom_data = 16'h98_03; // MANDATORY FIX: Must be 0x03
            5'd9:  rom_data = 16'h9A_E0; // MANDATORY FIX: Must be 0xE0
            5'd10: rom_data = 16'h9C_30; // MANDATORY FIX: Must be 0x30
            5'd11: rom_data = 16'h9D_61; // MANDATORY FIX: Must be 0x61
            5'd12: rom_data = 16'hA2_A4; // MANDATORY FIX: Must be 0xA4
            5'd13: rom_data = 16'hA3_A4; // MANDATORY FIX: Must be 0xA4
            5'd14: rom_data = 16'hE0_D0; // MANDATORY FIX: Must be 0xD0
            5'd15: rom_data = 16'hAF_06; // HDCP disable, select HDMI mode
            default: rom_data = 16'h00_00;
        endcase
    end

    wire [7:0] dev_addr = 8'h72;               // ADV7513 I2C Address (0x39 << 1) + Write(0)
    wire [7:0] reg_addr = rom_data[15:8];       // Subaddress
    wire [7:0] reg_data = rom_data[7:0];        // Register Value

    // -------------------------------------------------------------
    // 4. Deterministic 30-Step I2C Transaction Sequencer
    // -------------------------------------------------------------
    // Step 0: START
    // Step 1..8: Device Address (0x72)
    // Step 9: ACK 1
    // Step 10..17: Subaddress
    // Step 18: ACK 2
    // Step 19..26: Data
    // Step 27: ACK 3
    // Step 28: STOP
    // Step 29: Inter-packet Pause
    reg [4:0] step;
    reg       sda_out;
    reg       sda_oe; // 1 = drive sda_out, 0 = release (tri-state for ACK)

    assign i2c_sda = sda_oe ? sda_out : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step        <= 5'd0;
            cmd_idx     <= 5'd0;
            i2c_scl     <= 1'b1;
            sda_out     <= 1'b1;
            sda_oe      <= 1'b1;
            config_done <= 1'b0;
            ack_error   <= 1'b0;
        end else if (delay_done && !config_done) begin

            // Phase 0: SCL is LOW -> Change SDA data safely
            if (t_0) begin
                case (step)
                    // START preparation: SDA high while SCL is high
                    5'd0: begin
                        i2c_scl <= 1'b1;
                        sda_oe  <= 1'b1;
                        sda_out <= 1'b1;
                    end

                    // Send Device Address bits (0x72)
                    5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b1;
                        sda_out <= dev_addr[8 - step];
                    end

                    // ACK 1: Release SDA
                    5'd9: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b0;
                    end

                    // Send Subaddress bits
                    5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15, 5'd16, 5'd17: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b1;
                        sda_out <= reg_addr[17 - step];
                    end

                    // ACK 2: Release SDA
                    5'd18: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b0;
                    end

                    // Send Data bits
                    5'd19, 5'd20, 5'd21, 5'd22, 5'd23, 5'd24, 5'd25, 5'd26: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b1;
                        sda_out <= reg_data[26 - step];
                    end

                    // ACK 3: Release SDA
                    5'd27: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b0;
                    end

                    // STOP preparation: pull SDA low while SCL is low
                    5'd28: begin
                        i2c_scl <= 1'b0;
                        sda_oe  <= 1'b1;
                        sda_out <= 1'b0;
                    end

                    // Pause
                    5'd29: begin
                        i2c_scl <= 1'b1;
                        sda_oe  <= 1'b1;
                        sda_out <= 1'b1;
                    end
                endcase
            end

            // Phase 1: SCL goes HIGH
            else if (t_125) begin
                if (step >= 5'd1 && step <= 5'd28)
                    i2c_scl <= 1'b1;
            end

            // Phase 2: SCL is HIGH -> Generate START / STOP / Sample ACK
            else if (t_250) begin
                case (step)
                    // START: pull SDA low while SCL is HIGH
                    5'd0: begin
                        sda_out <= 1'b0;
                    end

                    // Sample ACK 1
                    5'd9: begin
                        if (i2c_sda != 1'b0)
                            ack_error <= 1'b1;
                    end

                    // Sample ACK 2
                    5'd18: begin
                        if (i2c_sda != 1'b0)
                            ack_error <= 1'b1;
                    end

                    // Sample ACK 3
                    5'd27: begin
                        if (i2c_sda != 1'b0)
                            ack_error <= 1'b1;
                    end

                    // STOP: pull SDA high while SCL is HIGH
                    5'd28: begin
                        sda_out <= 1'b1;
                    end

                    default: ;
                endcase
            end

            // Phase 3: SCL goes LOW (for data bits and ACKs)
            else if (t_375) begin
                if (step <= 5'd27)
                    i2c_scl <= 1'b0;

                // Advance step at end of bit period
                if (step == 5'd29) begin
                    step <= 5'd0;
                    if (cmd_idx == TOTAL_COMMANDS - 1)
                        config_done <= 1'b1;
                    else
                        cmd_idx <= cmd_idx + 1'b1;
                end else begin
                    step <= step + 1'b1;
                end
            end
        end else if (config_done) begin
            i2c_scl <= 1'b1;
            sda_oe  <= 1'b0;
        end
    end

endmodule
