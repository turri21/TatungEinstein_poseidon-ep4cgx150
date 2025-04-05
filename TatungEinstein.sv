//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`default_nettype none

module guest_top
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
`ifdef USE_MIDI_PINS
	output        MIDI_OUT,
	input         MIDI_IN,
`endif
`ifdef SIDI128_EXPANSION
	input         UART_CTS,
	output        UART_RTS,
	inout         EXP7,
	inout         MOTOR_CTRL,
`endif
	input         UART_RX,
	output        UART_TX
);


`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

assign LED = 0;

`include "build_id.v"
localparam CONF_STR = {
	"TatungEinstein;;",
	"S0U,DSK,Mount Disk 0:;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"-;",
	"OA,Einstein Version,TC01,256;",
	"-;",
	"O1,Swap Joysticks,No,Yes;",
	"O2,Joystick,Digital,Analog;",
	"O6,Diagnostic ROM mounted,Off,On;",
	"O7,Border,Off,On;",
	"T0,Reset;",
	"V,Poseidon-",`BUILD_DATE
};

wire forced_scandoubler;
wire scandoubler = (scale || forced_scandoubler);
wire scandoubler_disable;

wire no_csync;

reg old_mode;
always @(posedge clk_sys) old_mode <= status[10];
wire reset = status[0] | buttons[1] | (old_mode^status[10]);
wire [2:0] scale = status[5:3];

wire        direct_video;
wire [21:0] gamma_bus;

wire  [1:0] buttons;
wire  [1:0] switches;
wire [31:0] status;
wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code};

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_ack_conf;
wire        sd_busy;
wire        sd_sdhc;
wire        sd_conf;

wire  [1:0] img_mounted;
wire  [1:0] img_readonly;
wire [63:0] img_size;

wire [15:0] joystick_0;
wire [15:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;

wire [31:0] joystick_a = status[1] ? joystick_1 : joystick_0;
wire [31:0] joystick_b = status[1] ? joystick_0 : joystick_1;


///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire clk_vdp;
wire clk_vid;
wire pll_locked;

pll pll 
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.areset(0),
	.c0(clk_sys), // 32
	.c1(clk_vdp), // 21.33
	.c2(clk_vid), // 42.6
`ifdef USE_HDMI
	.c3(clk_hdmi),
`endif	
	.locked(pll_locked)
);

reg [2:0] clk_div;
wire clk_cpu = clk_div[2]; // 4M
wire clk_fdc = clk_div == 3'b111;
always @(posedge clk_sys) clk_div <= clk_div + 3'd1;

//////////////////////////////////////////////////////////////////

wire [7:0] kb_row;
wire [7:0] kb_col;
wire shift, ctrl, graph;
wire press_btn;

keyboard keyboard(
  .clk_sys(clk_sys),
  .reset(reset),
  .ps2_key(ps2_key),
  .addr(kb_row),
  .kb_cols(kb_col),
  .modif({ ctrl, graph, shift }),
  .press_btn(press_btn)
);

wire ps2_kbd_clk,ps2_kbd_data;
wire ps2_mouse_clk,ps2_mouse_data;

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;

wire        ioctl_download;
wire        ioctl_wr;
wire [22:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;

user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(1), .PS2DIV(500), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(	
	.clk_sys          (clk_sys          ),
	.clk_sd           (clk_sys          ),
	.conf_str         (CONF_STR         ),
	.SPI_CLK          (SPI_SCK          ),
	.SPI_SS_IO        (CONF_DATA0       ),
	.SPI_MISO         (SPI_DO           ),
	.SPI_MOSI         (SPI_DI           ),
	.buttons          (buttons          ),
	.switches         (switches         ),
	.no_csync         (no_csync         ),
	.ypbpr            (ypbpr            ),

	.ps2_kbd_clk      (ps2_kbd_clk      ),
	.ps2_kbd_data     (ps2_kbd_data     ),
	.key_strobe       (key_strobe       ),
	.key_pressed      (key_pressed      ),
	.key_extended     (key_extended     ),
	.key_code         (key_code         ),
	.joystick_0       (joystick_0       ),
	.joystick_1       (joystick_1       ),
	.status           (status           ),
	.scandoubler_disable(scandoubler_disable),

`ifdef USE_HDMI
	.i2c_start        (i2c_start        ),
	.i2c_read         (i2c_read         ),
	.i2c_addr         (i2c_addr         ),
	.i2c_subaddr      (i2c_subaddr      ),
	.i2c_dout         (i2c_dout         ),
	.i2c_din          (i2c_din          ),
	.i2c_ack          (i2c_ack          ),
	.i2c_end          (i2c_end          ),
`endif
	
// SD CARD
        .sd_lba           (sd_lba           ),
	.sd_rd            (sd_rd            ),
	.sd_wr            (sd_wr            ),
	.sd_ack           (sd_ack           ),
	.sd_ack_conf      (sd_ack_conf      ),
	.sd_conf          (sd_conf          ),
	.sd_sdhc          (1'b1             ),
	.sd_dout          (sd_buff_dout     ),
	.sd_din           (sd_buff_din      ),
	.sd_buff_addr     (sd_buff_addr     ),
	.sd_dout_strobe   (sd_buff_wr       ),
        .img_mounted      (img_mounted      ),
	.img_size         (img_size         )
);

data_io data_io(
	.clk_sys          (clk_sys          ),
	.SPI_SCK          (SPI_SCK          ),
	.SPI_SS2          (SPI_SS2          ),
	.SPI_DI           (SPI_DI           ),
	.clkref_n         (1'b0             ),
	.ioctl_download   (ioctl_download   ),
	.ioctl_index      (ioctl_index      ),
	.ioctl_wr         (ioctl_wr         ),
	.ioctl_addr       (ioctl_addr       ),
	.ioctl_dout       (ioctl_data       )
);

tatung tatung
(
	.clk_sys(clk_sys),
	.clk_vdp(clk_vdp),
	.clk_cpu(clk_cpu),
	.clk_fdc(clk_fdc),
	.clk_vdp9938(clk_vdp),
	.reset(reset),

	.vga_red(vga_red),
	.vga_green(vga_green),
	.vga_blue(vga_blue),
	.vga_hblank(vga_hblank),
	.vga_vblank(vga_vblank),
	.vga_hsync(vga_hsync),
	.vga_vsync(vga_vsync),
	
	.sound(sound),
	
	.kb_row(kb_row),
	.kb_col(kb_col),
	.kb_shift(shift),
	.kb_ctrl(ctrl),
	.kb_graph(graph),
	.kb_down(press_btn),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(|sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),

	.joystick_0(joystick_a),
	.joystick_1(joystick_b),
	.joystick_analog_0(joystick_analog_0),
        .joystick_analog_1(joystick_analog_1),

	.diagnostic(status[6]),
	.border(status[7]),
	.analog(status[2]),
	.m256(status[10]),
	.scandoubler(scandoubler)
);

////////////////////   VIDEO   ///////////////////

wire [7:0] vga_red, vga_green, vga_blue;
wire vga_hsync, vga_vsync;
wire vga_hblank, vga_vblank;
wire ypbpr;

`ifdef USE_HDMI
i2c_master #(100_000_000) i2c_master (
	.CLK              (clk_100          ),
	.I2C_START        (i2c_start        ),
	.I2C_READ         (i2c_read         ),
	.I2C_ADDR         (i2c_addr         ),
	.I2C_SUBADDR      (i2c_subaddr      ),
	.I2C_WDATA        (i2c_dout         ),
	.I2C_RDATA        (i2c_din          ),
	.I2C_END          (i2c_end          ),
	.I2C_ACK          (i2c_ack          ),

	//I2C bus
	.I2C_SCL          (HDMI_SCL         ),
	.I2C_SDA          (HDMI_SDA         )
);

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(10), .USE_BLANKS(1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video(
	.clk_sys          (clk_sys          ),
	.SPI_SCK          (SPI_SCK          ),
	.SPI_SS3          (SPI_SS3          ),
	.SPI_DI           (SPI_DI           ),
	.R                (R                ),
	.G                (G                ),
	.B                (B                ),
	.HBlank           (hblank           ),
	.VBlank           (vblank           ),
	.HSync            (hsync            ),
	.VSync            (vsync            ),
	.VGA_R            (HDMI_R           ),
	.VGA_G            (HDMI_G           ),
	.VGA_B            (HDMI_B           ),
	.VGA_VS           (HDMI_VS          ),
	.VGA_HS           (HDMI_HS          ),
	.VGA_DE           (HDMI_DE          ),
	.ce_divider       (3'd7             ),
	.scandoubler_disable(1'b1           ),
	.scanlines        (                 ),
	.ypbpr            (1'b0             ),
	.no_csync         (1'b1             )
);

assign HDMI_PCLK = clk_25;

`endif

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(11), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video(
	.clk_sys          (clk_vdp          ),
	.SPI_SCK          (SPI_SCK          ),
	.SPI_SS3          (SPI_SS3          ),
	.SPI_DI           (SPI_DI           ),
	.R                (vga_red          ),
	.G                (vga_green        ),
	.B                (vga_blue         ),
	.HSync            (vga_hsync        ),
	.VSync            (vga_vsync        ),
	.HBlank           (vga_hblank       ),
	.VBlank           (vga_vblank       ),
	.VGA_R            (VGA_R            ),
	.VGA_G            (VGA_G            ),
	.VGA_B            (VGA_B            ),
	.VGA_VS           (VGA_VS           ),
	.VGA_HS           (VGA_HS           ),
	.ce_divider       (1'b0             ),
	.no_csync         (no_csync         ),
	.scandoubler_disable(scandoubler_disable ),
	.ypbpr            (ypbpr            ),
	.scanlines        (scale            ),
	.rotate           (2'b00            ),
	.blend            (1'b0             )
);

////////////////////   AUDIO   ///////////////////

wire [9:0] sound;
assign AUDIO_L = { sound, 6'd0 };
assign AUDIO_R = { sound, 6'd0 };

`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd32_000_000;

i2s i2s (
	.reset(reset),
	.clk(clk_sys),
	.clk_rate(clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({sound, 6'd0}),
	.right_chan({sound, 6'd0})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(reset),
	.clk_rate_i(clk_rate),
	.spdif_o(SPDIF),
	.sample_i({{sound, 6'd0}, {sound, 6'd0}})
);
`endif

endmodule
