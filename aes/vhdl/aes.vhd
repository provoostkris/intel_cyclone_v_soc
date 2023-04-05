------------------------------------------------------------------------------
--  TOP level design file for HDMI controller <> Terrasic DE10 nano Cyclone 5 design
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

library work;
use     work.aes_pkg.all;

entity aes is
  generic (
    g_imp             : in    natural range 0 to 2 := 2
  );
  port (
    FPGA_CLK1_50      : in    std_ulogic; --! FPGA clock 1 input 50 MHz
    FPGA_CLK2_50      : in    std_ulogic; --! FPGA clock 2 input 50 MHz
    FPGA_CLK3_50      : in    std_ulogic; --! FPGA clock 3 input 50 MHz
    -- Buttons & LEDs
    KEY               : in    std_logic_vector(1 downto 0); --! Push button - debounced
    SW                : in    std_logic_vector(3 downto 0); --! Slide button
    Led               : out   std_logic_vector(7 downto 0); --! indicators
    -- status signal
    status            : out   std_logic
  );
end;

architecture rtl of aes is

signal rst_50    : std_logic;
signal rst_50_n  : std_logic;
signal clk_50    : std_logic;

-- local signals
signal subbytes_s    : std_logic_vector(c_seq-1 downto 0);
signal subbytes_m    : std_logic_vector(c_seq-1 downto 0);

signal shiftrows_s   : std_logic_vector(c_seq-1 downto 0);
signal shiftrows_m   : std_logic_vector(c_seq-1 downto 0);

signal mixcolumns_s  : std_logic_vector(c_seq-1 downto 0);
signal mixcolumns_m  : std_logic_vector(c_seq-1 downto 0);

signal addroundkey_s  : std_logic_vector(c_seq-1 downto 0);
signal subkey_s       : std_logic_vector(c_seq-1 downto 0);
signal addroundkey_m  : std_logic_vector(c_seq-1 downto 0);

begin


--! top level assigments

clk_50                  <= FPGA_CLK1_50 ;

led(1)                  <= '0';
led(2)                  <= '0';
led(3)                  <= '0';
led(4)                  <= '0';
led(5)                  <= '0';
led(6)                  <= '0';
led(7)                  <= '0';

--! syncronous resets
p_rst_50: process (clk_50, KEY(0) )
begin
  if KEY(0) = '0' then
    rst_50   <= '1';
    rst_50_n <= '0';
  elsif rising_edge(clk_50) then
    rst_50   <= '0';
    rst_50_n <= '1';
  end if;
end process p_rst_50;

--!
--! implementation
--!

-- dummy input assignment unit design is READY

  gen_dummy: for k in 0 to c_seq-1 generate
     subbytes_s(k)     <= SW(0) ;
  end generate;

  status <= or_reduce(addroundkey_m);

i_trf_subbytes: entity work.trf_subbytes(rtl)
  port map (
    clk               => clk_50,
    reset_n           => rst_50_n,

		subbytes_s        => subbytes_s,
    subbytes_m        => subbytes_m
  );

shiftrows_s <= subbytes_m;

i_trf_shiftrows: entity work.trf_shiftrows(rtl)
  port map (
    clk               => clk_50,
    reset_n           => rst_50_n,

		shiftrows_s       => shiftrows_s,
    shiftrows_m       => shiftrows_m
  );

mixcolumns_s <= shiftrows_m;

i_trf_mixcolumns: entity work.trf_mixcolumns(rtl)
  port map (
    clk               => clk_50,
    reset_n           => rst_50_n,

		mixcolumns_s      => mixcolumns_s,
    mixcolumns_m      => mixcolumns_m
  );
  
addroundkey_s <= mixcolumns_m;
subkey_s      <= shiftrows_m;

i_trf_addroundkey: entity work.trf_addroundkey(rtl)
  port map (
    clk               => clk_50,
    reset_n           => rst_50_n,

		addroundkey_s     => addroundkey_s,
		subkey_s          => subkey_s,
    addroundkey_m     => addroundkey_m
  );
--! just blink LED to see activity
p_led: process (clk_50, rst_50)
  variable v_cnt : unsigned(24 downto 0);
begin
  if rst_50 = '1' then
    led(0)   <= '0';
    v_cnt    := ( others => '0');
  elsif rising_edge(clk_50) then
    led(0)   <= v_cnt(v_cnt'high);
    v_cnt    := v_cnt + 1;
  end if;
end process p_led;

end architecture rtl;
