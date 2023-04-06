------------------------------------------------------------------------------
--  Simulation execution script
--  rev. 1.0 : 2023 Provoost Kris
------------------------------------------------------------------------------

  proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }


echo "Compiling design"

  ensure_lib work

  vcom  -quiet -work work ../vhdl/aes_pkg.vhd
  vcom  -quiet -work work ../vhdl/galois_mul.vhd
  vcom  -quiet -work work ../vhdl/sbox.vhd
  vcom  -quiet -work work ../vhdl/trf_subbytes.vhd
  vcom  -quiet -work work ../vhdl/trf_shiftrows.vhd
  vcom  -quiet -work work ../vhdl/trf_mixcolumns.vhd
  vcom  -quiet -work work ../vhdl/trf_addroundkey.vhd
  vcom  -quiet -work work ../vhdl/key_expand.vhd
  vcom  -quiet -work work ../vhdl/aes.vhd

  #vcom  -quiet -work work ../quartus/simulation/modelsim/aes.vho

echo "Compiling test bench"

  vcom  -quiet -work work ../bench/tb_trf_subbytes.vhd
  vcom  -quiet -work work ../bench/tb_trf_shiftrows.vhd
  vcom  -quiet -work work ../bench/tb_trf_mixcolumns.vhd
  vcom  -quiet -work work ../bench/tb_trf_addroundkey.vhd
  vcom  -quiet -work work ../bench/tb_key_expand.vhd
  vcom  -quiet -work work ../bench/tb_aes.vhd

echo "start simulation"

  #vsim -gui -t ps -novopt work.tb_trf_subbytes
  #vsim -gui -t ps -novopt work.tb_trf_shiftrows
  #vsim -gui -t ps -novopt work.tb_trf_mixcolumns
  #vsim -gui -t ps -novopt work.tb_trf_addroundkey
  vsim -gui -t ps -novopt work.tb_key_expand
  #vsim -gui -t ps -novopt work.tb_aes

echo "adding waves"

  view wave
  delete wave /*
  add wave -r /*
  
  #add wave  -expand        -group "dut i/o"     -ports            /tb_aes/dut/*
  #add wave  -expand        -group "dut sig"     -internal         /tb_aes/dut/*
  #
  #add wave  -expand        -group "i_trf_subbytes"        -internal         /tb_aes/dut/i_trf_subbytes/*
  #add wave  -expand        -group "i_trf_shiftrows"       -internal         /tb_aes/dut/i_trf_shiftrows/*
  #add wave  -expand        -group "i_trf_mixcolumns"      -internal         /tb_aes/dut/i_trf_mixcolumns/*
  #add wave  -expand        -group "i_trf_addroundkey"     -internal         /tb_aes/dut/i_trf_addroundkey/*

echo "view wave forms"

  run 10 us

  configure wave -namecolwidth  370
  configure wave -valuecolwidth 180
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
