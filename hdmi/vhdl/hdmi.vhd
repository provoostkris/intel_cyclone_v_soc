------------------------------------------------------------------------------
--  TOP level design file for HDMI controller <> Terrasic DE10 nano Cyclone 5 design
--  rev. 1.0 : 2020 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

entity hdmi is
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

component hdmi_pll is
  port (
    refclk   : in  std_logic;        -- clk
    rst      : in  std_logic;        -- reset
    outclk_0 : out std_logic;        -- clk
    outclk_1 : out std_logic;        -- clk
    locked   : out std_logic         -- export
  );
end component hdmi_pll;

signal rst_pll_25    : std_logic;
signal rst_pll_25_n  : std_logic;
signal rst_pll_50    : std_logic;
signal rst_pll_50_n  : std_logic;
signal rst_pll_40    : std_logic;
signal rst_pll_40_n  : std_logic;
signal rst_pll_65    : std_logic;
signal rst_pll_65_n  : std_logic;

signal clk_pll_25       : std_logic;
signal clk_pll_50       : std_logic;
signal clk_pll_125      : std_logic;
signal clk_pll_40       : std_logic;
signal clk_pll_65       : std_logic;
signal pll_locked       : std_logic;
signal hdmi_pll_locked  : std_logic;

-- now select the pixel clock/reset depending on the resolution
alias clk_pixel   : std_logic is clk_pll_40;
alias rst_pixel   : std_logic is rst_pll_40;
alias rst_pixel_n : std_logic is rst_pll_40_n;


-- local signals
constant OBJECT_SIZE  : natural := 16;
constant PIXEL_SIZE   : natural := 24;
constant ram_d        : natural := 3*3;
constant ram_x        : natural := 8;
constant ram_y        : natural := 8;

signal video_active   : std_logic;
signal pixel_x        : std_logic_vector(OBJECT_SIZE-1 downto 0);
signal pixel_y        : std_logic_vector(OBJECT_SIZE-1 downto 0);
signal ram_wr_ena     : std_logic;
signal ram_wr_dat     : std_logic_vector(ram_d-1 downto 0);
signal ram_wr_add     : std_logic_vector(ram_x+ram_y-1 downto 0);

signal i2c_rdy        : std_logic;
signal i2c_hold       : std_logic;
  
signal hdmi_hold      : std_logic;
signal key_db         : std_logic_vector(1 downto 0);
signal sw_db          : std_logic_vector(3 downto 0);

-- signal that need to drive the HDcontroller
type   t_a_std      is array ( integer range <> ) of std_logic;
type   t_a_slv_24   is array ( integer range <> ) of std_logic_vector(23 downto 0);

signal clk_out      : std_logic;
signal hs_out       : std_logic;
signal vs_out       : std_logic;
signal de_out       : std_logic;
signal rgb          : std_logic_vector(23 downto 0);


begin

--! top level assigments
led(1)                  <= i2c_rdy;
led(2)                  <= i2c_hold;
led(3)                  <= hdmi_hold;
led(4)                  <= sw_db(0);
led(5)                  <= sw_db(1);
led(6)                  <= sw_db(2);
led(7)                  <= sw_db(3);

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

--! syncronous resets
p_rst_pll_40: process (clk_pll_40, hdmi_pll_locked)
begin
  if hdmi_pll_locked = '0' then
    rst_pll_40   <= '1';
    rst_pll_40_n <= '0';
  elsif rising_edge(clk_pll_40) then
    rst_pll_40   <= '0';
    rst_pll_40_n <= '1';
  end if;
end process p_rst_pll_40;

--! syncronous resets
p_rst_pll_65 : process (clk_pll_65 , hdmi_pll_locked)
begin
  if hdmi_pll_locked = '0' then
    rst_pll_65    <= '1';
    rst_pll_65_n  <= '0';
  elsif rising_edge(clk_pll_65 ) then
    rst_pll_65    <= '0';
    rst_pll_65_n  <= '1';
  end if;
end process p_rst_pll_65 ;

--! general purpose pll, generate some clocks
i_pll : pll
  port map (
    refclk   => FPGA_CLK1_50,
    rst      => SW(0),
    outclk_0 => clk_pll_25,       --!  25 MHz
    outclk_1 => clk_pll_50,       --!  50 MHz
    outclk_2 => clk_pll_125,      --! 125 MHz
    locked   => pll_locked
  );

--! pll approximating HD resolution frequencies
i_hdmi_pll : hdmi_pll
  port map (
    refclk   => FPGA_CLK1_50,
    rst      => SW(0),
    outclk_0 => clk_pll_40,        --!  40 MHz
    outclk_1 => clk_pll_65 ,       --!  148.5 MHz
    locked   => hdmi_pll_locked
  );


--! get rid of the bounce
p_bounce: process (clk_pll_25, rst_pll_25)
  variable v_cnt   : unsigned(20 downto 0);
  variable v_sw_0  : std_logic_vector( 7 downto 0);
  variable v_sw_1  : std_logic_vector( 7 downto 0);
  variable v_sw_2  : std_logic_vector( 7 downto 0);
  variable v_sw_3  : std_logic_vector( 7 downto 0);
  variable v_key_0 : std_logic_vector( 7 downto 0);
  variable v_key_1 : std_logic_vector( 7 downto 0);
begin
  if rst_pll_25 = '1' then
    v_cnt   := ( others => '0');
    v_sw_0  := ( others => '0');
    v_sw_1  := ( others => '0');
    v_sw_2  := ( others => '0');
    v_sw_3  := ( others => '0');
    v_key_0 := ( others => '0');
    v_key_1 := ( others => '0');
    sw_db   <= ( others => '0');
    key_db  <= ( others => '0');
  elsif rising_edge(clk_pll_25) then
    v_cnt    := v_cnt + 1;
    if or_reduce(std_logic_vector(v_cnt)) = '1' then
      v_sw_0  := v_sw_0 (v_sw_0'high-1 downto 0)   & SW(0);
      v_sw_1  := v_sw_1 (v_sw_1'high-1 downto 0)   & SW(1);
      v_sw_2  := v_sw_2 (v_sw_2'high-1 downto 0)   & SW(2);
      v_sw_3  := v_sw_3 (v_sw_3'high-1 downto 0)   & SW(3);
      v_key_0 := v_key_0(v_key_0'high-1 downto 0)  & KEY(0);
      v_key_1 := v_key_1(v_key_1'high-1 downto 0)  & KEY(1);
    end if;
    sw_db(0)  <= or_reduce(v_sw_0 );
    sw_db(1)  <= or_reduce(v_sw_1 );
    sw_db(2)  <= or_reduce(v_sw_2 );
    sw_db(3)  <= or_reduce(v_sw_3 );
    key_db(0) <= or_reduce(v_key_0);
    key_db(1) <= or_reduce(v_key_1);
  end if;
end process p_bounce;

--!
--! implementation (0)
--!
gen_imp_0: if g_imp = 0 generate

  i_vgaHdmi: vgaHdmi
    port map(
    clock      => clk_pixel,
    clock50    => clk_pll_50,
    reset      => rst_pixel,

    switchR    => sw_db(1),
    switchG    => sw_db(2),
    switchB    => sw_db(3),

    hsync      => hs_out,
    vsync      => vs_out,
    dataEnable => de_out,
    vgaClock   => clk_out,
    RGBchannel => rgb
  );
  
end generate;

--!
--! implementation (1)
--!

gen_imp_1: if g_imp = 1 generate

  i_timing_generator: entity work.timing_generator(rtl)
    generic map (
      RESOLUTION  => "SVGA",
      GEN_PIX_LOC => true,
      OBJECT_SIZE => OBJECT_SIZE
      )
    port map (
      rst           => rst_pixel,
      clk           => clk_pixel,
      hsync         => hs_out,
      vsync         => vs_out,
      video_active  => video_active,
      pixel_x       => pixel_x,
      pixel_y       => pixel_y
    );

  i_pattern_generator: entity work.pattern_generator(rtl)
    port map (
      rst           =>  rst_pixel,
      clk           =>  clk_pixel,
      video_active  =>  video_active,
      rgb           =>  rgb
      );

  de_out  <= video_active;
  clk_out <= not clk_pll_40;

end generate;

--!
--! implementation (2)
--!

gen_imp_2: if g_imp = 2 generate

  i_timing_generator: entity work.timing_generator(rtl)
    generic map (
      RESOLUTION  => "SVGA",
      GEN_PIX_LOC => true,
      OBJECT_SIZE => OBJECT_SIZE
      )
    port map (
      rst           => rst_pixel,
      clk           => clk_pixel,
      hsync         => hs_out,
      vsync         => vs_out,
      video_active  => video_active,
      pixel_x       => pixel_x,
      pixel_y       => pixel_y
    );
    
  --! video_ram instance
  i_video_ram: entity work.video_ram(rtl)
    generic map (
      RESOLUTION  => "SVGA",
      OBJECT_SIZE => OBJECT_SIZE,
      PIXEL_SIZE  => PIXEL_SIZE,
      ram_d => ram_d,
      ram_x => ram_x,
      ram_y => ram_y
      )
    port map (
      rst=>rst_pixel,
      pixclk=>clk_pixel,
      video_active=>video_active,
      pixel_x=>pixel_x,
      pixel_y=>pixel_y,
      ram_wr_ena=>ram_wr_ena,
      ram_wr_dat=>ram_wr_dat,
      ram_wr_add=>ram_wr_add,
      rgb=>rgb
      );

  -- dummy data generator
  process(rst_pixel, clk_pixel) is
    variable v_cnt  : unsigned(PIXEL_SIZE-1 downto 0);
  begin
      if rst_pixel='1' then
          ram_wr_add <= ( others => '0');
          ram_wr_dat <= ( others => '0');
          ram_wr_ena <= '1';
          v_cnt      := ( others => '0');
      elsif rising_edge(clk_pixel) then
          v_cnt      := v_cnt + 1 ;
          ram_wr_add <= std_logic_vector(v_cnt(ram_wr_add'range));
          ram_wr_dat <= std_logic_vector(v_cnt(ram_wr_dat'range));
          ram_wr_ena <= '1';
      end if;
  end process;

  de_out  <= video_active;
  clk_out <= not clk_pll_40;

end generate;

--!
--! drive outputs
--!

  p_driver: process (clk_pixel, rst_pixel_n)
  begin
    if rst_pixel_n = '0' then
      HDMI_TX_D                   <= ( others => '0');
      HDMI_TX_HS                  <= '1';
      HDMI_TX_VS                  <= '1';
      HDMI_TX_DE                  <= '0';
    elsif rising_edge(clk_pixel) then
      HDMI_TX_D                   <= rgb;
      HDMI_TX_HS                  <= hs_out;
      HDMI_TX_VS                  <= vs_out;
      HDMI_TX_DE                  <= de_out;
    end if;
  end process p_driver;

  -- select the clock when reset is done
  HDMI_TX_CLK <= not clk_pixel and rst_pixel_n;

--!
--! setup for the registers in the HDMI controller
--!

--! the i2c has to wait > 200 ms before acessing the bus
--! we will also wait a moment for the i2c to complete after reset
p_wait: process (clk_pll_25, rst_pll_25)
  variable v_cnt : unsigned(24 downto 0);
  variable v_del : unsigned(25 downto 0);
begin
  if rst_pll_25 = '1' then
    i2c_hold  <= '0';
    hdmi_hold <= '0';
    v_cnt     := ( others => '0');
    v_del     := ( others => '0');
  elsif rising_edge(clk_pll_25) then
    v_cnt     := v_cnt + 1;
    v_del     := v_del + 1;
    i2c_hold  <= v_cnt(v_cnt'high) or i2c_hold;
    hdmi_hold <= v_del(v_del'high) or hdmi_hold;
  end if;
end process p_wait;

--! the actual controller
i_i2c_hdmi_config: i2c_hdmi_config
  generic map(
    CLK_Freq    => 50_000_000,
    I2C_Freq    =>     20_000
  )
  port map (
    iCLK        => clk_pll_50,
    iRST_N      => i2c_hold,

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
    v_cnt    := ( others => '0');
  elsif rising_edge(clk_pll_25) then
    led(0)   <= v_cnt(v_cnt'high);
    v_cnt    := v_cnt + 1;
  end if;
end process p_led;

end architecture rtl;