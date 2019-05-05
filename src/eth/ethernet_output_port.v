module ethernet_output_port (
	//external pins
	input 			clk_50m,
	output 			e_reset,
	output 			e_mdc,
	inout			e_mdio,
	output[3:0] 	rgmii_txd,
	output 			rgmii_txctl,
	output 			rgmii_txc,
	input[3:0] 		rgmii_rxd,
	input 			rgmii_rxctl,
	input 			rgmii_rxc,
	
	//internal clock 148.5Mhz
	input 			pixel_clk,
	input[15:0] 	pixel_per_line,
	input[11:0]		pixel_v_height,
	input[23:0] 	wr_data,
	input 			wr_de,
	input[15:0] 	line_number,
	
	input 			hs,
	input 			vs
);

wire reset_n;
wire   [ 7:0]   gmii_txd;
wire            gmii_tx_en;
wire            gmii_tx_er;
wire            gmii_tx_clk;
wire            gmii_crs;
wire            gmii_col;
wire   [ 7:0]   gmii_rxd;
wire            gmii_rx_dv;
wire            gmii_rx_er;
wire            gmii_rx_clk;
wire  [ 1:0]    speed_selection; // 1x gigabit, 01 100Mbps, 00 10mbps
wire            duplex_mode;     // 1 full, 0 half

assign speed_selection = 2'b10;
assign duplex_mode = 1'b1;
assign e_reset =  reset_n; 

miim_top miim_top_m0(
	.reset_i            (1'b0),
	.miim_clock_i       (gmii_tx_clk),
	.mdc_o              (e_mdc),
	.mdio_io            (e_mdio),
	.link_up_o          (),                  //link status
	.speed_o            (),                  //link speed
	.speed_override_i   (2'b11)              //11: autonegoation
	);
	
util_gmii_to_rgmii util_gmii_to_rgmii_m0(
	.reset(1'b0),
	
	.rgmii_td(rgmii_txd),
	.rgmii_tx_ctl(rgmii_txctl),
	.rgmii_txc(rgmii_txc),
	.rgmii_rd(rgmii_rxd),
	.rgmii_rx_ctl(rgmii_rxctl),
	.rgmii_rxc(rgmii_rxc),
	
	.gmii_txd(gmii_txd),
	.gmii_tx_en(gmii_tx_en),
	.gmii_tx_er(gmii_tx_er),
	.gmii_tx_clk(gmii_tx_clk),
	.gmii_crs(gmii_crs),
	.gmii_col(gmii_col),
	.gmii_rxd(gmii_rxd),
	.gmii_rx_dv(gmii_rx_dv),
	.gmii_rx_er(gmii_rx_er),
	.gmii_rx_clk(gmii_rx_clk),
	.speed_selection(speed_selection),
	.duplex_mode(duplex_mode)
	);

wire [31:0] ram_wr_data;
wire [31:0] ram_rd_data;
wire [31:0] fifo_rd_data;
wire [8:0] ram_wr_addr;
wire [8:0] ram_rd_addr;
wire fifo_rd_en;
wire buffer_eth_rdempty;

reg ram_wren_i;
wire [31:0] datain_reg;

wire [3:0] tx_state;
wire [3:0] rx_state;
wire [15:0] rx_total_length;    
wire [15:0] tx_total_length;    
wire [15:0] rx_data_length;     
//wire [15:0] tx_data_length;     
wire receive_flag;

wire data_o_valid;

//assign tx_data_length = //rx_data_length;
assign tx_total_length = rx_total_length;

reg wr_de_delay0;
reg wr_de_delay1;
reg wr_de_delay2;
reg wr_de_delay3;
reg[23:0] wr_data_delay0;
reg[23:0] wr_data_delay1;
reg[23:0] wr_data_delay2;
reg[23:0] wr_data_delay3;

wire line_sync;
always@(negedge pixel_clk)
begin
	wr_de_delay0 <= wr_de;
	wr_de_delay1 <= wr_de_delay0;
	wr_de_delay2 <= wr_de_delay1;
	wr_de_delay3 <= wr_de_delay2;
	wr_data_delay0 <= wr_data;
	wr_data_delay1 <= wr_data_delay0;
	wr_data_delay2 <= wr_data_delay1;
	wr_data_delay3 <= wr_data_delay2;
end

assign line_sync = wr_de & ~wr_de_delay1; 

lite_fifo#
(
	.COMMON_CLOCK(0),
	.ADDR_WIDTH(9),
	.DATA_WIDTH(24)
)

buffer_eth(
	.aclr		(line_sync),
	.data		(wr_data_delay2),
	.rdclk		(gmii_tx_clk),
	.rdreq		(fifo_rd_en),
	.wrclk		(pixel_clk),
	.wrreq		(wr_de_delay3),
	.q			(fifo_rd_data[23:0]),
	.rdempty	(buffer_eth_rdempty),
	.rdusedw	(),
	.wrfull		(),
	.wrusedw	()
	);

reset reset_m0(
	.clk(clk_50m),
	.rst_n(reset_n)
);

udp u1(
	.reset_n		(reset_n),
	.g_clk			(gmii_tx_clk),
	
	.e_rxc			(gmii_rx_clk),
	.e_rxd			(gmii_rxd),
	.e_rxdv			(gmii_rx_dv),
	.e_txen			(gmii_tx_en),
	.e_txd			(gmii_txd),
	.e_txer			(gmii_tx_er),	
	
	//receive data
	.data_o_valid	(data_o_valid),          /*接收数据有效信号*/ 
	.ram_wr_data	(ram_wr_data),            /*接收到的32bit IP包数据*/ 
	.rx_total_length(rx_total_length),    
	.rx_state		(rx_state),                  
	.rx_data_length	(rx_data_length),      
	.ram_wr_addr	(ram_wr_addr),            
	.data_receive	(data_receive),   		/*收到数据包*/

	//trasmitting data
	.fifo_rd_data	(fifo_rd_data), 
	.fifo_rd_en		(fifo_rd_en),	
	.tx_state		(tx_state),  
	.fifo_empty		(buffer_eth_rdempty),
	.frame_sync		(vs),
	.line_sync		(line_sync),
	.v_height		(pixel_v_height),
	.line_number	(line_number),
	
	.tx_data_length	(pixel_per_line),      
	.tx_total_length(tx_total_length)    
	);

dp_ram#(.DATA_WIDTH(32),.MEM_SIZE(16)) ram_inst
(
	.data(ram_wr_data),
	.rdaddress(ram_rd_addr),
	.rdclock(gmii_tx_clk),
	.wraddress(ram_wr_addr),
	.wrclock(gmii_rx_clk),
	.wren(data_o_valid),
	.q()
);

endmodule