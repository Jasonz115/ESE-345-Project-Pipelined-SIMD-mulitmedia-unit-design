library IEEE;
use ieee.std_logic_1164.all;
use work.pipe_pkg.all;

-- Forwarding unit (EX stage).
-- The only instruction ahead of the one in EX that has not yet reached the register file
-- is the one sitting in the EX/WB register, so there is exactly one forwarding source.
-- (Producer two instructions ahead is handled by the register-file write-before-read bypass.)
--
-- Forward a source only when ALL of these hold (lecture slides 6-7, adapted to this ISA):
--   * the EX instruction really uses that source (use flag: NOP / immediate fields excluded)
--   * the instruction in EX/WB really writes a register (wr_en = '1': NOPs excluded)
--   * its destination register equals the source register address
-- No "register /= 0" check: r0 is an ordinary register in this design.
entity forwarding_unit is
    port (
        idex_addr1, idex_addr2, idex_addr3 : in regaddr_t;
        idex_use1,  idex_use2,  idex_use3  : in std_logic;
        exwb_wr_en   : in  std_logic;
        exwb_reg_des : in  regaddr_t;
        fwd1, fwd2, fwd3 : out std_logic
    );
end entity forwarding_unit;

architecture behavioral of forwarding_unit is
begin
    fwd1 <= '1' when (idex_use1 = '1' and exwb_wr_en = '1' and exwb_reg_des = idex_addr1) else '0';
    fwd2 <= '1' when (idex_use2 = '1' and exwb_wr_en = '1' and exwb_reg_des = idex_addr2) else '0';
    fwd3 <= '1' when (idex_use3 = '1' and exwb_wr_en = '1' and exwb_reg_des = idex_addr3) else '0';
end architecture behavioral;
