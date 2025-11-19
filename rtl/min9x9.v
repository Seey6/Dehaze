module min9x9 #(
        parameter DATA_WIDTH = 8,
        parameter IMG_WIDTH  = 320 // Default to downsampled width
    )(
        input  wire                  clk,
        input  wire                  rst_n,
        input  wire                  valid_in,
        input  wire [DATA_WIDTH-1:0] r_in,
        input  wire [DATA_WIDTH-1:0] g_in,
        input  wire [DATA_WIDTH-1:0] b_in,
        output wire                  valid_out,
        output wire [DATA_WIDTH-1:0] dark_channel
    );

    // Internal signals for R channel
    wire [DATA_WIDTH-1:0] r_s1, r_s2, r_s3, r_s4;
    wire v_r1, v_r2, v_r3, v_r4;

    // Internal signals for G channel
    wire [DATA_WIDTH-1:0] g_s1, g_s2, g_s3, g_s4;
    wire v_g1, v_g2, v_g3;

    // Internal signals for B channel
    wire [DATA_WIDTH-1:0] b_s1, b_s2, b_s3, b_s4;
    wire v_b1, v_b2, v_b3;

    // ---------------------------------------------------------
    // R Channel Cascade
    // ---------------------------------------------------------
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_r1 (
               .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(r_in), .valid_out(v_r1), .data_out(r_s1)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_r2 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_r1), .data_in(r_s1), .valid_out(v_r2), .data_out(r_s2)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_r3 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_r2), .data_in(r_s2), .valid_out(v_r3), .data_out(r_s3)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_r4 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_r3), .data_in(r_s3), .valid_out(v_r4), .data_out(r_s4)
           );

    // ---------------------------------------------------------
    // G Channel Cascade
    // ---------------------------------------------------------
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_g1 (
               .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(g_in), .valid_out(v_g1), .data_out(g_s1)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_g2 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_g1), .data_in(g_s1), .valid_out(v_g2), .data_out(g_s2)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_g3 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_g2), .data_in(g_s2), .valid_out(v_g3), .data_out(g_s3)
           );
    /* verilator lint_off PINCONNECTEMPTY */
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_g4 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_g3), .data_in(g_s3), .valid_out(), .data_out(g_s4)
           );
    /* verilator lint_on PINCONNECTEMPTY */

    // ---------------------------------------------------------
    // B Channel Cascade
    // ---------------------------------------------------------
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_b1 (
               .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(b_in), .valid_out(v_b1), .data_out(b_s1)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_b2 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_b1), .data_in(b_s1), .valid_out(v_b2), .data_out(b_s2)
           );
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_b3 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_b2), .data_in(b_s2), .valid_out(v_b3), .data_out(b_s3)
           );
    /* verilator lint_off PINCONNECTEMPTY */
    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_b4 (
               .clk(clk), .rst_n(rst_n), .valid_in(v_b3), .data_in(b_s3), .valid_out(), .data_out(b_s4)
           );
    /* verilator lint_on PINCONNECTEMPTY */

    // ---------------------------------------------------------
    // Final Dark Channel Calculation (Min of R, G, B)
    // ---------------------------------------------------------
    // We assume all channels have same latency and valid signals are aligned.
    // Using v_r4 as the master valid.

    reg [DATA_WIDTH-1:0] min_rgb;
    reg                  valid_final;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_rgb <= 0;
            valid_final <= 0;
        end
        else begin
            valid_final <= v_r4; // Latency match
            if (v_r4) begin
                if (r_s4 <= g_s4 && r_s4 <= b_s4)
                    min_rgb <= r_s4;
                else if (g_s4 <= r_s4 && g_s4 <= b_s4)
                    min_rgb <= g_s4;
                else
                    min_rgb <= b_s4;
            end
        end
    end

    assign valid_out = valid_final;
    assign dark_channel = min_rgb;

endmodule
