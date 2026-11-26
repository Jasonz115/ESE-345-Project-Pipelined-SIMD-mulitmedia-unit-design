library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.pipe_pkg.all;

-- Behavioral testbench.
--   1. loads the instruction buffer from PROG_FILE (one 25-character binary line per instruction)
--   2. runs the pipeline until the last instruction has completed WB
--   3. writes the per-cycle pipeline status to RESULTS_FILE
--   4. compares the register file with EXPECT_FILE ("<reg#> <32 hex digits>" per line;
--      registers not listed are expected to be 0) and reports PASS/FAIL
entity pipeline_tb is
    generic (
        PROG_FILE    : string := "program.bin";
        EXPECT_FILE  : string := "expected.txt";
        RESULTS_FILE : string := "results.txt"
    );
end entity pipeline_tb;

architecture behavioral of pipeline_tb is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal ld_en    : std_logic := '0';
    signal ld_addr  : std_logic_vector(5 downto 0) := (others => '0');
    signal ld_data  : instr_t := (others => '0');
    signal dbg      : dbg_t;
    signal regs_out : reg_array_t;
    signal done     : boolean := false;
begin
    dut : entity work.pipeline_top
        port map (clk => clk, rst => rst, ld_en => ld_en, ld_addr => ld_addr,
                  ld_data => ld_data, dbg => dbg, regs_out => regs_out);

    clk_gen : process
    begin
        while not done loop
            clk <= '0';  wait for 5 ns;
            clk <= '1';  wait for 5 ns;
        end loop;
        wait;
    end process;

    main : process
        file pf : text;
        file ef : text;
        file rf : text open write_mode is RESULTS_FILE;
        variable fstat    : file_open_status;
        variable l        : line;
        variable bv       : bit_vector(24 downto 0);
        variable good     : boolean;
        variable n_instr  : integer := 0;
        variable cycle    : integer;
        variable expected : reg_array_t := (others => (others => '0'));
        variable errors   : integer := 0;
        variable regnum   : integer;
        variable sp       : integer;

        procedure put (constant s : in string) is
        begin
            write(l, s);
            writeline(rf, l);
        end procedure;

        -- one line of the expected file:  "<reg#> <32 hex digits>"   ('#' starts a comment line)
        procedure parse_expected (variable ln : inout line;
                                  variable exp : inout reg_array_t) is
            variable p : integer;
            variable r : integer;
        begin
            if ln'length > 0 then
                declare_s : for dummy in 1 to 1 loop
                    if ln.all(ln.all'low) = '#' or ln.all(ln.all'low) = ' ' then
                        exit declare_s;
                    end if;
                    p := ln.all'low;
                    while p <= ln.all'high and ln.all(p) /= ' ' loop
                        p := p + 1;
                    end loop;
                    r := integer'value(ln.all(ln.all'low to p-1));
                    while p <= ln.all'high and ln.all(p) = ' ' loop
                        p := p + 1;
                    end loop;
                    if p + 31 <= ln.all'high then
                        exp(r) := hex_to_slv(ln.all(p to p+31));
                    end if;
                end loop;
            end if;
        end procedure;

        function src_str (a : regaddr_t; u : std_logic) return string is
        begin
            if u = '1' then return reg_str(a); else return "--"; end if;
        end function;

        procedure log_cycle (constant c : in integer) is
        begin
            put("=== Cycle " & integer'image(c) & " ===");
            put("PC  = " & integer'image(to_integer(unsigned(dbg.pc))));
            put("IF  : " & mnemonic(dbg.if_instr) & " instr=0x" & slv_to_hex(dbg.if_instr));
            put("ID  : " & mnemonic(dbg.id_instr) & " instr=0x" & slv_to_hex(dbg.id_instr)
                & "  reads rs1=" & src_str(dbg.id_addr1, dbg.id_use(0))
                & " rs2=" & src_str(dbg.id_addr2, dbg.id_use(1))
                & " rs3=" & src_str(dbg.id_addr3, dbg.id_use(2))
                & "  regfile bypass(rs1,rs2,rs3)=" & sl_str(dbg.rf_bypass(0))
                & "," & sl_str(dbg.rf_bypass(1)) & "," & sl_str(dbg.rf_bypass(2)));
            put("EX  : " & mnemonic(dbg.ex_instr) & " instr=0x" & slv_to_hex(dbg.ex_instr)
                & "  uses(rs1,rs2,rs3)=" & sl_str(dbg.ex_use(0)) & "," & sl_str(dbg.ex_use(1))
                & "," & sl_str(dbg.ex_use(2))
                & "  FORWARD(rs1,rs2,rs3)=" & sl_str(dbg.ex_fwd(0)) & "," & sl_str(dbg.ex_fwd(1))
                & "," & sl_str(dbg.ex_fwd(2)));
            put("     op1 = " & slv_to_hex(dbg.ex_op1));
            put("     op2 = " & slv_to_hex(dbg.ex_op2));
            put("     op3 = " & slv_to_hex(dbg.ex_op3));
            put("     ALU result = " & slv_to_hex(dbg.alu_rd) & "  wr_en=" & sl_str(dbg.alu_wr_en)
                & "  dest=" & reg_str(dbg.alu_des));
            put("WB  : " & mnemonic(dbg.wb_instr) & "  reg_write=" & sl_str(dbg.wb_en)
                & "  dest=" & reg_str(dbg.wb_addr) & "  data=" & slv_to_hex(dbg.wb_data));
            put("");
        end procedure;
    begin
        ----------------------------------------------------------------
        -- 1. load the instruction buffer (reset is held high meanwhile)
        ----------------------------------------------------------------
        file_open(fstat, pf, PROG_FILE, read_mode);
        assert fstat = open_ok report "cannot open program file " & PROG_FILE severity failure;

        wait until falling_edge(clk);
        while not endfile(pf) loop
            readline(pf, l);
            read(l, bv, good);
            if good then
                ld_en   <= '1';
                ld_addr <= std_logic_vector(to_unsigned(n_instr, 6));
                ld_data <= to_stdlogicvector(bv);
                n_instr := n_instr + 1;
                wait until falling_edge(clk);
            end if;
        end loop;
        file_close(pf);
        assert n_instr > 0 and n_instr <= 60
            report "program must hold 1..60 instructions, found " & integer'image(n_instr)
            severity failure;

        ----------------------------------------------------------------
        -- 2. run: release reset, log every cycle until the last WB is done
        ----------------------------------------------------------------
        put("Program: " & PROG_FILE & "   instructions: " & integer'image(n_instr));
        put("Cycle c = clock period c after reset release; instruction k is in IF in cycle k+1, ID k+2, EX k+3, WB k+4.");
        put("");
        ld_en <= '0';
        rst   <= '0';
        log_cycle(1);                                   -- sampled at the falling edge in cycle 1
        for c in 2 to n_instr + 3 loop
            wait until falling_edge(clk);
            log_cycle(c);
        end loop;
        wait until falling_edge(clk);                   -- last result has been written

        ----------------------------------------------------------------
        -- 3. compare the register file with the expected results
        ----------------------------------------------------------------
        file_open(fstat, ef, EXPECT_FILE, read_mode);
        assert fstat = open_ok report "cannot open expected file " & EXPECT_FILE severity failure;
        while not endfile(ef) loop
            readline(ef, l);
            parse_expected(l, expected);
        end loop;
        file_close(ef);

        put("=== Final register file check ===");
        for i in 0 to 31 loop
            if regs_out(i) = expected(i) then
                if expected(i) /= (127 downto 0 => '0') then
                    put("r" & integer'image(i) & " OK   " & slv_to_hex(regs_out(i)));
                end if;
            else
                errors := errors + 1;
                put("r" & integer'image(i) & " FAIL got " & slv_to_hex(regs_out(i))
                    & "  expected " & slv_to_hex(expected(i)));
            end if;
        end loop;
        if errors = 0 then
            put("RESULT: PASS (all 32 registers match)");
            report "PASS: " & PROG_FILE & " (" & integer'image(n_instr) & " instructions)";
        else
            put("RESULT: FAIL (" & integer'image(errors) & " register mismatches)");
            report "FAIL: " & PROG_FILE & " - " & integer'image(errors) & " mismatches"
                severity error;
        end if;

        file_close(rf);
        done <= true;
        wait;
    end process;
end architecture behavioral;
