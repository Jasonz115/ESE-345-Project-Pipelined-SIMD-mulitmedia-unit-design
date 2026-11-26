library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pipe_pkg is
    subtype word128   is std_logic_vector(127 downto 0);
    subtype instr_t   is std_logic_vector(24 downto 0);
    subtype regaddr_t is std_logic_vector(4 downto 0);
    type reg_array_t is array (0 to 31) of word128;

    -- NOP = R3 format ("11"), opcode 0000, all other fields 0
    constant NOP_INSTR : instr_t := "11" & (22 downto 0 => '0');

    -- Everything the testbench needs to print the per-cycle results file
    type dbg_t is record
        pc        : std_logic_vector(5 downto 0);   -- PC (instruction being fetched)
        if_instr  : instr_t;                        -- instruction in IF
        id_instr  : instr_t;                        -- instruction in ID  (IF/ID register)
        ex_instr  : instr_t;                        -- instruction in EX  (ID/EX register)
        wb_instr  : instr_t;                        -- instruction in WB  (EX/WB register)
        id_addr1  : regaddr_t;                      -- register-file read addresses (ID)
        id_addr2  : regaddr_t;
        id_addr3  : regaddr_t;
        id_use    : std_logic_vector(2 downto 0);   -- which sources the ID instruction really uses
        rf_bypass : std_logic_vector(2 downto 0);   -- write-before-read bypass active on read port 1/2/3
        ex_use    : std_logic_vector(2 downto 0);   -- which sources the EX instruction really uses
        ex_fwd    : std_logic_vector(2 downto 0);   -- forwarding unit decision for rs1/rs2/rs3
        ex_op1    : word128;                        -- ALU operands (after forwarding mux)
        ex_op2    : word128;
        ex_op3    : word128;
        alu_rd    : word128;                        -- ALU result (before EX/WB register)
        alu_wr_en : std_logic;
        alu_des   : regaddr_t;
        wb_en     : std_logic;                      -- register file write port
        wb_addr   : regaddr_t;
        wb_data   : word128;
    end record;

    function mnemonic   (i : instr_t) return string;               -- always 6 characters
    function slv_to_hex (v : std_logic_vector) return string;
    function hex_to_slv (s : string) return std_logic_vector;
    function sl_str     (b : std_logic) return string;
    function reg_str    (a : regaddr_t) return string;
end package pipe_pkg;

package body pipe_pkg is

    function mnemonic (i : instr_t) return string is
    begin
        if i(24) = '0' then
            return "LI    ";
        elsif i(23) = '0' then                       -- R4 format "10"
            case i(22 downto 20) is
                when "000"  => return "SIMALS";
                when "001"  => return "SIMAHS";
                when "010"  => return "SIMSLS";
                when "011"  => return "SIMSHS";
                when "100"  => return "SLMALS";
                when "101"  => return "SLMAHS";
                when "110"  => return "SLMSLS";
                when "111"  => return "SLMSHS";
                when others => return "??????";
            end case;
        else                                         -- R3 format "11"
            case i(18 downto 15) is
                when "0000" => return "NOP   ";
                when "0001" => return "ABSDB ";
                when "0010" => return "AU    ";
                when "0011" => return "CNT1W ";
                when "0100" => return "AHS   ";
                when "0101" => return "AND   ";
                when "0110" => return "BCW   ";
                when "0111" => return "MAXWS ";
                when "1000" => return "MINWS ";
                when "1001" => return "MLHU  ";
                when "1010" => return "MLHCU ";
                when "1011" => return "OR    ";
                when "1100" => return "CNTLZ ";
                when "1101" => return "ROTW  ";
                when "1110" => return "SFWU  ";
                when "1111" => return "SFHS  ";
                when others => return "??????";
            end case;
        end if;
    end function;

    function slv_to_hex (v : std_logic_vector) return string is
        constant n : integer := (v'length + 3) / 4;
        variable vv  : std_logic_vector(v'length-1 downto 0);
        variable p   : std_logic_vector(n*4-1 downto 0) := (others => '0');
        variable s   : string(1 to n);
        variable nib : std_logic_vector(3 downto 0);
    begin
        vv := v;
        p(v'length-1 downto 0) := vv;
        for k in 0 to n-1 loop
            nib := p(p'high - 4*k downto p'high - 4*k - 3);
            case nib is
                when "0000" => s(k+1) := '0';
                when "0001" => s(k+1) := '1';
                when "0010" => s(k+1) := '2';
                when "0011" => s(k+1) := '3';
                when "0100" => s(k+1) := '4';
                when "0101" => s(k+1) := '5';
                when "0110" => s(k+1) := '6';
                when "0111" => s(k+1) := '7';
                when "1000" => s(k+1) := '8';
                when "1001" => s(k+1) := '9';
                when "1010" => s(k+1) := 'A';
                when "1011" => s(k+1) := 'B';
                when "1100" => s(k+1) := 'C';
                when "1101" => s(k+1) := 'D';
                when "1110" => s(k+1) := 'E';
                when "1111" => s(k+1) := 'F';
                when others => s(k+1) := 'X';
            end case;
        end loop;
        return s;
    end function;

    function hex_to_slv (s : string) return std_logic_vector is
        constant n : integer := s'length;
        variable r : std_logic_vector(n*4-1 downto 0);
        variable d : integer;
        variable c : character;
    begin
        for k in 0 to n-1 loop
            c := s(s'low + k);
            case c is
                when '0' to '9' => d := character'pos(c) - character'pos('0');
                when 'a' to 'f' => d := character'pos(c) - character'pos('a') + 10;
                when 'A' to 'F' => d := character'pos(c) - character'pos('A') + 10;
                when others     => d := 0;
            end case;
            r(r'high - 4*k downto r'high - 4*k - 3) := std_logic_vector(to_unsigned(d, 4));
        end loop;
        return r;
    end function;

    function sl_str (b : std_logic) return string is
    begin
        if    b = '1' then return "1";
        elsif b = '0' then return "0";
        else               return "X";
        end if;
    end function;

    function reg_str (a : regaddr_t) return string is
    begin
        return "r" & integer'image(to_integer(unsigned(a)));
    end function;

end package body pipe_pkg;
