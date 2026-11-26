library IEEE;
use ieee.std_logic_1164.all;
use work.pipe_pkg.all;

-- WB stage: drives the register-file write port from the EX/WB register.
-- The register file itself (written on the clock edge that ends this stage) is the
-- final "register" of the pipeline, so this stage has no output register of its own.
entity wb_stage is
    port (
        exwb_rd      : in  word128;
        exwb_wr_en   : in  std_logic;
        exwb_reg_des : in  regaddr_t;
        rf_wr_en     : out std_logic;
        rf_wr_addr   : out regaddr_t;
        rf_wr_data   : out word128
    );
end entity wb_stage;

architecture structural of wb_stage is
begin
    rf_wr_en   <= exwb_wr_en;
    rf_wr_addr <= exwb_reg_des;
    rf_wr_data <= exwb_rd;
end architecture structural;
