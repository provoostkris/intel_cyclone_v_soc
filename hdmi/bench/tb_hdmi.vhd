-- provoost kris
-- test bench for a hdmi

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hdmi is
	port(
		y        :  out std_logic
	);
end entity tb_hdmi;

architecture rtl of tb_hdmi is

constant c_clk_per  : time      := 20 ns ;

signal clk          : std_ulogic :='0';
signal rst          : std_ulogic :='0';

--! DUT ports
signal KEY          : std_logic_vector(1 downto 0); --! Push button - debounced
signal SW           : std_logic_vector(3 downto 0); --! Slide button
signal Led          : std_logic_vector(7 downto 0); --! indicators
signal HDMI_I2C_SCL : std_logic; -- i2c
signal HDMI_I2C_SDA : std_logic; -- i2c
signal HDMI_TX_INT  : std_logic;
signal HDMI_TX_HS   : std_logic; -- HS output to ADV7513
signal HDMI_TX_VS   : std_logic; -- VS output to ADV7513
signal HDMI_TX_CLK  : std_logic; -- ADV7513: CLK
signal HDMI_TX_D    : std_logic_vector(23 downto 0);-- data
signal HDMI_TX_DE   : std_logic;

begin

	clk            <= not clk  after c_clk_per/2;
	rst            <= '1', '0' after c_clk_per  ;
	KEY(0)         <= '1', '0' after c_clk_per * 10 ;
	KEY(1)         <= '1', '0' after c_clk_per * 12 ;
	SW(0)          <= '1', '0' after c_clk_per * 14 ;
	SW(1)          <= '1', '0' after c_clk_per * 16 ;
	SW(2)          <= '1', '0' after c_clk_per * 18 ;
	SW(3)          <= '1', '0' after c_clk_per * 20 ;

p_main: process(rst, clk) is
begin
   if rst = '1' then
      HDMI_TX_INT <= '0';
   elsif rising_edge(clk) then
      HDMI_TX_INT <= '1';
   end if;
end process;

dut: entity work.hdmi(rtl)
  generic map (
    g_imp             => 1
  )
  port map (
    FPGA_CLK1_50      => clk,
    FPGA_CLK2_50      => clk,
    FPGA_CLK3_50      => clk,
    -- Buttons & LEDs
    KEY               => KEY,
    SW                => SW,
    Led               => Led,
    -- ADV7513
    HDMI_I2C_SCL      => HDMI_I2C_SCL,
    HDMI_I2C_SDA      => HDMI_I2C_SDA,

    HDMI_TX_INT       => HDMI_TX_INT,
    HDMI_TX_HS        => HDMI_TX_HS,
    HDMI_TX_VS        => HDMI_TX_VS,
    HDMI_TX_CLK       => HDMI_TX_CLK,
    HDMI_TX_D         => HDMI_TX_D,
    HDMI_TX_DE        => HDMI_TX_DE
  );

end architecture rtl;