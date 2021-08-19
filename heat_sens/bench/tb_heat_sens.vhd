------------------------------------------------------------------------------
--  Test Bench for the heat sens top level
--  rev. 1.0 : 2020 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_heat_sens is
	port(
		y        :  out std_logic
	);
end entity tb_heat_sens;

architecture rtl of tb_heat_sens is

constant c_clk_per  : time      := 20 ns ;

signal clk          : std_ulogic :='0';
signal rst          : std_ulogic :='0';

--! DUT ports
signal KEY          : std_logic_vector(1 downto 0); --! Push button - debounced
signal SW           : std_logic_vector(3 downto 0); --! Slide button
signal Led          : std_logic_vector(7 downto 0); --! indicators

signal AMG_I2C_SCL  : std_logic;  -- i2c
signal AMG_I2C_SDA  : std_logic;  -- i2c

signal i2c_slv_read_req         : std_logic;
signal i2c_slv_data_to_master   : std_logic_vector(7 downto 0);
signal i2c_slv_data_valid       : std_logic;
signal i2c_slv_data_from_master : std_logic_vector(7 downto 0);

begin

	clk            <= not clk  after c_clk_per/2;
	rst            <= '1', '0' after c_clk_per *  3 ;
	KEY(0)         <= '1', '0' after c_clk_per * 10 ;
	KEY(1)         <= '1', '0' after c_clk_per * 12 ;
	SW(0)          <= '1', '0' after c_clk_per * 14 ;
	SW(1)          <= '1', '0' after c_clk_per * 16 ;
	SW(2)          <= '1', '0' after c_clk_per * 18 ;
	SW(3)          <= '1', '0' after c_clk_per * 20 ;

--! bus terminations
AMG_I2C_SCL <= 'H';   --should be 10 k on the boards
AMG_I2C_SDA <= 'H';   --should be 10 k on the boards

--! i2c slave model
i_i2c_slave: entity work.I2C_slave
  generic map (
    SLAVE_ADDR        => "1101000"
    )
  port map (
    scl              => AMG_I2C_SCL,
    sda              => AMG_I2C_SDA,
    clk              => clk,
    rst              => rst,
    -- User interface
    read_req         => i2c_slv_read_req        ,
    data_to_master   => i2c_slv_data_to_master  ,
    data_valid       => i2c_slv_data_valid      ,
    data_from_master => i2c_slv_data_from_master
    );
--! provide dummy data to the model
  process(i2c_slv_read_req, rst)
  begin
    if(rst = '1') then
      -- just some random value to start from
      i2c_slv_data_to_master  <= x"48";
    elsif(i2c_slv_read_req'event and i2c_slv_read_req = '1') then
      -- just some random increment
      i2c_slv_data_to_master  <= std_logic_vector(unsigned(i2c_slv_data_to_master) + x"13");
    end if;
  end process;


--! dut
dut: entity work.heat_sens(rtl)
  port map (
    FPGA_CLK1_50      => clk,
    FPGA_CLK2_50      => clk,
    FPGA_CLK3_50      => clk,
    -- Buttons & LEDs
    KEY               => KEY,
    SW                => SW,
    Led               => Led,
    -- sensor
    AMG_I2C_SCL       => AMG_I2C_SCL,
    AMG_I2C_SDA       => AMG_I2C_SDA
  );

end architecture rtl;