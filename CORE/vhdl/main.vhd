----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the Psycho-Nics Oscar core
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;

entity main is
   generic (
      G_VDNUM                 : natural
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      clk_main_speed_i        : in  natural;

      -- QNICE ROM download bus: ed08, du10, ed09, du11 (each its own device).
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(15 downto 0);
      dn_dev_i                : in  std_logic_vector(15 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;
      kb_key_pressed_n_i      : in  std_logic;

      -- MEGA65 joysticks and paddles
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

   -- Keyboard
   signal keyboard_n          : std_logic_vector(79 downto 0);

   -- Oscar video
   signal pixel_ce            : std_logic;
   signal rgb_r               : std_logic_vector(3 downto 0);
   signal rgb_g               : std_logic_vector(3 downto 0);
   signal rgb_b               : std_logic_vector(3 downto 0);
   signal hs                  : std_logic;
   signal vs                  : std_logic;
   signal lhbl                : std_logic;
   signal lvbl                : std_logic;

   -- Overlay clock enable
   signal overlay_div         : std_logic := '0';

   -- Character ROM storage and JTFRAME read interface.
   -- ed08 is four unmodified 4 KiB banks; video reads three planes
   -- concurrently on the 48 MHz core clock.
   signal char_addr           : std_logic_vector(12 downto 0);
   signal char_cs             : std_logic;
   signal char_data           : std_logic_vector(23 downto 0);
   signal char_half_d         : std_logic := '0';

   type t_char_banks is array (0 to 3) of std_logic_vector(7 downto 0);
   signal char_bank_q         : t_char_banks;
   signal char_bank_we        : std_logic_vector(3 downto 0);

   -- Main/sub 6809 memory buses
   signal cpu_addr             : std_logic_vector(15 downto 0);
   signal sub_addr             : std_logic_vector(15 downto 0);
   signal cpu_dout             : std_logic_vector(7 downto 0);
   signal sub_dout             : std_logic_vector(7 downto 0);

   -- Original CPU program ROM bytes (no ROM image embedded in bitstream).
   signal main_rom_q           : std_logic_vector(7 downto 0);
   signal bank_rom_q           : std_logic_vector(7 downto 0);
   signal sub_rom_q            : std_logic_vector(7 downto 0);
   signal main_rom_we          : std_logic;
   signal bank_rom_we          : std_logic;
   signal sub_rom_we           : std_logic;
   signal char_dn_wr           : std_logic;
   signal bank_rom_addr        : std_logic_vector(15 downto 0);

   -- Shared/private and video RAM (all instantiated here, not in mega65.vhd)
   signal shared_main_q        : std_logic_vector(7 downto 0);
   signal shared_sub_q         : std_logic_vector(7 downto 0);
   signal private_main_q       : std_logic_vector(7 downto 0);
   signal private_sub_q        : std_logic_vector(7 downto 0);
   signal cram_main_hi         : std_logic_vector(7 downto 0);
   signal cram_main_lo         : std_logic_vector(7 downto 0);
   signal bg_q                 : std_logic_vector(7 downto 0);
   signal sprite_q             : std_logic_vector(7 downto 0);
   signal palette_q            : std_logic_vector(7 downto 0);
   signal bg_we                : std_logic;
   signal sprite_we            : std_logic;
   signal palette_we           : std_logic;
   signal private_main_we      : std_logic;
   signal private_sub_we       : std_logic;
   signal shared_main_we       : std_logic;
   signal shared_sub_we        : std_logic;
   signal char_hi_we           : std_logic;
   signal char_lo_we           : std_logic;
   signal cram_addr            : std_logic_vector(9 downto 0);
   signal cram_data            : std_logic_vector(15 downto 0);


   -- Same 8-bit dual-port primitive/interface used in Double Dragon.
   component dualport_2clk_ram is
      generic (
         FALLING_A            : boolean := false;
         FALLING_B            : boolean := false;
         ADDR_WIDTH           : integer := 8
      );
      port (
         clock_a              : in  std_logic;
         clen_a               : in  std_logic := '1';
         address_a            : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
         q_a                  : out std_logic_vector(7 downto 0);
         clock_b              : in  std_logic;
         clen_b               : in  std_logic := '1';
         address_b            : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
         data_b               : in  std_logic_vector(7 downto 0);
         wren_b               : in  std_logic
      );
   end component;

   component jtframe_dual_ram is
      generic (
         AW                    : integer := 10;
         DW                    : integer := 8
      );
      port (
         clk0                  : in  std_logic;
         data0                 : in  std_logic_vector(DW-1 downto 0);
         addr0                 : in  std_logic_vector(AW-1 downto 0);
         we0                   : in  std_logic;
         q0                    : out std_logic_vector(DW-1 downto 0);
         clk1                  : in  std_logic;
         data1                 : in  std_logic_vector(DW-1 downto 0);
         addr1                 : in  std_logic_vector(AW-1 downto 0);
         we1                   : in  std_logic;
         q1                    : out std_logic_vector(DW-1 downto 0)
      );
   end component;

   -- Verilog module declaration for mixed-language instantiation
   component jtoscar_game is
      port (
         clk                   : in  std_logic;
         rst                   : in  std_logic;
         pxl_cen               : out std_logic;
         HS                    : out std_logic;
         VS                    : out std_logic;
         LHBL                  : out std_logic;
         LVBL                  : out std_logic;
         red                   : out std_logic_vector(3 downto 0);
         green                 : out std_logic_vector(3 downto 0);
         blue                  : out std_logic_vector(3 downto 0);
         cpu_addr              : out std_logic_vector(15 downto 0);
         sub_addr              : out std_logic_vector(15 downto 0);
         cpu_dout              : out std_logic_vector(7 downto 0);
         sub_dout              : out std_logic_vector(7 downto 0);
         bank_rom_addr         : out std_logic_vector(15 downto 0);
         shared_main_we        : out std_logic;
         shared_sub_we         : out std_logic;
         private_main_we       : out std_logic;
         private_sub_we        : out std_logic;
         char_hi_we            : out std_logic;
         char_lo_we            : out std_logic;
         bg_we                 : out std_logic;
         sprite_we             : out std_logic;
         palette_we            : out std_logic;
         shared_main_q         : in  std_logic_vector(7 downto 0);
         shared_sub_q          : in  std_logic_vector(7 downto 0);
         private_main_q        : in  std_logic_vector(7 downto 0);
         private_sub_q         : in  std_logic_vector(7 downto 0);
         cram_main_hi          : in  std_logic_vector(7 downto 0);
         cram_main_lo          : in  std_logic_vector(7 downto 0);
         bg_q                  : in  std_logic_vector(7 downto 0);
         sprite_q              : in  std_logic_vector(7 downto 0);
         palette_q             : in  std_logic_vector(7 downto 0);
         main_rom_q            : in  std_logic_vector(7 downto 0);
         bank_rom_q            : in  std_logic_vector(7 downto 0);
         sub_rom_q             : in  std_logic_vector(7 downto 0);
         cram_addr             : out std_logic_vector(9 downto 0);
         cram_data             : in  std_logic_vector(15 downto 0);
         char_rom_addr         : out std_logic_vector(12 downto 0);
         char_rom_cs           : out std_logic;
         char_rom_data         : in  std_logic_vector(23 downto 0);
         char_rom_ok           : in  std_logic
      );
   end component;

begin

   -- Load filenames are independent mandatory QNICE devices. No packed ROMs.
   char_dn_wr  <= dn_wr_i when dn_dev_i = C_DEV_OSCAR_CHAR_ROM and
                            unsigned(dn_addr_i(15 downto 14)) = 0 else '0';
   main_rom_we <= dn_wr_i when dn_dev_i = C_DEV_OSCAR_MAIN_ROM and dn_addr_i(15) = '0' else '0';
   bank_rom_we <= dn_wr_i when dn_dev_i = C_DEV_OSCAR_BANK_ROM else '0';
   sub_rom_we  <= dn_wr_i when dn_dev_i = C_DEV_OSCAR_SUB_ROM else '0';

   ----------------------------------------------------------------------------------
   -- Keyboard
   ----------------------------------------------------------------------------------

   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,
         example_n_o          => keyboard_n
      );

   ----------------------------------------------------------------------------------
   -- Character ROM: four 4 KiB banks, exactly as stored in ed08.
   -- QNICE writes on its falling edge; video reads at 48 MHz rising edge.
   -- Unlike the previous mega65.vhd version, this uses the actual
   -- dualport_2clk_ram interface: read-only port A, write-only port B.
   ----------------------------------------------------------------------------------

   gen_oscar_char_banks : for i in 0 to 3 generate
   begin
      char_bank_we(i) <= char_dn_wr
         when unsigned(dn_addr_i(13 downto 12)) = to_unsigned(i, 2)
         else '0';

      i_char_rom : dualport_2clk_ram
         generic map (
            FALLING_B            => true,
            ADDR_WIDTH           => 12
         )
         port map (
            clock_a              => clk_main_i,
            address_a            => char_addr(11 downto 0),
            q_a                  => char_bank_q(i),

            clock_b              => dn_clk_i,
            address_b            => dn_addr_i(11 downto 0),
            data_b               => dn_data_i,
            wren_b               => char_bank_we(i)
         );
   end generate gen_oscar_char_banks;

   -- Register bit 9 of the character code with the synchronous BRAM
   -- outputs so the selected ROM-plane group belongs to the same read.
   process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         char_half_d <= char_addr(12);
      end if;
   end process;

   -- MAME oscar_charlayout, using the original ed08 byte offsets:
   -- code 0..511:   plane2 = 0x1000, plane1 = 0x2000, plane0 = 0x3000
   -- code 512..1023: plane2 = 0x2000, plane1 = 0x3000, plane0 = 0x4000
   -- The last plane is outside the loaded 16 KiB ROM and reads as zero.
   char_data <= char_bank_q(1) & char_bank_q(2) & char_bank_q(3)
      when char_half_d = '0' else
      char_bank_q(2) & char_bank_q(3) & x"00";

   ----------------------------------------------------------------------------------
   -- Program ROMs: 6809E main fixed / banked / sub CPU
   ----------------------------------------------------------------------------------
   i_main_rom : dualport_2clk_ram
      generic map (
         FALLING_B            => true,
         ADDR_WIDTH           => 15
      )
      port map (
         clock_a              => clk_main_i,
         address_a            => cpu_addr(14 downto 0),
         q_a                  => main_rom_q,

         clock_b              => dn_clk_i,
         address_b            => dn_addr_i(14 downto 0),
         data_b               => dn_data_i,
         wren_b               => main_rom_we
      );

   i_bank_rom : dualport_2clk_ram
      generic map (
         FALLING_B            => true,
         ADDR_WIDTH           => 16
      )
      port map (
         clock_a              => clk_main_i,
         address_a            => bank_rom_addr,
         q_a                  => bank_rom_q,

         clock_b              => dn_clk_i,
         address_b            => dn_addr_i,
         data_b               => dn_data_i,
         wren_b               => bank_rom_we
      );

   i_sub_rom : dualport_2clk_ram
      generic map (
         FALLING_B            => true,
         ADDR_WIDTH           => 16
      )
      port map (
         clock_a              => clk_main_i,
         address_a            => sub_addr,
         q_a                  => sub_rom_q,

         clock_b              => dn_clk_i,
         address_b            => dn_addr_i,
         data_b               => dn_data_i,
         wren_b               => sub_rom_we
      );

   -- Both CPUs can access shared RAM concurrently (address $0000-$0eff
   -- and $1000-$1fff).  $0f00-$0fff is private to each CPU.
   i_shared_ram : jtframe_dual_ram
      generic map (
         AW                   => 13,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(12 downto 0),
         we0                  => shared_main_we,
         q0                   => shared_main_q,

         clk1                 => clk_main_i,
         data1                => sub_dout,
         addr1                => sub_addr(12 downto 0),
         we1                  => shared_sub_we,
         q1                   => shared_sub_q
      );

   i_private_main : jtframe_dual_ram
      generic map (
         AW                   => 8,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(7 downto 0),
         we0                  => private_main_we,
         q0                   => private_main_q,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => (others => '0'),
         we1                  => '0',
         q1                   => open
      );

   i_private_sub : jtframe_dual_ram
      generic map (
         AW                   => 8,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => sub_dout,
         addr0                => sub_addr(7 downto 0),
         we0                  => private_sub_we,
         q0                   => private_sub_q,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => (others => '0'),
         we1                  => '0',
         q1                   => open
      );

   -- Real writable character RAM: 1024 two-byte entries, in MAME byte order
   -- even $2000 = attribute, odd $2001 = code. Video reads both each cycle.
   i_cram_hi : jtframe_dual_ram
      generic map (
         AW                   => 10,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(10 downto 1),
         we0                  => char_hi_we,
         q0                   => cram_main_hi,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => cram_addr,
         we1                  => '0',
         q1                   => cram_data(15 downto 8)
      );

   i_cram_lo : jtframe_dual_ram
      generic map (
         AW                   => 10,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(10 downto 1),
         we0                  => char_lo_we,
         q0                   => cram_main_lo,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => cram_addr,
         we1                  => '0',
         q1                   => cram_data(7 downto 0)
      );

   -- Temporary CPU-visible RAM for background, sprites and palette.
   -- Their video readers/colour outputs are intentionally not connected yet.
   i_bg_ram : jtframe_dual_ram
      generic map (
         AW                   => 11,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(10 downto 0),
         we0                  => bg_we,
         q0                   => bg_q,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => (others => '0'),
         we1                  => '0',
         q1                   => open
      );

   i_sprite_ram : jtframe_dual_ram
      generic map (
         AW                   => 11,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(10 downto 0),
         we0                  => sprite_we,
         q0                   => sprite_q,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => (others => '0'),
         we1                  => '0',
         q1                   => open
      );

   i_palette_ram : jtframe_dual_ram
      generic map (
         AW                   => 10,
         DW                   => 8
      )
      port map (
         clk0                 => clk_main_i,
         data0                => cpu_dout,
         addr0                => cpu_addr(9 downto 0),
         we0                  => palette_we,
         q0                   => palette_q,

         clk1                 => clk_main_i,
         data1                => (others => '0'),
         addr1                => (others => '0'),
         we1                  => '0',
         q1                   => open
      );

   ----------------------------------------------------------------------------------
   -- Psycho-Nics Oscar game core
   ----------------------------------------------------------------------------------

   i_oscar_game : jtoscar_game
      port map (
         clk                  => clk_main_i,
         rst                  => reset_hard_i or reset_soft_i,
         pxl_cen              => pixel_ce,
         HS                   => hs,
         VS                   => vs,
         LHBL                 => lhbl,
         LVBL                 => lvbl,
         red                  => rgb_r,
         green                => rgb_g,
         blue                 => rgb_b,
         cpu_addr             => cpu_addr,
         sub_addr             => sub_addr,
         cpu_dout             => cpu_dout,
         sub_dout             => sub_dout,
         bank_rom_addr        => bank_rom_addr,
         shared_main_we       => shared_main_we,
         shared_sub_we        => shared_sub_we,
         private_main_we      => private_main_we,
         private_sub_we       => private_sub_we,
         char_hi_we           => char_hi_we,
         char_lo_we           => char_lo_we,
         bg_we                => bg_we,
         sprite_we            => sprite_we,
         palette_we           => palette_we,
         shared_main_q        => shared_main_q,
         shared_sub_q         => shared_sub_q,
         private_main_q       => private_main_q,
         private_sub_q        => private_sub_q,
         cram_main_hi         => cram_main_hi,
         cram_main_lo         => cram_main_lo,
         bg_q                 => bg_q,
         sprite_q             => sprite_q,
         palette_q            => palette_q,
         main_rom_q           => main_rom_q,
         bank_rom_q           => bank_rom_q,
         sub_rom_q            => sub_rom_q,
         cram_addr            => cram_addr,
         cram_data            => cram_data,
         char_rom_addr        => char_addr,
         char_rom_cs          => char_cs,
         char_rom_data        => char_data,
         char_rom_ok          => '1'
      );

   ----------------------------------------------------------------------------------
   -- Video output to MiSTer2MEGA65
   ----------------------------------------------------------------------------------

   video_ce_o      <= pixel_ce;

   video_red_o     <= rgb_r & rgb_r;
   video_green_o   <= rgb_g & rgb_g;
   video_blue_o    <= rgb_b & rgb_b;

   video_hs_o      <= hs;
   video_vs_o      <= vs;

   video_hblank_o  <= not lhbl;
   video_vblank_o  <= not lvbl;

   ----------------------------------------------------------------------------------
   -- Overlay clock enable: 48 MHz / 2 = 24 MHz
   ----------------------------------------------------------------------------------

   process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if reset_hard_i = '1' or reset_soft_i = '1' then
            overlay_div <= '0';
         else
            overlay_div <= not overlay_div;
         end if;
      end if;
   end process;

   video_ce_ovl_o <= overlay_div;

   ----------------------------------------------------------------------------------
   -- Audio (not yet implemented)
   ----------------------------------------------------------------------------------

   audio_left_o  <= (others => '0');
   audio_right_o <= (others => '0');

end architecture synthesis;
