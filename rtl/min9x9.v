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

    reg [DATA_WIDTH-1:0] rgb_min;
    reg valid_out_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_min <= 0;
            valid_out_reg <= 0;
        end
        else begin
            valid_out_reg <= valid_in;
            if (valid_in) begin
                if (r_in <= g_in && r_in <= b_in)
                    rgb_min <= r_in;
                else if (g_in <= r_in && g_in <= b_in)
                    rgb_min <= g_in;
                else
                    rgb_min <= b_in;
            end
        end
    end


    wire [DATA_WIDTH-1:0] r_s1, r_s2, r_s3, r_s4;
    wire v_r1, v_r2, v_r3, v_r4;

    min3x3 #(.DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH)) min3_r1 (
               .clk(clk), .rst_n(rst_n), .valid_in(valid_out_reg), .data_in(rgb_min), .valid_out(v_r1), .data_out(r_s1)
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

    assign valid_out = v_r4;
    assign dark_channel = r_s4;

endmodule
