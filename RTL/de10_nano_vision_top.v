`timescale 1ns / 1ps

module de10_nano_vision_top (
    input  wire        FPGA_CLK1_50, // 50MHz oscillator (PIN_V11)
    input  wire [0:0]  KEY,          // Pushbutton Reset (PIN_AH17)
    
    // On-Board Green User LEDs
    output wire [3:0]  LED,          // LED[0]=PIN_W15, LED[1]=PIN_AA24, LED[2]=PIN_V16, LED[3]=PIN_V15
    
    // ADV7513 I2C Config Lines
    output wire        HDMI_I2C_SCL, // PIN_U10
    inout  wire        HDMI_I2C_SDA, // PIN_AA4
    
    // ADV7513 HDMI Interface (24-bit RGB TrueColor)
    output wire        HDMI_TX_CLK,  // PIN_AG5
    output wire        HDMI_TX_DE,   // PIN_AD19
    output wire        HDMI_TX_HS,   // PIN_T8
    output wire        HDMI_TX_VS,   // PIN_V13
    output wire [23:0] HDMI_TX_D     // [23:16]=Red, [15:8]=Green, [7:0]=Blue
);

    wire sys_rst_n = KEY[0];

    // ---------------------------------------------------------
    // 1. Wake up the ADV7513 HDMI Transmitter via I2C
    // ---------------------------------------------------------
    wire hdmi_ready;
    wire i2c_ack_err;

    i2c_adv7513_config u_hdmi_i2c (
        .clk(FPGA_CLK1_50),
        .rst_n(sys_rst_n),
        .i2c_scl(HDMI_I2C_SCL),
        .i2c_sda(HDMI_I2C_SDA),
        .config_done(hdmi_ready),
        .ack_error(i2c_ack_err)
    );

    // ---------------------------------------------------------
    // 2. Internal Camera Emulator
    // ---------------------------------------------------------
    wire       emu_pclk;
    wire       emu_href;
    wire       emu_vsync;
    wire [7:0] emu_pixel;

    camera_emulator u_camera_sim (
        .clk_50m(FPGA_CLK1_50),
        .rst_n(sys_rst_n),
        .cam_pclk(emu_pclk),
        .cam_href(emu_href),
        .cam_vsync(emu_vsync),
        .cam_data(emu_pixel)
    );

    // ---------------------------------------------------------
    // 3. Real Hardware Sobel Edge & Defect Core
    // ---------------------------------------------------------
    wire       sobel_href;
    wire       sobel_vsync;
    wire [7:0] edge_data;
    wire       defect_trigger;

    sobel_filter #(
        .IMG_WIDTH(640),
        .THRESHOLD(8'd85)
    ) u_sobel (
        .clk(emu_pclk),
        .rst_n(sys_rst_n),
        .in_href(emu_href),
        .in_vsync(emu_vsync),
        .in_pixel(emu_pixel),
        .out_href(sobel_href),
        .out_vsync(sobel_vsync),
        .out_pixel(edge_data),
        .defect_flag(defect_trigger)
    );

    // ---------------------------------------------------------
    // 4. VESA Standard 640x480 Sync Generator
    // ---------------------------------------------------------
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge emu_pclk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == 10'd799) begin
                h_cnt <= 10'd0;
                if (v_cnt == 10'd524)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // Standard VESA Active-Low Sync Pulses
    wire hsync_standard = ~((h_cnt >= (640 + 16)) && (h_cnt < (640 + 16 + 96)));
    wire vsync_standard = ~((v_cnt >= (480 + 10)) && (v_cnt < (480 + 10 + 2)));
    wire de_standard    = (h_cnt < 640) && (v_cnt < 480);

    // Clean active visible area: masks the left 4 pixels to eliminate line-buffer startup artifacts
    wire clean_display = de_standard && (h_cnt >= 10'd4) && (h_cnt < 10'd638) && (v_cnt >= 10'd2) && (v_cnt < 10'd478);

    // Center clock edge in the data eye
    assign HDMI_TX_CLK = ~emu_pclk;
    assign HDMI_TX_DE  = de_standard;
    assign HDMI_TX_HS  = hsync_standard;
    assign HDMI_TX_VS  = vsync_standard;

    // 24-bit TrueColor Output:
    // Defect Edge = Bright Neon Red: 24'hFF0000 (R=255, G=0, B=0)
    // Clean Background = Solid Pitch Black: 24'h000000 (R=0, G=0, B=0)
    assign HDMI_TX_D = (clean_display && (edge_data == 8'hFF)) ? 24'hFF0000 : 24'h000000;

    // ---------------------------------------------------------
    // 5. On-Board Diagnostic LEDs
    // ---------------------------------------------------------
    reg [25:0] hb_cnt;
    reg        heartbeat;
    always @(posedge FPGA_CLK1_50 or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            hb_cnt    <= 26'd0;
            heartbeat <= 1'b0;
        end else if (hb_cnt == 26'd24_999_999) begin
            hb_cnt    <= 26'd0;
            heartbeat <= ~heartbeat;
        end else begin
            hb_cnt <= hb_cnt + 1'b1;
        end
    end

    reg [21:0] defect_pulse_stretch;
    always @(posedge emu_pclk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            defect_pulse_stretch <= 22'd0;
        else if (defect_trigger)
            defect_pulse_stretch <= 22'd2_500_000;
        else if (defect_pulse_stretch > 0)
            defect_pulse_stretch <= defect_pulse_stretch - 1'b1;
    end

    assign LED[0] = heartbeat;                  // 1Hz Blink: Clock running
    assign LED[1] = emu_vsync;                  // 60Hz Shimmer: Video frames active
    assign LED[2] = hdmi_ready & ~i2c_ack_err;  // Solid ON: ADV7513 initialized & ACKed
    assign LED[3] = (defect_pulse_stretch > 0); // Solid ON: Sobel defect detected

endmodule
