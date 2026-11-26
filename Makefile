PYTHON := python3
TOP := pochoco_soc
PCF := goboard_medicion.pcf

SRC := $(wildcard rtl/*.v rtl/espino_core/*.v)

BUILD := build_trader
JSON := $(BUILD)/pochoco_soc.json
ASC := $(BUILD)/pochoco_soc.asc
BIN := $(BUILD)/pochoco_soc.bin

.PHONY: all trade test test-short clean

all: trade
trade: $(BIN)

sw/trade.hex: sw/trade.s sw/assembler.py
	$(PYTHON) sw/assembler.py sw/trade.s sw/trade.hex

$(JSON): $(SRC) sw/trade.hex $(PCF)
	mkdir -p $(BUILD)
	yosys -p 'read_verilog $(SRC); synth_ice40 -top $(TOP) -json $(JSON)' > $(BUILD)/yosys.log

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 \
	--json $(JSON) \
	--pcf $(PCF) \
	--asc $(ASC) \
	--freq 25 \
	--log $(BUILD)/nextpnr.log

$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

test:
	$(PYTHON) sw/assembler.py sw/trade.s sw/trade.hex
	iverilog -g2012 -s tb_proyecto_4 \
	-o /tmp/pochoco_test.vvp \
	tb/tb_proyecto_4_test.sv \
	$(SRC) /usr/share/yosys/ice40/cells_sim.v
	vvp /tmp/pochoco_test.vvp

test-short:
	$(PYTHON) sw/assembler.py sw/trade.s sw/trade.hex
	iverilog -g2012 -s tb_proyecto_4 \
	-o /tmp/pochoco_test_short.vvp \
	tb/tb_proyecto_4.sv \
	$(SRC) /usr/share/yosys/ice40/cells_sim.v
	vvp /tmp/pochoco_test_short.vvp

clean:
	rm -rf $(BUILD)
