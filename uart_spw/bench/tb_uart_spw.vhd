------------------------------------------------------------------------------
--  Test Bench for the uart to spw bridge top level
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity tb_uart_spw is
	port(
		y        :  out std_logic
	);
end entity tb_uart_spw;

architecture rtl of tb_uart_spw is

constant c_clk_per       : time      := 20   ns ;
constant c_uart_clk_per  : time      := 8680 ns ;

signal clk          : std_ulogic :='0';
signal uart_clk     : std_ulogic :='0';
signal rst          : std_ulogic ;
signal rst_n        : std_ulogic ;

--! DUT ports
signal KEY          : std_logic_vector(1 downto 0); --! Push button - debounced
signal SW           : std_logic_vector(3 downto 0); --! Slide button
signal Led          : std_logic_vector(7 downto 0); --! indicators

signal rxd          : std_logic;
signal txd          : std_logic;

--! stimuli
constant  c_rx_data      : std_logic_vector(7 downto 0) := x"55";

begin

	clk            <= not clk       after c_clk_per/2;
	uart_clk       <= not uart_clk  after c_uart_clk_per/2;
	rst            <= '1', '0' after c_clk_per *  3 ;
  rst_n          <= not rst;
	KEY(0)         <= '1', '0' after c_clk_per * 10 ;
	KEY(1)         <= '1', '0' after c_clk_per * 12 ;
	SW(0)          <= '1', '0' after c_clk_per * 14 ;
	SW(1)          <= '1', '0' after c_clk_per * 16 ;
	SW(2)          <= '1', '0' after c_clk_per * 18 ;
	SW(3)          <= '1', '0' after c_clk_per * 20 ;

dummy_rx_data: process
begin
    assert false report " >> Send CHAR to RX " severity warning;
    --start idle
    rxd <= '1';
    wait for 5 us;
    wait until uart_clk'event and uart_clk = '1';
    --pull start bit
    rxd <= '0';
    wait for c_uart_clk_per;
    --data bits
    for i in 0 to 8-1 loop
        rxd <= c_rx_data(i); -- data bits
        wait for c_uart_clk_per;
    end loop;
    -- send stop bit
    rxd <= '1'; -- stop bit

    wait for 85 us;

    assert false report " >> Send inverted CHAR to RX " severity warning;
    --start idle
    rxd <= '1';
    wait for 5 us;
    wait until uart_clk'event and uart_clk = '1';
    --pull start bit
    rxd <= '0';
    wait for c_uart_clk_per;
    --data bits
    for i in 0 to 8-1 loop
        rxd <= not c_rx_data(i); -- data bits
        wait for c_uart_clk_per;
    end loop;
    -- send stop bit
    rxd <= '1'; -- stop bit

    wait;
end process;

--! dut
dut: entity work.uart_spw(rtl)
  port map (
    FPGA_CLK1_50      => clk,
    FPGA_CLK2_50      => clk,
    FPGA_CLK3_50      => clk,
    KEY               => KEY,
    SW                => SW,
    Led               => Led,
    rxd               => rxd,
    txd               => txd
  );


end architecture rtl;