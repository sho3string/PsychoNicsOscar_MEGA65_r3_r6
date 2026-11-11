-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Psycho-Nics Oscar / JTFRAME clock generator
--
--   Input:       100.000 MHz
--   MMCM VCO:    600.000 MHz (100 MHz * 6)
--   Main clock:   48.000 MHz (600 MHz / 12.5)
--
-- Oscar's nominal 6 MHz video pixel rate will be generated as a clock enable
-- in the 48 MHz domain. No separate pixel-clock domain is required here.
--
-- MiSTer2MEGA65 by sy2002 and MJoergen (GPL v3)
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk is
   port (
      sys_clk_i  : in  std_logic;  -- 100 MHz input
      main_clk_o : out std_logic;  -- 48 MHz main clock
      main_rst_o : out std_logic   -- active-high reset, synchronized to 48 MHz
   );
end entity clk;

architecture rtl of clk is
   signal clkfb_mmcm   : std_logic;
   signal clkfb_bufg   : std_logic;
   signal main_clk_mmcm: std_logic;
   signal main_clk_bufg: std_logic;
   signal main_locked  : std_logic;
begin
   i_clk_main : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.000,
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => 6.000,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 12.500,
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE
      )
      port map (
         CLKFBOUT     => clkfb_mmcm,
         CLKOUT0      => main_clk_mmcm,
         CLKFBIN      => clkfb_bufg,
         CLKIN1       => sys_clk_i,
         CLKIN2       => '0',
         CLKINSEL     => '1',
         DADDR        => (others => '0'),
         DCLK         => '0',
         DEN          => '0',
         DI           => (others => '0'),
         DO           => open,
         DRDY         => open,
         DWE          => '0',
         PSCLK        => '0',
         PSEN         => '0',
         PSINCDEC     => '0',
         PSDONE       => open,
         LOCKED       => main_locked,
         CLKINSTOPPED => open,
         CLKFBSTOPPED => open,
         PWRDWN       => '0',
         RST          => '0'
      );

   i_clkfb_bufg : BUFG
      port map (
         I => clkfb_mmcm,
         O => clkfb_bufg
      );

   i_main_clk_bufg : BUFG
      port map (
         I => main_clk_mmcm,
         O => main_clk_bufg
      );

   main_clk_o <= main_clk_bufg;

   i_main_reset : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         src_arst  => not main_locked,
         dest_clk  => main_clk_bufg,
         dest_arst => main_rst_o
      );
end architecture rtl;
