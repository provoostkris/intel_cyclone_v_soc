echo "Compiling IP"

  if ![info exists QUARTUS_INSTALL_DIR] {
    set QUARTUS_INSTALL_DIR "C:/intelfpga_lite/18.1/quartus/"
  }

  if ![info exists USER_DEFINED_COMPILE_OPTIONS] {
    set USER_DEFINED_COMPILE_OPTIONS ""
  }
  if ![info exists USER_DEFINED_VHDL_COMPILE_OPTIONS] {
    set USER_DEFINED_VHDL_COMPILE_OPTIONS ""
  }
  if ![info exists USER_DEFINED_VERILOG_COMPILE_OPTIONS] {
    set USER_DEFINED_VERILOG_COMPILE_OPTIONS ""
  }
  if ![info exists USER_DEFINED_ELAB_OPTIONS] {
    set USER_DEFINED_ELAB_OPTIONS ""
  }

  proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
  ensure_lib          ./libraries/
  ensure_lib          ./libraries/work/
  vmap       work     ./libraries/work/
  vmap       work_lib ./libraries/work/
  if ![ string match "*ModelSim ALTERA*" [ vsim -version ] ] {
    ensure_lib              ./libraries/altera/
    vmap       altera       ./libraries/altera/
    ensure_lib              ./libraries/lpm/
    vmap       lpm          ./libraries/lpm/
    ensure_lib              ./libraries/sgate/
    vmap       sgate        ./libraries/sgate/
    ensure_lib              ./libraries/altera_mf/
    vmap       altera_mf    ./libraries/altera_mf/
    ensure_lib              ./libraries/altera_lnsim/
    vmap       altera_lnsim ./libraries/altera_lnsim/
    ensure_lib              ./libraries/cyclonev/
    vmap       cyclonev     ./libraries/cyclonev/
  }
  alias dev_com {
    echo "\[exec\] dev_com"
    if ![ string match "*ModelSim ALTERA*" [ vsim -version ] ] {
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_syn_attributes.vhd"        -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_standard_functions.vhd"    -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/alt_dspbuilder_package.vhd"       -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_europa_support_lib.vhd"    -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_primitives_components.vhd" -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_primitives.vhd"            -work altera
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/220pack.vhd"                      -work lpm
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/220model.vhd"                     -work lpm
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/sgate_pack.vhd"                   -work sgate
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/sgate.vhd"                        -work sgate
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_mf_components.vhd"         -work altera_mf
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_mf.vhd"                    -work altera_mf
      eval  vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QUARTUS_INSTALL_DIR/eda/sim_lib/mentor/altera_lnsim_for_vhdl.sv"  -work altera_lnsim
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_lnsim_components.vhd"      -work altera_lnsim
      eval  vlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/mentor/cyclonev_atoms_ncrypt.v"   -work cyclonev
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_atoms.vhd"               -work cyclonev
      eval  vcom $USER_DEFINED_VHDL_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS        "$QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_components.vhd"          -work cyclonev
    }
  }

  #dev_com

  vcom ../vhdl/pll/pll_sim/pll.vho

echo "Compiling design"

  vlib work
  
  vcom  -quiet -work work ../../../vhdl-axis-uart/rtl/uart_rx.vhd
  vcom  -quiet -work work ../../../vhdl-axis-uart/rtl/uart_tx.vhd
  vcom  -quiet -work work ../../../vhdl-axis-uart/rtl/uart.vhd

  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecippackage.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecip.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecipfifo9x64.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodeciplinkinterface.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecipreceiversynchronize.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecipstatemachine.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecipstatisticalinformationcount.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodecipsynchronizeonepulse.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodeciptimecodecontrol.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodeciptimer.vhdl
  vcom  -quiet -work work ../../../SpaceWireCODECIP_100MHz/vhdl/spacewirecodeciptransmitter.vhdl


  vcom  -quiet -work work ../vhdl/uart_spw.vhd
  
  
echo "Compiling test bench"

  vcom  -quiet -work work ../bench/tb_uart_spw.vhd

echo "start simulation"

  vsim -gui -t ps -novopt work.tb_uart_spw

echo "adding waves"
  
  view wave
  delete wave /*

  add wave          -group "dut i/o"   -ports            /tb_uart_spw/dut/*

  add wave  -expand -group "spw codec"   -ports            /tb_uart_spw/dut/i_spw/*
  add wave  -expand -group "uart core"   -ports            /tb_uart_spw/dut/i_uart/*


echo "view wave forms"

  run 1500 us

  configure wave -namecolwidth  280
  configure wave -valuecolwidth 120
  configure wave -justifyvalue right
  configure wave -signalnamewidth 1
  configure wave -snapdistance 10
  configure wave -datasetprefix 0
  configure wave -rowmargin 4
  configure wave -childrowmargin 2
  configure wave -gridoffset 0
  configure wave -gridperiod 1
  configure wave -griddelta 40
  configure wave -timeline 1
  configure wave -timelineunits us
  update

  wave zoom full