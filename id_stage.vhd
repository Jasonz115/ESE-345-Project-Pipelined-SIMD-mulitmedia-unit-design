-- decode register sources and latch the operands for EX
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity decode_stage is
    port (clk, reset : in std_logic; if_id : in stage; wb : in writeback;
          id_ex : out execute_input; bypass_hits : out source_mask;
          registers : out reg_bank);
end entity;

architecture rtl of decode_stage is
    signal ids : source_ids;
    signal used : source_mask;
    signal from_rf, selected : operands;
begin
    process(all)
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
    rf : entity work.register_file port map (clk, reset, ids, from_rf, wb, registers);
    -- capture a write occurring on the same edge that ID advances.
    wb_to_id : entity work.forwarding_unit
        port map (if_id, ids, used, from_rf, wb, selected, bypass_hits);
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
