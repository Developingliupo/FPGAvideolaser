/*
视频输出处理模块，完成视频从ddr读取，缩放，然后再准备送给时序模块
*/
module vout_pro
#(
	parameter MEM_DATA_BITS = 64,              //存储器接口位宽
	parameter WITDH_2K = 0
)
   (
	input rst_n,
	input pixel_clk,                          //输出视频像素时钟
	input vs,                                 //输出视频场同步
	input pixel_rd_req,                       //对接时序发生模块，时序发生模块数据读取信号
	output[23:0] pixel_ycbcr,                 //输出视频数据
	input mem_clk,                            //存储器接口时钟
	output  rd_burst_req,                     //存储器突发请求（这里为读请求）
	output [9:0] rd_burst_len,                //读请求的数据长度（数据数量）
	output [23:0] rd_burst_addr,              //读请求的起始地址
	input rd_burst_data_valid,                //控制器返回的读数据有效指示
	input[MEM_DATA_BITS - 1:0] rd_burst_data, //控制器返回的数据
	input burst_finish,                       //控制器返回本次读完成
	input scaler_clk,                         //缩放模块时钟,这里使用输出像素时钟
	input[11:0] s_width,                      //存在存储器（ddr2）中的原始视频的宽度
	input[11:0] s_height,                     //存在存储器（ddr2）中的原始视频的高度
	input[11:0] t_width,                      //经过缩放处理后，也就是最终要输出的视频宽度
	input[11:0] t_height,                     //经过缩放处理后，也就是最终要输出的视频高度
	input[15:0] K_h,                          //视频宽度缩放比例 = s_width * 256 / t_width
	input[15:0] K_v,                          //视频高度缩放比例 = s_height * 256 / t_height
	input[11:0] wr_max_line,                  //辅助信号
	input[1:0] base_addr,                     //使用该信号可以控制在存储器中读取的区域，主要是为多通道读取设计
	input[1:0] wr_frame_addr                  //当前视频写入模块正在写的地址
);

localparam buff0_depth = 512;
localparam scaler_en = 1'b0;
localparam C0 = 60;

wire out_buff0_wrreq;
wire vout_rd_req;
wire fifo_rdempty;
wire out_buff0_wrfull;
wire[23:0] vout_data;
wire[23:0] out_buff0_data;
wire out_buff0_rdclk;
wire[23:0] out_buff0_q;
wire out_buff0_rdreq;
wire out_buff0_aclr;
wire[8 : 0] out_buff0_wrusedw;
//reg pixel_rd_req_d0 = 1'b0;
reg vs_d0  = 1'b0 ;
reg vs_d1 = 1'b0;
reg frame_flag  = 1'b0;
wire scaler_rd_req;
wire scaler_wr_req;
wire scaler_fifo_afull;
wire scaler_fifo_aempty;
wire[23:0] scaler_yc_data_in;
wire[23:0] scaler_yc_data_out;
wire[23:0] scl_out_buf_q;
wire scl_out_buf_rdempty;
wire[4:0] scl_out_buf_wrusedw;
wire line_end;
wire out_buff0_wrclk;
wire lwrfull;

wire[23:0] test_max_data_w;
wire[23:0] test_mem_fifo_data_w;
//assign vout_rd_req = scaler_rd_req;
assign vout_rd_req = ~fifo_rdempty & ~scaler_fifo_afull;
//视频读取帧缓存处理模块
vout_frame_buffer_ctrl
#
(
	.MEM_DATA_BITS(MEM_DATA_BITS),
	.WITDH_2K(WITDH_2K)
) vout_frame_buffer_ctrl_m0(
	.rst_n(rst_n),
	.vout_clk(pixel_clk),
	.vout_vs(vs),
	.vout_rd_req(vout_rd_req),
	.vout_data(vout_data),
	.vout_width(s_width),
	.vout_height(s_height),
	.fifo_rdempty(fifo_rdempty),
	.mem_clk(mem_clk),
	.rd_burst_req(rd_burst_req),
	.rd_burst_len(rd_burst_len),
	.rd_burst_addr(rd_burst_addr),
	.rd_burst_data_valid(rd_burst_data_valid),
	.rd_burst_data(rd_burst_data),
	.burst_finish(burst_finish),
	.wr_max_line(wr_max_line),
	.base_addr(base_addr),
	.test_max_data(test_max_data_w),
	.test_mem_fifo_data(test_mem_fifo_data_w),
	.wr_frame_addr(wr_frame_addr)
);
//defparam
//	vout_frame_buffer_ctrl_m0.MEM_DATA_BITS = MEM_DATA_BITS;

/*
assign scaler_fifo_aempty = fifo_rdempty;
assign scaler_yc_data_in = vout_data;
//读取ddr数据后经过缩放模块处理
scaler#
(
	.WITDH_2K(WITDH_2K)
) scaler_m0(
	.sys_clk(scaler_clk),
	.rst_n(rst_n),
	.fifo_aempty(scaler_fifo_aempty),
	.rd_req(scaler_rd_req),
	.yc_data_in(scaler_yc_data_in),
	.frame_flag(frame_flag),
	.fifo_afull(scaler_fifo_afull),
	.wr_req(scaler_wr_req),
	.yc_data_out(scaler_yc_data_out),
	.s_width(s_width),
	.s_height(s_height),
	.t_width(t_width),
	.t_height(t_height),
	.K_h(K_h),
	.K_v(K_v)
);
*/
assign scaler_fifo_afull = (out_buff0_wrusedw > buff0_depth  - C0);
assign out_buff0_wrreq = scaler_wr_req;
//assign out_buff0_data = scaler_yc_data_out;
assign out_buff0_data = vout_data;
assign out_buff0_wrclk = scaler_clk;
assign out_buff0_rdclk = pixel_clk;
assign out_buff0_rdreq = pixel_rd_req;
assign out_buff0_aclr = frame_flag;
//缩放处理后写入fifo，等待时序发生模块读取
lite_fifo#
(
	.COMMON_CLOCK(0),
	.ADDR_WIDTH(9),
	.DATA_WIDTH(24)
) 	out_buff0 (
	.wrclk (out_buff0_wrclk),
	.rdreq (out_buff0_rdreq),
	.aclr (out_buff0_aclr),
	.rdclk (out_buff0_rdclk),
	.wrreq (vout_rd_req),  //out_buff0_wrreq
	.data (vout_data),
	.rdempty (),
	.wrusedw (out_buff0_wrusedw),
	.wrfull (lwrfull),
	.q (pixel_ycbcr),
	.rdusedw ()
	); 

always@(posedge scaler_clk)
begin
	vs_d0 <= vs;
	vs_d1 <= vs_d0;
	frame_flag <= vs_d0 && ~vs_d1;
end

/*
always@(posedge pixel_clk)
begin
	pixel_rd_req_d0 <= pixel_rd_req;
end
//由于ddr2存储数据是YUV422，这里转换为YUV444，以便时序发生模块显示
YUV422_2YUV444 YUV422_2YUV444_u1(
   .clk  (pixel_clk),
   .y_i  (out_buff0_q[15:8]  ),
   .cbcr_i (out_buff0_q[7:0]),
   .de_i  (pixel_rd_req_d0),
   .hs_i  (),
   .vs_i  (),
   .y_o  (pixel_ycbcr[23:16]), 
   .cb_o (pixel_ycbcr[15:8]),
   .cr_o (pixel_ycbcr[7:0]),
   .de_o (),
   .hs_o (),
   .vs_o ()
   );
*/
endmodule 