library IEEE;
use ieee.std_logic_1164.all;
use work.pipe_pkg.all;

-- EX stage: forwarding unit + operand muxes + multimedia ALU + EX/WB interstage register.
entity ex_stage is
    port (
        clk, rst   : in  std_logic;
        -- ID/EX register outputs
        idex_instr : in  instr_t;
        idex_addr1, idex_addr2, idex_addr3 : in regaddr_t;
        idex_use1,  idex_use2,  idex_use3  : in std_logic;
        idex_data1, idex_data2, idex_data3 : in word128;
        -- observation
        fwd_out    : out std_logic_vector(2 downto 0);
        op1_out, op2_out, op3_out : out word128;
        alu_rd_out : out word128;
        alu_we_out : out std_logic;
        alu_des_out: out regaddr_t;
        -- EX/WB register outputs
        exwb_instr   : out instr_t;
        exwb_rd      : out word128;
        exwb_wr_en   : out std_logic;
        exwb_reg_des : out regaddr_t
    );
end entity ex_stage;

architecture structural of ex_stage is
    signal fwd1, fwd2, fwd3    : std_logic;
    signal op1, op2, op3       : word128;
    signal alu_rd              : word128;
    signal alu_we              : std_logic;
    signal alu_des             : regaddr_t;
    -- EX/WB register contents (also fed back to the forwarding unit / muxes)
    signal r_rd                : word128 := (others => '0');
    signal r_we                : std_logic := '0';
    signal r_des               : regaddr_t := (others => '0');
    signal r_instr             : instr_t := NOP_INSTR;
begin
    fu : entity work.forwarding_unit
        port map (idex_addr1 => idex_addr1, idex_addr2 => idex_addr2, idex_addr3 => idex_addr3,
                  idex_use1  => idex_use1,  idex_use2  => idex_use2,  idex_use3  => idex_use3,
                  exwb_wr_en => r_we, exwb_reg_des => r_des,
                  fwd1 => fwd1, fwd2 => fwd2, fwd3 => fwd3);

    -- operand muxes: forwarded value comes from the EX/WB register
    op1 <= r_rd when fwd1 = '1' else idex_data1;
    op2 <= r_rd when fwd2 = '1' else idex_data2;
    op3 <= r_rd when fwd3 = '1' else idex_data3;

    alu_inst : entity work.ALU
        port map (instr => idex_instr, rs1 => op1, rs2 => op2, rs3 => op3,
                  rd => alu_rd, wr_en => alu_we, reg_des => alu_des);

    exwb_reg : process (clk, rst)
    begin
        if rst = '1' then
            r_rd    <= (others => '0');
            r_we    <= '0';
            r_des   <= (others => '0');
            r_instr <= NOP_INSTR;
        elsif rising_edge(clk) then
            r_rd    <= alu_rd;
            r_we    <= alu_we;
            r_des   <= alu_des;
            r_instr <= idex_instr;
        end if;
    end process;

    fwd_out      <= fwd3 & fwd2 & fwd1;
    op1_out      <= op1;
    op2_out      <= op2;
    op3_out      <= op3;
    alu_rd_out   <= alu_rd;
    alu_we_out   <= alu_we;
    alu_des_out  <= alu_des;
    exwb_instr   <= r_instr;
    exwb_rd      <= r_rd;
    exwb_wr_en   <= r_we;
    exwb_reg_des <= r_des;
end architecture structural;
