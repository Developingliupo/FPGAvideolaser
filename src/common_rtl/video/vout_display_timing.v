/*******************************************************/
/****                                                  */
/****	本程序来自第三方，仅供参考，请勿传播、商用*****/
/****                                                  */
/*******************************************************/
/*
视频时序发生模块，本模块不要更具输入参数，实现不同分辨率的时序
这里没有考虑行场同步极性问题
*/
module vout_display_timing(
	input rst_n,               /*复位 */
	input dp_clk,              /*时钟*/
	input[11:0] h_fp,          /*行同步前肩 */
	input[11:0] h_sync,        /*行同步 */
	input[11:0] h_bp,          /*行同步后肩 */
	input[11:0] h_active,      /*行有效像素 */
	input[11:0] h_total,       /*行总周期（像素时钟） */
	input[11:0] v_fp,          /*场同步前肩（行）*/
	input[11:0] v_sync,        /*场同步（行）*/
	input[11:0] v_bp,          /*场同步后肩（行） */
	input[11:0] v_active,      /*场有效行 */
	input[11:0] v_total,       /*场总行 */
	input[11:0] h_clk_cnt,
	output reg rdreq0,
	output reg rdreq1,
	output reg rdreq2,
	output reg rdreq3,
	output reg rdreq4,
	output reg rdreq5,
	output reg[15:0] line_number,
	output hs,                 /*行同步输出 */
	output vs,                 /*场同步输出 */
	output de                  /*视频有效输出*/
);
reg[11:0] h_cnt = 12'd0;
reg[11:0] v_cnt = 12'd0;


//parameter PORTLEN = 12'd400;
wire rdreq0_w;
wire rdreq1_w;
wire rdreq2_w;
wire rdreq3_w;
wire rdreq4_w;
wire rdreq5_w;

reg hs_reg;
reg vs_reg;
reg de_reg;

wire hs_net;
wire vs_net;
wire de_net;
wire v_video;
wire h_video;

assign hs_net = (h_cnt > h_fp - 12'd1) && (h_cnt < h_fp + h_sync);/*行同步产生*/
assign h_video = (h_cnt >= h_fp + h_sync + h_bp) && (h_cnt < h_total);
assign v_video = (v_cnt >= v_fp + v_sync + v_bp) && (v_cnt < v_total);
assign vs_net = (v_cnt > v_fp - 12'd1) && (v_cnt < v_fp + v_sync);/*场同步产生*/
assign de_net = h_video && v_video;/*视频有效数据产生*/
assign hs = hs_reg;
assign vs = vs_reg;
assign de = de_reg;

//reg[15:0] line_number; // = v_cnt - v_fp - v_sync - v_bp;

assign rdreq0_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + 12'd0) && ( h_cnt < h_fp + h_sync + h_bp + h_clk_cnt) && (h_cnt < h_total);
assign rdreq1_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + h_clk_cnt) && (h_cnt < h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt) && (h_cnt < h_total);
assign rdreq2_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt) && (h_cnt < h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_total);
assign rdreq3_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_total);
assign rdreq4_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_total);
assign rdreq5_w = v_video && (h_cnt >= h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_fp + h_sync + h_bp + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt + h_clk_cnt) && (h_cnt < h_total);

/*行计数器，用于处理行相关*/
always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
		h_cnt <= 12'd0;
	else if(h_cnt == h_total - 12'd1)
		h_cnt <= 12'd0;
	else
		h_cnt <= h_cnt + 12'd1;		
end
/*场计数器，用于处理场相关*/
always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
		v_cnt <= 12'd0;
	else if(h_cnt == h_total - 12'd1)
		if(v_cnt == v_total - 12'd1)
			v_cnt <= 12'd0;
		else
			v_cnt <= v_cnt + 12'd1;
	else
		v_cnt <= v_cnt;
end

always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
		line_number <= 16'd0;
	else if (v_video)
		line_number <= {4'd0, v_cnt - v_fp - v_sync - v_bp};
	else
		line_number <= line_number;	
end

/*为了提高性能，打一拍再输出*/
always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		hs_reg <= 1'b0;
		rdreq0 <= 1'b0;
		rdreq1 <= 1'b0;
		rdreq2 <= 1'b0;
		rdreq3 <= 1'b0;
		rdreq4 <= 1'b0;
		rdreq5 <= 1'b0;
	end
	else
	begin
		hs_reg <= hs_net;
		rdreq0 <= rdreq0_w;
		rdreq1 <= rdreq1_w;
		rdreq2 <= rdreq2_w;
		rdreq3 <= rdreq3_w;
		rdreq4 <= rdreq4_w;
		rdreq5 <= rdreq5_w;
	end
end

/*为了提高性能，打一拍再输出*/
always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
		de_reg <= 1'b0;
	else
		de_reg <= de_net;
end
/*为了提高性能，打一拍再输出*/
always@(posedge dp_clk or negedge rst_n)
begin
	if(!rst_n)
		vs_reg <= 1'b0;
	else
		vs_reg <= vs_net;
end
endmodule 