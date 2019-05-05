module top(
	//key input
	input sys_key0,

	//led output
	output [3:0] led,
	
	//i2c
	input scl,
	inout sda,
	
	input hdmi_in_clk,
	input hdmi_in_hs,
	input hdmi_in_vs,
	input hdmi_in_de,
	input[23:0]  hdmi_in_data,
		
	//hdmi output
	output hdmi_out_clk,
	output hdmi_out_hs,
	output hdmi_out_vs,
	output hdmi_out_de,
	output[7:0]  hdmi_out_rgb_b,
	output[7:0]  hdmi_out_rgb_g,
	output[7:0]  hdmi_out_rgb_r,
	
	//vga output
	output vga_out_clk,         
	output vga_out_hs,          
	output vga_out_vs,          
	output vga_out_de,          
	output[23:0]  vga_out_data,
	
	//ddr3
`ifdef Xilinx	
	inout  [15:0]             mcb3_dram_dq,
	output [13:0]             mcb3_dram_a,
	output [2:0]              mcb3_dram_ba,
	output                    mcb3_dram_ras_n,
	output                    mcb3_dram_cas_n,
	output                    mcb3_dram_we_n,
	output                    mcb3_dram_odt,
	output                    mcb3_dram_reset_n,
	output                    mcb3_dram_cke,
	output                    mcb3_dram_dm,
	inout                     mcb3_dram_udqs,
	inout                     mcb3_dram_udqs_n,
	inout                     mcb3_rzq,
	inout                     mcb3_zio,
	output                    mcb3_dram_udm,
	inout                     mcb3_dram_dqs,
	inout                     mcb3_dram_dqs_n,
	output                    mcb3_dram_ck,
	output                    mcb3_dram_ck_n,
`else
	output  wire[0 : 0]  mem_cs_n,
	output  wire[0 : 0]  mem_cke,
	output  wire[12: 0]  mem_addr,
	output  wire[2 : 0]  mem_ba,
	output  wire  mem_ras_n,
	output  wire  mem_cas_n,
	output  wire  mem_we_n,
	inout  wire[0 : 0]  mem_clk,
	inout  wire[0 : 0]  mem_clk_n,
	output  wire[3 : 0]  mem_dm,
	inout  wire[31: 0]  mem_dq,
	inout  wire[3 : 0]  mem_dqs,
	output[0:0]	mem_odt,
`endif	
	//clock input
	input clk_50m,
	input clk_27m,
	
	//ethernet
	output e_reset0,
	output e_mdc0,
	inout  e_mdio0,

	output[3:0] rgmii_txd0,
	output rgmii_txctl0,
	output rgmii_txc0,
	input[3:0] rgmii_rxd0,
	input rgmii_rxctl0,
	input rgmii_rxc0,
	
	//port1
	output e_reset1,
	output e_mdc1,
	inout  e_mdio1,

	output[3:0] rgmii_txd1,
	output rgmii_txctl1,
	output rgmii_txc1,
	input[3:0] rgmii_rxd1,
	input rgmii_rxctl1,
	input rgmii_rxc1,
		
	//port2
	output e_reset2,
	output e_mdc2,
	inout  e_mdio2,

	output[3:0] rgmii_txd2,
	output rgmii_txctl2,
	output rgmii_txc2,
	input[3:0] rgmii_rxd2,
	input rgmii_rxctl2,
	input rgmii_rxc2,
	
	//port3
	output e_reset3,
	output e_mdc3,
	inout  e_mdio3,

	output[3:0] rgmii_txd3,
	output rgmii_txctl3,
	output rgmii_txc3,
	input[3:0] rgmii_rxd3,
	input rgmii_rxctl3,
	input rgmii_rxc3,
	
	//port4
	output e_reset4,
	output e_mdc4,
	inout  e_mdio4,

	output[3:0] rgmii_txd4,
	output rgmii_txctl4,
	output rgmii_txc4,
	input[3:0] rgmii_rxd4,
	input rgmii_rxctl4,
	input rgmii_rxc4,
	
	//port2
	output e_reset5,
	output e_mdc5,
	inout  e_mdio5,

	output[3:0] rgmii_txd5,
	output rgmii_txctl5,
	output rgmii_txc5,
	input[3:0] rgmii_rxd5,
	input rgmii_rxctl5,
	input rgmii_rxc5
);

assign sda = 1'bz;
assign led = 4'd2;

parameter H_ACTIVE = 16'd1920;
parameter H_FP = 16'd88;
parameter H_SYNC = 16'd44;
parameter H_BP = 16'd148; 
parameter V_ACTIVE = 16'd1080;
parameter V_FP 	= 16'd4;
parameter V_SYNC  = 16'd5;
parameter V_BP	= 16'd36;

parameter H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
parameter V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;
parameter VCH_NUM = 2;
parameter CH0 = 1;
parameter CH1 = 1;
parameter MEM_DATA_BITS = 64;

parameter PORTLEN = 16'd400;

wire rst_n;
wire phy_clk;
wire ch0_rd_burst_req;
wire[9:0] ch0_rd_burst_len;
wire[23:0] ch0_rd_burst_addr;
wire  ch0_rd_burst_data_valid;
wire[63:0] ch0_rd_burst_data;
wire ch0_rd_burst_finish;

wire ch0_wr_burst_req;
wire[9:0] ch0_wr_burst_len;
wire[23:0] ch0_wr_burst_addr;
wire ch0_wr_burst_data_req;
wire[63:0] ch0_wr_burst_data;
wire ch0_wr_burst_finish;

wire ch1_rd_burst_req;
wire[9:0] ch1_rd_burst_len;
wire[23:0] ch1_rd_burst_addr;
wire  ch1_rd_burst_data_valid;
wire[63:0] ch1_rd_burst_data;
wire ch1_rd_burst_finish;

wire ch1_wr_burst_req;
wire[9:0] ch1_wr_burst_len;
wire[23:0] ch1_wr_burst_addr;
wire ch1_wr_burst_data_req;
wire[63:0] ch1_wr_burst_data;
wire ch1_wr_burst_finish;

wire video_clk;

wire ch0_de;
wire ch0_vs;
wire[15:0] ch0_yc_data;
wire ch0_f;


wire video_hs;
wire video_vs;
wire video_de;
wire[7:0] video_r;
wire[7:0] video_g;
wire[7:0] video_b;

wire vga_hs;
wire vga_vs;
wire vga_de;
wire[7:0] vga_r;
wire[7:0] vga_g;
wire[7:0] vga_b;

wire hdmi_hs;
wire hdmi_vs;
wire hdmi_de;
wire[7:0] hdmi_r;
wire[7:0] hdmi_g;
wire[7:0] hdmi_b;
wire hdmi_in_hs_delay;
wire hdmi_in_vs_delay;
wire hdmi_in_de_delay;
wire[23:0] hdmi_in_data_delay;
wire sys_clk;
reset reset_m0(
	.clk(video_clk),
	.rst_n(rst_n)
);
wire clk_27m_buf;
clock_in clock_in_27m
(
	.clk_in(clk_27m),
	.clk_out(clk_27m_buf)
);
`ifdef Xilinx
pll pll_m0(
	.inclk0(clk_27m_buf),
	.c0(sys_clk),
	.c1(video_clk));
`else
pll pll_m0(
	.inclk0(clk_50m),
	.c0(sys_clk),
	.c1(video_clk));
`endif
clock_out clock_out_m0
(
	.clk_in(video_clk),
	.clk_out(hdmi_out_clk)
);
wire hdmi_in_clk_gbuf;
clock_in BUFGP_hdmi_in_clk
(
	.clk_in(hdmi_in_clk),
	.clk_out(hdmi_in_clk_gbuf)
);	
common_std_logic_vector_delay#
(
	.WIDTH(27),
	.DELAY(4)
)
common_std_logic_vector_delay_m2
(
	.clock(hdmi_in_clk_gbuf),
	.reset(1'b0),
	.ena(1'b1),
	.data({hdmi_in_hs,hdmi_in_vs,hdmi_in_de,hdmi_in_data}),
	.q({hdmi_in_hs_delay,hdmi_in_vs_delay,hdmi_in_de_delay,hdmi_in_data_delay})
);
wire[11:0] in_width,in_height;
wire[15:0] h_scale_K,v_scale_K;
video_check video_check_m0(
	.clk_148(sys_clk),
	.clk_pixel(hdmi_in_clk_gbuf),
	.vs(hdmi_in_vs_delay),
	.hs(hdmi_in_hs_delay),
	.de(hdmi_in_de_delay),
	.H_ACTIVE(in_width),
	.V_ACTIVE(in_height),
	.video_lost()
);
scaler_K_gen scaler_K_gen_m0(
	.clk(sys_clk),
	.s_width(in_width),
	.s_height(in_height),
	.t_width(H_ACTIVE[11:0]),
	.t_height(V_ACTIVE[11:0]),
	.h_scale_K(h_scale_K),
	.v_scale_K(v_scale_K)
);
/*
vin_rgb_pro vin_rgb_pro_m0(
	.rgb_pixel_clk(hdmi_in_clk_gbuf),
	.rgb_hs(hdmi_in_hs_delay),
	.rgb_vs(hdmi_in_vs_delay),
	.rgb_de(hdmi_in_de_delay),
	.rgb_r(hdmi_in_data_delay[23:16]),
	.rgb_g(hdmi_in_data_delay[15:8]),
	.rgb_b(hdmi_in_data_delay[7:0]),
	
	.yc_de(ch0_de),
	.yc_hs(),
	.yc_vs(ch0_vs),
	.yc_y(ch0_yc_data[15:8]),
	.yc_c(ch0_yc_data[7:0])
);
*/
wire ch0_vout_rd_req;
wire[23:0] ch0_vout_ycbcr;
video_pro#
(
	.MEM_DATA_BITS(MEM_DATA_BITS),
	.INTERLACE(0)
) video_pro_m0(
	.rst_n(rst_n),
	.vin_pixel_clk(hdmi_in_clk_gbuf),
	.vin_vs(hdmi_in_vs_delay),
	.vin_f(1'b1),
	.vin_pixel_de(hdmi_in_de_delay),
	.vin_pixel_rgb(hdmi_in_data_delay),
	.vin_s_width(in_width),
	.vin_s_height(in_height),
	.clipper_left(12'd0),
	.clipper_width(in_width),
	.clipper_top(12'd0),
	.clipper_height(in_height),
	.vout_pixel_clk(video_clk),
	.vout_vs(video_vs),
	.vout_pixel_rd_req(ch0_vout_rd_req),
	.vout_pixel_ycbcr(ch0_vout_ycbcr),
	.vout_scaler_clk(video_clk),
	.vout_t_width(H_ACTIVE[11:0]),
	.vout_t_height(V_ACTIVE[11:0]),
	.vout_K_h(h_scale_K),
	.vout_K_v(v_scale_K),
	.mem_clk(phy_clk),
	.wr_burst_req(ch0_wr_burst_req),
	.wr_burst_len(ch0_wr_burst_len),
	.wr_burst_addr(ch0_wr_burst_addr),
	.wr_burst_data_req(ch0_wr_burst_data_req),
	.wr_burst_data(ch0_wr_burst_data),
	.wr_burst_finish(ch0_wr_burst_finish),
	.rd_burst_req(ch0_rd_burst_req),
	.rd_burst_len(ch0_rd_burst_len),
	.rd_burst_addr(ch0_rd_burst_addr),
	.rd_burst_data_valid(ch0_rd_burst_data_valid),
	.rd_burst_data(ch0_rd_burst_data),
	.rd_burst_finish(ch0_rd_burst_finish),
	.base_addr(2'd0)
);

wire video_de0_w;
wire video_de1_w;
wire video_de2_w;
wire video_de3_w;
wire video_de4_w;
wire video_de5_w;
wire[15:0] line_number;

vout_display_pro vout_display_pro_m0(
	.rst_n(rst_n),
	.dp_clk(video_clk),
	.h_fp(H_FP[11:0]),
	.h_sync(H_SYNC[11:0]),
	.h_bp(H_BP[11:0]),
	.h_active(H_ACTIVE[11:0]),
	.h_total(H_TOTAL[11:0]),
	
	.v_fp(V_FP[11:0]),
	.v_sync(V_SYNC[11:0]),
	.v_bp(V_BP[11:0]), 
	.v_active(V_ACTIVE[11:0]),
	.v_total(V_TOTAL[11:0]),
	
	.hs(video_hs),
	.vs(video_vs),
	.de(video_de),

	.h_clk_cnt(PORTLEN),
	.rdreq0(video_de0_w),
	.rdreq1(video_de1_w),
	.rdreq2(video_de2_w),
	.rdreq3(video_de3_w),
	.rdreq4(video_de4_w),
	.rdreq5(video_de5_w),
	.line_number(line_number),

	.rgb_r(video_r),
	.rgb_g(video_g),
	.rgb_b(video_b),
	
	.layer0_top(12'd0),
	.layer0_left(12'd0),
	.layer0_width(H_ACTIVE[11:0]),
	.layer0_height(V_ACTIVE[11:0]),
	.layer0_alpha(8'hff),
	.layer0_rdreq(ch0_vout_rd_req),
	.layer0_ycbcr(ch0_vout_ycbcr)
);
mem_ctrl
#(
	.MEM_DATA_BITS(MEM_DATA_BITS)
)
mem_ctrl_m0(
	.rst_n(rst_n),
	.source_clk(clk_50m),
	.phy_clk(phy_clk),
	.ch0_rd_burst_req(ch0_rd_burst_req),
	.ch0_rd_burst_len(ch0_rd_burst_len),
	.ch0_rd_burst_addr(ch0_rd_burst_addr),
	.ch0_rd_burst_data_valid(ch0_rd_burst_data_valid),
	.ch0_rd_burst_data(ch0_rd_burst_data),
	.ch0_rd_burst_finish(ch0_rd_burst_finish),
		   
	.ch0_wr_burst_req(ch0_wr_burst_req),
	.ch0_wr_burst_len(ch0_wr_burst_len),
	.ch0_wr_burst_addr(ch0_wr_burst_addr),
	.ch0_wr_burst_data_req(ch0_wr_burst_data_req),
	.ch0_wr_burst_data(ch0_wr_burst_data),
	.ch0_wr_burst_finish(ch0_wr_burst_finish),
	

	
`ifdef Xilinx	
	.mcb3_dram_dq         (mcb3_dram_dq       ),
	.mcb3_dram_a          (mcb3_dram_a        ),
	.mcb3_dram_ba         (mcb3_dram_ba       ),
	.mcb3_dram_ras_n      (mcb3_dram_ras_n    ),
	.mcb3_dram_cas_n      (mcb3_dram_cas_n    ),
	.mcb3_dram_we_n       (mcb3_dram_we_n     ),
	.mcb3_dram_odt        (mcb3_dram_odt      ),
	.mcb3_dram_reset_n    (mcb3_dram_reset_n  ),
	.mcb3_dram_cke        (mcb3_dram_cke      ),
	.mcb3_dram_dm         (mcb3_dram_dm       ),
	.mcb3_dram_udqs       (mcb3_dram_udqs     ),
	.mcb3_dram_udqs_n     (mcb3_dram_udqs_n   ),
	.mcb3_rzq             (mcb3_rzq           ),
	.mcb3_zio             (mcb3_zio           ),
	.mcb3_dram_udm        (mcb3_dram_udm      ),
	.mcb3_dram_dqs        (mcb3_dram_dqs      ),
	.mcb3_dram_dqs_n      (mcb3_dram_dqs_n    ),
	.mcb3_dram_ck         (mcb3_dram_ck       ),
	.mcb3_dram_ck_n       (mcb3_dram_ck_n     )
`else
	.mem_cs_n(mem_cs_n),
	.mem_cke(mem_cke),
	.mem_addr(mem_addr),
	.mem_ba(mem_ba),
	.mem_ras_n(mem_ras_n),
	.mem_cas_n(mem_cas_n),
	.mem_we_n(mem_we_n),
	.mem_clk(mem_clk),
	.mem_clk_n(mem_clk_n),
	.mem_dm(mem_dm),
	.mem_dq(mem_dq),
	.mem_dqs(mem_dqs),
	.mem_odt(mem_odt)
`endif
);

common_std_logic_vector_delay#
(
	.WIDTH(27),
	.DELAY(1)
)
common_std_logic_vector_delay_m0
(
	.clock(video_clk),
	.reset(1'b0),
	.ena(1'b1),
	.data({video_hs,video_vs,video_de,video_r,video_g,video_b}),
	.q({hdmi_out_hs,hdmi_out_vs,hdmi_out_de,hdmi_out_rgb_r,hdmi_out_rgb_g,hdmi_out_rgb_b})
);

common_std_logic_vector_delay#
(
	.WIDTH(27),
	.DELAY(1)
)
common_std_logic_vector_delay_m1
(
	.clock(video_clk),
	.reset(1'b0),
	.ena(1'b1),
	.data({video_hs,video_vs,video_de,video_r,video_g,video_b}),
	.q({vga_hs,vga_vs,vga_de,vga_r,vga_g,vga_b})
);

vga_out_io vga_out_io_m0
(
	.vga_clk      (video_clk    ),
	.vga_hs       (vga_hs       ),
	.vga_vs       (vga_vs       ),
	.vga_de       (vga_de       ),
	.vga_rgb      ({vga_r,vga_g,vga_b}),
	.vga_out_clk  (vga_out_clk  ),
	.vga_out_hs   (vga_out_hs   ),
	.vga_out_de   (vga_out_de   ),
	.vga_out_vs   (vga_out_vs   ),
	.vga_out_data (vga_out_data )
);


//=================ethernet=====================
wire[15:0]  pixel_len_port0;
wire[15:0]  pixel_len_port1;
wire[15:0]  pixel_len_port2;
wire[15:0]  pixel_len_port3;
wire[15:0]  pixel_len_port4;
wire[11:0] pixel_v_height;

assign pixel_len_port0 = H_ACTIVE > PORTLEN ? PORTLEN : H_ACTIVE;
assign pixel_len_port1 = (pixel_len_port0 < PORTLEN)? 15'd0 : ((H_ACTIVE - PORTLEN) > PORTLEN ? PORTLEN : (H_ACTIVE - PORTLEN));
assign pixel_len_port2 = (pixel_len_port1 < PORTLEN)? 15'd0 : ((H_ACTIVE - PORTLEN - PORTLEN) > PORTLEN ? PORTLEN : (H_ACTIVE - PORTLEN - PORTLEN));
assign pixel_len_port3 = (pixel_len_port2 < PORTLEN)? 15'd0 : ((H_ACTIVE - PORTLEN - PORTLEN - PORTLEN)> PORTLEN ? PORTLEN : (H_ACTIVE - PORTLEN - PORTLEN - PORTLEN));
assign pixel_len_port4 = (pixel_len_port3 < PORTLEN)? 15'd0 : ((H_ACTIVE - PORTLEN - PORTLEN - PORTLEN - PORTLEN)> PORTLEN ? PORTLEN : (H_ACTIVE - PORTLEN - PORTLEN - PORTLEN - PORTLEN));

assign pixel_v_height = V_ACTIVE[11:0];

ethernet_output_port port0
(
	//external pins
	.clk_50m			(clk_50m),
	.e_reset			(e_reset0),
	.e_mdc				(e_mdc0),
	.e_mdio				(e_mdio0),
	.rgmii_txd			(rgmii_txd0),
	.rgmii_txctl		(rgmii_txctl0),
	.rgmii_txc			(rgmii_txc0),
	.rgmii_rxd			(rgmii_rxd0),
	.rgmii_rxctl		(rgmii_rxctl0),
	.rgmii_rxc			(rgmii_rxc0),
	
	//internal clock 145.125Mhz
	.pixel_clk			(video_clk),
	.pixel_per_line		(pixel_len_port0),
	.pixel_v_height		(pixel_v_height),
	.wr_data			(ch0_vout_ycbcr),
	.wr_de				(video_de0_w),
	.line_number		(line_number),

	.hs					(video_hs),
	.vs					(video_vs)
	//.de					(video_de)   //same with wr_de

);


ethernet_output_port port1
(
	//external pins
	.clk_50m			(clk_50m),
	.e_reset			(e_reset1),
	.e_mdc				(e_mdc1),
	.e_mdio				(e_mdio1),
	.rgmii_txd			(rgmii_txd1),
	.rgmii_txctl		(rgmii_txctl1),
	.rgmii_txc			(rgmii_txc1),
	.rgmii_rxd			(rgmii_rxd1),
	.rgmii_rxctl		(rgmii_rxctl1),
	.rgmii_rxc			(rgmii_rxc1),
	
	//internal clock 145.125Mhz
	.pixel_clk			(video_clk),
	.pixel_per_line		(pixel_len_port1),
	.pixel_v_height		(pixel_v_height),
	.wr_data			(ch0_vout_ycbcr),
	.wr_de				(video_de1_w),
	.line_number		(line_number),

	.hs					(video_hs),
	.vs					(video_vs)
);


ethernet_output_port port2
(
	//external pins
	.clk_50m			(clk_50m),
	.e_reset			(e_reset2),
	.e_mdc				(e_mdc2),
	.e_mdio				(e_mdio2),
	.rgmii_txd			(rgmii_txd2),
	.rgmii_txctl		(rgmii_txctl2),
	.rgmii_txc			(rgmii_txc2),
	.rgmii_rxd			(rgmii_rxd2),
	.rgmii_rxctl		(rgmii_rxctl2),
	.rgmii_rxc			(rgmii_rxc2),
	
	//internal clock 145.125Mhz
	.pixel_clk			(video_clk),
	.pixel_per_line		(pixel_len_port2),
	.pixel_v_height		(pixel_v_height),
	.wr_data			(ch0_vout_ycbcr),
	.wr_de				(video_de2_w),
	.line_number		(line_number),

	.hs					(video_hs),
	.vs					(video_vs)
);

ethernet_output_port port3
(
	//external pins
	.clk_50m			(clk_50m),
	.e_reset			(e_reset3),
	.e_mdc				(e_mdc3),
	.e_mdio				(e_mdio3),
	.rgmii_txd			(rgmii_txd3),
	.rgmii_txctl		(rgmii_txctl3),
	.rgmii_txc			(rgmii_txc3),
	.rgmii_rxd			(rgmii_rxd3),
	.rgmii_rxctl		(rgmii_rxctl3),
	.rgmii_rxc			(rgmii_rxc3),
	
	//internal clock 145.125Mhz
	.pixel_clk			(video_clk),
	.pixel_per_line		(pixel_len_port3),
	.pixel_v_height		(pixel_v_height),
	.wr_data			(ch0_vout_ycbcr),
	.wr_de				(video_de3_w),
	.line_number		(line_number),

	.hs					(video_hs),
	.vs					(video_vs)
);

ethernet_output_port port4
(
	//external pins
	.clk_50m			(clk_50m),
	.e_reset			(e_reset4),
	.e_mdc				(e_mdc4),
	.e_mdio				(e_mdio4),
	.rgmii_txd			(rgmii_txd4),
	.rgmii_txctl		(rgmii_txctl4),
	.rgmii_txc			(rgmii_txc4),
	.rgmii_rxd			(rgmii_rxd4),
	.rgmii_rxctl		(rgmii_rxctl4),
	.rgmii_rxc			(rgmii_rxc4),
	
	//internal clock 145.125Mhz
	.pixel_clk			(video_clk),
	.pixel_per_line		(pixel_len_port4),
	.pixel_v_height		(pixel_v_height),
	.wr_data			(ch0_vout_ycbcr),
	.wr_de				(video_de4_w),
	.line_number		(line_number),

	.hs					(video_hs),
	.vs					(video_vs)
);
endmodule