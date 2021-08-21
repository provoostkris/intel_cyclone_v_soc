------------------------------------------------------------------------------
--  TOP level design file for AMG8833 controller <> Terrasic DE10 nano Cyclone 5 design
--  rev. 1.0 : 2020 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

entity heat_sens is
  port (
    FPGA_CLK1_50      : in    std_ulogic; --! FPGA clock 1 input 50 MHz
    FPGA_CLK2_50      : in    std_ulogic; --! FPGA clock 2 input 50 MHz
    FPGA_CLK3_50      : in    std_ulogic; --! FPGA clock 3 input 50 MHz
    -- Buttons & LEDs
    KEY               : in    std_logic_vector(1 downto 0); --! Push button - debounced
    SW                : in    std_logic_vector(3 downto 0); --! Slide button
    Led               : out   std_logic_vector(7 downto 0); --! indicators
    -- ADV7513
    AMG_I2C_SCL       : inout std_logic; -- i2c
    AMG_I2C_SDA       : inout std_logic  -- i2c
  );
end;

architecture rtl of heat_sens is


--! definition of the altera IP
component pll is
  port (
    refclk   : in  std_logic;        -- clk
    rst      : in  std_logic;        -- reset
    outclk_0 : out std_logic;        -- clk
    outclk_1 : out std_logic;        -- clk
    outclk_2 : out std_logic;        -- clk
    locked   : out std_logic         -- export
  );
end component pll;

signal rst_pll_25     : std_logic;
signal rst_pll_25_n   : std_logic;
signal rst_pll_40     : std_logic;
signal rst_pll_40_n   : std_logic;
signal rst_pll_50     : std_logic;
signal rst_pll_50_n   : std_logic;

signal clk_pll_25     : std_logic;
signal clk_pll_40     : std_logic;
signal clk_pll_50     : std_logic;

-- local signals
signal pll_locked     : std_logic;
signal ena            : std_logic;                    --latch in command
signal addr           : std_logic_vector(6 downto 0); --address of target slave
signal rw             : std_logic;                    --'0' is write, '1' is read
signal data_wr        : std_logic_vector(7 downto 0); --data to write to slave
signal busy           : std_logic;                    --indicates transaction in progress
signal data_rd        : std_logic_vector(7 downto 0); --data read from slave
signal ack_error      : std_logic;                    --flag if improper acknowledge from slave
signal mean           : std_logic_vector(15 downto 0);--the average of all values

begin

--! top level assigments
led(1)                  <= or_reduce(KEY);
led(2)                  <= or_reduce(SW);
led(3)                  <= pll_locked;
led(4)                  <= busy;
led(5)                  <= ack_error;
led(6)                  <= mean(mean'low);
led(7)                  <= mean(mean'high);

--! syncronous resets
p_rst_pll_25: process (clk_pll_25, pll_locked)
begin
  if pll_locked = '0' then
    rst_pll_25   <= '1';
    rst_pll_25_n <= '0';
  elsif rising_edge(clk_pll_25) then
    rst_pll_25   <= '0';
    rst_pll_25_n <= '1';
  end if;
end process p_rst_pll_25;

--! syncronous resets
p_rst_pll_40: process (clk_pll_40, pll_locked)
begin
  if pll_locked = '0' then
    rst_pll_40   <= '1';
    rst_pll_40_n <= '0';
  elsif rising_edge(clk_pll_40) then
    rst_pll_40   <= '0';
    rst_pll_40_n <= '1';
  end if;
end process p_rst_pll_40;

--! syncronous resets
p_rst_pll_50: process (clk_pll_50, pll_locked)
begin
  if pll_locked = '0' then
    rst_pll_50   <= '1';
    rst_pll_50_n <= '0';
  elsif rising_edge(clk_pll_50) then
    rst_pll_50   <= '0';
    rst_pll_50_n <= '1';
  end if;
end process p_rst_pll_50;


--! general purpose pll, generate some clocks
i_pll : pll
  port map (
    refclk   => FPGA_CLK1_50,
    rst      => SW(0),
    outclk_0 => clk_pll_25,       --!  25 MHz
    outclk_1 => clk_pll_40,       --!  40 MHz
    outclk_2 => clk_pll_50,       --!  50 MHz
    locked   => pll_locked
  );

--!
--! adding the i2c master
--!
i_i2c_master: entity work.i2c_master
  generic map(
    input_clk => 25_000_000,              --input clock speed from user logic in hz
    bus_clk   => 400_000                  --speed the i2c bus (scl) will run at in hz
    )
  port map(
    clk       => clk_pll_25      ,        --system clock
    reset_n   => rst_pll_25_n    ,        --active low reset
    ena       => ena             ,        --latch in command
    addr      => addr            ,        --address of target slave
    rw        => rw              ,        --'0' is write, '1' is read
    data_wr   => data_wr         ,        --data to write to slave
    busy      => busy            ,        --indicates transaction in progress
    data_rd   => data_rd         ,        --data read from slave
    ack_error => ack_error       ,        --flag if improper acknowledge from slave
    sda       => AMG_I2C_SDA     ,        --serial data output of i2c bus
    scl       => AMG_I2C_SCL              --serial clock output of i2c bus
    );

--!
--! adding the i2c controller
--!
i_amg_controller: entity work.amg_controller
  port map(
    clk       => clk_pll_25      ,        --system clock
    reset_n   => rst_pll_25_n    ,        --active low reset
    ena       => ena             ,        --latch in command
    addr      => addr            ,        --address of target slave
    rw        => rw              ,        --'0' is write, '1' is read
    data_wr   => data_wr         ,        --data to write to slave
    busy      => busy            ,        --indicates transaction in progress
    data_rd   => data_rd         ,        --data read from slave
    ack_error => ack_error       ,        --flag if improper acknowledge from slave
    mean      => mean                     --the average of all values
    );



--! just blink LED to see activity
p_led: process (clk_pll_25, rst_pll_25)
  variable v_cnt : unsigned(24 downto 0);
begin
  if rst_pll_25 = '1' then
    led(0)   <= '0';
    v_cnt    := ( others => '0');
  elsif rising_edge(clk_pll_25) then
    led(0)   <= v_cnt(v_cnt'high);
    v_cnt    := v_cnt + 1;
  end if;
end process p_led;

end architecture rtl;