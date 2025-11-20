module top #(
        parameter DATA_WIDTH = 8,
        parameter IMG_WIDTH  = 320,
        parameter IMG_HEIGHT = 240
    )(
        input  wire                  clk,
        input  wire                  rst_n,
        input  wire                  vsync,
        input  wire                  hsync,
        input  wire                  valid_in,
        input  wire [DATA_WIDTH-1:0] r_in,
        input  wire [DATA_WIDTH-1:0] g_in,
        input  wire [DATA_WIDTH-1:0] b_in,
        output wire [DATA_WIDTH-1:0] A_val,
        output                       valid_out
    );

    calc_A #(
               .DATA_WIDTH(DATA_WIDTH),
               .IMG_WIDTH(IMG_WIDTH),
               .IMG_HEIGHT(IMG_HEIGHT)
           ) u_calc_A (
               .clk(clk),
               .rst_n(rst_n),
               .vsync(vsync),
               .hsync(hsync),
               .valid_in(valid_in),
               .r_in(r_in),
               .g_in(g_in),
               .b_in(b_in),
               .A_val(A_val),
               .valid_out(valid_out)
           );

endmodule
