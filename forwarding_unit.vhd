-- select the latest register value for each active source
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity forwarding_unit is
    port (slot : in stage; ids : in source_ids; used : in source_mask;
          original : in operands; wb : in writeback;
          selected : out operands; hits : out source_mask);
end entity;

architecture rtl of forwarding_unit is
begin
    process(all)
    begin
        selected <= original;
        hits <= "000";
        -- check each source separately since two operands can use the same register
        for i in 1 to 3 loop
            -- forward only when WB writes a register that this instruction reads
            if slot.valid = '1' and used(i) = '1' and wb.slot.valid = '1'
               and wb.enable = '1' and ids(i) = wb.dest then
                selected(i) <= wb.data;
                hits(i) <= '1';
            end if;
        end loop;
    end process;
end architecture;
