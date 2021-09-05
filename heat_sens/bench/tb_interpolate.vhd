------------------------------------------------------------------------------
--  Test Bench for the interpolate component
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- just for random functions
use ieee.math_real.all;

entity tb_interpolate is
	port(
		y        :  out std_logic
	);
end entity tb_interpolate;

architecture rtl of tb_interpolate is

constant c_clk_per  : time      := 20 ns ;

signal clk          : std_ulogic :='0';
signal rst          : std_ulogic :='0';
signal rst_n        : std_ulogic ;

constant c_s_addr : natural :=  4;--! size of address (2-4-6-8-...)
constant c_s_data : natural :=  8;--! size of data
constant c_int_f  : natural :=  1;--! interpolation factor ( in 2**n)

signal raw_wr_ena    : std_logic;
signal raw_wr_add    : std_logic_vector(c_s_addr-1 downto 0);
signal raw_wr_dat    : std_logic_vector(c_s_data-1 downto 0);
signal int_rd_ena    : std_logic;
signal int_rd_add    : std_logic_vector(c_s_addr+(2*c_int_f)-1 downto 0);
signal int_rd_dat    : std_logic_vector(c_s_data-1 downto 0);

impure function rand_slv(len : integer; rnd_1 : integer; rnd_2 : integer) return std_logic_vector is
  variable seed1 : integer;
  variable seed2 : integer;
  variable r : real;
  variable slv : std_logic_vector(len - 1 downto 0);
begin
  seed1 := rnd_1+1; --! add one to allow passing 0 as argument
  seed2 := rnd_2+1;
  for i in slv'range loop
    seed1 := seed1 +  3;
    seed2 := seed2 +  2 ;
    uniform(seed1, seed2, r);
    if r > 0.5 then
      slv(i) := '1';
    else
      slv(i) := '0';
    end if;
  end loop;
  return slv;
end function;

begin

	clk            <= not clk  after c_clk_per/2;
	rst            <= '1', '0' after c_clk_per *  3 ;
  rst_n          <= not rst;
  

-- dummy data generator
process(rst, clk) is
  variable v_cnt_addr  : unsigned(c_s_addr downto 0);
  variable v_cnt_data  : unsigned(c_s_data downto 0);
begin
    if rst='1' then
        raw_wr_add <= ( others => '0');
        raw_wr_dat <= ( others => '0');
        raw_wr_ena <= '0';
        v_cnt_addr := ( others => '0');
        v_cnt_data := ( others => '0');
    elsif rising_edge(clk) then
        raw_wr_add <= std_logic_vector(v_cnt_addr(raw_wr_add'range));
        raw_wr_dat <= rand_slv(raw_wr_dat'length,to_integer(v_cnt_addr),to_integer(v_cnt_data));
        if v_cnt_addr = 2**c_s_addr then
          raw_wr_ena  <= '0';
        else  
          raw_wr_ena  <= '1';
          v_cnt_addr := v_cnt_addr + 1 ;
          v_cnt_data := v_cnt_data + 1 ;
        end if;
    end if;
end process;

-- read interpolated data
process(rst, clk) is
  variable v_cnt_addr  : unsigned(c_s_addr+(2*c_int_f)-1 downto 0);
  variable v_delay     : unsigned(2**c_int_f downto 0);
begin
    if rst='1' then
        int_rd_add <= ( others => '0');
        int_rd_ena <= '0';
        v_cnt_addr := ( others => '0');
        v_delay    := ( others => '0');
    elsif rising_edge(clk) then
        v_delay    := v_delay + 1;
        int_rd_ena <= int_rd_ena or and_reduce(std_logic_vector(v_delay));
        int_rd_add <= std_logic_vector(v_cnt_addr(int_rd_add'range));
        if int_rd_ena = '1' then
          v_cnt_addr := v_cnt_addr + 1 ;
        end if;
    end if;
end process;


dut: entity work.interpolate_ram(rtl)
  generic map(
    g_s_addr => c_s_addr ,
    g_s_data => c_s_data ,
    g_int_f  => c_int_f
  )
  port map(
    clk           =>  clk           ,
    reset_n       =>  rst_n         ,
    raw_wr_ena    =>  raw_wr_ena    ,
    raw_wr_add    =>  raw_wr_add    ,
    raw_wr_dat    =>  raw_wr_dat    ,
    int_rd_ena    =>  int_rd_ena    ,
    int_rd_add    =>  int_rd_add    ,
    int_rd_dat    =>  int_rd_dat
  );
end architecture rtl;