/**** 
		sdram加上axi顶层模块 
****/
`include "defines.v"

module sdram_pro_axi_top#
	(
		// Base address of targeted slave
		// 基地址
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 'd0,
		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		// 突发长度
		parameter integer C_M_AXI_BURST_LEN	= 16,
		// Thread ID Width
		// ID位宽
		parameter integer C_M_AXI_ID_WIDTH	= 1,
		// Width of Address Bus
		// 地址位宽
		parameter integer C_M_AXI_ADDR_WIDTH	= 23,
		// Width of Data Bus
		// 数据位宽
		parameter integer C_M_AXI_DATA_WIDTH	= 16,
		
		// 用户接口？
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		input					sys_clk					, // 所有模块暂时共用一个时钟
		input					sys_rst_n				, // 所有模块暂时共用一个复位
		input	[22:0]			addr					, // 读写暂时共用同一addr
		//写FIFO信号
		output  wire    [9:0]   wr_fifo_num     		, //写fifo中的数据量	
		//读FIFO信号		
		output  wire    [15:0]  rd_fifo_rd_data 		, //读FIFO读数据
		output  wire    [9:0]   rd_fifo_num     		, //读fifo中的数据量
		//功能信号		
		input   wire            read_valid      		, //SDRAM读使能
		output  wire            init_end        		, //SDRAM初始化完成标志
		//SDRAM接口信号		
		output  wire            sdram_cke       		, //SDRAM时钟有效信号
		output  wire            sdram_cs_n      		, //SDRAM片选信号
		output  wire            sdram_ras_n     		, //SDRAM行地址选通脉冲
		output  wire            sdram_cas_n     		, //SDRAM列地址选通脉冲
		output  wire            sdram_we_n      		, //SDRAM写允许位
		output  wire    [1:0]   sdram_bank				, //SDRAM的L-Bank地址线
		output  wire    [11:0]  sdram_addr      		, //SDRAM地址总线
		output  wire    [1:0]   sdram_dqm       		, //SDRAM数据掩码
		inout   wire    [15:0]  sdram_dq        		, //SDRAM数据总线
		//AXI接口信号
		input					i_write_burst_en		, // 写突发使能
		input					i_read_burst_en			  // 读突发使能

		
	);

	//// define /////
	wire [C_M_AXI_ADDR_WIDTH-1:0]	axi_waddr		;
	wire [C_M_AXI_ADDR_WIDTH-1:0]	axi_raddr		;
	wire 							axi_aclk		;
	wire 							axi_aresetn		;	
	wire [C_M_AXI_ID_WIDTH-1 : 0]	axi_awid		;
	//wire [C_M_AXI_ADDR_WIDTH-1 : 0]	axi_awaddr		;
	wire [7 : 0]					axi_awlen		;
	wire [2 : 0]					axi_awsize		;
	wire [1 : 0]					axi_awburst		;	
	wire 							axi_awlock		;
	wire [3:0]						axi_awcache		;	
	wire [2:0]						axi_awprot		;
	wire [3:0]						axi_awqos		;
	wire [C_M_AXI_AWUSER_WIDTH-1:0]	axi_awuser		;
	wire 							axi_awvalid		;	
	wire 							axi_awready		;	
	wire [C_M_AXI_DATA_WIDTH-1:0]	axi_wdata		;
	wire [C_M_AXI_DATA_WIDTH/8-1:0]	axi_wstrb		;
	wire 							axi_wlast		;
	wire [C_M_AXI_WUSER_WIDTH-1:0]	axi_wuser		;
	wire 							axi_wvalid		;
	wire 							axi_wready		;
	wire [C_M_AXI_ID_WIDTH-1:0]		axi_bid			;	
	wire [1:0]						axi_bresp		;
	wire [C_M_AXI_BUSER_WIDTH-1:0]	axi_buser		;
	wire 							axi_bvalid		;
	wire 							axi_bready		;
	wire [C_M_AXI_ID_WIDTH-1:0]		axi_arid		;
	//wire [C_M_AXI_ADDR_WIDTH-1 : 0]	axi_araddr		;
	wire [7:0]						axi_arlen		;
	wire [2:0]						axi_arsize		;
	wire [1:0]						axi_arburst		;	
	wire 							axi_arlock		;
	wire [3:0]						axi_arcache		;	
	wire [2:0]						axi_arprot		;
	wire [3:0]						axi_arqos		;
	wire [C_M_AXI_AWUSER_WIDTH-1:0]	axi_aruser		;
	wire							axi_arvalid		;	
	wire							axi_arready		;	
	wire [C_M_AXI_ID_WIDTH-1:0]		axi_rid			;	
	wire [C_M_AXI_DATA_WIDTH-1:0]	axi_rdata		;
	wire [1:0]						axi_rresp		;
	wire 							axi_rlast		;
	wire [C_M_AXI_WUSER_WIDTH-1:0]	axi_ruser		;
	wire 							axi_rvalid		;
	wire 							axi_rready  	;
	wire [3:0]						axi_awregion	;
	wire [3:0]						axi_arregion	;
	wire 							init_axi_txn	;
	wire 							txn_done		;
	wire 							error			;
	wire [22:0]						sdram_wr_b_addr ;
	wire [22:0]						sdram_wr_e_addr ;
	wire [22:0]						sdram_rd_b_addr ;
	wire [22:0]						sdram_rd_e_addr ;
	wire [7:0]						wr_burst_len	;
	wire [7:0]						rd_burst_len	;
	
	// slave 到 fifo 的信号
	wire							wr_fifo_wr_req	; 		
	wire    [15:0]  				wr_fifo_wr_data ;	
	wire							rd_fifo_rd_req	;	
	// sdram写模块到 master 的信号
	wire 							sdram_wr_end	;
	// sdram读模块到 slave 的信号，用来接收读出的数据
	wire							sdram_rd_ack	;
	// master 到 fifo ctrl 的信号
	wire							WR_BURST_FLAG	;
	wire							RD_BURST_FLAG	;
	//// main code /////
	//assign axi_waddr        = addr;
	//assign axi_raddr        = addr;
	assign wr_burst_len	   = C_M_AXI_BURST_LEN;
	assign rd_burst_len	   = C_M_AXI_BURST_LEN;
	assign sdram_wr_b_addr = axi_waddr[22:0];
	assign sdram_wr_e_addr = sdram_wr_b_addr + wr_burst_len;	
	assign sdram_rd_b_addr = axi_waddr[22:0];
	assign sdram_rd_e_addr = sdram_rd_b_addr + rd_burst_len;
	

	//// inst ////
	// sdram inst
	sdram_pro_top u_sdram_pro_top
	(
		.WR_BURST_FLAG		(WR_BURST_FLAG		),
		.RD_BURST_FLAG		(RD_BURST_FLAG		),
		.sdram_wr_end		(sdram_wr_end	 	),
		.sys_clk			(sys_clk		 	),   //sdram时钟
		.sys_rst_n			(sys_rst_n		 	),   //sdram复位信号	
								
		.wr_fifo_wr_req  	(wr_fifo_wr_req  	),   //写FIFO写请求
		.wr_fifo_wr_data 	(wr_fifo_wr_data 	),   //写FIFO写数据
		.sdram_wr_b_addr 	(sdram_wr_b_addr 	),   //写SDRAM首地址
		.sdram_wr_e_addr 	(sdram_wr_e_addr 	),   //写SDRAM末地址
		.wr_burst_len    	(wr_burst_len    	),   //写SDRAM数据突发长度
		.wr_fifo_num     	(wr_fifo_num     	),   //写fifo中的数据量	
												
		.rd_fifo_rd_req  	(rd_fifo_rd_req  	),   //读FIFO读请求
		.sdram_rd_b_addr 	(sdram_rd_b_addr 	),   //读SDRAM首地址
		.sdram_rd_e_addr 	(sdram_rd_e_addr 	),   //读SDRAM末地址
		.rd_burst_len    	(rd_burst_len    	),   //读SDRAM数据突发长度
		.rd_fifo_rd_data 	(rd_fifo_rd_data 	),   //读FIFO读数据
		.rd_fifo_num     	(rd_fifo_num     	),   //读fifo中的数据量
								
		.read_valid      	(read_valid      	),   //SDRAM读使能
		.init_end        	(init_end        	),   //SDRAM初始化完成标志
		.sdram_rd_ack		(sdram_rd_ack	 	),	  //给slave模块的信号，用来接收读出的数据
		.sdram_rd_end       (sdram_rd_end	 	), 
			
		.sdram_cke       	(sdram_cke       	),   //SDRAM时钟有效信号
		.sdram_cs_n      	(sdram_cs_n      	),   //SDRAM片选信号
		.sdram_ras_n     	(sdram_ras_n     	),   //SDRAM行地址选通脉冲
		.sdram_cas_n     	(sdram_cas_n     	),   //SDRAM列地址选通脉冲
		.sdram_we_n      	(sdram_we_n      	),   //SDRAM写允许位
		.sdram_bank		 	(sdram_bank		 	),   //SDRAM的L-Bank地址线
		.sdram_addr      	(sdram_addr      	),   //SDRAM地址总线
		.sdram_dqm       	(sdram_dqm       	),   //SDRAM数据掩码
		.sdram_dq        	(sdram_dq        	)    //SDRAM数据总线
	);
	
	// axi slave inst
	sdram_pro_axi_slave #
	(
		.C_S_AXI_ID_WIDTH	(1 ),
		.C_S_AXI_DATA_WIDTH	(16),  // 数据总线位宽改为16位
		.C_S_AXI_ADDR_WIDTH	(23),  // 地址总线位宽改为32位
		.C_S_AXI_AWUSER_WIDTH(0),
		.C_S_AXI_ARUSER_WIDTH(0),
		.C_S_AXI_WUSER_WIDTH (0),
		.C_S_AXI_RUSER_WIDTH (0),
		.C_S_AXI_BUSER_WIDTH (0)
	)
	u_sdram_pro_axi_slave
	(
		. S_AXI_ACLK				(sys_clk			),
		. S_AXI_ARESETN				(sys_rst_n			),
		// user	
		.fifo_s_axi_wdata           (wr_fifo_wr_data	), // slave 到 fifo 的数据
		.wr_fifo_wr_req		        (wr_fifo_wr_req		), // slave 到 fifo 的fifo写使能信号
		.wr_fifo_num		        (wr_fifo_num		),
		.rd_fifo_num		        (rd_fifo_num		),
		.rd_fifo_rd_req	            (rd_fifo_rd_req		),
		.fifo_s_axi_rdata           (rd_fifo_rd_data	),
		.sdram_rd_ack				(sdram_rd_ack		),
		.sdram_rd_end				(sdram_rd_end		),
		// aw	
		. S_AXI_AWID				(axi_awid			),
		. S_AXI_AWADDR				(axi_waddr			),
		. S_AXI_AWLEN				(axi_awlen			),
		. S_AXI_AWSIZE				(axi_awsize			),
		. S_AXI_AWBURST				(axi_awburst		),
		. S_AXI_AWLOCK				(axi_awlock			),
		. S_AXI_AWCACHE				(axi_awcache		),
		. S_AXI_AWPROT				(axi_awprot			),
		. S_AXI_AWQOS				(axi_awqos			),
		. S_AXI_AWREGION			(axi_awregion		),
		. S_AXI_AWUSER				(axi_awuser			),
		. S_AXI_AWVALID				(axi_awvalid		),
		. S_AXI_AWREADY				(axi_awready		),
		// w	
		. S_AXI_WDATA				(axi_wdata			),
		. S_AXI_WSTRB				(axi_wstrb			),
		. S_AXI_WLAST				(axi_wlast			),
		. S_AXI_WUSER				(axi_wuser			),
		. S_AXI_WVALID				(axi_wvalid			),
		. S_AXI_WREADY				(axi_wready			),
		// b	
		. S_AXI_BID					(axi_bid			),
		. S_AXI_BRESP				(axi_bresp			),
		. S_AXI_BUSER				(axi_buser			),
		. S_AXI_BVALID				(axi_bvalid			),
		. S_AXI_BREADY				(axi_bready			),
		// ar	
		. S_AXI_ARID				(axi_arid			),
		. S_AXI_ARADDR				(axi_raddr			),
		. S_AXI_ARLEN				(axi_arlen			),
		. S_AXI_ARSIZE				(axi_arsize			),
		. S_AXI_ARBURST				(axi_arburst		),
		. S_AXI_ARLOCK				(axi_arlock			),
		. S_AXI_ARCACHE				(axi_arcache		),
		. S_AXI_ARPROT				(axi_arprot			),
		. S_AXI_ARQOS				(axi_arqos			),
		. S_AXI_ARREGION			(axi_arregion		),
		. S_AXI_ARUSER				(axi_aruser			),
		. S_AXI_ARVALID				(axi_arvalid		),
		. S_AXI_ARREADY				(axi_arready		),
		// r	
		. S_AXI_RID					(axi_rid			),
		. S_AXI_RDATA				(axi_rdata			),
		. S_AXI_RRESP				(axi_rresp			),
		. S_AXI_RLAST				(axi_rlast			),
		. S_AXI_RUSER				(axi_ruser			),
		. S_AXI_RVALID				(axi_rvalid			),
		. S_AXI_RREADY              (axi_rready			)
	);

	
	// axi master inst
	sdram_pro_axi_master #
	(
		.C_M_TARGET_SLAVE_BASE_ADDR	(23'h00000000		),
		.C_M_AXI_BURST_LEN			(16					),
		.C_M_AXI_ID_WIDTH			(1					),
		.C_M_AXI_ADDR_WIDTH			(23					),
		.C_M_AXI_DATA_WIDTH			(16					),
		.C_M_AXI_AWUSER_WIDTH		(0					),
		.C_M_AXI_ARUSER_WIDTH		(0					),
		.C_M_AXI_WUSER_WIDTH		(0					),
		.C_M_AXI_RUSER_WIDTH		(0					),
		.C_M_AXI_BUSER_WIDTH		(0					)
	)
	u_sdram_pro_axi_master
	(
		. WR_BURST_FLAG				(WR_BURST_FLAG		),
		. RD_BURST_FLAG				(RD_BURST_FLAG		),
		. i_write_burst_en			(i_write_burst_en	),
	    . i_read_burst_en			(i_read_burst_en	),
		. sdram_wr_end				(sdram_wr_end		),
		. sdram_rd_end				(sdram_rd_end		),
		. INIT_AXI_TXN				(init_end			),
		. TXN_DONE					(txn_done			),
		. ERROR						(error				),
		. M_AXI_ACLK				(sys_clk			),
		. M_AXI_ARESETN				(sys_rst_n			),
		// aw		
		. M_AXI_AWID				(axi_awid			),	
		. M_AXI_AWADDR				(axi_waddr			),
		. M_AXI_AWLEN				(axi_awlen			),
		. M_AXI_AWSIZE				(axi_awsize			),
		. M_AXI_AWBURST				(axi_awburst		),
		. M_AXI_AWLOCK				(axi_awlock			),
		. M_AXI_AWCACHE				(axi_awcache		),
		. M_AXI_AWPROT				(axi_awprot			),
		. M_AXI_AWQOS				(axi_awqos			),
		. M_AXI_AWUSER				(axi_awuser			),
		. M_AXI_AWVALID				(axi_awvalid		),
		. M_AXI_AWREADY				(axi_awready		),
		// w		
		. M_AXI_WDATA				(axi_wdata			),
		. M_AXI_WSTRB				(axi_wstrb			),
		. M_AXI_WLAST				(axi_wlast			),
		. M_AXI_WUSER				(axi_wuser			),
		. M_AXI_WVALID				(axi_wvalid			),
		. M_AXI_WREADY				(axi_wready			),
		// b		
		. M_AXI_BID					(axi_bid			),
		. M_AXI_BRESP				(axi_bresp			),
		. M_AXI_BUSER				(axi_buser			),
		. M_AXI_BVALID				(axi_bvalid			),
		. M_AXI_BREADY				(axi_bready			),
		// ar		
		. M_AXI_ARID				(axi_arid			),
		. M_AXI_ARADDR				(axi_raddr			),
		. M_AXI_ARLEN				(axi_arlen			),
		. M_AXI_ARSIZE				(axi_arsize			),
		. M_AXI_ARBURST				(axi_arburst		),
		. M_AXI_ARLOCK				(axi_arlock			),
		. M_AXI_ARCACHE				(axi_arcache		),
		. M_AXI_ARPROT				(axi_arprot			),
		. M_AXI_ARQOS				(axi_arqos			),
		. M_AXI_ARUSER				(axi_aruser			),
		. M_AXI_ARVALID				(axi_arvalid		),
		. M_AXI_ARREADY				(axi_arready		),
		// r		
		. M_AXI_RID					(axi_rid			),
		. M_AXI_RDATA				(axi_rdata			),
		. M_AXI_RRESP				(axi_rresp			),
		. M_AXI_RLAST				(axi_rlast			),
		. M_AXI_RUSER				(axi_ruser			),
		. M_AXI_RVALID				(axi_rvalid			),
		. M_AXI_RREADY              (axi_rready 		)
	);



































endmodule