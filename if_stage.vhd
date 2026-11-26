library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pipe_pkg.all;

-- IF stage: PC + instruction buffer + IF/ID interstage register.
entity if_stage is
    port (
        clk, rst   : in  std_logic;
        -- testbench program-load port (goes straight to the instruction buffer)
        ld_en      : in  std_logic;
        ld_addr    : in  std_logic_vector(5 downto 0);
        ld_data    : in  instr_t;
        -- observation
        pc_out     : out std_logic_vector(5 downto 0);
        fetch_out  : out instr_t;
        -- IF/ID register outputs
        ifid_instr : out instr_t := NOP_INSTR
    );
end entity if_stage;

architecture structural of if_stage is
    signal pc      : unsigned(5 downto 0) := (others => '0');
    signal pc_slv  : std_logic_vector(5 downto 0) := (others => '0');
    signal fetched : instr_t := NOP_INSTR;
begin
    pc_slv    <= std_logic_vector(pc);
    pc_out    <= pc_slv;
    fetch_out <= fetched;

    ibuf : entity work.instr_buffer
        port map (clk => clk, ld_en => ld_en, ld_addr => ld_addr, ld_data => ld_data,
                  pc => pc_slv, instr => fetched);

    pc_proc : process (clk, rst)
    begin
        if rst = '1' then
            pc <= (others => '0');
        elsif rising_edge(clk) then
            pc <= pc + 1;
        end if;
    end process;

    ifid_reg : process (clk, rst)
    begin
        if rst = '1' then
            ifid_instr <= NOP_INSTR;
        elsif rising_edge(clk) then
            ifid_instr <= fetched;
        end if;
    end process;
end architecture structural;
