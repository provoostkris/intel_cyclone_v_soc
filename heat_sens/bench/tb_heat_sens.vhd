------------------------------------------------------------------------------
--  Test Bench for the heat sens top level
--  rev. 1.0 : 2021 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- just for random functions
use ieee.math_real.all;

entity tb_heat_sens is
	port(
		y        :  out std_logic
	);
end entity tb_heat_sens;

architecture rtl of tb_heat_sens is

constant c_clk_per  : time      := 20 ns ;

--! amg8833 definitiois addr depends on pull-up/down
  -- constant c_amg_addr             : std_logic_vector(7 downto 0) := x"68";
  constant c_amg_addr             : std_logic_vector(7 downto 0) := x"69";

signal clk          : std_ulogic :='0';
signal rst          : std_ulogic :='0';
signal rst_n        : std_ulogic ;

--! DUT ports
signal KEY          : std_logic_vector(1 downto 0); --! Push button - debounced
signal SW           : std_logic_vector(3 downto 0); --! Slide button
signal Led          : std_logic_vector(7 downto 0); --! indicators

signal AMG_I2C_SCL  : std_logic;  -- i2c
signal AMG_I2C_SDA  : std_logic;  -- i2c

signal i2c_slv_read_req         : std_logic;
signal i2c_slv_data_to_master   : std_logic_vector(7 downto 0);
signal i2c_slv_data_valid       : std_logic;
signal i2c_slv_data_from_master : std_logic_vector(7 downto 0);


constant c_s_addr : natural :=  6;--! size of address
constant c_s_data : natural :=  8;--! size of data
constant c_int_f  : natural :=  1;--! interpolation factor ( in 2**n)

-- signal raw_wr_ena    : std_logic;
-- signal raw_wr_add    : std_logic_vector(c_s_addr-1 downto 0);
-- signal raw_wr_dat    : std_logic_vector(c_s_data-1 downto 0);
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
    seed1 := seed1 + 55;
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
	KEY(0)         <= '1', '0' after c_clk_per * 10 ;
	KEY(1)         <= '1', '0' after c_clk_per * 12 ;
	SW(0)          <= '1', '0' after c_clk_per * 14 ;
	SW(1)          <= '1', '0' after c_clk_per * 16 ;
	SW(2)          <= '1', '0' after c_clk_per * 18 ;
	SW(3)          <= '1', '0' after c_clk_per * 20 ;

--! bus terminations
AMG_I2C_SCL <= 'H';   --should be 10 k on the boards
AMG_I2C_SDA <= 'H';   --should be 10 k on the boards

--! i2c slave model
i_i2c_slave: entity work.i2c_slave
  generic map (
    slave_addr       => c_amg_addr(6 downto 0)
    )
  port map (
    scl              => amg_i2c_scl,
    sda              => amg_i2c_sda,
    clk              => clk,
    rst              => rst,
    -- user interface
    read_req         => i2c_slv_read_req        ,
    data_to_master   => i2c_slv_data_to_master  ,
    data_valid       => i2c_slv_data_valid      ,
    data_from_master => i2c_slv_data_from_master
    );
--! provide dummy data to the model
  process(i2c_slv_read_req, rst)
  begin
    if(rst = '1') then
      -- just some random value to start from
      i2c_slv_data_to_master  <= x"48";
    elsif(i2c_slv_read_req'event and i2c_slv_read_req = '1') then
      -- just some random increment
      i2c_slv_data_to_master  <= std_logic_vector(unsigned(i2c_slv_data_to_master) + x"13");
    end if;
  end process;


--! dut
dut: entity work.heat_sens(rtl)
  generic map(
    g_s_addr  => c_s_addr ,
    g_s_data  => c_s_data ,
    g_int_f   => c_int_f,
    input_clk => 25_000_000,              --input clock speed from user logic in hz
    bus_clk   =>  1_000_000               --speed the i2c bus (scl) will run at in hz
  )
  port map (
    FPGA_CLK1_50      => clk,
    FPGA_CLK2_50      => clk,
    FPGA_CLK3_50      => clk,
    KEY               => KEY,
    SW                => SW,
    Led               => Led,
    AMG_I2C_SCL       => AMG_I2C_SCL,
    AMG_I2C_SDA       => AMG_I2C_SDA,
    int_rd_ena        => int_rd_ena ,
    int_rd_add        => int_rd_add ,
    int_rd_dat        => int_rd_dat
  );


-- dummy data generator
-- process(rst, clk) is
  -- variable v_cnt_addr  : unsigned(c_s_addr-1 downto 0);
  -- variable v_cnt_data  : unsigned(c_s_data-1 downto 0);
-- begin
    -- if rst='1' then
        -- raw_wr_add <= ( others => '0');
        -- raw_wr_dat <= ( others => '0');
        -- raw_wr_ena <= '1';
        -- v_cnt_addr := ( others => '0');
        -- v_cnt_data := ( others => '0');
    -- elsif rising_edge(clk) then
        -- if v_cnt_addr = 2**c_s_addr-1 then
          -- raw_wr_ena <= '0';
        -- end if;
        -- v_cnt_addr := v_cnt_addr + 1 ;
        -- v_cnt_data := v_cnt_data + 1 ;
        -- raw_wr_add <= std_logic_vector(v_cnt_addr(raw_wr_add'range));
        -- raw_wr_dat <= rand_slv(raw_wr_dat'length,to_integer(v_cnt_addr),to_integer(v_cnt_data));
    -- end if;
-- end process;

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

end architecture rtl;