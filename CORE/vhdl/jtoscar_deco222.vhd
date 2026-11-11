----------------------------------------------------------------------------------
-- Psycho-Nics Oscar: DECO 222-compatible encrypted 6502 opcode fetches.
-- The T65 core is the existing JTFRAME-recommended 6502 implementation.
-- Original ROM and RAM bytes remain unmodified in main.vhd.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity jtoscar_deco222 is
   port (
      clk                   : in  std_logic;
      reset                 : in  std_logic;
      cpu_cen               : in  std_logic;
      irq_n                 : in  std_logic;
      nmi_n                 : in  std_logic;
      address               : out std_logic_vector(15 downto 0);
      data_in               : in  std_logic_vector(7 downto 0);
      data_out              : out std_logic_vector(7 downto 0);
      read_nwrite           : out std_logic;
      write_strobe          : out std_logic
   );
end entity jtoscar_deco222;

architecture rtl of jtoscar_deco222 is
   signal t65_addr            : std_logic_vector(23 downto 0);
   signal t65_din             : std_logic_vector(7 downto 0);
   signal t65_dout            : std_logic_vector(7 downto 0);
   signal t65_rnw             : std_logic;
   signal t65_sync            : std_logic;
   signal opcode_data         : std_logic_vector(7 downto 0);
begin

   -- MAME DECO_222: swap bits 5 and 6 on opcode fetches only.
   opcode_data <= data_in(7) & data_in(5) & data_in(6) & data_in(4 downto 0);

   -- T65 requires its write data fed back to DI during write cycles.
   t65_din <= t65_dout when t65_rnw = '0' else
              opcode_data when t65_sync = '1' else
              data_in;

   address      <= t65_addr(15 downto 0);
   data_out     <= t65_dout;
   read_nwrite  <= t65_rnw;
   write_strobe <= cpu_cen and not t65_rnw;

   i_sound_cpu : entity work.T65
      port map (
         Mode                 => "00",
         BCD_en               => '1',
         Res_n                => not reset,
         Enable               => cpu_cen,
         Clk                  => clk,
         Rdy                  => '1',
         Abort_n              => '1',
         IRQ_n                => irq_n,
         NMI_n                => nmi_n,
         SO_n                 => '1',
         R_W_n                => t65_rnw,
         Sync                 => t65_sync,
         EF                   => open,
         MF                   => open,
         XF                   => open,
         ML_n                 => open,
         VP_n                 => open,
         VDA                  => open,
         VPA                  => open,
         A                    => t65_addr,
         DI                   => t65_din,
         DO                   => t65_dout,
         Regs                 => open,
         DEBUG                => open,
         NMI_ack              => open
      );

end architecture rtl;
