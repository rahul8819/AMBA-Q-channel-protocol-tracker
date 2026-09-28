# Q-Channel tracker - run targets
#   make verilator   build + run (open-source; coverage module is skipped)
#   make bug         same, but the device violates the protocol once
#   make questa | vcs | xrun   full run including functional coverage
#                              (commercial simulators - not tested in this repo's CI)

NUM_TXNS ?= 50

verilator:
	verilator --binary --timing --assert -Wno-fatal -Wno-WIDTH -Wno-INITIALDLY \
	  +define+NO_COVERAGE --top-module tb_top -f filelist.f -Mdir sim/obj_dir -CFLAGS -w
	cd sim && ./obj_dir/Vtb_top +NUM_TXNS=$(NUM_TXNS) +verilator+error+limit+100

bug: verilator
	cd sim && ./obj_dir/Vtb_top +NUM_TXNS=$(NUM_TXNS) +INJECT_BUG +verilator+error+limit+100

questa:
	vlog -sv -f filelist.f
	vsim -c -coverage work.tb_top +NUM_TXNS=$(NUM_TXNS) -do "run -all; coverage report -details; quit"

vcs:
	vcs -sverilog -f filelist.f -cm assert+group -o sim/simv
	./sim/simv -cm assert+group +NUM_TXNS=$(NUM_TXNS)

xrun:
	xrun -sv -f filelist.f -access +r -coverage functional +NUM_TXNS=$(NUM_TXNS)

clean:
	rm -rf sim/obj_dir sim/*.log work simv* csrc *.log xcelium.d INCA_libs

.PHONY: verilator bug questa vcs xrun clean
