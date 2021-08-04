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
component sync_vg is
  generic (
   X_BITS : integer range 8 to 16 := 12;
   Y_BITS : integer range 8 to 16 := 12
  );
  port (
   clk          : in std_logic;
   reset        : in std_logic;

   interlaced   : in std_logic;
   v_total_0    : in std_logic_vector(Y_BITS-1 downto 0);
   v_fp_0       : in std_logic_vector(Y_BITS-1 downto 0);
   v_bp_0       : in std_logic_vector(Y_BITS-1 downto 0);
   v_sync_0     : in std_logic_vector(Y_BITS-1 downto 0);
   v_total_1    : in std_logic_vector(Y_BITS-1 downto 0);
   v_fp_1       : in std_logic_vector(Y_BITS-1 downto 0);
   v_bp_1       : in std_logic_vector(Y_BITS-1 downto 0);
   v_sync_1     : in std_logic_vector(Y_BITS-1 downto 0);
   h_total      : in std_logic_vector(X_BITS-1 downto 0);
   h_fp         : in std_logic_vector(X_BITS-1 downto 0);
   h_bp         : in std_logic_vector(X_BITS-1 downto 0);
   h_sync       : in std_logic_vector(X_BITS-1 downto 0);
   hv_offset_0  : in std_logic_vector(X_BITS-1 downto 0);
   hv_offset_1  : in std_logic_vector(X_BITS-1 downto 0);

   vs_out       : out std_logic;
   hs_out       : out std_logic;
   de_out       : out std_logic;
   v_count_out  : out std_logic_vector(Y_BITS downto 0);
   h_count_out  : out std_logic_vector(X_BITS-1 downto 0);
   x_out        : out std_logic_vector(X_BITS-1 downto 0);
   y_out        : out std_logic_vector(Y_BITS downto 0);
   field_out    : out std_logic;
   clk_out      : out std_logic
  );
end component;

component pattern_vg
  generic(
    B               : integer := 8;
    X_BITS          : integer := 12;
    Y_BITS          : integer := 12;
    FRACTIONAL_BITS : integer := 12
  );
  port (
    reset               : in std_logic;
    clk_in              : in std_logic;
    x                   : in std_logic_vector(X_BITS-1 downto 0);
    y                   : in std_logic_vector(Y_BITS-1 downto 0);
    vn_in               : in std_logic;
    hn_in               : in std_logic;
    dn_in               : in std_logic;
    r_in                : in std_logic_vector(B-1 downto 0);
    g_in                : in std_logic_vector(B-1 downto 0);
    b_in                : in std_logic_vector(B-1 downto 0);

    vn_out              : out std_logic;
    hn_out              : out std_logic;
    den_out             : out std_logic;
    r_out               : out std_logic_vector(B-1 downto 0);
    g_out               : out std_logic_vector(B-1 downto 0);
    b_out               : out std_logic_vector(B-1 downto 0);

    total_active_pix    : in std_logic_vector(X_BITS-1 downto 0);
    total_active_lines  : in std_logic_vector(Y_BITS-1 downto 0);
    pattern             : in std_logic_vector(7 downto 0);
    ramp_step           : in std_logic_vector(B+FRACTIONAL_BITS-1 downto 0)
  );
end component;

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
  
constant c_interlaced   : std_logic := '0';
constant c_v_total_0    : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(750,12));
constant c_v_fp_0       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(5,12));
constant c_v_bp_0       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(20,12));
constant c_v_sync_0     : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(5,12));
constant c_v_total_1    : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_v_fp_1       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_v_bp_1       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_v_sync_1     : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_h_total      : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(1650,12));
constant c_h_fp         : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(110,12));
constant c_h_bp         : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(220,12));
constant c_h_sync       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(40,12));
constant c_hv_offset_0  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_hv_offset_1  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0,12));
constant c_ramp_step    : std_logic_vector(19 downto 0) := x"00333";
constant c_pattern_type : std_logic_vector(7 downto 0) := x"04";

constant c_active_pix : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(1650-110-220-40,12));
constant c_active_lin : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(750-5-20-5,12));

signal rst_pll_25   : std_logic;
signal rst_pll_25_n : std_logic;
signal rst_pll_50   : std_logic;
signal rst_pll_50_n : std_logic;

signal clk_pll_25  : std_logic;
signal clk_pll_50  : std_logic;
signal clk_pll_125 : std_logic;
signal pll_locked  : std_logic;

signal hs       : std_logic;
signal vs       : std_logic;
signal de       : std_logic;
signal hs_out   : std_logic;
signal vs_out   : std_logic;
signal de_out   : std_logic;
signal x_out    : std_logic_vector(11 downto 0);
signal y_out    : std_logic_vector(12 downto 0);
signal r_out    : std_logic_vector(7 downto 0);
signal g_out    : std_logic_vector(7 downto 0);
signal b_out    : std_logic_vector(7 downto 0);
signal field    : std_logic;

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


-- i_sync_vg: sync_vg
-- port map(
   -- clk          => clk_pll_25,
   -- reset        => rst_pll_25,

   -- interlaced   => c_interlaced,
   -- v_total_0    => c_v_total_0,
   -- v_fp_0       => c_v_fp_0,
   -- v_bp_0       => c_v_bp_0,
   -- v_sync_0     => c_v_sync_0,
   -- v_total_1    => c_v_total_1,
   -- v_fp_1       => c_v_fp_1,
   -- v_bp_1       => c_v_bp_1,
   -- v_sync_1     => c_v_sync_1,
   -- h_total      => c_h_total,
   -- h_fp         => c_h_fp,
   -- h_bp         => c_h_bp,
   -- h_sync       => c_h_sync,
   -- hv_offset_0  => c_hv_offset_0,
   -- hv_offset_1  => c_hv_offset_1,

   -- vs_out       => vs,
   -- hs_out       => hs,
   -- de_out       => de,
   -- v_count_out  => open,
   -- h_count_out  => open,
   -- x_out        => x_out,
   -- y_out        => y_out,
   -- field_out    => field,
   -- clk_out      => open
  -- );

-- i_pattern_vg: pattern_vg
-- port map(
  -- clk_in      => clk_pll_25,
  -- reset       => rst_pll_25,

  -- x           => x_out,
  -- y           => y_out(11 downto 0),
  -- vn_in       => vs,
  -- hn_in       => hs,
  -- dn_in       => de,
  -- r_in        => x"10",
  -- g_in        => x"40",
  -- b_in        => x"80",

  -- vn_out      => vs_out,
  -- hn_out      => hs_out,
  -- den_out     => de_out,
  -- r_out       => r_out,
  -- g_out       => g_out,
  -- b_out       => b_out,

  -- total_active_pix    => c_active_pix,
  -- total_active_lines  => c_active_lin,
  -- pattern             => c_pattern_type,
  -- ramp_step           => c_ramp_step
-- );

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

i_i2c_hdmi_config: i2c_hdmi_config
  generic map(
    CLK_Freq    => 50_000_000,
    I2C_Freq    =>     20_000
  )
  port map (
    iCLK        => clk_pll_25,
    iRST_N      => rst_pll_25_n,
    
    I2C_SCLK    => HDMI_I2C_SCL,
    I2C_SDAT    => HDMI_I2C_SDA,
    HDMI_TX_INT => HDMI_TX_INT,
    READY       => i2c_rdy
);

--! register outputs
-- p_driver: process (clk_pll_25, rst_pll_25)
  -- variable v_cnt : unsigned(24 downto 0);
-- begin
  -- if rst_pll_25 = '1' then
    -- HDMI_TX_D                   <= ( others => '0');
    -- HDMI_TX_HS                  <= '0';
    -- HDMI_TX_VS                  <= '0';
    -- HDMI_TX_DE                  <= '0';
  -- elsif rising_edge(clk_pll_25) then
    -- HDMI_TX_D(3*8-1 downto 2*8) <= r_out ;
    -- HDMI_TX_D(2*8-1 downto 1*8) <= g_out ;
    -- HDMI_TX_D(1*8-1 downto 0*8) <= b_out ;
    -- HDMI_TX_HS                  <= hs_out;
    -- HDMI_TX_VS                  <= vs_out;
    -- HDMI_TX_DE                  <= de_out;
  -- end if;
-- end process p_driver;

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