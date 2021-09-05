#------------------------------------------------------------------------------
#--  Quartus timing constraint file for heat camera <> Terrasic DE10 nano Cyclone 5 design
#--  rev. 1.0 : 2021 Provoost Kris
#------------------------------------------------------------------------------

# clock definitions
create_clock -name fpga_clk_1  -period 20    [get_ports FPGA_CLK1_50]
create_clock -name fpga_clk_2  -period 20    [get_ports FPGA_CLK2_50]
create_clock -name fpga_clk_3  -period 20    [get_ports FPGA_CLK3_50]

create_clock -name adv_i2c_clk -period 50000 [get_ports HDMI_I2C_SCL]
create_clock -name amg_i2c_clk -period 25000 [get_ports AMG_I2C_SCL]

create_clock -name i2c_clk_src -period 50000 [get_keepers *mI2C_CTRL_CLK]

# set false paths from user I/O
set_false_path -from [get_ports { KEY[0] KEY[1] } ]           -to [get_registers *]
set_false_path -from [get_ports { SW[0] SW[1] SW[2] SW[3] } ] -to [get_registers *]
set_false_path                                                -to [get_ports { Led[*] } ]

# general directives for PLL usage
derive_pll_clocks
derive_clock_uncertainty

# I2C IO
set_input_delay  -clock [get_clocks {amg_i2c_clk}] 10 [get_ports {AMG_I2C_SDA}]
set_output_delay -clock [get_clocks {amg_i2c_clk}] 10 [get_ports {AMG_I2C_SDA}]

set_input_delay  -clock [get_clocks {adv_i2c_clk}] 10 [get_ports {hdmi_i2c_sda}]
set_output_delay -clock [get_clocks {adv_i2c_clk}] 10 [get_ports {hdmi_i2c_sda}]

# Video IO
set hdmi_pll_out  [get_pins {i_pll|pll_inst|altera_pll_i|outclk_wire[1]~CLKENA0|outclk}]
create_generated_clock -name hdmi_tx_clk        -source  $hdmi_pll_out             -divide_by 1 -multiply_by 1 [get_ports HDMI_TX_CLK]

set HDMI_CLK_PERIOD [get_clock_info -period [get_clocks hdmi_tx_clk]]
set HDMI_TSU 1.0
set HDMI_TH  0.7
set HDMI_PAD 0.3
set HDMI_MAX [expr ${HDMI_CLK_PERIOD} - ${HDMI_TSU} - ${HDMI_PAD}]
set HDMI_MIN [expr ${HDMI_CLK_PERIOD} + ${HDMI_TH}  + ${HDMI_PAD}]

post_message -type info [format "HDMI_NOM = %f" ${HDMI_CLK_PERIOD}]
post_message -type info [format "HDMI_MAX = %f" ${HDMI_MAX}]
post_message -type info [format "HDMI_MIN = %f" ${HDMI_MIN}]

set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[0]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[1]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[2]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[3]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[4]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[5]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[6]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[7]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[8]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[9]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[10]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[11]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[12]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[13]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[14]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[15]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[16]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[17]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[18]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[19]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[20]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[21]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[22]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {HDMI_TX_D[23]}]

set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[0]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[1]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[2]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[3]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[4]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[5]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[6]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[7]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[8]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[9]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[10]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[11]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[12]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[13]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[14]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[15]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[16]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[17]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[18]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[19]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[20]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[21]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[22]}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {HDMI_TX_D[23]}]

set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {hdmi_tx_de}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {hdmi_tx_de}]

set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {hdmi_tx_hs}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {hdmi_tx_hs}]

set_output_delay -clock [get_clocks hdmi_tx_clk] -max ${HDMI_MAX} [get_ports {hdmi_tx_vs}]
set_output_delay -clock [get_clocks hdmi_tx_clk] -min ${HDMI_MIN} [get_ports {hdmi_tx_vs}]
