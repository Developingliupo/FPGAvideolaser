//////////////////////////////////////////////////////////////////////////////////
// Module Name:    udp����ͨ��ģ��
//////////////////////////////////////////////////////////////////////////////////

module udp(
			input wire           reset_n,
			input  wire          g_clk,
			
			input	 wire           e_rxc,
			input  wire	[7:0]	    e_rxd, 
			input	 wire           e_rxdv,
			output wire	          e_txen,
			output wire	[7:0]     e_txd,                              
			output wire		       e_txer,		
		
			output wire 	       data_o_valid,                        //����������Ч�ź�// 
			output wire [31:0]    ram_wr_data,                         //���յ���32bit IP������//  
			output wire [15:0]    rx_total_length,                     //����IP�����ܳ���

			output wire [3:0]     rx_state,                            //UDP���ݽ���״̬��
			output wire [15:0]    rx_data_length,		                 //����IP�������ݳ���/
			output wire [8:0]     ram_wr_addr,                         //ram����д��ַ
			
			//transmitting
			input  wire [31:0]    fifo_rd_data,                         //fifo����������
			output wire 		  fifo_rd_en,
			input wire			  fifo_empty,
			output      [3:0]     tx_state,                            //UDP���ݷ���״̬��
			input wire 			  frame_sync,
			input wire 			  line_sync,
			input wire [11:0]	  v_height,
			input wire [15:0]	  line_number,

			input  wire [15:0]    tx_data_length,                      //����IP�������ݳ���/
			input  wire [15:0]    tx_total_length,                     //����IP�����ܳ���/
			//output wire [8:0]     ram_rd_addr,                         //ram���ݶ���ַ

			output wire           data_receive
);


wire	[31:0] crcnext;
wire	[31:0] crc32;
wire	crcreset;
wire	crcen;


//IP frame����
ipsend ipsend_inst(
	.clk(g_clk),
	.txen(e_txen),
	.txer(e_txer),
	.dataout(e_txd),
	.crc(crc32),
	.datain(),
	.crcen(crcen),
	.crcre(crcreset),
	.tx_state(tx_state),
	.fifo_rd_data(fifo_rd_data),
	.fifo_rd_en(fifo_rd_en),
	.fifo_empty(fifo_empty),
	.frame_sync(frame_sync),
	.line_sync(line_sync),
	.v_height(v_height),
	.line_number(line_number),
	
	.tx_data_length(tx_data_length),
	.tx_total_length(tx_total_length),
	//.ram_rd_addr(ram_rd_addr)
	);
	
//crc32У��
crc	crc_inst(
	.Clk(g_clk),
	.Reset(crcreset),
	.Enable(crcen),
	.Data_in(e_txd),
	.Crc(crc32),
	.CrcNext(crcnext));

//IP frame���ճ���
iprecieve iprecieve_inst(
	.clk(e_rxc),
	.datain(e_rxd),
	.e_rxdv(e_rxdv),	
	.clr(reset_n),
	.board_mac(),	
	.pc_mac(),
	.IP_Prtcl(),
	.IP_layer(),
	.pc_IP(),	
	.board_IP(),
	.UDP_layer(),
	.data_o(ram_wr_data),	
	.valid_ip_P(),
	.rx_total_length(rx_total_length),
	.data_o_valid(data_o_valid),                                       
	.rx_state(rx_state),
	.rx_data_length(rx_data_length),
	.ram_wr_addr(ram_wr_addr),
	.data_receive(data_receive)	
	
	
	);
	
endmodule
