YOSYS_ICEPIE_OPT=-DICE_PIE -q -p "synth_ice40 -abc9 -device u -dsp -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICEPIE_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/icepie.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --up5k --package sg48 --opt-timing

#######################################################################################################################

ICEPIE: ICEPIE.firmware_config ICEPIE.synth ICEPIE.prog

ICEPIE.synth: 
	yosys $(YOSYS_ICEPIE_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEPIE_OPT)
	icetime -p BOARDS/icepie.pcf -P sg48 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc 
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICEPIE.show: 
	yosys $(YOSYS_ICEPIE_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEPIE_OPT) --gui

ICEPIE.prog:
	iceprog $(PROJECTNAME).bin

ICEPIE.firmware_config:
	BOARD=icebreaker TOOLS/make_config.sh -DICE_PIE
	(cd FIRMWARE; make libs)

ICEPIE.lint:
	verilator -DICE_PIE -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
