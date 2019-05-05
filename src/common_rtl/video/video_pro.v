/*
模块封装了视频输入处理、视频输出模块
需要注意的是，视频输入和视频输出模块之间有一frame_addr信号，
视频输出依赖于frame_addr经行帧轮转，如果frame_addr保持不变，视频输出会冻结，
而frame_addr依赖于视频输入的场同步，如果视频输入场同步不存在，或者异常，
视频输出同样会冻结，因为frame_addr是一个2bit的数，所以视频输入视频输出缓存区
里有4帧数据在轮转，假定视频输出帧率是60Hz，那么输入最大的帧率是多少，额，这个
需要算算，反正大于120Hz了
*/
module video_pro
#(
	parameter MEM_DATA_BITS = 64,
	parameter INTERLACE = 1
)
(
	input                            rst_n,
	input                            vin_pixel_clk,
	input                            vin_vs,
	input                            vin_f,
	input                            vin_pixel_de,
	input[23:0]                      vin_pixel_rgb,
	input[11:0]                      clipper_top,
	input[11:0]                      clipper_left,
	input[11:0]                      clipper_width,
	input[11:0]                      clipper_height,
	input[11:0]                      vin_s_width,
	input[11:0]                      vin_s_height,
	input                            vout_pixel_clk,
	input                            vout_vs,
	input                            vout_pixel_rd_req,
	output[23:0]                     vout_pixel_ycbcr,
	input                            vout_scaler_clk,	
	input[11:0]                      vout_t_width,
	input[11:0]                      vout_t_height,
	input[15:0]                      vout_K_h,
	input[15:0]                      vout_K_v, 
	input                            mem_clk,
	output                           wr_burst_req,
	output[9:0]                      wr_burst_len,
	output[23:0]                     wr_burst_addr,
	input                            wr_burst_data_req,
	output[MEM_DATA_BITS - 1:0]      wr_burst_data,
	input                            wr_burst_finish,
	output                           rd_burst_req,
	output [9:0]                     rd_burst_len,
	output [23:0]                    rd_burst_addr,
	input                            rd_burst_data_valid,
	input[MEM_DATA_BITS - 1:0]       rd_burst_data,
	input                            rd_burst_finish,
	input[1:0]                       base_addr
);
wire[1:0] frame_addr;
/*视频输入处理模块*/
vin_pro#
(
	.MEM_DATA_BITS(MEM_DATA_BITS),
	.INTERLACE(INTERLACE)
) vin_pro_m0(
	.rst_n(rst_n),
	.pixel_clk(vin_pixel_clk),
	.vs(vin_vs),
	.f(vin_f),
	.pixel_de(vin_pixel_de),
	.pixel_rgb(vin_pixel_rgb),
	.clipper_top(clipper_top),
	.clipper_left(clipper_left),
	.clipper_height(clipper_height),
	.clipper_width(clipper_width),
	.mem_clk(mem_clk),
	.wr_burst_req(wr_burst_req),
	.wr_burst_len(wr_burst_len),
	.wr_burst_addr(wr_burst_addr),
	.wr_burst_data_req(wr_burst_data_req),
	.wr_burst_data(wr_burst_data),
	.burst_finish(wr_burst_finish),
	.s_width(vin_s_width),
	.s_height(vin_s_height),
	.base_addr(base_addr),
	.frame_addr(frame_addr)
);
/*视频输出模块*/	
vout_pro#
(
	.MEM_DATA_BITS(MEM_DATA_BITS),
	.WITDH_2K(INTERLACE ? 0:1)
) vout_pro_m0(
	.rst_n(rst_n),
	.pixel_clk(vout_pixel_clk),
	.vs(vout_vs),
	.pixel_rd_req(vout_pixel_rd_req),
	.pixel_ycbcr(vout_pixel_ycbcr),
	.mem_clk(mem_clk),
	.rd_burst_req(rd_burst_req),
	.rd_burst_len(rd_burst_len),
	.rd_burst_addr(rd_burst_addr),
	.rd_burst_data_valid(rd_burst_data_valid),
	.rd_burst_data(rd_burst_data),
	.burst_finish(rd_burst_finish),
	.scaler_clk(vout_scaler_clk),
	.s_width(vin_s_width),
	.s_height(vin_s_height),
	.t_width(vout_t_width),
	.t_height(vout_t_height),
	.K_h(vout_K_h),
	.K_v(vout_K_v),
	.base_addr(base_addr),
	.wr_frame_addr(frame_addr)
);
endmodule 