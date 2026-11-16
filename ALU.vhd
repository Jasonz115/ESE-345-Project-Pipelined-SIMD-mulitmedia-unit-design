library IEEE;
use ieee.std_logic_1164.all;   
use ieee.numeric_std.all;

entity ALU is 
	port ( 
	
	instr : in std_logic_vector(24 downto 0); 
	rs1 : in std_logic_vector(127 downto 0);
	rs2 : in std_logic_vector(127 downto 0);
	rs3 : in std_logic_vector(127 downto 0);
	rd : out std_logic_vector(127 downto 0);	
	wr_en : out std_logic;
	reg_des : out std_logic_vector(4 downto 0)
	
	);				   
	
end entity ALU; 

architecture behavioral of ALU is
    alias type_bits : std_logic_vector(1 downto 0) is instr(24 downto 23);
    alias r3_op     : std_logic_vector(3 downto 0) is instr(18 downto 15);
begin
    reg_des <= instr(4 downto 0);   -- always just the rd field

    process (instr, rs1, rs2, rs3)	  
	variable sum : signed(31 downto 0);	
	variable cnt : integer range 0 to 32;  
	variable a, b : unsigned(7 downto 0);
	variable prod : signed(31 downto 0);
	variable acc : signed (63 downto 0);
	constant MAX32 : signed(63 downto 0) := to_signed(2147483647, 64);
	constant MIN32 : signed(63 downto 0) := to_signed(-2147483647, 64) - 1;	
-- process declarations
	variable prod64 : signed(63 downto 0);
	variable acc65  : signed(64 downto 0);
	constant MAX64  : signed(64 downto 0) := (64 => '0', 63 => '0', others => '1');  --  2^63 - 1
	constant MIN64  : signed(64 downto 0) := (64 => '1', 63 => '1', others => '0');  -- -2^63
	variable idx : integer range 0 to 7;
    begin
        -- defaults, so every path assigns something (no latches)
        rd    <= (others => '0');
        wr_en <= '0';

        case type_bits is
            when "11" =>                       -- R3 format
			wr_en <= '1'; -- default for R3, NOP overrides	
				
                case r3_op is
                    when "0000" =>             -- NOP
					wr_en <= '0';				   
					
                    when "0101" =>             -- AND
					rd <= rs1 and rs2;		   
					
					when "1011"=> 					  
					rd <= rs1 or rs2;		   --OR	   
					
					when "0010" =>  -- AU  
						for i in 0 to 3 loop
						rd(i*32+31 downto i*32) <=
							std_logic_vector( unsigned(rs1(i*32+31 downto i*32))
                            + unsigned(rs2(i*32+31 downto i*32)) );
    				end loop;	
					
					when "1110" =>	 			--SFWU
						for i in 0 to 3 loop
							rd(i*32+31 downto i*32) <= 
							std_logic_vector( unsigned(rs2(i*32+31 downto i*32))
							- unsigned(rs1(i*32+31 downto i*32)) ); 
					end loop;	
					
					when "0110" => 				--BCW	
						for i in 0 to 3 loop
							rd(i*32+31 downto i*32) <= rs1(31 downto 0);
					end loop; 
					
					when "0111" => 				--MAXWS
						for i in 0 to 3 loop
							         if signed(rs1(i*32+31 downto i*32)) > signed(rs2(i*32+31 downto i*32)) then
            							rd(i*32+31 downto i*32) <= (rs1(i*32+31 downto i*32));
        			else
            							rd(i*32+31 downto i*32) <= (rs2(i*32+31 downto i *32));
        			end if;
    				end loop;	
					
					when "1000" =>			--MINWS
					for i in 0 to 3 loop	
						if signed (rs1(i*32+31 downto i*32)) < signed (rs2(i*32+31 downto i*32)) then
							rd(i*32+31 downto i*32) <= (rs1(i*32+31 downto i*32));
						else
							rd(i*32+31 downto i*32) <= (rs2(i*32+31 downto i*32));
						end if;
						end loop;	
						
					when "1101" =>                          -- ROTW
    				for i in 0 to 3 loop
        				rd(i*32+31 downto i*32) <=
            				std_logic_vector(
                			  rotate_right( unsigned(rs1(i*32+31 downto i*32)),
                              to_integer(unsigned(rs2(i*32+4 downto i*32)) ) ));
					end loop;  
					when "0100" =>			 --AHS
					for i in 0 to 7 loop 
						sum := resize(signed(rs1(i*16+15 downto i*16)), 32)+
						resize(signed(rs2(i*16+15 downto i*16)), 32);
						if sum > 32767 then
							rd(i*16+15 downto i*16)<= x"7FFF";
						elsif sum < -32767 then
							rd(i*16+15 downto i*16)<= x"8000";
						else
							rd(i*16+15 downto i*16)<= std_logic_vector(sum(15 downto 0)); 
						end if;	  
						end loop;
						
					when "1111" =>	   --SFHS
					for i in 0 to 7 loop
						sum := resize(signed(rs2(i*16+15 downto i*16)), 32)- 
						resize(signed(rs1(i*16+15 downto i*16)), 32);
						if sum > 32767 then
							rd(i*16+15 downto i*16)<= x"7FFF";
						elsif sum < -32767 then
							rd(i*16+15 downto i*16)<= x"8000";
						else	
							rd(i*16+15 downto i*16)<= std_logic_vector(sum(15 downto 0));
						end if;
						end loop;
						
					when "1001"=>	   --MLHU
					for i in 0 to 3 loop
						rd(i*32+31 downto i*32) <= std_logic_vector(
						unsigned(rs1(i*32+15 downto i*32)) *
						unsigned(rs2(i*32+15 downto i*32)) );
					end loop;		  
					
					when "1010" =>	   --MLHCU
					for i in 0 to 3 loop  
						rd(i*32+31 downto i*32) <= std_logic_vector( resize(
						unsigned(rs1(i*32+15 downto i*32)) *
						unsigned(instr(14 downto 10)), 32));
					end loop;  
					
					when "0011" =>                          -- CNT1W
    				for i in 0 to 3 loop
        				cnt := 0;                       -- reset for every word
        			for j in 0 to 31 loop
            		if rs1(i*32 + j) = '1' then
                		cnt := cnt + 1;
            		end if;
        			end loop;
        				rd(i*32+31 downto i*32) <= std_logic_vector(to_unsigned(cnt, 32));
    				end loop;	
					
					when "1100" =>                          -- CNTLZ
    					for i in 0 to 7 loop
        			cnt := 0;
        			for j in 15 downto 0 loop
            			exit when rs1(i*16 + j) = '1';
            			cnt := cnt + 1;
        			end loop;
        				rd(i*16+15 downto i*16) <= std_logic_vector(to_unsigned(cnt, 16));
    				end loop;
					
					when "0001" =>                          -- ABSDB
    				for i in 0 to 15 loop
        				a := unsigned(rs1(i*8+7 downto i*8));
        				b := unsigned(rs2(i*8+7 downto i*8));
        			if a > b then
            			rd(i*8+7 downto i*8) <= std_logic_vector(a-b);
        			else
            			rd(i*8+7 downto i*8) <= std_logic_vector(b-a);
        			end if;
    				end loop; 
						
					when others =>	
                    	wr_en <= '0';          -- op not implemented yet
                	end case; 
					--------------------------------------r4 op-----------------------------
					when "10" =>		 --Signed Integer Multiply-Add Low with Saturation
					wr_en <= '1';
					case instr(22 downto 20) is 
						
					when "000" =>
						for i in 0 to 3 loop
							prod:= signed(rs3(i*32+15 downto i*32)) * signed(rs2(i*32+15 downto i*32));
							acc:= resize(signed(rs1(i*32+31 downto i*32)), 64) + resize(prod,64);
							if acc > MAX32 then 
								rd(i*32+31 downto i*32) <= x"7FFFFFFF";
							elsif acc < MIN32 then
								rd(i*32+31 downto i*32) <= x"80000000";
							else 
								rd(i*32+31 downto i*32) <= std_logic_vector(acc(31 downto 0));
							end if;
						end loop; 
						
					when "001" =>	   --Signed Integer Multiply-Add High with Saturation
					for i in 0 to 3 loop 
						prod:= signed(rs3(i*32+31 downto i*32+16)) * signed(rs2(i*32+31 downto i*32+16));
						acc := resize(signed(rs1(i*32+31 downto i*32)), 64) + resize(prod, 64);
						if acc > MAX32 then	
							rd(i*32+31 downto i*32) <= x"7FFFFFFF";
						elsif acc < MIN32 then 
							rd(i*32+31 downto i*32) <= x"80000000";
						else 
							rd(i*32+31 downto i*32) <= std_logic_vector(acc(31 downto 0));
						end if;
						end loop;
					
					when "010" =>	   --Signed Integer Mulitply- Subtract low with Saturation
						for i in 0 to 3 loop
							prod:= signed(rs3(i*32+15 downto i*32)) * signed(rs2(i*32+15 downto i*32));
							acc:= resize(signed(rs1(i*32+31 downto i*32)), 64) - resize(prod,64);
							if acc > MAX32 then 
								rd(i*32+31 downto i*32) <= x"7FFFFFFF";
							elsif acc < MIN32 then
								rd(i*32+31 downto i*32) <= x"80000000";
							else 
								rd(i*32+31 downto i*32) <= std_logic_vector(acc(31 downto 0));
							end if;
						end loop; 
					
					when "011" =>		--signed integer mulitply - subtract high with saturation
						for i in 0 to 3 loop 
							prod:= signed(rs3(i*32+31 downto i*32+16)) * signed(rs2(i*32+31 downto i*32+16));
							acc := resize(signed(rs1(i*32+31 downto i*32)), 64) - resize(prod, 64);
							if acc > MAX32 then	
								rd(i*32+31 downto i*32) <= x"7FFFFFFF";
							elsif acc < MIN32 then 
								rd(i*32+31 downto i*32) <= x"80000000";
							else 
								rd(i*32+31 downto i*32) <= std_logic_vector(acc(31 downto 0));
							end if;
						end loop;	
						
					when "100" =>		--signed long mulitply - add low with saturation
					for i in 0 to 1 loop 
						prod64:= signed(rs3(i*64+31 downto i*64)) * signed(rs2(i*64+31 downto i*64));
						acc65 := resize(signed(rs1(i*64+63 downto i*64)), 65) + resize(prod64, 65);
						if acc65 > MAX64 then
							rd(i*64+63 downto i*64) <= x"7FFFFFFFFFFFFFFF";
						elsif acc65 < MIN64 then
							rd(i*64+63 downto i*64) <= x"8000000000000000";
						else 
							rd(i*64+63 downto i*64) <= std_logic_vector(acc65(63 downto 0));
						end if;
					end loop; 
					
					when "101" =>			  --signed long mulitply - add high with saturation
					   	for i in 0 to 1 loop 
						prod64:= signed(rs3(i*64+63 downto i*64+32)) * signed(rs2(i*64+63 downto i*64+32));
						acc65 := resize(signed(rs1(i*64+63 downto i*64)), 65) + resize(prod64, 65);
						if acc65 > MAX64 then
							rd(i*64+63 downto i*64) <= x"7FFFFFFFFFFFFFFF";
						elsif acc65 < MIN64 then
							rd(i*64+63 downto i*64) <= x"8000000000000000";
						else 
							rd(i*64+63 downto i*64) <= std_logic_vector(acc65(63 downto 0));
						end if;
					end loop;  
					
					when "110" =>		   --signed long mulitply - subtract low with saturation
						for i in 0 to 1 loop 
						prod64:= signed(rs3(i*64+31 downto i*64)) * signed(rs2(i*64+31 downto i*64));
						acc65 := resize(signed(rs1(i*64+63 downto i*64)), 65) - resize(prod64, 65);
						if acc65 > MAX64 then
							rd(i*64+63 downto i*64) <= x"7FFFFFFFFFFFFFFF";
						elsif acc65 < MIN64 then
							rd(i*64+63 downto i*64) <= x"8000000000000000";
						else 
							rd(i*64+63 downto i*64) <= std_logic_vector(acc65(63 downto 0));
						end if;
					end loop;  
					
					when "111" =>		   --signed long mulitply - subtract high with saturation
						for i in 0 to 1 loop 
						prod64:= signed(rs3(i*64+63 downto i*64+32)) * signed(rs2(i*64+63 downto i*64+32));
						acc65 := resize(signed(rs1(i*64+63 downto i*64)), 65) - resize(prod64, 65);
						if acc65 > MAX64 then
							rd(i*64+63 downto i*64) <= x"7FFFFFFFFFFFFFFF";
						elsif acc65 < MIN64 then
							rd(i*64+63 downto i*64) <= x"8000000000000000";
						else 
							rd(i*64+63 downto i*64) <= std_logic_vector(acc65(63 downto 0));
						end if;
					end loop; 
										
				when others =>
					wr_en <= '0';
				end case;
				
				
				
				when "00" | "01" =>                       -- Load Immediate
    				wr_en <= '1';
		idx := to_integer(unsigned(instr(23 downto 21)));
    				rd <= rs1;                            -- keep all fields (rs1 carries the old rd value)
    				rd(idx*16+15 downto idx*16) <= instr(20 downto 5);	
	
						
									
										
        when others =>
            null;
    end case;                             -- closes the type_bits case
end process;
end architecture behavioral;