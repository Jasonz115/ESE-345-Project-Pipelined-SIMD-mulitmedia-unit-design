-- write back: present the EX/WB register to the register file
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity wb_stage is
    port (ex_wb : in writeback;
          commit : out writeback);   -- register file write port: enable, dest, data
end entity;

architecture rtl of wb_stage is
begin
    -- the register file stores this on the rising edge that ends the WB cycle;
    -- an empty slot (bubble) can never enable a write
    commit <= (ex_wb.slot, ex_wb.enable and ex_wb.slot.valid, ex_wb.dest, ex_wb.data);
end architecture;
