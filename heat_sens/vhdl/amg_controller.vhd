------------------------------------------------------------------------------
--  design file for amg8833 controller <> terrasic de10 nano cyclone 5 design
--  rev. 1.0 : 2020 provoost kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity amg_controller is
  port(
    clk       : in      std_logic;                    --system clock
    reset_n   : in      std_logic;                    --active low reset
    ena       : out     std_logic;                    --latch in command
    addr      : out     std_logic_vector(6 downto 0); --address of target slave
    rw        : out     std_logic;                    --'0' is write, '1' is read
    data_wr   : out     std_logic_vector(7 downto 0); --data to write to slave
    busy      : in      std_logic;                    --indicates transaction in progress
    data_rd   : in      std_logic_vector(7 downto 0); --data read from slave
    ack_error : in      std_logic;                    --flag if improper acknowledge from slave
    mean      : out     std_logic_vector(15 downto 0) --the average of all values
  );
end amg_controller;

architecture rtl of amg_controller is
--!
  constant c_busy_is_done         : std_logic_vector(3 downto 0) := "0000";
  constant c_busy_is_over         : std_logic_vector(3 downto 0) := "1100";
  constant c_busy_is_busy         : std_logic_vector(3 downto 0) := "1111";

--! amg8833 definitiois
  constant c_amg_addr             : std_logic_vector(7 downto 0) := x"68";
  --! register addresses
  constant c_amg_register_pctl    : std_logic_vector(7 downto 0) := x"00"; --! power control register
  constant c_amg_register_rst     : std_logic_vector(7 downto 0) := x"01"; --! reset register
  constant c_amg_register_fpsc    : std_logic_vector(7 downto 0) := x"02"; --! frame rate register
  constant c_amg_register_intc    : std_logic_vector(7 downto 0) := x"03"; --! interrupt control register
  constant c_amg_register_ave     : std_logic_vector(7 downto 0) := x"07"; --! interrupt control register
  constant c_amg_register_t01l    : std_logic_vector(7 downto 0) := x"80"; --! pixel 1 output value (lower level)
  constant c_amg_register_t01h    : std_logic_vector(7 downto 0) := x"81"; --! pixel 1 output value (higher level)
  constant c_amg_register_tthl    : std_logic_vector(7 downto 0) := x"0e"; --! thermistor output value (lower level)
  constant c_amg_register_tthh    : std_logic_vector(7 downto 0) := x"0f"; --! thermistor output value (higher level)
  --! power control register values
  constant c_amg_pctl_normal      : std_logic_vector(7 downto 0) := x"00"; --! normal operating mode
  constant c_amg_pctl_sleep       : std_logic_vector(7 downto 0) := x"10"; --! sleep mode
  constant c_amg_pctl_standby10   : std_logic_vector(7 downto 0) := x"21"; --! stand-by (10 sec intermittence)
  constant c_amg_pctl_standby60   : std_logic_vector(7 downto 0) := x"20"; --! stand-by (60 sec intermittence)
  --! reset register values
  constant c_amg_rst_flagreset    : std_logic_vector(7 downto 0) := x"30"; --! flag reset
  constant c_amg_rst_initialreset : std_logic_vector(7 downto 0) := x"30"; --! flag reset
  --! frame rate control register values
  constant c_amg_fpsc_framerate_10: std_logic_vector(7 downto 0) := x"00"; --! 10 fps measurement
  constant c_amg_fpsc_framerate_1 : std_logic_vector(7 downto 0) := x"01"; --!  1 fps measurement

--! constrol signals
  type t_state is(idle,
                  amg_reset,
                  amg_initialize,
                  amg_frame_rate,
                  amg_frame_rate_val,
                  amg_wake_up,
                  amg_read_pixels_addr,
                  amg_read_pixels_low,
                  amg_read_pixels_high,
                  amg_process_area,
                  amg_read_done
                  );

  signal state         : t_state;                        --state machine
  signal busy_shift    : std_logic_vector(3 downto 0);   --shift register with busy port

--! RAW pixel values
  constant c_pixel_area : integer := 64;
  type   t_a_slv_16     is array ( integer range <> ) of std_logic_vector(15 downto 0);
  signal heat_values    : t_a_slv_16(0 to c_pixel_area-1);
  signal cnt_pix        : integer range 0 to c_pixel_area-1;
--! sidebind information
  signal calc_mean_ena  : std_logic;
  signal mean_values    : unsigned(31 downto 0);

begin


  -- put the busy signal in a shift register for edge detect
  process(clk, reset_n)
  begin
    if(reset_n = '0') then
      busy_shift  <= ( others => '0');
    elsif(clk'event and clk = '1') then
      busy_shift  <= busy_shift(busy_shift'high-1 downto 0) & busy;
    end if;
  end process;

  --state machine control
  process(clk, reset_n)
  begin
    if(reset_n = '0') then
      state          <= idle;
      ena            <= '0';
      addr           <= ( others => '0');
      rw             <= '0';
      data_wr        <= ( others => '0');
      cnt_pix        <= 0;
      heat_values    <= ( others => ( others => '0'));
      calc_mean_ena  <= '0';
    elsif(clk'event and clk = '1') then

        -- set address for chip
        addr      <= c_amg_addr(addr'range);

        case state is
          when idle =>
            calc_mean_ena <= '0';
            -- state control
            if busy = '0' then
              state   <=  amg_reset;
            end if;
          when amg_reset =>
            rw        <= '0';
            data_wr   <= c_amg_register_rst;
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_initialize;
            end if;
          when amg_initialize =>
            rw        <= '0';
            data_wr   <= c_amg_rst_initialreset;
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_frame_rate;
            end if;
          when amg_frame_rate =>
            rw        <= '0';
            data_wr   <= c_amg_register_fpsc;
                        --c_amg_fpsc_framerate_1
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_frame_rate_val;
            end if;
          when amg_frame_rate_val =>
            rw        <= '0';
            data_wr   <= c_amg_fpsc_framerate_1;
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_wake_up;
            end if;
          when amg_wake_up =>
            rw        <= '0';
            data_wr   <= c_amg_pctl_normal;
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_read_pixels_addr;
            end if;
          when amg_read_pixels_addr =>
          -- 64 x
            rw        <= '0';
            data_wr   <= c_amg_register_t01l;
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_read_pixels_low;
            end if;
          when amg_read_pixels_low =>
            rw        <= '1';
            data_wr   <= ( others => '0');
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_read_pixels_high;
            end if;
            -- store the heat value
            heat_values(cnt_pix)( 7 downto 0) <= data_rd;
          when amg_read_pixels_high =>
            rw        <= '1';
            data_wr   <= ( others => '0');
            ena       <= not busy_shift(busy_shift'high) ;
            -- state control
            if busy_shift = c_busy_is_over then
              state   <=  amg_process_area;
            end if;
            -- store the heat value
            heat_values(cnt_pix)(15 downto 8) <= data_rd;
          when amg_process_area =>
            if cnt_pix < c_pixel_area-1 then 
              cnt_pix <=  cnt_pix + 1;
              state   <=  amg_read_pixels_addr;
            else
              cnt_pix <= 0;
              state   <=  amg_read_done;
            end if;
          when amg_read_done =>
            calc_mean_ena <= '1';
            -- state control
            state   <=  idle;

          when others =>
              state   <=  idle;
        end case;
      end if;
  end process;
  
  -- perfrom a contineous averaging of the heat_values
  -- to get a mean temperature
  -- for now just take MSBs of the value
  process(clk, reset_n)
  begin
    if(reset_n = '0') then
      mean_values   <= ( others => '0');
      mean          <= ( others => '0');
    elsif(clk'event and clk = '1') then
    if state = idle then
      mean_values   <= ( others => '0');
    elsif state = amg_process_area then
      mean_values   <= mean_values  + unsigned(heat_values(cnt_pix));
    end if;
    if calc_mean_ena = '1' then
      mean  <= std_logic_vector(mean_values(31 downto 16));
    end if;  
    end if;
  end process;
  
end rtl;
