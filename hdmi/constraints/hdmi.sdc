#------------------------------------------------------------------------------
#--  Quartus timing constraint file for HDMI <> Terrasic DE10 nano Cyclone 5 design
#--  rev. 1.0 : 2021 Provoost Kris
#------------------------------------------------------------------------------

# dedicated clock inputs (pins on the kit)
create_clock -period 20    [get_ports FPGA_CLK1_50]
create_clock -period 20    [get_ports FPGA_CLK2_50]
create_clock -period 20    [get_ports FPGA_CLK3_50]
create_clock -period 50000 [get_ports HDMI_I2C_SCL]
create_clock -period 50000 [get_keepers *mI2C_CTRL_CLK]

# set false paths from user I/O
set_false_path -from [get_ports { KEY[0] KEY[1] } ]           -to [get_registers *]
set_false_path -from [get_ports { SW[0] SW[1] SW[2] SW[3] } ] -to [get_registers *]

# general directives for PLL usage
derive_pll_clocks
derive_clock_uncertainty