-- check the instruction buffer, register file and forwarding unit
library ieee;
use ieee.std_logic_1164.all;
use work.pipeline_types.all;

entity modules_tb is end entity;
architecture test of modules_tb is
    signal clk, rst, load_en : std_logic := '0';
    signal addr : natural range 0 to 63 := 0;
    signal length : natural range 0 to 64 := 0;
    signal f, d : stage;
    signal ids : source_ids := ("00000", "11111", "00000");
    signal wb : writeback := empty_wb;
    signal q, selected : operands;
    signal used, hits : source_mask := "000";
    signal bank : reg_bank;
    constant val : reg_value := x"F0000000000000000000000000000001";
begin
    rf : entity work.register_file port map (clk, rst, ids, q, wb, bank);
    fw : entity work.forwarding_unit port map (d, ids, used, q, wb, selected, hits);
    fetch : entity work.if_stage port map(clk, rst, load_en, addr, nop, length, f, d);
    process
        procedure tick is
        begin
            wait for 2 ns; clk <= '1'; wait for 2 ns; clk <= '0'; wait for 1 ns;
        end procedure;
    begin
        rst <= '1'; load_en <= '1'; length <= 1; tick;
        -- fetch the only instruction and check that the next slot is empty
        rst <= '0'; load_en <= '0'; tick;
        assert d = ('1', 0, nop) and f.valid = '0' severity failure;
        -- only the first matching read port is marked as an active source
        used <= "110"; wb <= (('1', 0, nop), '1', "00000", val); wait for 1 ns;
        assert hits = "100" and selected(1) = val and q(1) /= val severity failure;
        tick;
        assert q(1) = val and q(3) = val and q(2) = (reg_value'range => '0') severity failure;
        assert d.valid = '0' and hits = "000" severity failure;
        -- check that a disabled write leaves register 31 at zero
        wb.dest <= "11111"; wb.enable <= '0'; tick;
        assert q(2) = (reg_value'range => '0') severity failure;
        wb.enable <= '1'; tick;
        assert q(2) = val severity failure;
        report "PASS: fetch, register file and forwarding unit" severity note;
        wait;
    end process;
end architecture;
