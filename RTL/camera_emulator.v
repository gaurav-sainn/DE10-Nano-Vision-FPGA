`timescale 1ns / 1ps

module camera_emulator (
    input  wire        clk_50m,      // 50MHz oscillator
    input  wire        rst_n,        // Active-low reset
    output reg         cam_pclk,     // Emulated 25MHz pixel clock
    output wire        cam_href,     // Horizontal line active
    output wire        cam_vsync,    // Vertical frame sync
    output reg  [7:0]  cam_data      // Pixel intensity (0-255)
);

    // 1. Generate 25MHz Pixel Clock from 50MHz oscillator
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n)
            cam_pclk <= 1'b0;
        else
            cam_pclk <= ~cam_pclk;
    end

    // 2. Standard 640x480 @ 60Hz Video Counters
    // Total line = 800 clocks, Total frame = 525 lines
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
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

    // Active Video Flags
    assign cam_href  = (h_cnt < 640) && (v_cnt < 480);
    assign cam_vsync = (v_cnt >= 490) && (v_cnt < 492);

    // 3. Animation Engine: Move a simulated PCB component across the screen
    reg [9:0] box_x;
    reg [9:0] box_y;
    reg       dir_x;
    reg       dir_y;

    // Update position once per frame (during VSYNC)
    wire frame_tick = (h_cnt == 0) && (v_cnt == 480);

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            box_x <= 10'd100;
            box_y <= 10'd100;
            dir_x <= 1'b1;
            dir_y <= 1'b1;
        end else if (frame_tick) begin
            // X movement & bounce (bounds: 50 to 450)
            if (dir_x) begin
                if (box_x >= 10'd450) begin
                    dir_x <= 1'b0;
                    box_x <= box_x - 10'd2;
                end else begin
                    box_x <= box_x + 10'd2;
                end
            end else begin
                if (box_x <= 10'd50) begin
                    dir_x <= 1'b1;
                    box_x <= box_x + 10'd2;
                end else begin
                    box_x <= box_x - 10'd2;
                end
            end

            // Y movement & bounce (bounds: 50 to 300)
            if (dir_y) begin
                if (box_y >= 10'd300) begin
                    dir_y <= 1'b0;
                    box_y <= box_y - 10'd1;
                end else begin
                    box_y <= box_y + 10'd1;
                end
            end else begin
                if (box_y <= 10'd50) begin
                    dir_y <= 1'b1;
                    box_y <= box_y + 10'd1;
                end else begin
                    box_y <= box_y - 10'd1;
                end
            end
        end
    end

    // 4. Generate Moving Object with a Simulated Defect (Solder bridge / notch)
    // Box dimensions: 120 pixels wide x 80 pixels tall
    wire in_box = (h_cnt >= box_x) && (h_cnt < box_x + 120) &&
                  (v_cnt >= box_y) && (v_cnt < box_y + 80);

    // Simulated component defect: an irregular protrusion / bridge on the edge
    wire in_defect_spur = (h_cnt >= box_x + 120) && (h_cnt < box_x + 145) &&
                         (v_cnt >= box_y + 30)  && (v_cnt < box_y + 45);

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            cam_data <= 8'd0;
        end else if (cam_href) begin
            if (in_box || in_defect_spur)
                cam_data <= 8'd220; // High brightness (Component / Defect)
            else
                cam_data <= 8'd30;  // Dark background (PCB Board substrate)
        end else begin
            cam_data <= 8'd0;
        end
    end

endmodule
