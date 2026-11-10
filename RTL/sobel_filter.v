module sobel_filter #(
    parameter IMG_WIDTH  = 640,
    parameter THRESHOLD  = 8'd90
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_href,
    input  wire       in_vsync,
    input  wire [7:0] in_pixel,     // Grayscale input
    output reg        out_href,
    output reg        out_vsync,
    output reg  [7:0] out_pixel,    // Thresholded binary/intensity output
    output reg        defect_flag   // High if edge density indicates defect
);

    wire [7:0] l0, l1, l2;

    line_buffer #(
        .DATA_WIDTH(8),
        .IMG_WIDTH(IMG_WIDTH)
    ) u_buf (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(in_href),
        .din(in_pixel),
        .line0(l0),
        .line1(l1),
        .line2(l2)
    );

    // 3x3 Window Registers
    reg [7:0] p11, p12, p13;
    reg [7:0] p21, p22, p23;
    reg [7:0] p31, p32, p33;

    // Shift registers for control signals to align with calculation latency (3 clock cycles)
    reg [2:0] href_pipe;
    reg [2:0] vsync_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p11 <= 8'd0; p12 <= 8'd0; p13 <= 8'd0;
            p21 <= 8'd0; p22 <= 8'd0; p23 <= 8'd0;
            p31 <= 8'd0; p32 <= 8'd0; p33 <= 8'd0;
            href_pipe <= 3'b0;
            vsync_pipe <= 3'b0;
        end else if (in_href) begin
            // Shift 3x3 matrix right to left
            p11 <= p12; p12 <= p13; p13 <= l0;
            p21 <= p22; p22 <= p23; p23 <= l1;
            p31 <= p32; p32 <= p33; p33 <= l2;

            href_pipe  <= {href_pipe[1:0], in_href};
            vsync_pipe <= {vsync_pipe[1:0], in_vsync};
        end else begin
            href_pipe  <= {href_pipe[1:0], 1'b0};
            vsync_pipe <= {vsync_pipe[1:0], in_vsync};
        end
    end

    // Pipeline Stage 1: Sobel Kernels
    // Gx: [ -1  0  +1 ]   Gy: [ -1  -2  -1 ]
    //     [ -2  0  +2 ]       [  0   0   0 ]
    //     [ -1  0  +1 ]       [ +1  +2  +1 ]
    reg signed [10:0] gx;
    reg signed [10:0] gy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx <= 11'sd0;
            gy <= 11'sd0;
        end else begin
            gx <= ($signed({3'b0, p13}) + $signed({2'b0, p23, 1'b0}) + $signed({3'b0, p33})) -
                  ($signed({3'b0, p11}) + $signed({2'b0, p21, 1'b0}) + $signed({3'b0, p31}));

            gy <= ($signed({3'b0, p31}) + $signed({2'b0, p32, 1'b0}) + $signed({3'b0, p33})) -
                  ($signed({3'b0, p11}) + $signed({2'b0, p12, 1'b0}) + $signed({3'b0, p13}));
        end
    end

    // Pipeline Stage 2: Absolute Value & Manhattan Magnitude (|Gx| + |Gy|)
    wire [10:0] abs_gx = (gx < 0) ? -gx : gx;
    wire [10:0] abs_gy = (gy < 0) ? -gy : gy;
    reg  [10:0] mag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mag <= 11'd0;
        end else begin
            mag <= abs_gx + abs_gy;
        end
    end

    // Pipeline Stage 3: Threshold and Defect Detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_pixel   <= 8'd0;
            defect_flag <= 1'b0;
            out_href    <= 1'b0;
            out_vsync   <= 1'b0;
        end else begin
            out_href  <= href_pipe[2];
            out_vsync <= vsync_pipe[2];

            if (mag > {3'b0, THRESHOLD}) begin
                out_pixel   <= 8'hFF; // Highlighted Defect Edge (White)
                defect_flag <= 1'b1;
            end else begin
                out_pixel   <= 8'h00; // Background (Black)
                defect_flag <= 1'b0;
            end
        end
    end

endmodule