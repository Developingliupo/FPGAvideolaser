`timescale 1ps/1ps
/*
模块完成16bit的YC数据的64bit的数据对齐，然后写入FIFO，
有帧写入状态机完成64bit数据写入ddr2
*/
module vin_frame_buffer_ctrl
 #(
	parameter MEM_DATA_BITS = 64,
	parameter INTERLACE = 1
) 
(
	input rst_n,                                    /*复位 */
	input vin_clk,                                  /*视频输入时钟 */
	input vin_vs,                                   /*视频输入场同步 */
	input vin_f,                                    /*视频输入奇偶场标志 */
	input vin_de,                                   /*视频输入数据有效 */
	input[23:0] vin_data,                           /*视频输入数据RGB */
	input[11:0] vin_width,                          /*视频输入宽度*/
	input[11:0] vin_height,                         /*视频输入高度*/
	output reg fifo_afull,                          /*输入fifo快满*/
	input mem_clk,                                  /*存储器接口：时钟*/
	output reg wr_burst_req,                        /*存储器接口：写请求*/
	output reg[9:0] wr_burst_len,                   /*存储器接口：写长度*/
	output reg[23:0] wr_burst_addr,                 /*存储器接口：写首地址 */
	input wr_burst_data_req,                        /*存储器接口：写数据数据读指示 */
	output[MEM_DATA_BITS - 1:0] wr_burst_data,      /*存储器接口：写数据*/
	input burst_finish,                             /*存储器接口：本次写完成 */
	output reg[11:0] wr_max_line,                   /*辅助信号，测试用 */
	input[1:0] base_addr,                           /*帧地址参数*/
	input[23:0] test_max_data_w,
	output reg[1:0] frame_addr                      /*当前写入帧地址*/
);                                                   
initial                                              
begin
	frame_addr <= 2'd0;
end
localparam BURST_LEN = 10'd64;               /*一次写操作数据长度 */
localparam BURST_IDLE = 3'd0;                 /*状态机状态：空闲 */
localparam BURST_ONE_LINE_START = 3'd1;       /*状态机状态：视频数据一行写开始 */
localparam BURSTINGR = 3'd2;                   /*状态机状态：正在处理一次ddr2写操作 */
localparam BURSTINGG = 3'd3;                   /*状态机状态：正在处理一次ddr2写操作 */
localparam BURSTINGB = 3'd4;                   /*状态机状态：正在处理一次ddr2写操作 */
localparam BURST_END = 3'd5;                  /*状态机状态：一次ddr2写操作完成*/
localparam BURST_ONE_LINE_END = 3'd6;         /*状态机状态：视频数据一行写完成*/
reg[2:0] burst_state = 3'd0;                  /*状态机状态：当前状态 */
reg[2:0] burst_state_next = 3'd0;             /*状态机状态：下一个状态*/
reg[11:0] burst_line = 12'd0;/*已经写入ddr2的行计数*/
reg[9:0] byte_per_line = 10'd0;/*将视频宽度换算成写入ddr2的数据个数*/
 /*由于视频数据是16bit，ddr2接口是64bit，需要字节对齐操作，这个寄存器用来计算每行视频换算为ddr2接口后的数据长度 */
 /*如：视频宽度是200，换算后是50，视频宽度是199，换算后长度也是50，视频宽度是201，换算后长度是51*/
reg[9:0] remain_len = 10'd0;/*当前视频一行数据的剩余数据个数*/

wire[MEM_DATA_BITS - 1:0] datar;/*待写入fifo的数据 */
wire[MEM_DATA_BITS - 1:0] datag;/*待写入fifo的数据 */
wire[MEM_DATA_BITS - 1:0] datab;/*待写入fifo的数据 */

reg[7:0] pixelr0 = 8'd0;
reg[7:0] pixelr1 = 8'd0;
reg[7:0] pixelr2 = 8'd0;
reg[7:0] pixelr3 = 8'd0;
reg[7:0] pixelr4 = 8'd0;
reg[7:0] pixelr5 = 8'd0;
reg[7:0] pixelr6 = 8'd0;
reg[7:0] pixelr7 = 8'd0;
reg[7:0] pixelg0 = 8'd0;
reg[7:0] pixelg1 = 8'd0;
reg[7:0] pixelg2 = 8'd0;
reg[7:0] pixelg3 = 8'd0;
reg[7:0] pixelg4 = 8'd0;
reg[7:0] pixelg5 = 8'd0;
reg[7:0] pixelg6 = 8'd0;
reg[7:0] pixelg7 = 8'd0;
reg[7:0] pixelb0 = 8'd0;
reg[7:0] pixelb1 = 8'd0;
reg[7:0] pixelb2 = 8'd0;
reg[7:0] pixelb3 = 8'd0;
reg[7:0] pixelb4 = 8'd0;
reg[7:0] pixelb5 = 8'd0;
reg[7:0] pixelb6 = 8'd0;
reg[7:0] pixelb7 = 8'd0;

reg[11:0] data_cnt  = 12'd0;
reg vin_vs_mem_clk_d0 = 1'b0;
reg vin_vs_mem_clk_d1 = 1'b0;
reg vin_vs_d0 = 1'b0;
reg vin_vs_d1 = 1'b0;
reg frame_flag = 1'b0;
reg frame_flag_vin = 1'b0;
reg fifo_wr_req = 1'b0;
wire[7:0] rdusedwr;
wire[7:0] rdusedwg;
wire[7:0] rdusedwb;
wire[7:0] wrusedwr;
wire[7:0] wrusedwg;
wire[7:0] wrusedwb;
wire wr_burst_data_reqr;
wire wr_burst_data_reqg;
wire wr_burst_data_reqb;

wire[63:0] wr_burst_datar;
wire[63:0] wr_burst_datag;
wire[63:0] wr_burst_datab;

always@(posedge vin_clk)
begin
	fifo_afull <= (wrusedwb > 8'd245);
end


//==================MIX PIXEL===========================================================
assign datar= {pixelr7[7:0],pixelr6[7:0],pixelr5[7:0],pixelr4[7:0],pixelr3[7:0],pixelr2[7:0],pixelr1[7:0],pixelr0[7:0]};
assign datag= {pixelg7[7:0],pixelg6[7:0],pixelg5[7:0],pixelg4[7:0],pixelg3[7:0],pixelg2[7:0],pixelg1[7:0],pixelg0[7:0]};
assign datab= {pixelb7[7:0],pixelb6[7:0],pixelb5[7:0],pixelb4[7:0],pixelb3[7:0],pixelb2[7:0],pixelb1[7:0],pixelb0[7:0]};

//==================MIX PIXEL===========================================================
assign wr_burst_data_reqr = (burst_state_next == BURSTINGR) ? wr_burst_data_req:1'b0;
assign wr_burst_data_reqg = (burst_state_next == BURSTINGG) ? wr_burst_data_req:1'b0;
assign wr_burst_data_reqb = (burst_state_next == BURSTINGB) ? wr_burst_data_req:1'b0;
assign wr_burst_data = (burst_state_next == BURSTINGR) ? wr_burst_datar:((burst_state_next == BURSTINGG) ? wr_burst_datag:((burst_state_next == BURSTINGB) ? wr_burst_datab:64'd0));
//assign wr_burst_data = (burst_state == BURSTINGR) ? 64'h1122334455667788 : ((burst_state == BURSTINGG) ? 64'h9988776655443322 : ((burst_state == BURSTINGB) ? 64'heeddccbbaa998877:64'd0));

fifo_256_64
 vin_frame_buffer_ctrl_fifo_mr(
	.aclr(frame_flag),
	.data(datar),
	.rdclk(mem_clk),
	.rdreq(wr_burst_data_reqr),  ///* TODO: */
	.wrclk(vin_clk),
	.wrreq(fifo_wr_req),
	.q(wr_burst_datar),		    ///* TODO*/
	.rdempty(),
	.rdusedw(rdusedwr),  		///* TODO*/
	.wrfull(),
	.wrusedw(wrusedwr)); 

fifo_256_64
 vin_frame_buffer_ctrl_fifo_mg(
	.aclr(frame_flag),
	.data(datag),
	.rdclk(mem_clk),
	.rdreq(wr_burst_data_reqg),
	.wrclk(vin_clk),
	.wrreq(fifo_wr_req),
	.q(wr_burst_datag),
	.rdempty(),
	.rdusedw(rdusedwg),
	.wrfull(),
	.wrusedw(wrusedwg)); 
	
fifo_256_64
 vin_frame_buffer_ctrl_fifo_mb(
	.aclr(frame_flag),
	.data(datab),
	.rdclk(mem_clk),
	.rdreq(wr_burst_data_reqb),
	.wrclk(vin_clk),
	.wrreq(fifo_wr_req),
	.q(wr_burst_datab),
	.rdempty(),
	.rdusedw(rdusedwb),
	.wrfull(),
	.wrusedw(wrusedwb)); 

always@(posedge vin_clk)
begin
	vin_vs_d0 <= vin_vs;
	vin_vs_d1 <= vin_vs_d0;
	frame_flag_vin <= vin_vs_d0 && ~vin_vs_d1;
end
/* 每行的行数据计数 */
always@(posedge vin_clk)
begin
	if(!rst_n)
		data_cnt <= 12'd0;
	else if(frame_flag_vin)
		data_cnt <= 12'd0;
	else if(vin_de)
		begin
			if(data_cnt == vin_width - 12'd1)
				data_cnt <= 12'd0;
			else
				data_cnt <= data_cnt + 12'd1;
		end
	else
		data_cnt <= data_cnt;
end

//==================MIX PIXEL===========================================================
//------------------RED PIXEL----------------------
/*当data_cnt[2:0] == 0 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd0))
		pixelr0 <= vin_data[7:0];
	else
		pixelr0 <= pixelr0;		
end
/*当data_cnt[2:0] == 1 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd1))
		pixelr1 <= vin_data[7:0];
	else
		pixelr1 <= pixelr1;		
end
/*当data_cnt[2:0] == 2 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd2))
		pixelr2 <= vin_data[7:0];
	else
		pixelr2 <= pixelr2;		
end
/*当data_cnt[2:0] == 3 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd3))
		pixelr3 <= vin_data[7:0];
	else
		pixelr3 <= pixelr3;		
end
/*当data_cnt[2:0] == 4 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd4))
		pixelr4 <= vin_data[7:0];
	else
		pixelr4 <= pixelr4;		
end
/*当data_cnt[2:0] == 5 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd5))
		pixelr5 <= vin_data[7:0];
	else
		pixelr5 <= pixelr5;		
end
/*当data_cnt[2:0] == 6 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd6))
		pixelr6 <= vin_data[7:0];
	else
		pixelr6 <= pixelr6;		
end
/*当data_cnt[2:0] == 7 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd7))
		pixelr7 <= vin_data[7:0];
	else
		pixelr7 <= pixelr7;		
end
//---------------GREEN PIXEL---------------
/*当data_cnt[2:0] == 0 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd0))
		pixelg0 <= vin_data[15:8];
	else
		pixelg0 <= pixelg0;		
end
/*当data_cnt[2:0] == 1 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd1))
		pixelg1 <= vin_data[15:8];
	else
		pixelg1 <= pixelg1;		
end
/*当data_cnt[2:0] == 2 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd2))
		pixelg2 <= vin_data[15:8];
	else
		pixelg2 <= pixelg2;		
end
/*当data_cnt[2:0] == 3 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd3))
		pixelg3 <= vin_data[15:8];
	else
		pixelg3 <= pixelg3;		
end
/*当data_cnt[2:0] == 4 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd4))
		pixelg4 <= vin_data[15:8];
	else
		pixelg4 <= pixelg4;		
end
/*当data_cnt[2:0] == 5 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd5))
		pixelg5 <= vin_data[15:8];
	else
		pixelg5 <= pixelg5;		
end
/*当data_cnt[2:0] == 6 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd6))
		pixelg6 <= vin_data[15:8];
	else
		pixelg6 <= pixelg6;		
end
/*当data_cnt[2:0] == 7 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd7))
		pixelg7 <= vin_data[15:8];
	else
		pixelg7 <= pixelg7;		
end
//---------------BLUE PIXEL----------------------
/*当data_cnt[2:0] == 0 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd0))
		pixelb0 <= vin_data[23:16];
	else
		pixelb0 <= pixelb0;		
end
/*当data_cnt[2:0] == 1 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd1))
		pixelb1 <= vin_data[23:16];
	else
		pixelb1 <= pixelb1;		
end
/*当data_cnt[2:0] == 2 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd2))
		pixelb2 <= vin_data[23:16];
	else
		pixelb2 <= pixelb2;		
end
/*当data_cnt[2:0] == 3 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd3))
		pixelb3 <= vin_data[23:16];
	else
		pixelb3 <= pixelb3;		
end
/*当data_cnt[2:0] == 4 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd4))
		pixelb4 <= vin_data[23:16];
	else
		pixelb4 <= pixelb4;		
end
/*当data_cnt[2:0] == 5 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd5))
		pixelb5 <= vin_data[23:16];
	else
		pixelb5 <= pixelb5;		
end
/*当data_cnt[2:0] == 6 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd6))
		pixelb6 <= vin_data[23:16];
	else
		pixelb6 <= pixelb6;		
end
/*当data_cnt[2:0] == 7 时，pixelr0取当前像素值*/
always@(posedge vin_clk)
begin
	if(vin_de && (data_cnt[2:0] == 3'd7))
		pixelb7 <= vin_data[23:16];
	else
		pixelb7 <= pixelb7;		
end
//===============END PIXEL MIX==============================================================

/*当data_cnt[2:0] == 7 时，pixelx0~pixelx7都有值，可拼接为三个64bit，完成一次写入FIFO操作*/
always@(posedge vin_clk)
begin
	if(vin_de &&(data_cnt[2:0] == 3'd7 || data_cnt == vin_width - 12'd1))
		fifo_wr_req <= 1'b1;
	else
		fifo_wr_req <= 1'b0;
end
/*将视频宽度换算成写入ddr2的数据个数 = 1920/8 */
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		byte_per_line <= 10'd0;
	else if(frame_flag)
		if(vin_width[2:0] == 3'd0)
			byte_per_line <= vin_width[11:3];
		else
			byte_per_line <= vin_width[11:3] + 10'd1;
	else
		byte_per_line <= byte_per_line;
end

/*突发写首地址的产生*/
wire[23:0] ddr_wr_baser;

assign ddr_wr_baser =  {base_addr,frame_addr[1:0],burst_line[11:0],8'd0};//24bit ddr addr


//TODO: wr_burst_address 应该变化
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		wr_burst_addr <= 24'd0;
	else if(burst_state_next == BURST_ONE_LINE_START)
		wr_burst_addr <= ddr_wr_baser;   //red address 
	else if(burst_state_next == BURSTINGG && burst_state != BURSTINGG)
		wr_burst_addr <= wr_burst_addr + 24'h50000;  //green address 1280*256;
	else if(burst_state_next == BURSTINGB && burst_state != BURSTINGB)
		wr_burst_addr <= wr_burst_addr + 24'h50000;  //blue address
	else if(burst_state_next == BURST_END  && burst_state != BURST_END)
		wr_burst_addr <= wr_burst_addr + {15'd0,BURST_LEN[8:0]} - 24'ha0000;
	else
		wr_burst_addr <= wr_burst_addr;
end

always@(posedge mem_clk)
begin
	vin_vs_mem_clk_d0 <= vin_vs;
	vin_vs_mem_clk_d1 <= vin_vs_mem_clk_d0;
	frame_flag <= vin_vs_mem_clk_d0 && ~vin_vs_mem_clk_d1;
end
/*每一帧都将状态机强行进入BURST_IDLE状态*/
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		burst_state <= BURST_IDLE;
	else if(frame_flag)
		burst_state <= BURST_IDLE;
	else
		burst_state <= burst_state_next;
end
always@(*)
begin
	case(burst_state)
		BURST_IDLE:/*如果FIFO有足够的数据则完成一行第一次写操作*/
			if(rdusedwr > BURST_LEN[7:0])
				burst_state_next <= BURST_ONE_LINE_START;
			else
				burst_state_next <= BURST_IDLE;
		BURST_ONE_LINE_START:/*一行的写操作开始*/
			burst_state_next <= BURSTINGR;
		BURSTINGR:/*写操作*/
			if(burst_finish)
				burst_state_next <= BURSTINGG;
			else
				burst_state_next <= BURSTINGR;
		BURSTINGG:/*写操作*/
			if(burst_finish)
				burst_state_next <= BURSTINGB;
			else
				burst_state_next <= BURSTINGG;
		BURSTINGB:/*写操作*/
			if(burst_finish)
				burst_state_next <= BURST_END;
			else
				burst_state_next <= BURSTINGB;
		BURST_END:/*写操作完成时判断一行数据是否已经完全写入ddr2，如果完成则进入空闲状态，等待第二行数据*/
			if(remain_len == 10'd0)
				burst_state_next <= BURST_ONE_LINE_END;
			else if((rdusedwr >= BURST_LEN[7:0]) || (remain_len < BURST_LEN && rdusedwr >= remain_len))  //(remain_len < BURST_LEN && rdusedw >= remain_len)
				burst_state_next <= BURSTINGR;
			else
				burst_state_next <= BURST_END;
		BURST_ONE_LINE_END:
			burst_state_next <= BURST_IDLE;
		default:
			burst_state_next <= BURST_IDLE;
	endcase
end

always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		wr_max_line <= 12'd0;
	else if(frame_flag)
		wr_max_line <= burst_line;
	else
		wr_max_line <= wr_max_line;
end
/*burst_line产生*/
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		burst_line <= 12'd0;
	else if(frame_flag)
		burst_line <= 12'd0;
	else if(burst_state == BURST_ONE_LINE_END)//每次一行写完burst_line加1
		burst_line <= burst_line + 12'd1;
	else
		burst_line <= burst_line;
end
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		frame_addr <= 2'd0;
	else if(frame_flag && vin_f)//没写入一帧数据frame_addr加1
	//else if(frame_flag)
		frame_addr <= frame_addr + 2'd1;
	else
		frame_addr <= frame_addr;
end	

/*remain_len产生，每一行写开始时等于byte_per_line，如果一行数据小于一次写的最大长度，
一次写完，则remain_len = 0，否则减去最大写长度*/
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		remain_len <= 10'd0;
	else if(burst_state_next == BURST_ONE_LINE_START)
		remain_len <= byte_per_line;
	else if(burst_state_next == BURST_END && burst_state != BURST_END)
		if(remain_len < BURST_LEN)
			remain_len <= 10'd0;
		else
			remain_len <= remain_len - BURST_LEN;	
	else
		remain_len <= remain_len;
end
/*突发长度产生，如果一行的剩余数据大于最大写长度，则突发长度是BURST_LEN，否则就等于剩余数据长度*/
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		wr_burst_len <= 10'd0;
	else if(burst_state_next == BURSTINGR && burst_state != BURSTINGR)
		if(remain_len > BURST_LEN)
			wr_burst_len <= BURST_LEN;
		else
			wr_burst_len <= remain_len;
	else
		wr_burst_len <=  wr_burst_len;
end
/*ddr2写请求信号的产生于撤销*/
always@(posedge mem_clk or negedge rst_n)
begin
	if(!rst_n)
		wr_burst_req <= 1'd0;
	else if ((burst_state_next == BURSTINGR && burst_state != BURSTINGR) || 
				(burst_state_next == BURSTINGG && burst_state != BURSTINGG) || 
				(burst_state_next == BURSTINGB && burst_state != BURSTINGB) )
		wr_burst_req <= 1'b1;
	else if(burst_finish  || wr_burst_data_req || burst_state == BURST_IDLE)
		wr_burst_req <= 1'b0;
	else
		wr_burst_req <= wr_burst_req;
end

endmodule 