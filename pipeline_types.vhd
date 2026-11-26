-- shared signal types for the four pipeline stages
library ieee;
use ieee.std_logic_1164.all;

package pipeline_types is
    subtype instruction is std_logic_vector(24 downto 0);
    subtype reg_index is std_logic_vector(4 downto 0);
    subtype reg_value is std_logic_vector(127 downto 0);
    type reg_bank is array (0 to 31) of reg_value;
    type source_ids is array (1 to 3) of reg_index;
    type operands is array (1 to 3) of reg_value;
    subtype source_mask is std_logic_vector(1 to 3);
    constant nop : instruction := "11" & (22 downto 0 => '0');
    -- carry the instruction address into each stage for the cycle trace
    type stage is record
        valid : std_logic;
        pc : natural range 0 to 63;
        ins : instruction;
    end record;
    -- valid is low for an empty stage and high for a fetched NOP
    constant bubble : stage := ('0', 0, nop);
    type execute_input is record
        slot : stage;
        ids : source_ids;
        used : source_mask;
        data : operands;
    end record;
    type writeback is record
        slot : stage;
        enable : std_logic;
        dest : reg_index;
        data : reg_value;
    end record;
    constant empty_ex : execute_input :=
        (bubble, (others => (others => '0')), "000", (others => (others => '0')));
    constant empty_wb : writeback := (bubble, '0', (others => '0'), (others => '0'));
    type pipeline_trace is record
        fetch, decode : stage;
        ex : execute_input;
        wb : writeback;
        alu_inputs : operands;
        forwarded : source_mask;
        decode_bypass : source_mask;
        alu_result : reg_value;
        alu_write : std_logic;
    end record;
end package;
