library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pipe_pkg.all;

-- 32 x 128-bit register file: 3 combinational reads, 1 write at the rising clock edge.
-- Write-before-read: if the WB stage is writing the register being read in ID in the
-- same cycle, the new value is passed straight to the read port (lecture slide 32).
entity regfile is
    port (
        clk, rst  : in  std_logic;
        -- read ports (ID stage)
        rd1_addr  : in  regaddr_t;
        rd2_addr  : in  regaddr_t;
        rd3_addr  : in  regaddr_t;
        rd1_data  : out word128;
        rd2_data  : out word128;
        rd3_data  : out word128;
        bypass    : out std_logic_vector(2 downto 0);   -- bypass active on port 1/2/3
        -- write port (WB stage)
        wr_en     : in  std_logic;                      -- explicit register-write signal
        wr_addr   : in  regaddr_t;
        wr_data   : in  word128;
        -- whole register file, for the testbench check
        regs_out  : out reg_array_t
    );
end entity regfile;

architecture behavioral of regfile is
    signal regs : reg_array_t := (others => (others => '0'));
begin
    regs_out <= regs;

    write_proc : process (clk, rst)
    begin
        if rst = '1' then
            regs <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if wr_en = '1' then
                regs(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
        end if;
    end process;

    read_proc : process (regs, rd1_addr, rd2_addr, rd3_addr, wr_en, wr_addr, wr_data)
    begin
        if wr_en = '1' and wr_addr = rd1_addr then
            rd1_data  <= wr_data;  bypass(0) <= '1';
        else
            rd1_data  <= regs(to_integer(unsigned(rd1_addr)));  bypass(0) <= '0';
        end if;

        if wr_en = '1' and wr_addr = rd2_addr then
            rd2_data  <= wr_data;  bypass(1) <= '1';
        else
            rd2_data  <= regs(to_integer(unsigned(rd2_addr)));  bypass(1) <= '0';
        end if;

        if wr_en = '1' and wr_addr = rd3_addr then
            rd3_data  <= wr_data;  bypass(2) <= '1';
        else
            rd3_data  <= regs(to_integer(unsigned(rd3_addr)));  bypass(2) <= '0';
        end if;
    end process;
end architecture behavioral;
