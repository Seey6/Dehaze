
MODULE=top
RTL_DIR=../rtl
RTL_FILES=$(RTL_DIR)/top.v $(RTL_DIR)/min9x9.v $(RTL_DIR)/min3x3.v $(RTL_DIR)/line_buf.v
CPP_FILE=sim_main.cpp

all:
	verilator --trace -cc $(RTL_FILES) --top-module $(MODULE) --exe $(CPP_FILE) -I$(RTL_DIR)
	make -C obj_dir -f V$(MODULE).mk V$(MODULE)

run: all
	./obj_dir/V$(MODULE)

clean:
	rm -rf obj_dir
