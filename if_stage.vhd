-- fetch one 25-bit instruction per cycle
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity if_stage is
    port (clk, reset, load_en : in std_logic;
          load_addr : in natural range 0 to 63;
          load_data : in instruction;
          program_length : in natural range 0 to 64;
          fetch_slot, if_id : out stage);
end entity;

architecture rtl of if_stage is
    signal pc : natural range 0 to 64 := 0;
    signal current_slot : stage;
    signal fetched : instruction;
begin
    -- the buffer is loaded by the testbench while the PC is held in reset
    ibuf : entity work.instruction_buffer
        port map (clk, load_en, load_addr, load_data, pc, fetched);

    process(reset, pc, program_length, fetched)
    begin
        current_slot <= bubble;
        -- send an empty slot after the last instruction so the pipeline can drain
        if reset = '0' and pc < program_length then
            current_slot <= ('1', pc, fetched);
        end if;
    end process;
    fetch_slot <= current_slot;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc <= 0;
                if_id <= bubble;
            else
                if_id <= current_slot;
                if current_slot.valid = '1' then
                    pc <= pc + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
