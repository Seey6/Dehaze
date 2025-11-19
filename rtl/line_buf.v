module line_buf #(
        parameter DATA_WIDTH = 8,
        parameter DEPTH = 640
    )(
        input  wire                  clk,
        input  wire                  rst_n,
        input  wire                  wen,
        input  wire [DATA_WIDTH-1:0] din,
        output wire [DATA_WIDTH-1:0] dout
    );

    localparam PTR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [DATA_WIDTH-1:0] dout_reg;

    // Simple dual port RAM behavior or FIFO
    // Since it's a line buffer for a stream, it's effectively a delay line of length DEPTH.
    // We can implement it as a circular buffer or just a pointer based delay.

    // However, for a 3x3 filter, we usually need to tap into the stream.
    // A line buffer usually takes one pixel in and gives one pixel out (delayed by one row).

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end
        else if (wen) begin
            /* verilator lint_off WIDTHEXPAND */
            if (wr_ptr == DEPTH - 1)
                /* verilator lint_on WIDTHEXPAND */
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1;
        end
    end

    // Read logic (1 cycle latency usually for BRAM)
    // If we want it to be a delay of exactly DEPTH, we read from wr_ptr (if we write then read same address, it's old data? No, standard RAM).
    // We want a delay of DEPTH.
    // If we write to addr X, we want to read from addr X (which contains data from DEPTH cycles ago if we cycle through).

    always @(posedge clk) begin
        if (wen) begin
            ram[wr_ptr] <= din;
        end
        dout_reg <= ram[wr_ptr]; // Read-during-write: returns OLD data at this address (which is what we want for a delay line)
    end

    assign dout = dout_reg;

endmodule
