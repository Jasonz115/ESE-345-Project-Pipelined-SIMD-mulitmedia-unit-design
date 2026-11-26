-- forward operands to the ALU and latch the result for WB
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity ex_stage is
    port (clk, reset : in std_logic; id_ex : in execute_input; wb : in writeback;
          ex_wb : out writeback; actual : out operands; hits : out source_mask;
          result : out reg_value; alu_write : out std_logic);
end entity;

architecture rtl of ex_stage is
    signal dest : reg_index;
    signal wr_en : std_logic;
    signal operand : operands;      -- operands after forwarding
    signal alu_result : reg_value;
    signal write_ok : std_logic;
begin
    -- use the preceding result when EX needs a value still in WB
    wb_to_ex : entity work.forwarding_unit
        port map (id_ex.slot, id_ex.ids, id_ex.used, id_ex.data, wb, operand, hits);
    actual <= operand;
    alu_inst : entity work.ALU
        port map (id_ex.slot.ins, operand(1), operand(2), operand(3), alu_result, wr_en, dest);
    result <= alu_result;
    -- an empty EX slot cannot enable a register write
    write_ok <= wr_en and id_ex.slot.valid;
    alu_write <= write_ok;
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ex_wb <= empty_wb;
            else
                ex_wb <= (id_ex.slot, write_ok, dest, alu_result);
            end if;
        end if;
    end process;
end architecture;
