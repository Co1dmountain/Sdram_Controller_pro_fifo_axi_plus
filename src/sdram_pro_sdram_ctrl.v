/**** 
		sdram顶层模块 
		对接fifo，产生读写请求、使能
****/
`include "defines.v"

module sdram_pro_sdram_ctrl(
		// 系统时钟、复位
		input					sys_clk					,
		input					sys_rst_n				,
		output					init_end				,
		// sdram写端口
		input		[15:0]		sdram_data_in			,
		input		[9:0]		WR_BURST_LEN			,
		input					sdram_wr_req			,
		input		[22:0]		sdram_wr_addr			, // 包括行地址、列地址、bank地址 9 + 12 + 2 = 23
		output  	            sdram_wr_ack    		, // 写SDRAM响应信号 ? 
		output					sdram_wr_end			, // sdram写模块到master的信号
		output					sdram_rd_end			,
		// sdram读端口
		input					sdram_rd_req			,
		input		[9:0]		RD_BURST_LEN			,
		input		[22:0]		sdram_rd_addr			, // 包括行地址、列地址、bank地址 9 + 12 + 2 = 23
		output		[15:0]		sdram_data_out			,
		output  	            sdram_rd_ack    		, // 读SDRAM响应信号 ? 
		// 物理接口
		output					sdram_cke				,
		output	reg	[3:0]		sdram_cmd				,
		output	reg	[1:0]		sdram_bank				,
		output	reg	[11:0]		sdram_addr				,
		inout		[15:0]		sdram_dq				
);
	
	//// define ////
	wire [3:0]  init_cmd;
	wire [11:0] init_addr;
	wire [1:0]  init_bank;
	//wire init_end;
	
	wire [3:0]  atref_cmd;
	wire [11:0] atref_addr;
	wire [1:0]  atref_bank;
	wire atref_req;
	wire atref_en;
	wire atref_end;
	
	
	wire [3:0]  wr_sdram_cmd;
	wire [11:0] wr_sdram_addr;
	wire [1:0]  wr_sdram_bank;
	wire [15:0]  wr_sdram_data;
	wire wr_end;
	wire wr_en;
	wire wr_data_valid;
	
	wire [3:0]  rd_sdram_cmd;
	wire [11:0] rd_sdram_addr;
	wire [1:0]  rd_sdram_bank;
	wire rd_end;
	wire rd_en;
	wire rd_data_valid;
	
	wire [2:0] cur_state;
	wire [2:0] next_state;
	
	//// main code //// 
	// sdram_dq 在写操作时需赋写数据
	assign sdram_dq = (wr_data_valid == 1'b1) ? wr_sdram_data : 16'bz;
	assign sdram_wr_end = wr_end; // sdram写模块到master的信号
	assign sdram_rd_end	= rd_end; // sdram读模块到slave的信号
	// sdram_addr, sdram_bank, sdram_cmd
	always @(*) begin
		if(cur_state == 'd3) begin
			sdram_addr = wr_sdram_addr;
			sdram_bank = wr_sdram_bank;
			sdram_cmd  = wr_sdram_cmd;
		end
		else if(cur_state == 'd4) begin
			sdram_addr = rd_sdram_addr;
			sdram_bank = rd_sdram_bank;
			sdram_cmd  = rd_sdram_cmd;
		end
		else if(cur_state == 'd0) begin
			sdram_addr = init_addr;
			sdram_bank = init_bank;
			sdram_cmd  = init_cmd;
		end
		else if(cur_state == 'd2) begin
			sdram_addr = atref_addr;
			sdram_bank = atref_bank;
			sdram_cmd  = atref_cmd;
		end
		else begin
			sdram_addr = 12'hfff;
			sdram_bank = 2'b11;
			sdram_cmd  = `NO_OPERATION;
		end
	end
	
	// 各种例化
	// sdram仲裁模块
	sdram_pro_arbit U_sdram_pro_arbit(
		.sys_clk		(sys_clk		),
		.sys_rst_n		(sys_rst_n		),
		.init_cmd       (init_cmd		),
		.init_end       (init_end		),
		.init_bank      (init_bank		),
		.init_addr 		(init_addr 		),	
		.atref_req      (atref_req    	),
		.atref_end      (atref_end    	),
	    .atref_cmd      (atref_cmd    	),
	    .atref_bank     (atref_bank   	),
	    .atref_addr     (atref_addr   	),
	    .wr_req         (sdram_wr_req   ),
	    .wr_bank		(wr_sdram_bank	),
	    .wr_end         (wr_end			),
	    .wr_cmd         (wr_sdram_cmd   ),
	    .wr_addr        (wr_sdram_addr  ),
	    //.wr_data_valid  (wr_data_valid 	),
	    //.wr_sdram_data  (sdram_data_in	), // 要写入的数据？
	    .rd_req         (sdram_rd_req   ),
	    .rd_end         (rd_end       	),
	    .rd_cmd         (rd_sdram_cmd   ),
	    .rd_addr        (rd_sdram_addr  ),
	    .rd_bank		(rd_sdram_bank	), 
	    .atref_en       (atref_en     	),
	    .wr_en          (wr_en        	),
	    .rd_en          (rd_en        	),
		.sdram_cke      (sdram_cke    	),
		.cur_state		(cur_state		),	
		.next_state		(next_state		)
		//.sdram_cmd      (sdram_cmd    	),
		//.sdram_bank     (sdram_bank   	),
		//.sdram_addr     (sdram_addr   	)
		//.sdram_dq       (sdram_dq     	)
	);
	// sdram初始化模块
	sdram_pro_init  U_sdram_pro_init(
		.sys_clk   		(sys_clk    	),
		.sys_rst_n 		(sys_rst_n  	),
		.init_cmd   	(init_cmd   	),
		.init_bank		(init_bank		),
		.init_addr  	(init_addr  	),
		.init_end   	(init_end   	)
	);

	// sdram自动刷新模块
	sdram_pro_autorefresh U_sdram_pro_autorefresh(
		.sys_clk		(sys_clk		),
		.sys_rst_n		(sys_rst_n		),
		.init_end		(init_end		),
		.atref_en		(atref_en   	),
		.atref_req		(atref_req		),
		.atref_addr		(atref_addr		),
		.atref_cmd		(atref_cmd		),
		.atref_bank		(atref_bank 	),
		.atref_end		(atref_end  	)
	);

	// sdram写数据模块
	sdram_pro_write U_sdram_pro_write(
	 
		.sys_clk        (sys_clk		),
		.sys_rst_n      (sys_rst_n      ),
		.init_end       (init_end       ),
		.wr_en          (wr_en          ),
	 
		.wr_addr        (sdram_wr_addr  ),
		.wr_data        (sdram_data_in  ),
		.wr_burst_len   (WR_BURST_LEN   ),
	 
		.wr_ack         (sdram_wr_ack   ),
		.wr_end         (wr_end         ),
		.wr_sdram_cmd	(wr_sdram_cmd	),
		.wr_sdram_bank	(wr_sdram_bank	),
		.wr_sdram_addr	(wr_sdram_addr	),
		.wr_sdram_en    (wr_data_valid  ),
		.wr_sdram_data  (wr_sdram_data  )
	 
	);

	// sdram读数据模块
	sdram_pro_read  U_sdram_pro_read(
		.sys_clk       	(sys_clk        ),
		.sys_rst_n     	(sys_rst_n      ),
		.init_end       (init_end       ),
		.rd_en          (rd_en          ),
		.rd_addr        (sdram_rd_addr	),
		.rd_sdram_data  (sdram_dq       ),
		.rd_burst_len   (WR_BURST_LEN   ),
		.rd_ack         (sdram_rd_ack   ),
		.rd_end         (rd_end         ),
		.rd_sdram_cmd	(rd_sdram_cmd	),
		.rd_sdram_bank	(rd_sdram_bank	),
		.rd_sdram_addr	(rd_sdram_addr	),
		.rd_data_valid	(rd_data_valid	),
		.rd_data_out	(sdram_data_out	)
	);
	















































endmodule