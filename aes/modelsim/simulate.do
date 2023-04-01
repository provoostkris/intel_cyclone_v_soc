

  proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }


echo "Compiling design"

  ensure_lib work

    vcom  -quiet -work work ../vhdl/sbox.vhd
    vcom  -quiet -work work ../vhdl/trf_subbytes.vhd

echo "Compiling test bench"

  vcom  -quiet -work work ../bench/tb_trf_subbytes.vhd

echo "start simulation"

  vsim -gui -t ps -novopt work.tb_trf_subbytes

echo "adding waves"

  view wave
  delete wave /*

  add wave  -expand        -group "dut i/o"     -ports            /tb_trf_subbytes/dut/*
  add wave  -expand        -group "dut sig"     -internal         /tb_trf_subbytes/dut/*


echo "view wave forms"

  run 10 us

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
