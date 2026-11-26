-- decode register sources and latch the operands for EX
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity id_stage is
    port (clk, reset : in std_logic; if_id : in stage; wb : in writeback;
          -- register file read ports (the register file sits at the top level)
          rf_ids : out source_ids; rf_data : in operands;
          id_ex : out execute_input; bypass_hits : out source_mask);
end entity;

architecture rtl of id_stage is
    signal ids : source_ids;
    signal used : source_mask;
    signal selected : operands;
begin
    process(if_id)
        variable ins : instruction;
    begin
        ins := if_id.ins;
        -- default register fields for R4 instructions
        ids <= (ins(9 downto 5), ins(14 downto 10), ins(19 downto 15));
        if ins(24) = '0' then
            ids(1) <= ins(4 downto 0);  -- LI reads the old destination
            used <= "100";
        elsif ins(23) = '0' then
            used <= "111";
        else
            case ins(18 downto 15) is
                when "0000" => used <= "000";  -- NOP
                -- CNT1W, BCW, MLHCU and CNTLZ only read rs1
                when "0011" | "0110" | "1010" | "1100" => used <= "100";
                when others => used <= "110";
            end case;
        end if;
    end process;
    rf_ids <= ids;
    -- capture a write occurring on the same edge that ID advances.
    wb_to_id : entity work.forwarding_unit
        port map (if_id, ids, used, rf_data, wb, selected, bypass_hits);
    -- capture the selected data and source IDs together for the next stage
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                id_ex <= empty_ex;
            else
                id_ex <= (if_id, ids, used, selected);
            end if;
        end if;
    end process;
end architecture;
