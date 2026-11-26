library IEEE;
use ieee.std_logic_1164.all;
use work.pipe_pkg.all;

-- Four-stage pipelined multimedia unit:  IF -> ID -> EX -> WB
entity pipeline_top is
    port (
        clk, rst : in  std_logic;
        -- program load port (testbench -> instruction buffer)
        ld_en    : in  std_logic;
        ld_addr  : in  std_logic_vector(5 downto 0);
        ld_data  : in  instr_t;
        -- observation ports (testbench only)
        dbg      : out dbg_t;
        regs_out : out reg_array_t
    );
end entity pipeline_top;

architecture structural of pipeline_top is
    -- IF
    signal pc          : std_logic_vector(5 downto 0) := (others => '0');
    signal fetch_instr : instr_t := NOP_INSTR;
    signal ifid_instr  : instr_t := NOP_INSTR;
    -- ID
    signal rf_a1, rf_a2, rf_a3 : regaddr_t := (others => '0');
    signal rf_d1, rf_d2, rf_d3 : word128;
    signal rf_bypass   : std_logic_vector(2 downto 0);
    signal id_use      : std_logic_vector(2 downto 0);
    signal idex_instr  : instr_t := NOP_INSTR;
    signal idex_a1, idex_a2, idex_a3 : regaddr_t;
    signal idex_u1, idex_u2, idex_u3 : std_logic;
    signal idex_d1, idex_d2, idex_d3 : word128;
    -- EX
    signal ex_fwd      : std_logic_vector(2 downto 0);
    signal ex_op1, ex_op2, ex_op3 : word128;
    signal alu_rd      : word128;
    signal alu_we      : std_logic;
    signal alu_des     : regaddr_t;
    signal exwb_instr  : instr_t := NOP_INSTR;
    signal exwb_rd     : word128;
    signal exwb_we     : std_logic;
    signal exwb_des    : regaddr_t;
    -- WB
    signal wr_en       : std_logic := '0';
    signal wr_addr     : regaddr_t := (others => '0');
    signal wr_data     : word128 := (others => '0');
begin
    u_if : entity work.if_stage
        port map (clk => clk, rst => rst,
                  ld_en => ld_en, ld_addr => ld_addr, ld_data => ld_data,
                  pc_out => pc, fetch_out => fetch_instr,
                  ifid_instr => ifid_instr);

    u_id : entity work.id_stage
        port map (clk => clk, rst => rst, ifid_instr => ifid_instr,
                  rf_addr1 => rf_a1, rf_addr2 => rf_a2, rf_addr3 => rf_a3,
                  rf_data1 => rf_d1, rf_data2 => rf_d2, rf_data3 => rf_d3,
                  dec_use => id_use,
                  idex_instr => idex_instr,
                  idex_addr1 => idex_a1, idex_addr2 => idex_a2, idex_addr3 => idex_a3,
                  idex_use1 => idex_u1, idex_use2 => idex_u2, idex_use3 => idex_u3,
                  idex_data1 => idex_d1, idex_data2 => idex_d2, idex_data3 => idex_d3);

    u_rf : entity work.regfile
        port map (clk => clk, rst => rst,
                  rd1_addr => rf_a1, rd2_addr => rf_a2, rd3_addr => rf_a3,
                  rd1_data => rf_d1, rd2_data => rf_d2, rd3_data => rf_d3,
                  bypass => rf_bypass,
                  wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
                  regs_out => regs_out);

    u_ex : entity work.ex_stage
        port map (clk => clk, rst => rst,
                  idex_instr => idex_instr,
                  idex_addr1 => idex_a1, idex_addr2 => idex_a2, idex_addr3 => idex_a3,
                  idex_use1 => idex_u1, idex_use2 => idex_u2, idex_use3 => idex_u3,
                  idex_data1 => idex_d1, idex_data2 => idex_d2, idex_data3 => idex_d3,
                  fwd_out => ex_fwd,
                  op1_out => ex_op1, op2_out => ex_op2, op3_out => ex_op3,
                  alu_rd_out => alu_rd, alu_we_out => alu_we, alu_des_out => alu_des,
                  exwb_instr => exwb_instr, exwb_rd => exwb_rd,
                  exwb_wr_en => exwb_we, exwb_reg_des => exwb_des);

    u_wb : entity work.wb_stage
        port map (exwb_rd => exwb_rd, exwb_wr_en => exwb_we, exwb_reg_des => exwb_des,
                  rf_wr_en => wr_en, rf_wr_addr => wr_addr, rf_wr_data => wr_data);

    -- observation record
    dbg.pc        <= pc;
    dbg.if_instr  <= fetch_instr;
    dbg.id_instr  <= ifid_instr;
    dbg.ex_instr  <= idex_instr;
    dbg.wb_instr  <= exwb_instr;
    dbg.id_addr1  <= rf_a1;
    dbg.id_addr2  <= rf_a2;
    dbg.id_addr3  <= rf_a3;
    dbg.id_use    <= id_use;
    dbg.rf_bypass <= rf_bypass;
    dbg.ex_use    <= idex_u3 & idex_u2 & idex_u1;
    dbg.ex_fwd    <= ex_fwd;
    dbg.ex_op1    <= ex_op1;
    dbg.ex_op2    <= ex_op2;
    dbg.ex_op3    <= ex_op3;
    dbg.alu_rd    <= alu_rd;
    dbg.alu_wr_en <= alu_we;
    dbg.alu_des   <= alu_des;
    dbg.wb_en     <= wr_en;
    dbg.wb_addr   <= wr_addr;
    dbg.wb_data   <= wr_data;
end architecture structural;
