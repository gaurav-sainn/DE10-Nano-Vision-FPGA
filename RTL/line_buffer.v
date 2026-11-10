module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 640
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  pixel_valid,
    input  wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] line0, // Row n - 2
    output wire [DATA_WIDTH-1:0] line1, // Row n - 1
    output wire [DATA_WIDTH-1:0] line2  // Row n (Current)
);

    reg [9:0] wr_ptr;
    
    // Line buffer memory blocks inferred as M10K blocks
    (* ramstyle = "M10K" *) reg [DATA_WIDTH-1:0] ram_line0 [0:IMG_WIDTH-1];
    (* ramstyle = "M10K" *) reg [DATA_WIDTH-1:0] ram_line1 [0:IMG_WIDTH-1];

    reg [DATA_WIDTH-1:0] r_line0;
    reg [DATA_WIDTH-1:0] r_line1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 10'd0;
            r_line0 <= {DATA_WIDTH{1'b0}};
            r_line1 <= {DATA_WIDTH{1'b0}};
        end else if (pixel_valid) begin
            // Read older scan lines
            r_line0 <= ram_line0[wr_ptr];
            r_line1 <= ram_line1[wr_ptr];

            // Cascade write current input into buffers
            ram_line0[wr_ptr] <= ram_line1[wr_ptr];
            ram_line1[wr_ptr] <= din;

            if (wr_ptr == IMG_WIDTH - 1)
                wr_ptr <= 10'd0;
            else
                wr_ptr <= wr_ptr + 10'd1;
        end
    end

    assign line0 = r_line0;
    assign line1 = r_line1;
    assign line2 = din;

endmodule