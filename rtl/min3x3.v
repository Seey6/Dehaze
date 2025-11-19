module min3x3 #(
        parameter DATA_WIDTH = 8,
        parameter IMG_WIDTH  = 640
    )(
        input  wire                  clk,
        input  wire                  rst_n,
        input  wire                  valid_in,
        input  wire [DATA_WIDTH-1:0] data_in,
        output reg                   valid_out,
        output reg  [DATA_WIDTH-1:0] data_out
    );

    // Line buffers
    wire [DATA_WIDTH-1:0] lb1_out;
    wire [DATA_WIDTH-1:0] lb2_out;

    // We need to write to LB1 when valid_in is high.
    // LB1 input is data_in.
    // LB2 input is LB1 output.
    // But wait, if we chain them:
    // data_in -> LB1 -> LB2
    // Then we have:
    // row0 = data_in (current)
    // row1 = LB1_out (previous row)
    // row2 = LB2_out (row before previous)

    // We need to enable LBs only when valid_in is high?
    // Assuming continuous stream or valid_in acts as write enable.

    line_buf #(
                 .DATA_WIDTH(DATA_WIDTH),
                 .DEPTH(IMG_WIDTH-1)
             ) lb1 (
                 .clk(clk),
                 .rst_n(rst_n),
                 .wen(valid_in),
                 .din(data_in),
                 .dout(lb1_out)
             );

    line_buf #(
                 .DATA_WIDTH(DATA_WIDTH),
                 .DEPTH(IMG_WIDTH-1)
             ) lb2 (
                 .clk(clk),
                 .rst_n(rst_n),
                 .wen(valid_in),
                 .din(lb1_out),
                 .dout(lb2_out)
             );
    // 3x3 Window Registers
    // We need to store the last 3 pixels of each row.
    reg [DATA_WIDTH-1:0] r0_0, r0_1, r0_2;
    reg [DATA_WIDTH-1:0] r1_0, r1_1, r1_2;
    reg [DATA_WIDTH-1:0] r2_0, r2_1, r2_2;

    // Valid pipeline
    // We need to delay valid signal to match the window latency.
    // Latency:
    // Line buffers fill up: 2 rows.
    // Window fills up: 2 more pixels (since we need 3 columns).
    // Actually, once we have 2 rows + 3 pixels, we can output.
    // But for a stream, we usually output aligned with the center or just delayed.
    // Let's count valid pixels to handle startup.
    reg [2:0] valid_pipe;

    reg [15:0] pixel_cnt;
    reg        process_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0_0 <= 0;
            r0_1 <= 0;
            r0_2 <= 0;
            r1_0 <= 0;
            r1_1 <= 0;
            r1_2 <= 0;
            r2_0 <= 0;
            r2_1 <= 0;
            r2_2 <= 0;
            pixel_cnt <= 0;
            process_en <= 0;
        end
        else if (valid_in) begin
            // Shift in new pixels
            r0_0 <= data_in;
            r0_1 <= r0_0;
            r0_2 <= r0_1;
            r1_0 <= lb1_out;
            r1_1 <= r1_0;
            r1_2 <= r1_1;
            r2_0 <= lb2_out;
            r2_1 <= r2_0;
            r2_2 <= r2_1;

            if (pixel_cnt < (2*IMG_WIDTH + 2)) begin
                pixel_cnt <= pixel_cnt + 1;
            end
            else begin
                process_en <= 1;
            end
        end
        else begin
            process_en <= 0; // Or keep it high if we want to flush?
            // Usually valid_out follows valid_in with delay.
            // If valid_in goes low, valid_out should go low (after pipeline drains? or immediately?)
            // For simple stream processing, we often just gate with valid_in delayed.
        end
        if (!rst_n) begin
            valid_pipe <= 0;
        end
        else begin
            valid_pipe <= {valid_pipe[1:0], valid_in};
        end
    end

    // Min calculation
    // Stage 1: Row mins
    reg [DATA_WIDTH-1:0] min_r0, min_r1, min_r2;

    function [DATA_WIDTH-1:0] min3;
        input [DATA_WIDTH-1:0] a, b, c;
        begin
            if (a <= b && a <= c)
                min3 = a;
            else if (b <= a && b <= c)
                min3 = b;
            else
                min3 = c;
        end
    endfunction

    always @(posedge clk) begin
        if (valid_pipe[0]) begin // Pipeline enable
            min_r0 <= min3(r0_0, r0_1, r0_2);
            min_r1 <= min3(r1_0, r1_1, r1_2);
            min_r2 <= min3(r2_0, r2_1, r2_2);
        end
    end

    // Stage 2: Final min
    reg [DATA_WIDTH-1:0] min_final;


    always @(posedge clk) begin
        if (valid_pipe[1]) begin // Should match pipeline delay
            min_final <= min3(min_r0, min_r1, min_r2);
        end
    end

    // Valid signal management
    // We have registers rX_X (1 cycle from input/LB), min_rX (1 cycle), min_final (1 cycle).
    // Total latency from rX_X update to min_final is 2 cycles.
    // Plus the startup time.

    // We need to delay the 'process_en' signal by 2 cycles to match the pipeline depth of the min calculation.
    reg process_en_d1, process_en_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            process_en_d1 <= 0;
            process_en_d2 <= 0;
            valid_out <= 0;
        end
        else begin
            process_en_d1 <= process_en & valid_pipe[0];
            process_en_d2 <= process_en_d1 & valid_pipe[1];
            valid_out <= process_en_d2 & valid_pipe[2];
        end
    end

    always @(posedge clk) begin
        if (process_en_d2 & valid_pipe[2])
            data_out <= min_final;
        else
            data_out <= {DATA_WIDTH{1'b1}}; // 255 for 8-bit
    end

endmodule
