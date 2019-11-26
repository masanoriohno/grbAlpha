# Project setup
PROJ      = readgrbalpha
BUILD     = ./build
DEVICE    = 8k
FOOTPRINT = ct256

# Files
FILES = readgrbalpha_top.v 

.PHONY: all clean burn

all:
	# if build folder doesn't exist, create it
	mkdir -p $(BUILD)
	# synthesize using Yosys
	yosys -p "synth_ice40 -top readgrbalpha_top -blif $(BUILD)/$(PROJ).blif" $(FILES)
	# Place and route using arachne
	arachne-pnr -d $(DEVICE) -P $(FOOTPRINT) -o $(BUILD)/$(PROJ).asc -p ice40hx8k.pcf $(BUILD)/$(PROJ).blif
	# Convert to bitstream using IcePack
	icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin

nextpnr:
	yosys -p 'synth_ice40 -top readgrbalpha_top -json readgrbalpha_top.json' $(FILES)
	nextpnr-ice40 --hx8k --package ct256 --json readgrbalpha_top.json --pcf ice40hx8k.pcf --asc $(BUILD)/$(PROJ).asc
	icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin
burn:
	iceprog $(BUILD)/$(PROJ).bin

sim:
	iverilog -o uart_tb uart_tb.v readgrbalpha_top.v /usr/local/Cellar/yosys/0.9/share/yosys/ice40/cells_sim.v
	vvp uart_tb

clean:
	rm build/*
