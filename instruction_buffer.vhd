-- 64 x 25-bit instruction buffer (behavioral).
-- The testbench writes it through the load port; the fetch stage reads it with the PC.
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity instruction_buffer is
    port (clk, load_en : in std_logic;
          load_addr : in natural range 0 to 63;
          load_data : in instruction;
          pc : in natural range 0 to 64;
          instr : out instruction);
end entity;

architecture behavioral of instruction_buffer is
    type buffer_type is array (0 to 63) of instruction;
    signal buffer_mem : buffer_type := (others => nop);
begin
    -- write one instruction per clock edge while the testbench is loading
    process(clk)
    begin
        if rising_edge(clk) then
            if load_en = '1' then
                buffer_mem(load_addr) <= load_data;
            end if;
        end if;
    end process;
    -- pc reaches 64 after a full 64-instruction program, which is past the end of the buffer
    instr <= buffer_mem(pc) when pc < 64 else nop;
end architecture;
    
