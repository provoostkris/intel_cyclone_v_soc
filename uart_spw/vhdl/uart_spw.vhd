------------------------------------------------------------------------------
--  TOP level design file for uart_spw <> Terrasic DE10 nano Cyclone 5 design
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

library work;
use     work.SpaceWireCODECIPPackage.all;

entity uart_spw is
  GENERIC(
      CLKFREQ    : integer := 50e6; -- 50 Mhz clock
      BAUDRATE   : integer := 115200;
      DATA_WIDTH : integer := 8;
      PARITY     : string  := "NONE"; -- NONE, EVEN, ODD
      STOP_WIDTH : integer := 1
    );
  port (
    FPGA_CLK1_50      : in    std_ulogic; --! FPGA clock 1 input 50 MHz
    FPGA_CLK2_50      : in    std_ulogic; --! FPGA clock 2 input 50 MHz
    FPGA_CLK3_50      : in    std_ulogic; --! FPGA clock 3 input 50 MHz
    -- Buttons & LEDs
    KEY               : in    std_logic_vector(1 downto 0); --! Push button - debounced
    SW                : in    std_logic_vector(3 downto 0); --! Slide button
    Led               : out   std_logic_vector(7 downto 0); --! indicators
    -- external interface signals
    rxd               : in  std_logic;
    txd               : out std_logic
  );
end;

architecture rtl of uart_spw is


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

--! UART ports
signal m_axis_tready        : std_logic;
signal m_axis_tdata         : std_logic_vector(DATA_WIDTH-1 downto 0);
signal m_axis_tvalid        : std_logic;
signal s_axis_tvalid        : std_logic;
signal s_axis_tdata         : std_logic_vector(DATA_WIDTH-1 downto 0);
signal s_axis_tready        : std_logic;

--! SPW ports
signal spw_0_clock                       : std_logic;
signal spw_0_transmitClock               : std_logic;
signal spw_0_receiveClock                : std_logic;
signal spw_0_reset                       : std_logic;
signal spw_0_transmitFIFOWriteEnable     : std_logic;
signal spw_0_transmitFIFODataIn          : std_logic_vector(8 downto 0);
signal spw_0_transmitFIFOFull            : std_logic;
signal spw_0_transmitFIFODataCount       : std_logic_vector(5 downto 0);
signal spw_0_receiveFIFOReadEnable       : std_logic;
signal spw_0_receiveFIFODataOut          : std_logic_vector(8 downto 0);
signal spw_0_receiveFIFOFull             : std_logic;
signal spw_0_receiveFIFOEmpty            : std_logic;
signal spw_0_receiveFIFODataCount        : std_logic_vector(5 downto 0);
signal spw_0_tickIn                      : std_logic;
signal spw_0_timeIn                      : std_logic_vector(5 downto 0);
signal spw_0_controlFlagsIn              : std_logic_vector(1 downto 0);
signal spw_0_tickOut                     : std_logic;
signal spw_0_timeOut                     : std_logic_vector(5 downto 0);
signal spw_0_controlFlagsOut             : std_logic_vector(1 downto 0);
signal spw_0_linkStart                   : std_logic;
signal spw_0_linkDisable                 : std_logic;
signal spw_0_autoStart                   : std_logic;
signal spw_0_linkStatus                  : std_logic_vector(15 downto 0);
signal spw_0_errorStatus                 : std_logic_vector(7 downto 0);
signal spw_0_transmitClockDivideValue    : std_logic_vector(5 downto 0);
signal spw_0_creditCount                 : std_logic_vector(5 downto 0);
signal spw_0_outstandingCount            : std_logic_vector(5 downto 0);
signal spw_0_transmitActivity            : std_logic;
signal spw_0_receiveActivity             : std_logic;
signal spw_0_spaceWireDataOut            : std_logic;
signal spw_0_spaceWireStrobeOut          : std_logic;
signal spw_0_spaceWireDataIn             : std_logic;
signal spw_0_spaceWireStrobeIn           : std_logic;
signal spw_0_statisticalInformationClear : std_logic;
signal spw_0_statisticalInformation      : bit32X8Array;

begin

--! top level assigments
led(1)                  <= or_reduce(KEY);
led(2)                  <= or_reduce(SW);
led(3)                  <= pll_locked;
led(4)                  <= '1';
led(5)                  <= '0';
led(6)                  <= '0';
led(7)                  <= '1';

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

i_uart : entity work.uart
  generic map (
    CLKFREQ         => CLKFREQ,
    BAUDRATE        => BAUDRATE,
    DATA_WIDTH      => DATA_WIDTH,
    PARITY          => PARITY,
    STOP_WIDTH      => STOP_WIDTH
  )
  port map(
    clk             => clk_pll_50,
    rxd             => rxd,
    txd             => txd,
    m_axis_tvalid   => m_axis_tvalid,
    m_axis_tdata    => m_axis_tdata,
    m_axis_tready   => m_axis_tready,
    s_axis_tvalid   => s_axis_tvalid,
    s_axis_tdata    => s_axis_tdata,
    s_axis_tready   => s_axis_tready
  );

--!
--! spacewire codec assignments
--!
--clocks
spw_0_clock                       <= clk_pll_50;
spw_0_reset                       <= rst_pll_50;

spw_0_transmitClock               <= clk_pll_50;
spw_0_receiveClock                <= clk_pll_50;
--no time code
spw_0_tickIn                      <= '0';
spw_0_timeIn                      <= ( others => '0');
spw_0_controlFlagsIn              <= ( others => '0');
-- start enabled              
spw_0_linkStart                   <= '1';
spw_0_linkDisable                 <= '0';
spw_0_autoStart                   <= '1';
-- configuration
spw_0_statisticalInformationClear <= '0';
spw_0_transmitClockDivideValue    <= std_logic_vector(to_unsigned(4,spw_0_transmitClockDivideValue'length));
--loop
spw_0_spaceWireDataIn             <= spw_0_spaceWireDataOut;
spw_0_spaceWireStrobeIn           <= spw_0_spaceWireStrobeOut;
--TX FIFO interface
spw_0_transmitFIFOWriteEnable     <= m_axis_tvalid;
spw_0_transmitFIFODataIn          <= '0' & m_axis_tdata;
m_axis_tready                     <= not spw_0_transmitFIFOFull;
--RX FIFO interface
p_s_axis_tvalid: process (spw_0_clock, spw_0_reset)
begin
  if spw_0_reset = '1' then
    s_axis_tvalid                 <= '0';
  elsif rising_edge(spw_0_clock) then
    s_axis_tvalid                 <= not spw_0_receiveFIFOEmpty and s_axis_tready;
  end if;
end process p_s_axis_tvalid;
s_axis_tdata                      <= spw_0_receiveFIFODataOut(7 downto 0);
spw_0_receiveFIFOReadEnable       <= s_axis_tready;

--! spacewire codec
i_spw: entity work.SpaceWireCODECIP(Behavioral)
  port map (
    clock                               =>  spw_0_clock                         ,
    transmitClock                       =>  spw_0_transmitClock                 ,
    receiveClock                        =>  spw_0_receiveClock                  ,
    reset                               =>  spw_0_reset                         ,
    
    transmitFIFOWriteEnable             =>  spw_0_transmitFIFOWriteEnable       ,
    transmitFIFODataIn                  =>  spw_0_transmitFIFODataIn            ,
    transmitFIFOFull                    =>  spw_0_transmitFIFOFull              ,
    transmitFIFODataCount               =>  spw_0_transmitFIFODataCount         ,
    
    receiveFIFOReadEnable               =>  spw_0_receiveFIFOReadEnable         ,
    receiveFIFODataOut                  =>  spw_0_receiveFIFODataOut            ,
    receiveFIFOFull                     =>  spw_0_receiveFIFOFull               ,
    receiveFIFOEmpty                    =>  spw_0_receiveFIFOEmpty              ,
    receiveFIFODataCount                =>  spw_0_receiveFIFODataCount          ,
    
    tickIn                              =>  spw_0_tickIn                        ,
    timeIn                              =>  spw_0_timeIn                        ,
    controlFlagsIn                      =>  spw_0_controlFlagsIn                ,
    tickOut                             =>  spw_0_tickOut                       ,
    timeOut                             =>  spw_0_timeOut                       ,
    controlFlagsOut                     =>  spw_0_controlFlagsOut               ,
    linkStart                           =>  spw_0_linkStart                     ,
    linkDisable                         =>  spw_0_linkDisable                   ,
    autoStart                           =>  spw_0_autoStart                     ,
    linkStatus                          =>  spw_0_linkStatus                    ,
    errorStatus                         =>  spw_0_errorStatus                   ,
    transmitClockDivideValue            =>  spw_0_transmitClockDivideValue      ,
    creditCount                         =>  spw_0_creditCount                   ,
    outstandingCount                    =>  spw_0_outstandingCount              ,
    transmitActivity                    =>  spw_0_transmitActivity              ,
    receiveActivity                     =>  spw_0_receiveActivity               ,
    spaceWireDataOut                    =>  spw_0_spaceWireDataOut              ,
    spaceWireStrobeOut                  =>  spw_0_spaceWireStrobeOut            ,
    spaceWireDataIn                     =>  spw_0_spaceWireDataIn               ,
    spaceWireStrobeIn                   =>  spw_0_spaceWireStrobeIn             ,
    statisticalInformationClear         =>  spw_0_statisticalInformationClear   ,
    statisticalInformation              =>  spw_0_statisticalInformation
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