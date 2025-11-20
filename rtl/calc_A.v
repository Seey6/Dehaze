module calc_A #(
        parameter DATA_WIDTH = 8,
        parameter IMG_WIDTH  = 640,
        parameter IMG_HEIGHT = 480
    )(
        input  wire                  clk,
        input  wire                  rst_n,
        input  wire                  vsync,
        input  wire                  hsync,
        input  wire                  valid_in,
        input  wire [DATA_WIDTH-1:0] r_in,
        input  wire [DATA_WIDTH-1:0] g_in,
        input  wire [DATA_WIDTH-1:0] b_in,
        output reg  [DATA_WIDTH-1:0] A_val,
        output                       valid_out
    );


    // 图像同步
    reg [11:0] x_cnt;
    reg [11:0] y_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end
        else begin
            if (vsync) begin
                x_cnt <= 0;
                y_cnt <= 0;
            end
            else if (hsync) begin
                x_cnt <= 0;
                // 行同步时不许写入数据
                // if (valid_in) begin
                //     y_cnt <= y_cnt + 1;
                // end
            end
            else if (valid_in) begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

    reg hsync_d;
    wire hsync_rise = hsync && !hsync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            hsync_d <= 0;
        else
            hsync_d <= hsync;
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_cnt <= 0;
        end
        else begin
            if (vsync)
                y_cnt <= 0;
            else if (hsync_rise)
                y_cnt <= y_cnt + 1;
        end
    end

    // vsync信号的延迟，用于同步输出
    reg [16:0] vsync_pipe;
    assign valid_out = vsync_pipe[16];
    reg vsync_clear;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || vsync_clear) begin
            vsync_pipe <= 0;
            vsync_clear <= 0;
        end
        else begin
            vsync_pipe <= {vsync_pipe[15:0], vsync};
        end
    end


    // downscale 输入给9x9min
    wire keep_pixel = (x_cnt[0] == 1'b0) && (y_cnt[0] == 1'b0);
    wire ds_valid_pre = valid_in && keep_pixel;

    localparam DS_WIDTH = IMG_WIDTH / 2;

    wire [DATA_WIDTH-1:0] dark_channel_out;
    wire valid_out_min9x9;

    min9x9 #(
               .DATA_WIDTH(DATA_WIDTH),
               .IMG_WIDTH(DS_WIDTH)
           ) u_min9x9 (
               .clk(clk),
               .rst_n(rst_n),
               .valid_in(ds_valid_pre),
               .r_in(r_in),
               .g_in(g_in),
               .b_in(b_in),
               .valid_out(valid_out_min9x9),
               .dark_channel(dark_channel_out)
           );


    // A值的计算
    reg [DATA_WIDTH-1:0] current_max;

    localparam MIN_A_THRESHOLD = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_max <= 0;
            A_val <= MIN_A_THRESHOLD; // Default safe value
        end
        else begin
            if (vsync_pipe[15]) begin
                if (current_max < MIN_A_THRESHOLD)
                    A_val <= MIN_A_THRESHOLD;
                else
                    A_val <= current_max;
                current_max <= 0;
                vsync_clear <= 1;
            end
            else if (valid_out_min9x9) begin
                if (dark_channel_out > current_max)
                    current_max <= dark_channel_out;
            end
        end
    end

endmodule
