------------------------------------------------------------------------------
--  Simulation execution script
--  rev. 1.0 : 2023 Provoost Kris
------------------------------------------------------------------------------

  do compile.do

echo "start simulation"

  vsim -gui -t ps -novopt work.tb_trf_shiftrows

echo "running simulation"

  do run.do
