------------------------------------------------------------------------------
--  package for the aes designs
--  rev. 1.0 : 2023 Provoost Kris
------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

package aes_pkg is

  constant c_seq    : natural := 128; --! definition of the sequences size
  constant c_arr    : natural :=  16; --! definition of the matrix size

  type t_raw_bytes          is array ( integer range <> ) of std_logic_vector(7 downto 0);
  type t_state_bytes        is array ( integer range <> ) of t_raw_bytes ( 0 to 3);

  function f_slv_to_bytes     (x: std_logic_vector)   return t_raw_bytes;
  function f_bytes_to_slv     (x: t_raw_bytes)        return std_logic_vector;

  function f_bytes_to_state   (x: t_raw_bytes)        return t_state_bytes;
  function f_state_to_bytes   (x: t_state_bytes)      return t_raw_bytes;

end aes_pkg;

package body aes_pkg is

  --! conversion of a std_logic_vector to an array of bytes
  function f_slv_to_bytes(x: std_logic_vector) return t_raw_bytes is
    variable v_result: t_raw_bytes( 0 to c_arr-1);
  begin
    v_result := ( others => ( others => '0'));
    for j in v_result'range loop
      v_result(j) := x(j*8+7 downto j*8+0);
    end loop;
    return v_result;
  end f_slv_to_bytes;

  --! conversion of an array of bytes to a std_logic_vector
  function f_bytes_to_slv(x: t_raw_bytes) return std_logic_vector is
    variable v_result: std_logic_vector(c_seq-1 downto 0);
  begin
    v_result := ( others => '0');
    for j in 0 to c_arr-1 loop
      v_result(j*8+7 downto j*8+0) := x(j);
    end loop;
    return v_result;
  end f_bytes_to_slv;

  --! conversion of an array of bytes to a state matrix
  function f_bytes_to_state(x: t_raw_bytes) return t_state_bytes is
    variable v_result: t_state_bytes(0 to 3);
  begin
    v_result := ( others => ( others => ( others => '0' ) ) );
    for col in 0 to 3 loop
      for row in 0 to 3 loop
        v_result(col)(row) := x(col+row*4);
      end loop;
    end loop;
    return v_result;
  end f_bytes_to_state;

  --! conversion of a state matrix to an array of bytes
  function f_state_to_bytes(x: t_state_bytes) return t_raw_bytes is
    variable v_result: t_raw_bytes(0 to c_arr-1);
  begin
    v_result := ( others => ( others => '0'));
    for col in 0 to 3 loop
      for row in 0 to 3 loop
        v_result(col+row*4) := x(col)(row);
      end loop;
    end loop;
    return v_result;
  end f_state_to_bytes;


end aes_pkg;