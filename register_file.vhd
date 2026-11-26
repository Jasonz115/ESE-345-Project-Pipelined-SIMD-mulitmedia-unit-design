-- 32 registers with three read ports and one write port
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pipeline_types.all;

entity register_file is
    port (clk, reset : in std_logic;
          ids : in source_ids;
          read_data : out operands;
          wb : in writeback;
          registers : out reg_bank);
end entity;

architecture behavioral of register_file is
    signal bank : reg_bank := (others => (others => '0'));
begin
    -- each read address selects a 128-bit value independently
    ports_read : for i in 1 to 3 generate
        read_data(i) <= bank(to_integer(unsigned(ids(i)))) when not is_x(ids(i)) else (others => '0');
    end generate;
    registers <= bank;
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                bank <= (others => (others => '0'));
            -- write the destination on the rising edge at the end of WB
            elsif wb.slot.valid = '1' and wb.enable = '1' then
                bank(to_integer(unsigned(wb.dest))) <= wb.data;
            end if;
        end if;
    end process;
end architecture;
