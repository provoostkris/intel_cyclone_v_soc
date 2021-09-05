------------------------------------------------------------------------------
--  linear grid interpolater
--  rev. 1.0 : 2021 provoost kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_misc.all;
use     ieee.numeric_std.all;

entity interpolate_ram is
  generic (
    g_s_addr : natural range 1 to 16 :=  8;--! size of address
    g_s_data : natural range 1 to 16 :=  8;--! size of data
    g_int_f  : natural range 1 to 16 :=  2 --! interpolation factor ( in 2**n)
  );
  port(
    clk           : in  std_logic;                    --system clock
    reset_n       : in  std_logic;                    --active low reset

    raw_wr_ena    : in  std_logic;
    raw_wr_add    : in  std_logic_vector(g_s_addr-1 downto 0);
    raw_wr_dat    : in  std_logic_vector(g_s_data-1 downto 0);
    int_rd_ena    : in  std_logic;
    int_rd_add    : in  std_logic_vector(g_s_addr+(2*g_int_f)-1 downto 0);
    int_rd_dat    : out std_logic_vector(g_s_data-1 downto 0)
  );
end interpolate_ram;

architecture rtl of interpolate_ram is

    --! design constants
    constant c_int_f        : natural := 2**g_int_f;          --! interpolation factor (integer)
    constant c_grid_x       : natural := 2**(g_s_addr/2);     --! grid size X dimention (integer)
    constant c_grid_y       : natural := 2**(g_s_addr/2);     --! grid size Y dimention (integer)
    constant c_grid_a       : natural := c_grid_x * c_grid_y; --! grid size total dimention (integer)

    type t_a_ram               is array ( integer range <> ) of unsigned(g_s_data-1 downto 0);
    type t_x_ram               is array ( 0 to 1*c_int_f-1 ) of t_a_ram( 0 to 2**g_s_addr-1);
    type t_y_ram               is array ( 0 to 2*c_int_f-1 ) of t_a_ram( 0 to 2**g_s_addr-1);

    type t_ram_dat             is array ( integer range <> ) of unsigned(g_s_data-1 downto 0);
    type t_ram_loc             is array ( integer range <> ) of integer range 0 to 2**g_s_addr-1;

    -- all memories grouped
    signal raw_memory       : t_a_ram ( 0 to 2**g_s_addr-1);
    signal int_x_mem        : t_x_ram ;
    signal int_y_mem        : t_y_ram ;
    signal grid_mem         : t_a_ram ( 0 to 2**(g_s_addr+(2*g_int_f))-1);

    -- keep track of the steps along the process of interpolions and calculations
    signal step             : std_logic_vector(15 downto 0);

    -- input memory
    signal raw_rd_add       : unsigned(g_s_addr-1 downto 0);

    -- 1st stage memory
    signal int_x_wr_add     : unsigned(g_s_addr-1 downto 0);
    signal int_x_wr_dat     : t_ram_dat( 0 to 1*c_int_f-1);
    signal int_x_wr_ram     : t_ram_loc( 0 to 1*c_int_f-1);

    signal int_x_rd_add     : unsigned(g_s_addr-1 downto 0);
    signal int_x_rd_dat     : t_ram_dat( 0 to 1*c_int_f-1);
    signal int_x_rd_ram     : t_ram_loc( 0 to 1*c_int_f-1);

    -- 2nd stage memory
    signal int_y_wr_add     : unsigned(g_s_addr-1 downto 0);
    signal int_y_wr_dat     : t_ram_dat( 0 to 2*c_int_f-1);
    signal int_y_wr_ram     : t_ram_loc( 0 to 2*c_int_f-1);

    -- 3rd stage memory
    signal grid_rd_row      : unsigned(g_s_addr/2+g_int_f-1 downto 0);
    signal grid_rd_col      : unsigned(g_s_addr/2+g_int_f-1 downto 0);
    signal grid_rd_x        : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    signal grid_rd_y        : integer range 0 to 2**c_int_f-1;
    signal grid_rd_dat      : unsigned(g_s_data-1 downto 0);
    signal grid_wr_add      : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    signal grid_wr_add_d    : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    --references for interpolation
    type t_ref_points         is array ( integer range <> ) of unsigned(g_s_data-1 downto 0);
    signal ref_x_points       : t_ref_points ( 0 to 2-1 );
    signal ref_y_points       : t_ref_points ( 0 to 2*c_int_f-1 );

    --calculations array's
    type t_calc_values      is array ( integer range <> ) of integer range 0 to 2**(g_s_data+g_int_f);
    signal calc_x_value   : t_calc_values ( 0 to 1*c_int_f-1 );
    signal calc_x_ena     : std_logic;
    signal calc_x_ena_d   : std_logic;
    signal calc_y_value   : t_calc_values ( 0 to 2*c_int_f-1 );
    signal calc_y_ena     : std_logic;
    signal calc_y_ena_d   : std_logic;


begin

--! user access memory space
    --! write raw data in memory
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          null;
        elsif rising_edge(clk) then
          if raw_wr_ena = '1' then
            raw_memory(to_integer(unsigned(raw_wr_add))) <= unsigned(raw_wr_dat);
          end if;
        end if;
    end process;

    --! read interpolated data from memory
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          int_rd_dat <= ( others => '0');
        elsif rising_edge(clk) then
          if int_rd_ena = '1' then
            int_rd_dat <= std_logic_vector(grid_mem(to_integer(unsigned(int_rd_add))));
          end if;
        end if;
    end process;

--! track sequential relations
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          step    <= ( others => '0');
        elsif rising_edge(clk) then
          step    <= step(step'high-1 downto 0) & '1';
        end if;
    end process;

    --! address controller
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          raw_rd_add    <= ( others => '0');
          int_x_wr_add  <= ( others => '0');
        elsif rising_edge(clk) then
          if step(1) = '1' then
            raw_rd_add  <= raw_rd_add + 1;
          end if;
          if step(4) = '1' then
            int_x_wr_add  <= int_x_wr_add + 1;
          end if;
        end if;
    end process;

    --! get reference points
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          ref_x_points  <= ( others => ( others => '0'));
        elsif rising_edge(clk) then
          if step(1) = '1' then
            -- assign the point values
            ref_x_points(1) <= unsigned(raw_memory(to_integer(raw_rd_add)));
            ref_x_points(0) <= ref_x_points(1);
          end if;
        end if;
    end process;

    --! perform interpolation
    gen_linear_points: for j in 0 to c_int_f-1 generate
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            calc_x_value(j) <= 0;
          elsif rising_edge(clk) then
            if step(1) = '1' then
              -- simple linear operation should avoid DSP/MACC block
              calc_x_value(j)   <= (c_int_f-j) * to_integer(unsigned(ref_x_points(0))) / c_int_f +
                                   (        j) * to_integer(unsigned(ref_x_points(1))) / c_int_f ;
            end if;
          end if;
      end process;
    end generate;

--! memory write controller
      gen_wr_x_mem: for i in 0 to c_int_f-1 generate
        process(reset_n, clk) is
        begin
            if reset_n = '0' then
              int_x_wr_ram(i) <= 0;
              int_x_wr_dat(i) <= ( others => '0');
            elsif rising_edge(clk) then
              int_x_wr_ram(i) <= to_integer(int_x_wr_add);
              int_x_wr_dat(i) <= to_unsigned(calc_x_value(i),g_s_data);
              int_x_mem(i)(int_x_wr_ram(i)) <= int_x_wr_dat(i);
            end if;
        end process;
      end generate;

--! get reference points
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            int_x_rd_add  <= ( others => '0');
          elsif rising_edge(clk) then
              if step(6) = '1' then
                int_x_rd_add  <= int_x_rd_add + 1;
              end if;

          end if;
      end process;

      gen_rd_x_mem: for i in 0 to c_int_f-1 generate
        process(reset_n, clk) is
        begin
            if reset_n = '0' then
              int_x_rd_ram(i) <= 0;
            elsif rising_edge(clk) then
              int_x_rd_ram(i) <= to_integer(int_x_rd_add)*c_grid_x mod c_grid_a + to_integer(int_x_rd_add)/c_grid_x mod c_grid_a ;
              int_x_rd_dat(i) <= int_x_mem(i)(int_x_rd_ram(i));
            end if;
        end process;
      end generate;

    gen_ref_y_points: for i in 0 to c_int_f-1 generate
      process(reset_n, clk) is
      begin
          if reset_n = '0' then
            ref_y_points(i)          <= ( others => '0');
            ref_y_points(i+c_int_f)  <= ( others => '0');
          elsif rising_edge(clk) then
            if step(8) = '1' then
              ref_y_points(i)         <= ref_y_points(i+c_int_f);
              ref_y_points(i+c_int_f) <= int_x_rd_dat(i);
            end if;
          end if;
      end process;
    end generate;

    --! perform interpolation
    gen_linear_y_points: for j in 0 to c_int_f-1 generate
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            calc_y_value(j) <= 0;
          elsif rising_edge(clk) then
            if step(9) = '1' then
              -- simple linear operation should avoid DPS/MACC blocks
              calc_y_value(j)         <=  (c_int_f-j) * to_integer(unsigned(ref_y_points(0)))           / c_int_f +
                                          (        j) * to_integer(unsigned(ref_y_points(0+c_int_f)))   / c_int_f ;
              calc_y_value(j+c_int_f) <=  (c_int_f-j) * to_integer(unsigned(ref_y_points(1)))           / c_int_f +
                                          (        j) * to_integer(unsigned(ref_y_points(1+c_int_f)))   / c_int_f ;
            end if;
          end if;
      end process;
    end generate;

    --! store interpolated values
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            int_y_wr_add  <= ( others => '0');
          elsif rising_edge(clk) then
            if step(11) = '1' then
              int_y_wr_add  <= int_y_wr_add + 1;
            end if;
          end if;
      end process;

      gen_wr_y_mem: for i in 0 to 2*c_int_f-1 generate
        process(reset_n, clk) is
        begin
            if reset_n = '0' then
              int_y_wr_ram(i) <= 0;
              int_y_wr_dat(i) <= ( others => '0');
            elsif rising_edge(clk) then
              int_y_wr_ram(i) <= to_integer(int_y_wr_add);
              int_y_wr_dat(i) <= to_unsigned(calc_y_value(i),g_s_data);
              int_y_mem(i)(int_y_wr_ram(i)) <= int_y_wr_dat(i);
            end if;
        end process;
      end generate;

    --! unfold grid
    --! because of the two pass interpolation
    --! the grid is scrambled , for user we will make it a grid again accessible by linear addresses
    p_unfold: process(reset_n, clk) is
      variable v_row    : integer range 0 to 2**grid_rd_row'length-1;
      variable v_col    : integer range 0 to 2**grid_rd_col'length-1;
      variable v_x_off  : integer range 0 to 2**grid_rd_row'length-1;
      variable v_y_off  : integer range 0 to 2**grid_rd_col'length-1;
    begin
        if reset_n='0' then
          grid_rd_row     <= ( others => '0');
          grid_rd_col     <= ( others => '0');
          grid_rd_x       <= 0;
          grid_rd_y       <= 0;
          grid_wr_add     <= 0;
          grid_wr_add_d   <= 0;

          v_row           := 0;
          v_col           := 0;
          v_x_off         := 0;
          v_y_off         := 0;
        elsif rising_edge(clk) then
          --address control
          if step(11) = '1' then
            grid_rd_row <= grid_rd_row + 1;
            if and_reduce(std_logic_vector(grid_rd_row)) = '1' then
              grid_rd_col <= grid_rd_col + 1;
            end if;
          end if;
          v_row         := to_integer(grid_rd_row);
          v_col         := to_integer(grid_rd_col);
          v_x_off       := v_col mod c_int_f;
          v_y_off       := v_col  /  c_int_f;
          grid_rd_x     <= ( (v_row / c_int_f )  *   c_grid_x )  + v_y_off ;
          grid_rd_y     <= ( (v_row mod c_int_f ) * c_int_f  )  + v_x_off ;
          --write access
          grid_wr_add   <= v_row + v_col*c_grid_x*c_int_f;
          grid_wr_add_d <= grid_wr_add;
        end if;
    end process;

    -- memory read controller
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          grid_rd_dat <= ( others => '0');
        elsif rising_edge(clk) then
          if step(12) = '1' then
            grid_rd_dat   <= int_y_mem(grid_rd_y)(grid_rd_x);
          end if;
        end if;
    end process;

    --memory write controller
    process(reset_n, clk) is
    begin
        if reset_n='0' then
        elsif rising_edge(clk) then
          if step(12) = '1' then
            grid_mem(grid_wr_add_d) <= grid_rd_dat;
          end if;
        end if;
    end process;

end rtl;