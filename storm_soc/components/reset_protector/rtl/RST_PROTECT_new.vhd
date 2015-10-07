-- ######################################################
-- #          < STORM SoC by Stephan Nolting >          #
-- # ************************************************** #
-- #                -- RESET Protector --               #
-- # ************************************************** #
-- #  Valid system reset after pushing the RST button   #
-- #  for at least 3 seconds.                           #
-- # ************************************************** #
-- # Last modified: 21.04.2012                          #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RST_PROTECT is
	generic	(
				TRIGGER_VAL   : natural := 50000000; -- controls SYS trigger in sys clocks
				LOW_ACT_RST   : boolean := TRUE;      -- valid reset level
				CPU_TRIGGER_VAL   : natural := 131000 --(tics) controls CPU trigger in sys clocks ~ 3msec
			);
	port	(
				-- Interface --
				MAIN_CLK_I    : in  STD_LOGIC; -- system master clock
				EXT_RST_I     : in  STD_LOGIC; -- external reset input
				SYS_RST_O     : out STD_LOGIC;  -- system master reset
				CPU_RST_O     : out STD_LOGIC  -- system master reset
			);
end RST_PROTECT;

architecture Behavioral of RST_PROTECT is

	--- Counter ---
	signal SYS_RST_CNT   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	signal SYS_RST_STATE : STD_LOGIC := '1';
	signal internal_SYS_RST_O: STD_LOGIC;

		--- Counter ---
	signal CPU_RST_CNT   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	signal CPU_RST_STATE : STD_LOGIC := '1';

begin

	-- SYS_Reset Counter ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		SYS_RESET_COUNTER: process(MAIN_CLK_I)
		begin
			if rising_edge(MAIN_CLK_I) then
				if (SYS_RST_STATE = '0') then -- wait for reset
					SYS_RST_O <= '0';
					if ((EXT_RST_I = '0') and (LOW_ACT_RST = TRUE)) or ((EXT_RST_I = '1') and (LOW_ACT_RST = FALSE)) then
						if (to_integer(unsigned(SYS_RST_CNT)) < TRIGGER_VAL) then -- wait 3 seconds
							SYS_RST_CNT   <= Std_Logic_Vector(unsigned(SYS_RST_CNT) + 1);
							SYS_RST_STATE <= '0';
						else
							SYS_RST_CNT   <= (others => '0');
							SYS_RST_STATE <= '1';
						end if;
					else
						SYS_RST_CNT   <= (others => '0');
						SYS_RST_STATE <= '0';
					end if;
				else -- do reset
					if (to_integer(unsigned(SYS_RST_CNT)) < TRIGGER_VAL/100000) then -- hold reset
						SYS_RST_O <= '1';
						internal_SYS_RST_O <= '1';
						SYS_RST_CNT   <= Std_Logic_Vector(unsigned(SYS_RST_CNT) + 1);
						SYS_RST_STATE <= '1';
					elsif ((EXT_RST_I = '0') and (LOW_ACT_RST = TRUE)) or ((EXT_RST_I = '1') and (LOW_ACT_RST = FALSE)) then -- ext reset still active?
						SYS_RST_O <= '1';
						internal_SYS_RST_O <= '1';
						SYS_RST_STATE <= '1';
					else
						SYS_RST_O <= '0';
						internal_SYS_RST_O <= '0';
						SYS_RST_CNT   <= (others => '0');
						SYS_RST_STATE <= '0';
					end if;
				end if;
			end if;
		end process SYS_RESET_COUNTER;

	-- CPU Reset Counter ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		CPU_RESET_COUNTER: process(MAIN_CLK_I)
		begin
			if rising_edge(MAIN_CLK_I) then
				if (CPU_RST_STATE = '0') then -- wait for reset
					CPU_RST_O <= '0';
					if (internal_SYS_RST_O = '1') then
						-- if (to_integer(unsigned(CPU_RST_CNT)) < TRIGGER_VAL) then -- wait 3 seconds
							-- CPU_RST_CNT   <= Std_Logic_Vector(unsigned(CPU_RST_CNT) + 1);
							-- CPU_RST_STATE <= '0';
						-- else
							CPU_RST_CNT   <= (others => '0');
							CPU_RST_STATE <= '1';
						--end if;
					else
						CPU_RST_CNT   <= (others => '0');
						CPU_RST_STATE <= '0';
					end if;
				else -- do reset
					if ((internal_SYS_RST_O = '1')) then -- Is SYSTEM still in reset, then CPU must be in rest
						CPU_RST_O <= '1';
						CPU_RST_STATE <= '1';
					elsif ((to_integer(unsigned(CPU_RST_CNT)) < CPU_TRIGGER_VAL) ) then -- hold reset about 3ms
						CPU_RST_O <= '1';
						CPU_RST_CNT   <= Std_Logic_Vector(unsigned(CPU_RST_CNT) + 1);
						CPU_RST_STATE <= '1';
					else -- no longer in reset (after 3ms and SYS_RST_O = 0
						CPU_RST_O <= '0';
						CPU_RST_CNT   <= (others => '0');
						CPU_RST_STATE <= '0';
					end if;
				end if;
			end if;
		end process CPU_RESET_COUNTER;


end Behavioral;