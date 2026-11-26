-- connect the four stages of the SIMD multimedia unit
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity multimedia_unit is
    port (clk, reset, load_en : in std_logic;
          load_addr : in natural range 0 to 63; load_data : in instruction;
          program_length : in natural range 0 to 64;
          trace : out pipeline_trace; registers : out reg_bank);
end entity;

architecture structural of multimedia_unit is
    -- pipeline registers between fetch, decode, execute and writeback
    signal if_id : stage := bubble;
    signal id_ex : execute_input := empty_ex;
    signal ex_wb : writeback := empty_wb;
begin
    fetch : entity work.fetch_stage
        port map (clk, reset, load_en, load_addr, load_data, program_length, trace.fetch, if_id);
    decode : entity work.decode_stage
        port map (clk, reset, if_id, ex_wb, id_ex, trace.decode_bypass, registers);
    execute : entity work.execute_stage
        port map (clk, reset, id_ex, ex_wb, ex_wb, trace.alu_inputs, trace.forwarded,
                  trace.alu_result, trace.alu_write);
    -- WB presents ex_wb to the register file until the committing rising edge.
    -- expose the registered stages for the testbench and waveform
    trace.decode <= if_id;
    trace.ex <= id_ex;
    trace.wb <= ex_wb;
end architecture;
