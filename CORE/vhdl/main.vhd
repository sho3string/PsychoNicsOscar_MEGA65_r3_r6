
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

      -- QNICE ROM download bus (write-only ed08 device).
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(13 downto 0);
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

   -- 2 KiB Oscar character RAM snapshot from MAME, $2000-$27FF.
   -- Each tile is [attribute byte, code byte]. This is a READ-ONLY
   -- checkpoint fixture; replace it with JTFRAME dual-port RAM when
   -- the 6809 CPU is connected.
   signal cram_addr         : std_logic_vector(9 downto 0);
   signal cram_data         : std_logic_vector(15 downto 0);
   type t_ramtest_words is array (0 to 1023) of std_logic_vector(15 downto 0);
   constant C_RAMTEST_WORDS : t_ramtest_words := (
         66 => x"400A",  -- $2084
         67 => x"400B",
         68 => x"8010",
         69 => x"8010",
         75 => x"400E",
         76 => x"400F",
         84 => x"4014",
         85 => x"4015",
         86 => x"0031",
         87 => x"0037",
         88 => x"0038",
        104 => x"0030",
        109 => x"0036",
        110 => x"0038",
        111 => x"0030",
        112 => x"0039",
        113 => x"0030",
        116 => x"4016",
        117 => x"4017",
        118 => x"8018",
        119 => x"8018",
        120 => x"8018",
        121 => x"4019",
        122 => x"4019",
    
        -- Bottom weapon-selection bar
        897 => x"C01E",  -- $2702
        898 => x"C01C",
        899 => x"0030",
        900 => x"0030",
        901 => x"4100",
        902 => x"4101",
        903 => x"4102",
        904 => x"4103",
        905 => x"4104",
        906 => x"410C",
        907 => x"410D",
        908 => x"410E",
        909 => x"410F",
        910 => x"4110",
        911 => x"4118",
        912 => x"4119",
        913 => x"411A",
        914 => x"411B",
        915 => x"411C",
        916 => x"4124",
        917 => x"4125",
        918 => x"4126",
        919 => x"4127",
        920 => x"4128",
        921 => x"4130",
        922 => x"4131",
        923 => x"4132",
        924 => x"4133",
        925 => x"4134",
        929 => x"C01F",  -- $2742
        930 => x"C01D",
    
        others => x"0000"
    );


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

   -- Verilog module declaration for mixed-language instantiation
   component jtoscar_game is
      port (
         rst                  : in  std_logic;
         clk                  : in  std_logic;
         cen_main             : in  std_logic;
         cen_sub              : in  std_logic;
         cen_snd              : in  std_logic;
         cen_pixel            : in  std_logic;

         pxl_cen              : out std_logic;
         HS                   : out std_logic;
         VS                   : out std_logic;
         LHBL                 : out std_logic;
         LVBL                 : out std_logic;
         red                  : out std_logic_vector(3 downto 0);
         green                : out std_logic_vector(3 downto 0);
         blue                 : out std_logic_vector(3 downto 0);

         main_rom_addr        : out std_logic_vector(19 downto 0);
         main_rom_data        : in  std_logic_vector(7 downto 0);
         sub_rom_addr         : out std_logic_vector(19 downto 0);
         sub_rom_data         : in  std_logic_vector(7 downto 0);
         snd_rom_addr         : out std_logic_vector(19 downto 0);
         snd_rom_data         : in  std_logic_vector(7 downto 0);
         char_rom_addr        : out std_logic_vector(12 downto 0);
         char_rom_cs          : out std_logic;
         char_rom_data        : in  std_logic_vector(23 downto 0);
         char_rom_ok          : in  std_logic;
         cram_addr            : out std_logic_vector(9 downto 0);
         cram_data            : in  std_logic_vector(15 downto 0);
         obj_rom_addr         : out std_logic_vector(19 downto 0);
         obj_rom_data         : in  std_logic_vector(7 downto 0);
         scr_rom_addr         : out std_logic_vector(19 downto 0);
         scr_rom_data         : in  std_logic_vector(7 downto 0)
      );
   end component;

begin

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
      char_bank_we(i) <= dn_wr_i
         when unsigned(dn_addr_i(13 downto 12)) = to_unsigned(i, 2)
         else '0';

      i_char_rom : dualport_2clk_ram
         generic map (
            FALLING_B  => true,
            ADDR_WIDTH => 12
         )
         port map (
            clock_a   => clk_main_i,
            address_a => char_addr(11 downto 0),
            q_a       => char_bank_q(i),

            clock_b   => dn_clk_i,
            address_b => dn_addr_i(11 downto 0),
            data_b    => dn_data_i,
            wren_b    => char_bank_we(i)
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
   -- Temporary character RAM contents captured from Oscar's MAME RAM test.
   -- The video-side tilemap uses a one-cycle synchronous memory read,
   -- matching the JTFRAME dual-port CRAM read timing used by Double Dragon.
   ----------------------------------------------------------------------------------
   process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         cram_data <= C_RAMTEST_WORDS(to_integer(unsigned(cram_addr)));
      end if;
   end process;

   ----------------------------------------------------------------------------------
   -- Psycho-Nics Oscar game core
   ----------------------------------------------------------------------------------

   i_oscar_game : jtoscar_game
      port map (
         clk                  => clk_main_i,
         rst                  => reset_hard_i or reset_soft_i,

         -- CPU clock enables not yet implemented
         cen_main             => '0',
         cen_sub              => '0',
         cen_snd              => '0',
         cen_pixel            => '0',

         -- Video
         pxl_cen              => pixel_ce,
         HS                   => hs,
         VS                   => vs,
         LHBL                 => lhbl,
         LVBL                 => lvbl,
         red                  => rgb_r,
         green                => rgb_g,
         blue                 => rgb_b,

         -- Character ROM from local dual-port BRAM; other ROMs are placeholders.
         main_rom_addr        => open,
         main_rom_data        => (others => '0'),
         sub_rom_addr         => open,
         sub_rom_data         => (others => '0'),
         snd_rom_addr         => open,
         snd_rom_data         => (others => '0'),
         char_rom_addr        => char_addr,
         char_rom_cs          => char_cs,
         char_rom_data        => char_data,
         char_rom_ok          => '1',
         cram_addr            => cram_addr,
         cram_data            => cram_data,
         obj_rom_addr         => open,
         obj_rom_data         => (others => '0'),
         scr_rom_addr         => open,
         scr_rom_data         => (others => '0')
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
