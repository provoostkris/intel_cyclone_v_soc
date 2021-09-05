------------------------------------------------------------------------------
--  TOP level design file for heat camera <> Terrasic DE10 nano Cyclone 5 design
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

entity heat_cam is
  generic (
    g_tst_mode  : boolean := false ;
    g_s_addr    : natural :=  6;--! size of address
    g_s_data    : natural := 16;--! size of data
    g_int_f     : natural :=  4;--! interpolation factor ( in 2**n)
    g_arr_init  : boolean := false;
    input_clk   : integer := 25_000_000; --input clock speed from user logic in hz
    bus_clk     : integer := 400_000     --speed the i2c bus (scl) will run at in hz
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
    HDMI_TX_DE        : out std_logic;
    -- AMG8833
    AMG_I2C_SCL       : inout std_logic; -- i2c
    AMG_I2C_SDA       : inout std_logic -- i2c
  );
end;

architecture rtl of heat_cam is

--! definition of the verilog modules
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

type     t_dummy_ram is array ( 0 to 63 ) of integer range 0 to 2**16-1 ;
constant c_dummy_ram : t_dummy_ram :=
  (
        0,2**15, 2**15,2**15, 2**15,2**15, 2**15,    0,
    2**15,2**15, 2**15,2**15, 2**15,2**15, 2**15,2**15,

    2**15,2**15, 2**7 ,2**15, 2**15,2**7 , 2**15,2**15,
    2**15,2**15, 2**15,2**15, 2**15,2**15, 2**15,2**15,

    2**15,2**15, 2**15,2**15, 2**15,2**15, 2**15,2**15,
    2**15,2**15, 2**7 ,2**15, 2**15,2**7 , 2**15,2**15,

    2**15,2**15, 2**15,2**15, 2**15,2**15, 2**15,2**15,
        0,2**15, 2**15,2**15, 2**15,2**15, 2**15,    0
  );


signal rst_pll_25     : std_logic;
signal rst_pll_25_n   : std_logic;
signal rst_pll_40     : std_logic;
signal rst_pll_40_n   : std_logic;
signal rst_pll_50     : std_logic;
signal rst_pll_50_n   : std_logic;

signal clk_pll_25     : std_logic;
signal clk_pll_40     : std_logic;
signal clk_pll_50     : std_logic;


-- now select the pixel clock/reset depending on the resolution
alias clk_pixel   : std_logic is clk_pll_40;
alias rst_pixel   : std_logic is rst_pll_40;
alias rst_pixel_n : std_logic is rst_pll_40_n;

-- local signals
signal pll_locked     : std_logic;
signal ena            : std_logic;                    --latch in command
signal addr           : std_logic_vector(6 downto 0); --address of target slave
signal rw             : std_logic;                    --'0' is write, '1' is read
signal data_wr        : std_logic_vector(7 downto 0); --data to write to slave
signal busy           : std_logic;                    --indicates transaction in progress
signal data_rd        : std_logic_vector(7 downto 0); --data read from slave
signal ack_error      : std_logic;                    --flag if improper acknowledge from slave

signal raw_wr_ena    : std_logic;
signal raw_wr_add    : std_logic_vector(g_s_addr-1 downto 0);
signal raw_wr_dat    : std_logic_vector(g_s_data-1 downto 0);
signal int_rd_ena    : std_logic;
signal int_rd_add    : std_logic_vector(g_s_addr+(2*g_int_f)-1 downto 0);
signal int_rd_dat    : std_logic_vector(g_s_data-1 downto 0);

-- local signals HDMI controller
constant OBJECT_SIZE  : natural := 16;
constant c_pixel_size : natural := 24;    -- bit size for one pixel color (in RGB)  
constant ram_d        : natural := 3*8;   -- in multiples of 3 ( N  bits for each color)
constant ram_x        : natural := g_s_addr/2+g_int_f;
constant ram_y        : natural := g_s_addr/2+g_int_f;

signal video_active   : std_logic;
signal pixel_x        : std_logic_vector(OBJECT_SIZE-1 downto 0);
signal pixel_y        : std_logic_vector(OBJECT_SIZE-1 downto 0);
signal ram_wr_ena     : std_logic;
signal ram_wr_dat     : std_logic_vector(ram_d-1 downto 0);
signal ram_wr_add     : std_logic_vector(g_s_addr+(2*g_int_f)-1 downto 0);

signal i2c_rdy        : std_logic;
signal i2c_hold       : std_logic;

-- signal that need to drive the HDMI controller
signal hs_out       : std_logic;
signal vs_out       : std_logic;
signal de_out       : std_logic;
signal rgb          : std_logic_vector(23 downto 0);

begin

--! top level assigments
led(1)                  <= i2c_rdy;
led(2)                  <= i2c_hold;
led(3)                  <= clk_pll_40;
led(4)                  <= SW(0);
led(5)                  <= SW(1);
led(6)                  <= SW(2);
led(7)                  <= SW(3);

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


gen_live_mode: if g_tst_mode = false generate

  --!
  --! adding the i2c master
  --!
  i_i2c_master: entity work.i2c_master
    generic map(
      input_clk => input_clk,              --input clock speed from user logic in hz
      bus_clk   => bus_clk                 --speed the i2c bus (scl) will run at in hz
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
    generic map(
      g_s_addr    => g_s_addr ,
      g_s_data    => g_s_data ,
      g_arr_init  => g_arr_init
    )
    port map(
      clk           => clk_pll_25      ,        --system clock
      reset_n       => rst_pll_25_n    ,        --active low reset
      swap_byte     => SW(1)           ,        --swap pixel bytes
      ena           => ena             ,        --latch in command
      addr          => addr            ,        --address of target slave
      rw            => rw              ,        --'0' is write, '1' is read
      data_wr       => data_wr         ,        --data to write to slave
      busy          => busy            ,        --indicates transaction in progress
      data_rd       => data_rd         ,        --data read from slave
      ack_error     => ack_error       ,        --flag if improper acknowledge from slave
      raw_wr_ena    => raw_wr_ena      ,
      raw_wr_add    => raw_wr_add      ,
      raw_wr_dat    => raw_wr_dat
      );

end generate gen_live_mode;


gen_test_mode: if g_tst_mode = true generate
  -- or generate some data pattern from a 8x8 ROM
  -- note this only works for 8x8 raw configuration for test purpose
  process(rst_pixel, clk_pixel) is
    variable v_cnt  : unsigned(g_s_addr-1 downto 0);
  begin
      if rst_pll_25_n='0' then
          raw_wr_add <= ( others => '0');
          raw_wr_dat <= ( others => '0');
          raw_wr_ena <= '0';
          v_cnt      := ( others => '0');
      elsif rising_edge(clk_pll_25) then-- send pixel rom to video ram
          raw_wr_add <= std_logic_vector(v_cnt);
          raw_wr_dat <= std_logic_vector(to_unsigned(c_dummy_ram(to_integer(v_cnt)),g_s_data));
          raw_wr_ena <= '1';
          -- go to next pixel
          v_cnt      := v_cnt + 1 ;
      end if;
  end process;
end generate gen_test_mode;

--!
--! interpolate the sensor values
--!
i_interpolate: entity work.interpolate_ram(rtl)
  generic map(
    g_s_addr => g_s_addr ,
    g_s_data => g_s_data ,
    g_int_f  => g_int_f
  )
  port map(
    clk           =>  clk_pll_25    ,
    reset_n       =>  rst_pll_25_n  ,
    raw_wr_ena    =>  raw_wr_ena    ,
    raw_wr_add    =>  raw_wr_add    ,
    raw_wr_dat    =>  raw_wr_dat    ,
    int_rd_ena    =>  int_rd_ena    ,
    int_rd_add    =>  int_rd_add    ,
    int_rd_dat    =>  int_rd_dat
  );

  -- transfer data from interpolator to HDMI controller
  process(rst_pll_25_n, clk_pll_25) is
    variable v_cnt  : unsigned(g_s_addr+(2*g_int_f)-1 downto 0);
  begin
      if rst_pll_25_n='0' then
          int_rd_add <= ( others => '0');
          int_rd_ena <= '0';
          ram_wr_add <= ( others => '0');
          ram_wr_dat <= ( others => '0');
          v_cnt      := ( others => '0');
      elsif rising_edge(clk_pll_25) then
          v_cnt      := v_cnt + 1 ;
          int_rd_add <= std_logic_vector(v_cnt(int_rd_add'range));
          int_rd_ena <= '1';
          -- send pixel data to video ram
          ram_wr_add <= int_rd_add;
          ram_wr_ena <= int_rd_ena;
          -- for now just map the data
          -- later a mapping to the R-G-B values must happen
          ram_wr_dat(int_rd_dat'range) <= int_rd_dat;
          ram_wr_dat(ram_wr_dat'high downto int_rd_dat'high) <= ( others => '0');
      end if;
  end process;
  
--!
--! generate video timing
--!
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

--!
--! video ram
--!
  i_video_ram: entity work.video_ram(rtl)
    generic map (
      RESOLUTION  => "SVGA",
      OBJECT_SIZE => OBJECT_SIZE,
      PIXEL_SIZE  => c_pixel_size,
      ram_d       => ram_d,
      ram_x       => ram_x,
      ram_y       => ram_y
      )
    port map (
      rst         =>rst_pixel,
      pixclk      =>clk_pixel,
      video_active=>video_active,
      pixel_x     =>pixel_x,
      pixel_y     =>pixel_y,
      ram_wr_clk  =>clk_pll_25,
      ram_wr_ena  =>ram_wr_ena,
      ram_wr_dat  =>ram_wr_dat,
      ram_wr_add  =>ram_wr_add,
      rgb         =>rgb
      );

  de_out  <= video_active;

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
    v_cnt     := ( others => '0');
    v_del     := ( others => '0');
  elsif rising_edge(clk_pll_25) then
    v_cnt     := v_cnt + 1;
    v_del     := v_del + 1;
    i2c_hold  <= v_cnt(v_cnt'high) or i2c_hold;
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