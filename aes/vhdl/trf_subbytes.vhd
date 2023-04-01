------------------------------------------------------------------------------
--  AES transformation function : sub bytes
--  rev. 1.0 : 2023 provoost kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_misc.all;
use     ieee.numeric_std.all;

entity trf_subbytes is
  generic (
    g_size  : natural :=  128 --! radix of the vectors
  );
  port(
    clk           : in  std_logic;                    --system clock
    reset_n       : in  std_logic;                    --active low reset

    subbytes_s    : in  std_logic_vector(g_size-1 downto 0);
    subbytes_m    : out std_logic_vector(g_size-1 downto 0)
  );
end trf_subbytes;

architecture rtl of trf_subbytes is

    --! design constants
    constant c_depth          : natural := g_size/8;          --! depth of the implmentation

    --! array storage
    type t_raw_bytes          is array ( integer range <> ) of std_logic_vector(7 downto 0);
    signal subbytes_s_i       : t_raw_bytes ( 0 to c_depth-1);
    signal subbytes_m_i       : t_raw_bytes ( 0 to c_depth-1);

begin

gen_subbytes: for j in 0 to c_depth-1 generate

--! map input to Sbox lookup's
  process(reset_n, clk) is
  begin
      if reset_n='0' then
        null;
      elsif rising_edge(clk) then
          subbytes_s_i(j) <= subbytes_s(j*8+7 downto j*8+0);
      end if;
  end process;

--! use Sbox
i_sbox : entity work.sbox
  port map(
    input_byte  => subbytes_s_i(j),
    output_byte => subbytes_m_i(j)
  );

--! map outputs to Sbox lookup's
  process(reset_n, clk) is
  begin
      if reset_n='0' then
        null;
      elsif rising_edge(clk) then
          subbytes_m(j*8+7 downto j*8+0) <= subbytes_m_i(j);
      end if;
  end process;

end generate;

end rtl;
