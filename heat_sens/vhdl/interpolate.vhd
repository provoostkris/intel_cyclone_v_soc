------------------------------------------------------------------------------
--  linear grid interpolater
--  rev. 1.0 : 2021 provoost kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_misc.all;
use     ieee.numeric_std.all;

entity interpolate is
  generic (
    g_s_addr : natural :=  8;--! size of address
    g_s_data : natural :=  8;--! size of data
    g_int_f  : natural :=  2 --! interpolation factor ( in 2**n)
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
end interpolate;

architecture rtl of interpolate is

    --! design constants
    constant c_int_f        : natural := 2**g_int_f;          --! interpolation factor (integer)
    constant c_grid_x       : natural := 2**(g_s_addr/2);     --! grid size X dimention (integer)
    constant c_grid_y       : natural := 2**(g_s_addr/2);     --! grid size Y dimention (integer)
    constant c_grid_a       : natural := c_grid_x * c_grid_y; --! grid size total dimention (integer)
    

    -- input memory
    type t_raw_ram          is array ( integer range <> ) of std_logic_vector(g_s_data-1 downto 0);
    signal raw_memory       : t_raw_ram ( 0 to 2**g_s_addr-1);
    signal raw_rd_add       : unsigned(g_s_addr-1 downto 0);
    signal raw_rd_ena       : std_logic;

    type t_ram              is array ( integer range <> ) of std_logic_vector(g_s_data-1 downto 0);
    -- 1st stage memory
    signal int_x_mem        : t_ram ( 0 to 2**(g_s_addr+g_int_f)-1);
    signal int_x_wr_add     : unsigned(g_s_addr+g_int_f-1 downto 0);
    signal int_x_wr_ena     : std_logic_vector(c_int_f-1 downto 0);
    signal int_x_rd_row     : unsigned(g_s_addr/2+g_int_f-1 downto 0);
    signal int_x_rd_col     : unsigned(g_s_addr/2-1 downto 0);
    signal int_x_rd_add     : integer range 0 to 2**(g_s_addr+g_int_f)-1;
    signal int_x_rd_ena     : unsigned(g_int_f-1 downto 0);
    -- indicators for address zero crossing
    signal int_x_rd_add_zero   : std_logic;
    signal int_x_rd_add_zero_d : std_logic_vector(c_int_f-1 downto 0);

    -- 2nd stage memory
    signal int_y_mem        : t_ram ( 0 to 2**(g_s_addr+(2*g_int_f))-1);
    signal int_y_wr_add     : unsigned(g_s_addr+(2*g_int_f)-1 downto 0);
    signal int_y_wr_ena     : std_logic;

    -- 3rd stage memory
    signal grid_mem         : t_ram ( 0 to 2**(g_s_addr+(2*g_int_f))-1);
    signal grid_rd_row      : unsigned(g_s_addr/2+g_int_f-1 downto 0);      
    signal grid_rd_col      : unsigned(g_s_addr/2+g_int_f-1 downto 0);      
    signal grid_rd_add      : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    signal grid_wr_add      : unsigned(g_s_addr+(2*g_int_f)-1 downto 0);
    signal grid_wr_add_d    : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    signal grid_wr_add_dd   : integer range 0 to 2**(g_s_addr+(2*g_int_f))-1;
    signal grid_rd_dat      : std_logic_vector(g_s_data-1 downto 0);

    --references for interpolation
    type t_ref_points         is array ( integer range <> ) of std_logic_vector(g_s_data-1 downto 0);
    signal ref_x_points       : t_ref_points ( 0 to 1 );
    signal ref_y_points       : t_ref_points ( 0 to 1 );

    --calculations array's
    type t_calc_values      is array ( integer range <> ) of integer range 0 to 2**(g_s_data+g_int_f);
    signal calc_x_value   : t_calc_values ( 0 to c_int_f-1 );
    signal calc_x_ena     : std_logic;
    signal calc_y_value   : t_calc_values ( 0 to c_int_f-1 );
    signal calc_y_ena     : std_logic;


begin

--! user access memory space
    --! write raw data in memory
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          null;
        elsif rising_edge(clk) then
          if raw_wr_ena = '1' then
            raw_memory(to_integer(unsigned(raw_wr_add))) <= raw_wr_dat;
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
            int_rd_dat <= grid_mem(to_integer(unsigned(int_rd_add)));
          end if;
        end if;
    end process;

--! interpolation memory access horizontal run
    --! get reference points
    process(reset_n, clk) is
      variable v_cnt  : unsigned(g_int_f-1 downto 0);
    begin
        if reset_n='0' then
          v_cnt       := ( others => '0');
          raw_rd_add  <= ( others => '0');
          raw_rd_ena  <= '0';
          ref_x_points  <= ( others => ( others => '0'));
        elsif rising_edge(clk) then
            v_cnt := v_cnt + 1;
            if v_cnt /= 0 then
              raw_rd_ena  <= '0';
            else
              raw_rd_ena  <= '1';
              raw_rd_add  <= raw_rd_add + 1;
            end if;
            -- assign the point values
            ref_x_points(1) <= raw_memory(to_integer(raw_rd_add));
            ref_x_points(0) <= ref_x_points(1);
        end if;
    end process;

    --! determine the enable for the interpolation
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          calc_x_ena  <= '0';
        elsif rising_edge(clk) then
          calc_x_ena  <= raw_rd_ena;
        end if;
    end process;

    --! perform interpolation
    gen_linear_points: for j in 0 to c_int_f-1 generate
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            calc_x_value(j) <= 0;
          elsif rising_edge(clk) then
            if calc_x_ena = '1' then
              -- simple linear operation to be checked if one MAC/DSP can handle this
              calc_x_value(j)   <= (c_int_f-j) * to_integer(unsigned(ref_x_points(0))) / c_int_f +
                                   (        j) * to_integer(unsigned(ref_x_points(1))) / c_int_f ;
            end if;
          end if;
      end process;
    end generate;

    --! store interpolated values
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          int_x_wr_ena  <= ( others => '0');
          int_x_wr_add  <= ( others => '0');
        elsif rising_edge(clk) then
            int_x_wr_ena  <= int_x_wr_ena(int_x_wr_ena'high-1 downto 0) & calc_x_ena;
            -- carefull with the loop , for high int factors this could explode the design
            for i in 0 to c_int_f-1 loop
              if int_x_wr_ena(i) = '1' then
                int_x_wr_add  <= int_x_wr_add + 1;
                int_x_mem(to_integer(int_x_wr_add)) <= std_logic_vector(to_unsigned(calc_x_value(i),g_s_data));
              end if;
            end loop;
        end if;
    end process;


--! interpolation memory access vertical run
    --! get reference points
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          int_x_rd_row  <= ( others => '0');
          int_x_rd_col  <= ( others => '0');
          int_x_rd_add  <= 0;
          int_x_rd_ena  <= ( others => '0');
          ref_y_points  <= ( others => ( others => '0'));
        elsif rising_edge(clk) then
          -- note that in the first run all samples are incremental in the memory
          -- since we have a grid, we have to jump addresses to find two adjacent values
            int_x_rd_ena <= int_x_rd_ena + 1;
            if and_reduce(std_logic_vector(int_x_rd_ena)) = '1' then
              if and_reduce(std_logic_vector(int_x_rd_col)) = '1' then
                int_x_rd_row <= int_x_rd_row + 1;
              end if;
              int_x_rd_col  <= int_x_rd_col + 1;
            end if;
            int_x_rd_add  <= to_integer(int_x_rd_col)*c_grid_x*c_int_f + to_integer(int_x_rd_row);
            -- assign the point values
            ref_y_points(1) <= int_x_mem(int_x_rd_add);
            ref_y_points(0) <= ref_y_points(1);
        end if;
    end process;

    --! determine the enable for the interpolation
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          calc_y_ena            <= '0';
          int_x_rd_add_zero     <= '0';
          int_x_rd_add_zero_d   <= ( others => '0');
        elsif rising_edge(clk) then
          calc_y_ena  <= and_reduce(std_logic_vector(int_x_rd_ena));
          if and_reduce(std_logic_vector(int_x_rd_ena)) = '1' and int_x_rd_add = 0 then
            int_x_rd_add_zero  <= '1';
          else
            int_x_rd_add_zero  <= '0';
          end if;
          int_x_rd_add_zero_d  <= int_x_rd_add_zero_d(int_x_rd_add_zero_d'high-1 downto 0) & int_x_rd_add_zero;
        end if;
    end process;

    --! perform interpolation
    gen_linear_y_points: for j in 0 to c_int_f-1 generate
      process(reset_n, clk) is
      begin
          if reset_n='0' then
            calc_y_value(j) <= 0;
          elsif rising_edge(clk) then
            if calc_y_ena = '1' then
              -- simple linear operation to be checked if one MAC/DSP can handle this
              calc_y_value(j)   <= (c_int_f-j) * to_integer(unsigned(ref_y_points(0))) / c_int_f +
                                   (        j) * to_integer(unsigned(ref_y_points(1))) / c_int_f ;
            end if;
          end if;
      end process;
    end generate;

    --! store interpolated values
    process(reset_n, clk) is
    begin
        if reset_n='0' then
          int_y_wr_ena  <= '0';
          int_y_wr_add  <= ( others => '0');
        elsif rising_edge(clk) then
            int_y_wr_ena  <= calc_y_ena;
            if int_x_rd_add_zero_d(int_x_rd_add_zero_d'high) = '1' then
              int_y_wr_add  <= ( others => '0');
            else
              int_y_wr_add  <= int_y_wr_add + 1;
            end if;
            -- carefull with the loop , for high int factors this could explode the design
            for i in 0 to c_int_f-1 loop
              if int_y_wr_ena = '1' then
                int_y_mem(to_integer(int_y_wr_add+i)) <= std_logic_vector(to_unsigned(calc_y_value(i),g_s_data));
              end if;
            end loop;
        end if;
    end process;


    --! unfold grid
    --! because of the two pass interpolation
    --! the grid is scrambled , for user we will make it a grid again accessible by linear addresses
    process(reset_n, clk) is
      variable v_row  : integer range 0 to 2**grid_rd_row'length-1;
      variable v_col  : integer range 0 to 2**grid_rd_col'length-1;
    begin
        if reset_n='0' then
          grid_rd_dat     <= ( others => '0');
          grid_rd_row     <= ( others => '0');
          grid_rd_col     <= ( others => '0');
          grid_rd_add     <= 0;
          grid_wr_add     <= ( others => '0');
          grid_wr_add_d   <= 0;
          grid_wr_add_dd  <= 0;
          v_row           := 0;
          v_col           := 0;
        elsif rising_edge(clk) then
          --address control
          grid_rd_row <= grid_rd_row + 1;
          if and_reduce(std_logic_vector(grid_rd_row)) = '1' then
            grid_rd_col <= grid_rd_col + 1;
          end if;
          v_row         := to_integer(grid_rd_row);
          v_col         := to_integer(grid_rd_col);
          grid_rd_add   <= v_row*c_grid_x*c_int_f + v_col;
          grid_wr_add_d <= v_row + v_col*c_grid_y*c_int_f;
          grid_wr_add_dd<= grid_wr_add_d;
          -- memory control
          grid_rd_dat              <= int_y_mem(grid_rd_add);
          grid_mem(grid_wr_add_dd) <= grid_rd_dat;
        end if;
    end process;

end rtl;