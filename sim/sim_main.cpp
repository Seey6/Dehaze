#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <vector>
#include <algorithm>
#include <cstdlib>
#include <ctime>

vluint64_t main_time = 0;

double sc_time_stamp() {
    return main_time;
}

// Helper to get pixel from 1D array
uint8_t get_pixel(const std::vector<uint8_t>& img, int x, int y, int width) {
    if (x < 0 || x >= width || y < 0) return 255; // Boundary check (simplified)
    return img[y * width + x];
}

// Software 9x9 min filter calculation for a single channel
uint8_t calc_min9x9_window(const std::vector<uint8_t>& img, int cx, int cy, int width) {
    uint8_t min_val = 255;
    for (int dy = -4; dy <= 4; dy++) {
        for (int dx = -4; dx <= 4; dx++) {
            uint8_t val = get_pixel(img, cx + dx, cy + dy, width);
            if (val < min_val) min_val = val;
        }
    }
    return min_val;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    Vtop* top = new Vtop;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Simulation parameters
    const int WIDTH = 320;
    const int HEIGHT = 50; 
    const int TOTAL_PIXELS = WIDTH * HEIGHT;

    // 1. Generate Random Input Data
    std::srand(std::time(nullptr));
    std::vector<uint8_t> r_data(TOTAL_PIXELS);
    std::vector<uint8_t> g_data(TOTAL_PIXELS);
    std::vector<uint8_t> b_data(TOTAL_PIXELS);

    for (int i = 0; i < TOTAL_PIXELS; i++) {
        r_data[i] = std::rand() % 256;
        g_data[i] = std::rand() % 256;
        b_data[i] = std::rand() % 256;
    }

    // 2. Calculate Expected Outputs (Software Reference 9x9)
    // The 9x9 filter is valid for centers at (4,4) to (WIDTH-5, HEIGHT-5)
    std::vector<uint8_t> expected_outputs;
    std::cout << "Calculating expected outputs for 9x9..." << std::endl;
    for (int y = 4; y < HEIGHT - 4; y++) {
        for (int x = 4; x < WIDTH - 4; x++) {
            uint8_t min_r = calc_min9x9_window(r_data, x, y, WIDTH);
            uint8_t min_g = calc_min9x9_window(g_data, x, y, WIDTH);
            uint8_t min_b = calc_min9x9_window(b_data, x, y, WIDTH);
            // Dark channel is minimum of R, G, B
            uint8_t dark = std::min({min_r, min_g, min_b});
            expected_outputs.push_back(dark);
        }
    }
    std::cout << "Expected valid pixels: " << expected_outputs.size() << std::endl;

    // 3. Run Hardware Simulation
    top->clk = 0;
    top->rst_n = 0;
    top->valid_in = 0;
    
    // Reset
    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
        main_time++;
        tfp->dump(main_time);
    }
    top->rst_n = 1;

    int in_pixel_idx = 0;
    int out_pixel_idx = 0; 
    int error_count = 0;
    int valid_out_count = 0;
    
    // Hardware output coordinate trackers for 9x9
    // Stage 1 starts outputting at (4,4)
    int hw_x = 4;
    int hw_y = 4;

    std::cout << "Starting hardware simulation..." << std::endl;

    while (!Verilated::gotFinish() && (out_pixel_idx < expected_outputs.size() || in_pixel_idx < TOTAL_PIXELS)) {
        top->clk = !top->clk;

        if (top->clk) { // Rising edge
            // Feed Input
            if (in_pixel_idx < TOTAL_PIXELS) {
                top->valid_in = 1;
                top->r_in = r_data[in_pixel_idx];
                top->g_in = g_data[in_pixel_idx]; // Unused
                top->b_in = b_data[in_pixel_idx]; // Unused
                in_pixel_idx++;
            } else {
                top->valid_in = 0;
            }
        }

        top->eval();

        if (top->clk) { // Check Output on Rising Edge (after eval)
            if (top->valid_out) {
                // Check if current HW pixel is in the valid verification region
                // Valid X range for 9x9: [4, WIDTH-5]
                bool is_valid_region = (hw_x >= 4 && hw_x <= WIDTH - 5);
                
                if (is_valid_region) {
                    if (out_pixel_idx < expected_outputs.size()) {
                        uint8_t hw_val = top->dark_channel; // Mapped to data_out
                        uint8_t sw_val = expected_outputs[out_pixel_idx];
                        
                        if (hw_val != sw_val) {
                            if (error_count < 10) {
                                std::cout << "Mismatch at SW index " << out_pixel_idx 
                                          << " HW Coord (" << hw_x << "," << hw_y << ")"
                                          << ": HW=" << (int)hw_val << " SW=" << (int)sw_val << std::endl;
                            }
                            error_count++;
                        }
                        out_pixel_idx++;
                    }
                }

                // Update HW coordinates
                hw_x++;
                if (hw_x >= WIDTH) {
                    hw_x = 0;
                    hw_y++;
                }
                
                valid_out_count++;
            }
        }
        
        main_time++;
        tfp->dump(main_time);
        
        if (main_time > TOTAL_PIXELS * 4 + 30000) {
            std::cout << "Simulation timeout!" << std::endl;
            break;
        }
    }

    top->final();
    tfp->close();
    delete tfp;
    delete top;

    // 4. Final Report
    std::cout << "--------------------------------" << std::endl;
    std::cout << "Simulation Result Summary" << std::endl;
    std::cout << "--------------------------------" << std::endl;
    std::cout << "Total Inputs Fed: " << in_pixel_idx << std::endl;
    std::cout << "Total Valid Outputs: " << valid_out_count << std::endl;
    std::cout << "Expected Valid Outputs: " << expected_outputs.size() << std::endl;
    std::cout << "Errors: " << error_count << std::endl;

    // Check if we verified all expected pixels
    if (error_count == 0 && out_pixel_idx == expected_outputs.size()) {
        std::cout << "SUCCESS: Hardware matches Software Reference!" << std::endl;
        return 0;
    } else {
        std::cout << "FAILURE: Mismatches or count error." << std::endl;
        std::cout << "Verified " << out_pixel_idx << "/" << expected_outputs.size() << " expected pixels." << std::endl;
        return 1;
    }
}
