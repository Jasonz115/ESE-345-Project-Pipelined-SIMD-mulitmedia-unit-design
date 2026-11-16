library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU_tb is
end entity ALU_tb;

architecture sim of ALU_tb is

    -- signals wire to alu.vhd
    signal s_instr   : std_logic_vector(24 downto 0)  := (others => '0');
    signal s_rs1     : std_logic_vector(127 downto 0) := (others => '0');
    signal s_rs2     : std_logic_vector(127 downto 0) := (others => '0');
    signal s_rs3     : std_logic_vector(127 downto 0) := (others => '0');
    signal s_rd      : std_logic_vector(127 downto 0);
    signal s_wr_en   : std_logic;
    signal s_reg_des : std_logic_vector(4 downto 0);

    constant ZERO : std_logic_vector(127 downto 0) := (others => '0');

    -- R3 opcodes 
    constant OP_NOP    : std_logic_vector(3 downto 0) := "0000";
    constant OP_ABSDB  : std_logic_vector(3 downto 0) := "0001";
    constant OP_AU     : std_logic_vector(3 downto 0) := "0010";
    constant OP_CNT1W  : std_logic_vector(3 downto 0) := "0011";
    constant OP_AHS    : std_logic_vector(3 downto 0) := "0100";
    constant OP_AND    : std_logic_vector(3 downto 0) := "0101";
    constant OP_BCW    : std_logic_vector(3 downto 0) := "0110";
    constant OP_MAXWS  : std_logic_vector(3 downto 0) := "0111";
    constant OP_MINWS  : std_logic_vector(3 downto 0) := "1000";
    constant OP_MLHU   : std_logic_vector(3 downto 0) := "1001";
    constant OP_MLHCU  : std_logic_vector(3 downto 0) := "1010";
    constant OP_OR     : std_logic_vector(3 downto 0) := "1011";
    constant OP_ROTW   : std_logic_vector(3 downto 0) := "1101";
    constant OP_SFWU   : std_logic_vector(3 downto 0) := "1110";
    constant OP_SFHS   : std_logic_vector(3 downto 0) := "1111";
	constant OP_CNTLZ : std_logic_vector(3 downto 0) := "1100";
	-- R4 opcodes	OP_|I = integer/ L = long| A = add, S = subtract| L= low, H = high
	constant OP_IAL : std_logic_vector(2 downto 0) := "000";
	constant OP_IAH : std_logic_vector(2 downto 0) := "001";
	constant OP_ISL : std_logic_vector(2 downto 0) := "010";
	constant OP_ISH : std_logic_vector(2 downto 0) := "011";
	constant OP_LAL	: std_logic_vector(2 downto 0) := "100";
	constant OP_LAH : std_logic_vector(2 downto 0) := "101";
	constant OP_LSL : std_logic_vector(2 downto 0) := "110";
	constant OP_LSH : std_logic_vector(2 downto 0) := "111";
	
	
	

    -- builds a 25-bit R3 instruction: 11 | xxxx op | rs2 field | rs1 field=1 | rd field=3
    function mk_r3 (op : std_logic_vector(3 downto 0);
                    f2 : std_logic_vector(4 downto 0) := "00010")
                    return std_logic_vector is		 
	begin
        return "11" & "0000" & op & f2 & "00001" & "00011";
    end function;
	
	-- R4: 10 | op[22:20] | rs3 field | rs2 field | rs1 field | rd field=00101
    function mk_r4 (op : std_logic_vector(2 downto 0))
			return std_logic_vector is	
	begin
        return "10" & op & "00100" & "00011" & "00010" & "00101";
    end function;
	
	   -- Load Immediate: 0 | load index [23:21] | 16-bit immediate [20:5] | rd field [4:0]
    function mk_li (idx : std_logic_vector(2 downto 0);
                    imm : std_logic_vector(15 downto 0))
                    return std_logic_vector is
    begin
        return "0" & idx & imm & "00011";
    end function;
	
					

    -- 128-bit vector to 32-character hex string (for readable reports)
    function to_hex (v : std_logic_vector(127 downto 0)) return string is
        variable r   : string(1 to 32);
        variable nib : std_logic_vector(3 downto 0);
        constant hx  : string(1 to 16) := "0123456789ABCDEF";
    begin
        for k in 0 to 31 loop
            nib    := v(127-4*k downto 124-4*k);
            r(k+1) := hx(to_integer(unsigned(nib)) + 1);
        end loop;
        return r;
    end function;

begin

    uut : entity work.ALU
        port map (
            instr   => s_instr,
            rs1     => s_rs1,
            rs2     => s_rs2,
            rs3     => s_rs3,
            rd      => s_rd,
            wr_en   => s_wr_en,
            reg_des => s_reg_des
        );

    stim : process
        variable fails : integer := 0;
        variable total : integer := 0;

        procedure run_test (
            name     : in string;
            i_word   : in std_logic_vector(24 downto 0);
            a, b, c  : in std_logic_vector(127 downto 0);
            expected : in std_logic_vector(127 downto 0);
            exp_we   : in std_logic;
            check_rd : in boolean := true
        ) is
            variable ok : boolean := true;
        begin
            s_instr <= i_word;
            s_rs1   <= a;
            s_rs2   <= b;
            s_rs3   <= c;
            wait for 10 ns;

            total := total + 1;
            if check_rd and (s_rd /= expected) then ok := false; end if;
            if s_wr_en /= exp_we then ok := false; end if;
            if s_reg_des /= i_word(4 downto 0) then ok := false; end if;

            if ok then
                report "PASS: " & name & "  rd=" & to_hex(s_rd) severity note;
            else
                fails := fails + 1;
                report "FAIL: " & name & "  got=" & to_hex(s_rd) &
                       "  expected=" & to_hex(expected) severity error;
            end if;
        end procedure;

    begin
        -- NOP: must not write (rd value is not checked)
        run_test("NOP", mk_r3(OP_NOP), ZERO, ZERO, ZERO, ZERO, '0', false);

        -- ABSDB: absolute difference of 16 bytes
        run_test("ABSDB", mk_r3(OP_ABSDB),
                 x"FF008010_20304050_60708090_A0B0C0D0",
                 x"00FF7F20_20105050_10908000_A0FF00D1",
                 ZERO,
                 x"FFFF0110_00201000_50200090_004FC001", '1');

        -- AU: add word unsigned (word 3 wraps, no carry into neighbors)
        run_test("AU", mk_r3(OP_AU),
                 x"FFFFFFFF_00000001_00000002_00000003",
                 x"00000001_00000001_00000001_00000001",
                 ZERO,
                 x"00000000_00000002_00000003_00000004", '1');

        -- CNT1W: count 1s in each word (32, 0, 2, 16)
        run_test("CNT1W", mk_r3(OP_CNT1W),
                 x"FFFFFFFF_00000000_80000001_0F0F0F0F",
                 ZERO, ZERO,
                 x"00000020_00000000_00000002_00000010", '1');

        -- AHS: add halfword saturated (HW7 clamps high, HW6 clamps low)
        run_test("AHS", mk_r3(OP_AHS),
                 x"7FFF8000_0001FFFF_7FFF8000_0001FFFF",
                 x"0001FFFF_00010001_00000000_FFFF0001",
                 ZERO,
                 x"7FFF8000_00020000_7FFF8000_00000000", '1');

        -- AND
        run_test("AND", mk_r3(OP_AND),
                 x"FFFF0000_FFFF0000_FFFF0000_FFFF0000",
                 x"FF00FF00_FF00FF00_FF00FF00_FF00FF00",
                 ZERO,
                 x"FF000000_FF000000_FF000000_FF000000", '1');

        -- BCW: broadcast rightmost word of rs1
        run_test("BCW", mk_r3(OP_BCW),
                 x"AAAAAAAA_BBBBBBBB_CCCCCCCC_12345678",
                 ZERO, ZERO,
                 x"12345678_12345678_12345678_12345678", '1');

        -- MAXWS: signed max per word
        run_test("MAXWS", mk_r3(OP_MAXWS),
                 x"FFFFFFFF_00000005_80000000_00000001",
                 x"00000001_00000003_00000000_FFFFFFFF",
                 ZERO,
                 x"00000001_00000005_00000000_00000001", '1');

        -- MINWS: signed min per word
        run_test("MINWS", mk_r3(OP_MINWS),
                 x"FFFFFFFF_00000005_80000000_00000001",
                 x"00000001_00000003_00000000_FFFFFFFF",
                 ZERO,
                 x"FFFFFFFF_00000003_80000000_FFFFFFFF", '1');

        -- MLHU: low halves multiplied as unsigned
        run_test("MLHU", mk_r3(OP_MLHU),
                 x"0000FFFF_ABCD0003_00008000_00000001",
                 x"0000FFFF_12340004_00000002_0000FFFF",
                 ZERO,
                 x"FFFE0001_0000000C_00010000_0000FFFF", '1');

        -- MLHCU: low half times 5-bit constant from instr[14:10] (here 5); rs2 ignored
        run_test("MLHCU", mk_r3(OP_MLHCU, "00101"),
                 x"0000FFFF_ABCD0003_00008000_00000001",
                 x"FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF",
                 ZERO,
                 x"0004FFFB_0000000F_00028000_00000005", '1');

        -- OR
        run_test("OR", mk_r3(OP_OR),
                 x"FFFF0000_FFFF0000_FFFF0000_FFFF0000",
                 x"FF00FF00_FF00FF00_FF00FF00_FF00FF00",
                 ZERO,
                 x"FFFFFF00_FFFFFF00_FFFFFF00_FFFFFF00", '1');

        -- ROTW: rotate each word of rs1 right by low 5 bits of matching rs2 word
        run_test("ROTW", mk_r3(OP_ROTW),
                 x"00000001_80000000_12345678_000000F0",
                 x"00000001_0000001F_00000004_FFFFFFE4",
                 ZERO,
                 x"80000000_00000001_81234567_0000000F", '1');

        -- SFWU: rd = rs2 - rs1 per word (wraps)
        run_test("SFWU", mk_r3(OP_SFWU),
                 x"FFFFFFFF_00000001_00000002_00000003",
                 x"00000001_00000001_00000001_00000001",
                 ZERO,
                 x"00000002_00000000_FFFFFFFF_FFFFFFFE", '1');

        -- SFHS: rd = rs2 - rs1 per halfword, saturated (HW2 clamps high)
        run_test("SFHS (clamp high)", mk_r3(OP_SFHS),
                 x"7FFF8000_0001FFFF_7FFF8000_0001FFFF",
                 x"0001FFFF_00010001_00000000_FFFF0001",
                 ZERO,
                 x"80027FFF_00000002_80017FFF_FFFE0002", '1');

        -- SFHS: HW0 = 8000 - 0001 = -32769, must clamp to 8000
        run_test("SFHS (clamp low)", mk_r3(OP_SFHS),
                 x"00000000_00000000_00000000_00000001",
                 x"00000000_00000000_00000000_00008000",
                 ZERO,
                 x"00000000_00000000_00000000_00008000", '1'); 
		
				 
		        -- 1100: count leading zeros per word 
        run_test("CNTLZ", mk_r3(OP_CNTLZ),
                 x"0000_0001_8000_00FF_0F00_FFFF_4000_0000",
                 ZERO, ZERO,
                 x"0010_000F_0000_0008_0004_0000_0001_0010", '1');

        --R4 Int (32-bit fields)
        -- args to run_test: name, instr, rs1, rs2, rs3, expected, wr_en
        run_test("R4 IAL", mk_r4(OP_IAL),
                 x"7FFFFFFF_00000010_80000000_00000005",
                 x"00000002_00000003_00000004_00000003",
                 x"00000002_00000003_00000004_00000002",
                 x"7FFFFFFF_00000019_80000010_0000000B", '1');

        run_test("R4 IAL (neg clamp)", mk_r4(OP_IAL),
                 x"80000000_80000000_80000000_80000000",
                 x"0000FFFF_0000FFFF_0000FFFF_0000FFFF",
                 x"00007FFF_00007FFF_00007FFF_00007FFF",
                 x"80000000_80000000_80000000_80000000", '1');

        -- low halves are decoys (FFFF), real values are in the high halves
        run_test("R4 IAH", mk_r4(OP_IAH),
                 x"7FFFFFFF_00000010_80000000_00000005",
                 x"0002FFFF_0003FFFF_0004FFFF_0003FFFF",
                 x"0002FFFF_0003FFFF_0004FFFF_0002FFFF",
                 x"7FFFFFFF_00000019_80000010_0000000B", '1');

        run_test("R4 ISL", mk_r4(OP_ISL),
                 x"7FFFFFFF_00000010_80000000_00000005",
                 x"00000002_00000003_00000004_00000003",
                 x"00000002_00000003_00000004_00000002",
                 x"7FFFFFFB_00000007_80000000_FFFFFFFF", '1');

        -- 7FFFFFFF - (-32767) overflows upward
        run_test("R4 ISL (pos clamp)", mk_r4(OP_ISL),
                 x"7FFFFFFF_7FFFFFFF_7FFFFFFF_7FFFFFFF",
                 x"0000FFFF_0000FFFF_0000FFFF_0000FFFF",
                 x"00007FFF_00007FFF_00007FFF_00007FFF",
                 x"7FFFFFFF_7FFFFFFF_7FFFFFFF_7FFFFFFF", '1');

        run_test("R4 ISH", mk_r4(OP_ISH),
                 x"7FFFFFFF_00000010_80000000_00000005",
                 x"0002FFFF_0003FFFF_0004FFFF_0003FFFF",
                 x"0002FFFF_0003FFFF_0004FFFF_0002FFFF",
                 x"7FFFFFFB_00000007_80000000_FFFFFFFF", '1');

        -- R4 Long (64-bit fields) 
        run_test("R4 LAL", mk_r4(OP_LAL),
                 x"7FFFFFFFFFFFFFFF_0000000000000010",
                 x"0000000000000004_0000000000000005",
                 x"0000000000000002_0000000000000003",
                 x"7FFFFFFFFFFFFFFF_000000000000001F", '1');

        run_test("R4 LAL (neg clamp)", mk_r4(OP_LAL),
                 x"8000000000000000_8000000000000000",
                 x"00000000FFFFFFFF_00000000FFFFFFFF",
                 x"0000000000000001_0000000000000001",
                 x"8000000000000000_8000000000000000", '1');

        -- low 32 bits are decoys (FFFFFFFF), real values are in the high 32 bits
        run_test("R4 LAH", mk_r4(OP_LAH),
                 x"7FFFFFFFFFFFFFFF_0000000000000010",
                 x"00000004FFFFFFFF_00000005FFFFFFFF",
                 x"00000002FFFFFFFF_00000003FFFFFFFF",
                 x"7FFFFFFFFFFFFFFF_000000000000001F", '1');

        run_test("R4 LSL", mk_r4(OP_LSL),
                 x"7FFFFFFFFFFFFFFF_0000000000000010",
                 x"0000000000000004_0000000000000005",
                 x"0000000000000002_0000000000000003",
                 x"7FFFFFFFFFFFFFF7_0000000000000001", '1');

        -- 7FFF...F - (-1) overflows upward
        run_test("R4 LSL (pos clamp)", mk_r4(OP_LSL),
                 x"7FFFFFFFFFFFFFFF_7FFFFFFFFFFFFFFF",
                 x"00000000FFFFFFFF_00000000FFFFFFFF",
                 x"0000000000000001_0000000000000001",
                 x"7FFFFFFFFFFFFFFF_7FFFFFFFFFFFFFFF", '1');

        run_test("R4 LSH", mk_r4(OP_LSH),
                 x"7FFFFFFFFFFFFFFF_0000000000000010",
                 x"00000004FFFFFFFF_00000005FFFFFFFF",
                 x"00000002FFFFFFFF_00000003FFFFFFFF",
                 x"7FFFFFFFFFFFFFF7_0000000000000001", '1');

        --Load Immediate 
        run_test("LI idx 010", mk_li("010", x"1234"),
                 x"FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF", ZERO, ZERO,
                 x"FFFFFFFF_FFFFFFFF_FFFF1234_FFFFFFFF", '1');

        run_test("LI idx 000", mk_li("000", x"ABCD"),
                 x"FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF", ZERO, ZERO,
                 x"FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFABCD", '1');

        run_test("LI idx 111", mk_li("111", x"BEEF"),
                 x"11111111_22222222_33333333_44444444", ZERO, ZERO,
                 x"BEEF1111_22222222_33333333_44444444", '1');

        run_test("LI idx 100", mk_li("100", x"5A5A"),
                 x"11111111_22222222_33333333_44444444", ZERO, ZERO,
                 x"11111111_22225A5A_33333333_44444444", '1');
				 
		

        report "DONE: " & integer'image(total - fails) & " of " &
               integer'image(total) & " tests passed" severity note;
        wait;
    end process;

end architecture sim;