library IEEE;
use ieee.std_logic_1164.all;
use work.pipe_pkg.all;

-- ID stage: decode + register-file read addressing + ID/EX interstage register.
--
-- Instruction formats (from the ALU):
--   LI : 0 x  idx[23:21] imm16[20:5]                 rd[4:0]   bit24 = '0'
--   R4 : 10   op[22:20] rs3[19:15] rs2[14:10] rs1[9:5] rd[4:0]
--   R3 : 11   -----  op[18:15]     rs2[14:10] rs1[9:5] rd[4:0]
--
-- "use" flags say which register sources an instruction REALLY reads. Only those may be forwarded.
--   LI    : reads its own rd (old value, the other 7 halfwords are kept) -> address = rd field
--   NOP   : none
--   R3    : rs1 always; rs2 except BCW, CNT1W, CNTLZ (one source) and MLHCU (field 14:10 is a 5-bit immediate)
--   R4    : rs1, rs2, rs3
entity id_stage is
    port (
        clk, rst   : in  std_logic;
        ifid_instr : in  instr_t;
        -- register file read interface
        rf_addr1, rf_addr2, rf_addr3 : out regaddr_t := (others => '0');
        rf_data1, rf_data2, rf_data3 : in  word128;
        -- observation of the decode (combinational, for the instruction in ID)
        dec_use    : out std_logic_vector(2 downto 0);
        -- ID/EX register outputs
        idex_instr : out instr_t;
        idex_addr1, idex_addr2, idex_addr3 : out regaddr_t;
        idex_use1,  idex_use2,  idex_use3  : out std_logic;
        idex_data1, idex_data2, idex_data3 : out word128
    );
end entity id_stage;

architecture structural of id_stage is
    signal a1, a2, a3 : regaddr_t := (others => '0');
    signal u1, u2, u3 : std_logic;
begin
    -- source register addresses
    a1 <= ifid_instr(4 downto 0) when ifid_instr(24) = '0' else ifid_instr(9 downto 5);
    a2 <= ifid_instr(14 downto 10);
    a3 <= ifid_instr(19 downto 15);

    rf_addr1 <= a1;
    rf_addr2 <= a2;
    rf_addr3 <= a3;

    -- which sources are really used
    decode_proc : process (ifid_instr)
    begin
        u1 <= '0';  u2 <= '0';  u3 <= '0';
        if ifid_instr(24) = '0' then                       -- LI
            u1 <= '1';
        elsif ifid_instr(23) = '0' then                    -- R4
            u1 <= '1';  u2 <= '1';  u3 <= '1';
        else                                               -- R3
            case ifid_instr(18 downto 15) is
                when "0000" =>                             -- NOP
                    null;
                when "0110" | "0011" | "1100" | "1010" =>  -- BCW, CNT1W, CNTLZ, MLHCU
                    u1 <= '1';
                when others =>
                    u1 <= '1';  u2 <= '1';
            end case;
        end if;
    end process;

    dec_use <= u3 & u2 & u1;

    -- ID/EX register
    idex_reg : process (clk, rst)
    begin
        if rst = '1' then
            idex_instr <= NOP_INSTR;
            idex_addr1 <= (others => '0');
            idex_addr2 <= (others => '0');
            idex_addr3 <= (others => '0');
            idex_use1  <= '0';
            idex_use2  <= '0';
            idex_use3  <= '0';
            idex_data1 <= (others => '0');
            idex_data2 <= (others => '0');
            idex_data3 <= (others => '0');
        elsif rising_edge(clk) then
            idex_instr <= ifid_instr;
            idex_addr1 <= a1;
            idex_addr2 <= a2;
            idex_addr3 <= a3;
            idex_use1  <= u1;
            idex_use2  <= u2;
            idex_use3  <= u3;
            idex_data1 <= rf_data1;
            idex_data2 <= rf_data2;
            idex_data3 <= rf_data3;
        end if;
    end process;
end architecture structural;
