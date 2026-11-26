library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pipe_pkg.all;

-- 64 x 25-bit instruction buffer. The testbench loads it through the ld_* port;
-- the pipeline reads it combinationally with the PC. Unwritten entries are NOPs.
entity instr_buffer is
    port (
        clk     : in  std_logic;
        ld_en   : in  std_logic;
        ld_addr : in  std_logic_vector(5 downto 0);
        ld_data : in  instr_t;
        pc      : in  std_logic_vector(5 downto 0);
        instr   : out instr_t
    );
end entity instr_buffer;

architecture behavioral of instr_buffer is
    type mem_t is array (0 to 63) of instr_t;
    signal mem : mem_t := (others => NOP_INSTR);
begin
    load_proc : process (clk)
    begin
        if rising_edge(clk) then
            if ld_en = '1' then
                mem(to_integer(unsigned(ld_addr))) <= ld_data;
            end if;
        end if;
    end process;

    instr <= mem(to_integer(unsigned(pc)));
end architecture behavioral;
