-- run an instruction file and check the final register values
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.pipeline_types.all;

entity pipeline_tb is
generic (
    program_file : string := "coverage_program.txt";
    expected_file : string := "coverage_expected.txt";
    check_smoke_timing : boolean := false;
    check_full_coverage : boolean := true
);
end entity;

architecture test of pipeline_tb is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal load_en : std_logic := '0';
    signal addr : natural range 0 to 63 := 0;
    signal length : natural range 0 to 64 := 0;
    signal data : instruction := nop;
    signal t : pipeline_trace;
    signal bank : reg_bank;
    procedure log_slot(variable l : inout line; name : string; s : stage) is
    begin
        write(l, " " & name & "=");
        if s.valid = '1' then
            write(l, integer'image(s.pc) & "/" & mnemonic(s.ins) & "(" & to_hex(s.ins) & ")");
        else
            write(l, string'("-"));
        end if;
    end procedure;
begin
    dut : entity work.multimedia_unit port map(clk, reset, load_en, addr, data, length, t, bank);
    process
        file program : text open read_mode is program_file;
        file expected : text open read_mode is expected_file;
        file results : text open write_mode is "results.txt";
        file reg_output : text open write_mode is "register_output.txt";
        variable l, row_text : line;
        variable bits : instruction;
        variable value : reg_value;
        variable count : natural := 0;
        variable seen : std_logic_vector(24 downto 0) := (others => '0');
        variable op_index : natural range 0 to 24;
        procedure tick is
        begin
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
        end procedure;
    begin
        tick;
        -- load one 25-bit instruction into the buffer on each clock edge
        while not endfile(program) loop
            readline(program, l);
            assert count < 64 and l.all'length = 25 report "Expected at most 64 lines of 25 binary digits" severity failure;
            for k in l.all'range loop
                assert l.all(k) = '0' or l.all(k) = '1' report "Nonbinary instruction" severity failure;
            end loop;
            -- first character is the most significant bit
            bits := (others => '0');
            for k in 0 to 24 loop
                if l.all(l.all'low + k) = '1' then
                    bits(24 - k) := '1';
                end if;
            end loop;
            addr <= count;
            data <= bits;
            load_en <= '1';
            tick;
            count := count + 1;
        end loop;
        load_en <= '0';
        length <= count;
        reset <= '0';
        -- allow three extra cycles for the last instruction to reach writeback
        for cycle in 1 to count + 3 loop
            wait for 1 ns;  -- sample all four stages before the committing edge
            write(row_text, "cycle=" & integer'image(cycle));
            log_slot(row_text, "IF", t.fetch);
            log_slot(row_text, "ID", t.decode);
            log_slot(row_text, "EX", t.ex.slot);
            log_slot(row_text, "WB", t.wb.slot);
            write(row_text, " ID_bypass=" & to_bin(t.decode_bypass));
            write(row_text, " EX_used=" & to_bin(t.ex.used) & " EX_forward=" & to_bin(t.forwarded));
            for i in 1 to 3 loop
                write(row_text, " src" & integer'image(i) & "=" & reg_name(t.ex.ids(i))
                      & "/" & to_hex(t.alu_inputs(i)));
            end loop;
            write(row_text, " EX_write=" & std_logic'image(t.alu_write) & " EX_result=" & to_hex(t.alu_result));
            write(row_text, " WB_write=" & std_logic'image(t.wb.enable) & " WB_rd=" & reg_name(t.wb.dest)
                  & " WB_data=" & to_hex(t.wb.data));
            writeline(results, row_text);
            -- Verify one instruction advances each cycle without stalls.
            if cycle >= 3 and cycle <= count + 2 then
                assert t.ex.slot.valid = '1' and t.ex.slot.pc = cycle - 3
                    report "EX pipeline timing error" severity failure;
                if t.ex.slot.ins(24) = '0' then
                    op_index := 0;
                elsif t.ex.slot.ins(23) = '0' then
                    op_index := 1 + to_integer(unsigned(t.ex.slot.ins(22 downto 20)));
                else
                    op_index := 9 + to_integer(unsigned(t.ex.slot.ins(18 downto 15)));
                end if;
                seen(op_index) := '1';
                if op_index = 9 then
                    assert t.alu_write = '0' and t.forwarded = "000"
                        report "NOP must not write or forward" severity failure;
                else
                    assert t.alu_write = '1' report "Missing EX write enable" severity failure;
                end if;
            else
                assert t.ex.slot.valid = '0' report "Unexpected EX instruction" severity failure;
            end if;
            if cycle >= 4 then
                assert t.wb.slot.valid = '1' and t.wb.slot.pc = cycle - 4
                    report "WB pipeline timing error" severity failure;
            else
                assert t.wb.slot.valid = '0' report "Unexpected WB instruction" severity failure;
            end if;
            -- check forwarding into LI and then into both AU operands
            if check_smoke_timing then
                if cycle = 4 then
                    assert t.fetch = ('1', 3, nop) and t.decode.pc = 2 and t.ex.slot.pc = 1
                        and t.wb.slot.pc = 0 and t.forwarded = "100"
                        report "Expected four occupied stages and LI forwarding" severity failure;
                elsif cycle = 5 then
                    assert t.forwarded = "110" report "Expected AU to forward both inputs" severity failure;
                end if;
            end if;
            wait for 4 ns;
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
        end loop;
	if check_full_coverage and not check_smoke_timing then
    	assert seen = (seen'range => '1')
        	report "Incomplete instruction coverage: "
            	& to_bin(seen) severity failure;
    	report "PASS: all 25 instruction types reached EX"
        severity note;
	end if;
        -- compare all 32 registers in order from r0 through r31
        for i in bank'range loop
            assert not endfile(expected) report "Missing expected value for register " & integer'image(i) severity failure;
            readline(expected, l);
            assert l.all'length = 32 and valid_hex(l.all) report "Expected 32 hex digits per register" severity failure;
            value := hex_to_slv(l.all);
            write(row_text, to_hex(bank(i)));
            writeline(reg_output, row_text);
            assert bank(i) = value report "r" & integer'image(i) & " expected " & to_hex(value)
                & " got " & to_hex(bank(i)) severity failure;
        end loop;
        assert endfile(expected) report "Extra expected register lines" severity failure;
        report "PASS: all 32 registers match" severity note;
        wait;
    end process;
end architecture;

entity smoke_tb is end entity;
architecture test of smoke_tb is
begin
    short_run : entity work.pipeline_tb
        generic map ("smoke_program.txt", "smoke_expected.txt", true);	   -- smoke is just a given name to test with the four instructions LI(16 bit halfword), LI(the other 16 bits), AU, NOP
end architecture;	   


entity directed_tb is
end entity;
architecture test of directed_tb is
begin
    directed_run : entity work.pipeline_tb
        generic map (
            program_file => "directed_program.txt",
            expected_file => "directed_expected.txt",
            check_smoke_timing => false,
            check_full_coverage => false
        );
end architecture;
