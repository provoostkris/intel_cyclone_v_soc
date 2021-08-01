-- AN-1270
-- ADV7511-/ADV7511W-/ADV7513-Based Video Generators
-- By Witold Kaczurba
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
    adv7511_hs        : out std_logic; -- HS output to ADV7513
    adv7511_vs        : out std_logic; -- VS output to ADV7513
    adv7511_clk       : out std_logic; -- ADV7513: CLK
    adv7511_d         : out std_logic_vector(35 downto 0);-- data
    adv7511_de        : out std_logic
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

signal hdmi_rst   : std_logic;
signal hdmi_clk   : std_logic;
signal pll_locked : std_logic;

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

begin

hdmi_rst <= not pll_locked;

i_pll : pll
  port map (
    refclk   => FPGA_CLK1_50,
    rst      => SW(0),
    outclk_0 => hdmi_clk,
    outclk_1 => open,
    outclk_2 => open,
    locked   => pll_locked
  );


i_sync_vg: sync_vg
port map(

   clk          => hdmi_clk,
   reset        => hdmi_rst,

   interlaced   => c_interlaced,
   v_total_0    => c_v_total_0,
   v_fp_0       => c_v_fp_0,
   v_bp_0       => c_v_bp_0,
   v_sync_0     => c_v_sync_0,
   v_total_1    => c_v_total_1,
   v_fp_1       => c_v_fp_1,
   v_bp_1       => c_v_bp_1,
   v_sync_1     => c_v_sync_1,
   h_total      => c_h_total,
   h_fp         => c_h_fp,
   h_bp         => c_h_bp,
   h_sync       => c_h_sync,
   hv_offset_0  => c_hv_offset_0,
   hv_offset_1  => c_hv_offset_1,

   vs_out       => vs,
   hs_out       => hs,
   de_out       => de,
   v_count_out  => open,
   h_count_out  => open,
   x_out        => x_out,
   y_out        => y_out,
   field_out    => field,
   clk_out      => open
  );

i_pattern_vg: pattern_vg
port map(

  clk_in      => hdmi_clk,
  reset       => hdmi_rst,

  x           => x_out,
  y           => y_out(11 downto 0),
  vn_in       => vs,
  hn_in       => hs,
  dn_in       => de,
  r_in        => x"00",
  g_in        => x"00",
  b_in        => x"00",

  vn_out      => vs_out,
  hn_out      => hs_out,
  den_out     => de_out,
  r_out       => r_out,
  g_out       => g_out,
  b_out       => b_out,

  total_active_pix    => c_active_pix,
  total_active_lines  => c_active_lin,
  pattern             => c_pattern_type,
  ramp_step           => c_ramp_step
);

--! register outputs
p_driver: process (hdmi_clk, hdmi_rst)
  variable v_cnt : unsigned(24 downto 0);
begin
  if hdmi_rst = '1' then
    adv7511_d        <= ( others => '0');
    adv7511_hs       <= '0';
    adv7511_vs       <= '0';
    adv7511_de       <= '0';
  elsif rising_edge(hdmi_clk) then
    adv7511_d(3*12-1 downto 2*12) <= r_out & "0000";
    adv7511_d(2*12-1 downto 1*12) <= g_out & "0000";
    adv7511_d(1*12-1 downto 0*12) <= b_out & "0000";
    adv7511_hs              <= hs_out;
    adv7511_vs              <= vs_out;
    adv7511_de              <= de_out;
  end if;
end process p_driver;

--! just blink LED to see activity
p_led: process (hdmi_clk, hdmi_rst)
  variable v_cnt : unsigned(24 downto 0);
begin
  if hdmi_rst = '1' then
    led(0)   <= '0';
    v_cnt    := ( others => '1');
  elsif rising_edge(hdmi_clk) then
    led(0)   <= v_cnt(v_cnt'high);
    v_cnt    := v_cnt + 1;
  end if;
end process p_led;

end architecture rtl;