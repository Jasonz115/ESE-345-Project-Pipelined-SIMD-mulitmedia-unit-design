-- shared signal types for the four pipeline stages
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pipeline_types is
    subtype instruction is std_logic_vector(24 downto 0);
    subtype reg_index is std_logic_vector(4 downto 0);
    subtype reg_value is std_logic_vector(127 downto 0);
    type reg_bank is array (0 to 31) of reg_value;
    type source_ids is array (1 to 3) of reg_index;
    type operands is array (1 to 3) of reg_value;
    subtype source_mask is std_logic_vector(1 to 3);
    constant nop : instruction := "11" & (22 downto 0 => '0');
    -- carry the instruction address into each stage for the cycle trace
    type stage is record
        valid : std_logic;
        pc : natural range 0 to 63;
        ins : instruction;
    end record;
    -- valid is low for an empty stage and high for a fetched NOP
    constant bubble : stage := ('0', 0, nop);
    type execute_input is record
        slot : stage;
        ids : source_ids;
        used : source_mask;
        data : operands;
    end record;
    type writeback is record
        slot : stage;
        enable : std_logic;
        dest : reg_index;
        data : reg_value;
    end record;
    constant empty_ex : execute_input :=
        (bubble, (others => (others => '0')), "000", (others => (others => '0')));
    constant empty_wb : writeback := (bubble, '0', (others => '0'), (others => '0'));
    type pipeline_trace is record
        fetch, decode : stage;
        ex : execute_input;
        wb : writeback;
        alu_inputs : operands;
        forwarded : source_mask;
        decode_bypass : source_mask;
        alu_result : reg_value;
        alu_write : std_logic;
    end record;

    -- text helpers for the results file; plain VHDL-93, so no to_string / to_hstring / hread
    function mnemonic (ins : instruction) return string;      -- "AU", "LI", "NOP", ...
    function to_hex (v : std_logic_vector) return string;
    function to_bin (v : std_logic_vector) return string;
    function reg_name (r : reg_index) return string;          -- "r17"
    function valid_hex (s : string) return boolean;
    function hex_to_slv (s : string) return std_logic_vector;
end package;

package body pipeline_types is

    function mnemonic (ins : instruction) return string is
    begin
        if ins(24) = '0' then
            return "LI";
        elsif ins(23) = '0' then                       -- R4 format
            case ins(22 downto 20) is
                when "000"  => return "SIMALS";
                when "001"  => return "SIMAHS";
                when "010"  => return "SIMSLS";
                when "011"  => return "SIMSHS";
                when "100"  => return "SLMALS";
                when "101"  => return "SLMAHS";
                when "110"  => return "SLMSLS";
                when "111"  => return "SLMSHS";
                when others => return "R4?";
            end case;
        else                                           -- R3 format
            case ins(18 downto 15) is
                when "0000" => return "NOP";
                when "0001" => return "ABSDB";
                when "0010" => return "AU";
                when "0011" => return "CNT1W";
                when "0100" => return "AHS";
                when "0101" => return "AND";
                when "0110" => return "BCW";
                when "0111" => return "MAXWS";
                when "1000" => return "MINWS";
                when "1001" => return "MLHU";
                when "1010" => return "MLHCU";
                when "1011" => return "OR";
                when "1100" => return "CNTLZ";
                when "1101" => return "ROTW";
                when "1110" => return "SFWU";
                when "1111" => return "SFHS";
                when others => return "R3?";
            end case;
        end if;
    end function;

    function to_hex (v : std_logic_vector) return string is
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

    function to_bin (v : std_logic_vector) return string is
        variable s : string(1 to v'length);
        variable k : integer := 0;
    begin
        for i in v'range loop
            k := k + 1;
            case v(i) is
                when '0'    => s(k) := '0';
                when '1'    => s(k) := '1';
                when others => s(k) := 'X';
            end case;
        end loop;
        return s;
    end function;

    function reg_name (r : reg_index) return string is
    begin
        for i in r'range loop
            if r(i) /= '0' and r(i) /= '1' then
                return "r?";
            end if;
        end loop;
        return "r" & integer'image(to_integer(unsigned(r)));
    end function;

    function valid_hex (s : string) return boolean is
    begin
        for k in s'range loop
            case s(k) is
                when '0' to '9' | 'a' to 'f' | 'A' to 'F' => null;
                when others => return false;
            end case;
        end loop;
        return true;
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

end package body;
