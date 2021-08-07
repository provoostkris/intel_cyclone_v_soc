-- provoost kris

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity hdmi is
  port (
    FPGA_CLK1_50      : in    std_ulogic; --! FPGA clock 1 input 50 MHz
    FPGA_CLK2_50      : in    std_ulogic; --! FPGA clock 2 input 50 MHz
    FPGA_CLK3_50      : in    std_ulogic; --! FPGA clock 3 input 50 MHz
    -- Buttons & LEDs
    KEY               : in    std_logic_vector(1 downto 0); --! Push button - debounced
    SW                : in    std_logic_vector(3 downto 0); --! Slide button
    Led               : out   std_logic_vector(7 downto 0); --! indicators
    -- ADV7513
    HDMI_I2C_SCL      : out   std_logic; -- i2c
    HDMI_I2C_SDA      : inout std_logic; -- i2c
    
    HDMI_TX_INT       : in  std_logic;
    HDMI_TX_HS        : out std_logic; -- HS output to ADV7513
    HDMI_TX_VS        : out std_logic; -- VS output to ADV7513
    HDMI_TX_CLK       : out std_logic; -- ADV7513: CLK
    HDMI_TX_D         : out std_logic_vector(23 downto 0);-- data
    HDMI_TX_DE        : out std_logic
  );
end;

architecture rtl of hdmi is

--! definition of the verilog modules
component vgahdmi
  port (
  clock      : in  std_logic;
  clock50    : in  std_logic;
  reset      : in  std_logic;
  
  switchR    : in  std_logic;
  switchG    : in  std_logic;
  switchB    : in  std_logic;
  
  hsync      : out std_logic;
  vsync      : out std_logic;
  dataEnable : out std_logic;
  vgaClock   : out std_logic;
  RGBchannel : out std_logic_vector(23 downto 0)
);
end component;

component i2c_hdmi_config
  generic(
    CLK_Freq    : integer;
    I2C_Freq    : integer
  );
  port(
    iCLK        : in    std_logic;
    iRST_N      : in    std_logic;
    I2C_SCLK    : out   std_logic;
    I2C_SDAT    : inout std_logic;
    HDMI_TX_INT : in    std_logic;
    READY       : out   std_logic
);
end component;

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
  
signal rst_pll_25   : std_logic;
signal rst_pll_25_n : std_logic;
signal rst_pll_50   : std_logic;
signal rst_pll_50_n : std_logic;

signal clk_pll_25  : std_logic;
signal clk_pll_50  : std_logic;
signal clk_pll_125 : std_logic;
signal pll_locked  : std_logic;

signal hs_out       : std_logic;
signal vs_out       : std_logic;
signal de_out       : std_logic;
signal rgb          : std_logic_vector(23 downto 0);
signal video_active : std_logic;

signal i2c_rdy  : std_logic;

begin

--! top level assigments
led(1)                  <= i2c_rdy;
led(2)                  <= SW(1);
led(3)                  <= SW(2);
led(4)                  <= SW(3);
led(led'high downto 5)  <= ( others => '0');

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

i_pll : pll
  port map (
    refclk   => FPGA_CLK1_50,
    rst      => SW(0),
    outclk_0 => clk_pll_25,       --!  25 MHz
    outclk_1 => clk_pll_50,       --!  50 MHz
    outclk_2 => clk_pll_125,      --! 125 MHz
    locked   => pll_locked
  );


i_vgaHdmi: vgaHdmi  
  port map(
  clock      => clk_pll_25,
  clock50    => clk_pll_50,
  reset      => rst_pll_25,
  
  switchR    => SW(1),
  switchG    => SW(2),
  switchB    => SW(3),
  
  hsync      => HDMI_TX_HS,
  vsync      => HDMI_TX_VS,
  dataEnable => HDMI_TX_DE,
  vgaClock   => HDMI_TX_CLK,
  RGBchannel => HDMI_TX_D
);


-- i_timing_generator: entity work.timing_generator(rtl)
  -- generic map (
    -- RESOLUTION  => "VGA", 
    -- GEN_PIX_LOC => false, 
    -- OBJECT_SIZE => 16
    -- )
  -- port map (
    -- rst           => rst_pll_25, 
    -- clk           => clk_pll_25, 
    -- hsync         => hs_out, 
    -- vsync         => vs_out, 
    -- video_active  => video_active, 
    -- pixel_x       => open, 
    -- pixel_y       => open
  -- );

-- i_pattern_generator: entity work.pattern_generator(rtl)
  -- port map (
    -- rst           =>  rst_pll_25,
    -- clk           =>  clk_pll_25, 
    -- video_active  =>  video_active, 
    -- rgb           =>  rgb
    -- );
    
    -- HDMI_TX_CLK <= clk_pll_25;

--! register outputs
-- p_driver: process (clk_pll_25, rst_pll_25)
-- begin
  -- if rst_pll_25 = '1' then
    -- HDMI_TX_D                   <= ( others => '0');
    -- HDMI_TX_HS                  <= '0';
    -- HDMI_TX_VS                  <= '0';
    -- HDMI_TX_DE                  <= '0';
  -- elsif rising_edge(clk_pll_25) then
    -- HDMI_TX_D                   <= "10001000" & "01110111" & "00110011";
    -- HDMI_TX_HS                  <= hs_out;
    -- HDMI_TX_VS                  <= vs_out;
    -- HDMI_TX_DE                  <= video_active;
  -- end if;
-- end process p_driver;

i_i2c_hdmi_config: i2c_hdmi_config
  generic map(
    CLK_Freq    => 50_000_000,
    I2C_Freq    =>     20_000
  )
  port map (
    iCLK        => clk_pll_50,
    iRST_N      => rst_pll_50_n,
    
    I2C_SCLK    => HDMI_I2C_SCL,
    I2C_SDAT    => HDMI_I2C_SDA,
    HDMI_TX_INT => HDMI_TX_INT,
    READY       => i2c_rdy
);

--! just blink LED to see activity
p_led: process (clk_pll_25, rst_pll_25)
  variable v_cnt : unsigned(24 downto 0);
begin
  if rst_pll_25 = '1' then
    led(0)   <= '0';
    v_cnt    := ( others => '1');
  elsif rising_edge(clk_pll_25) then
    led(0)   <= v_cnt(v_cnt'high);
    v_cnt    := v_cnt + 1;
  end if;
end process p_led;

end architecture rtl;