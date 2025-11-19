module top #(
        parameter DATA_WIDTH = 8,
        parameter IMG_WIDTH  = 320
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

    // min9x9 #(
    //            .DATA_WIDTH(DATA_WIDTH),
    //            .IMG_WIDTH(IMG_WIDTH)
    //        ) u_min9x9 (
    //            .clk(clk),
    //            .rst_n(rst_n),
    //            .valid_in(valid_in),
    //            .r_in(r_in),
    //            .g_in(g_in),
    //            .b_in(b_in),
    //            .valid_out(valid_out),
    //            .dark_channel(dark_channel)
    //        );

    // DEBUG: Test single min3x3 on R channel
    min3x3 #(
               .DATA_WIDTH(DATA_WIDTH),
               .IMG_WIDTH(IMG_WIDTH)
           ) u_min3x3 (
               .clk(clk),
               .rst_n(rst_n),
               .valid_in(valid_in),
               .data_in(r_in),
               .valid_out(valid_out),
               .data_out(dark_channel)
           );

endmodule
