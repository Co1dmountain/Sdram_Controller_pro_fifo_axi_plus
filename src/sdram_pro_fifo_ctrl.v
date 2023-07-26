/**** 
		fifo控制模块 
		将写入和读出的数据经过fifo再给到sdram
****/
`include "defines.v"

module sdram_pro_fifo_ctrl(
		input					sys_clk					,
		input					sys_rst_n				,
		// 写数据操作相关信号
		//input					wr_fifo_wr_clk
		
		input	[15:0]			wr_fifo_wr_data			, // 写fifo写数据 外部输入   外部->写fifo
		input					wr_fifo_wr_req			, // 写fifo写请求
		input	[22:0]			sdram_wr_b_addr			, // sdram写起始地址
		input	[22:0]			sdram_wr_e_addr			, // sdram写结束地址
		input	[7:0]			wr_burst_len			, // 写突发长度
		output	[9:0]			wr_fifo_num				, // 写fifo数据个数
		input					sdram_wr_end			,
		// 读数据操作相关信号
		output	[15:0]			rd_fifo_rd_data			, // 读fifo读数据            读fifo->外部
		input					rd_fifo_rd_req			, // 读fifo读请求
		input	[22:0]			sdram_rd_b_addr			, // sdram读起始地址
		input	[22:0]			sdram_rd_e_addr			, // sdram读结束地址
		input	[7:0]			rd_burst_len			, // 读突发长度
		output	[9:0]			rd_fifo_num				, // 读fifo数据个数
		input   	            read_valid      		,   //SDRAM读使能
		input   	            init_end        		,   //SDRAM初始化完成标志
		input					sdram_rd_end			,
		// sdram写数据相关信号
		output	[15:0]			sdram_in_data			, // wr_fifo到sdram的数据    写fifo->sdram
		output	reg				sdram_wr_req			, // sdram写请求
		input					sdram_wr_ack			, // sdram写响应
		output	reg [22:0]			sdram_wr_addr			, // sdram写地址
		// sdram读数据相关信号
		input	[15:0]			sdram_out_data			, // sdram到rd_fifo的数据    sdram->读fifo
		output	reg				sdram_rd_req			, // sdram读请求
		input					sdram_rd_ack			, // sdram读响应
		output	reg [22:0]			sdram_rd_addr			  // sdram读地址
		
		
);

	//// define ////
	reg [15:0] reg_rd_fifo_rd_data; 
	reg [15:0] reg_sdram_in_data;
	reg [15:0] reg_sdram_out_data;
	reg [22:0] reg_sdram_wr_addr;

	//// main code ////
	//wire define
	wire	sdram_wr_ack_fall ;   //写响应信号下降沿
	wire	sdram_rd_ack_fall ;   //读响应信号下降沿
	wire 	sdram_wr_req_neg  ;   //sdram_wr_req下降沿脉冲
	//reg define
	reg		sdram_wr_ack_d1	;     //写响应打1拍
	reg		sdram_wr_ack_d2	;     //写响应打2拍
	reg		sdram_rd_ack_d1	;     //读响应打1拍
	reg		sdram_rd_ack_d2	;     //读响应打2拍
	// 获取sdram_wr_req下降沿
	reg sdram_wr_req_r1;
	reg sdram_wr_req_r2;
	// 表示一次写完成
	//reg sdram_wr_end;
	 
	//********************************************************************//
	//***************************** Main Code ****************************//
	//********************************************************************//
	 
	//wr_ack_dly:写响应信号打拍,采集下降沿
	always@(posedge sys_clk or negedge sys_rst_n)begin
		if(!sys_rst_n)begin
			sdram_wr_ack_d1 <=  1'b0;
			sdram_wr_ack_d2 <=  1'b0;	
		end
		else begin
			sdram_wr_ack_d1 <=  sdram_wr_ack;
			sdram_wr_ack_d2 <=  sdram_wr_ack_d1;	
		end
	end
	 
	//rd_ack_dly:读响应信号打拍,采集下降沿
	always@(posedge sys_clk or negedge sys_rst_n)begin
		if(!sys_rst_n)begin
			sdram_rd_ack_d1 <=  1'b0;
			sdram_rd_ack_d2 <=  1'b0;	
		end
		else begin
			sdram_rd_ack_d1 <=  sdram_rd_ack;
			sdram_rd_ack_d2 <=  sdram_rd_ack_d1;	
		end
	end
	 
	//sdram_wr_ack_fall,sdram_rd_ack_fall:检测读写响应信号下降沿
	assign  sdram_wr_ack_fall = (sdram_wr_ack_d2 & ~sdram_wr_ack_d1);
	assign  sdram_rd_ack_fall = (sdram_rd_ack_d2 & ~sdram_rd_ack_d1);
	 
	//sdram_wr_addr:sdram写地址
	always@(posedge sys_clk or negedge sys_rst_n)begin
		if(!sys_rst_n)
			sdram_wr_addr <= sdram_wr_b_addr;							//复位fifo则地址为初始地址
		else if(sdram_wr_ack_fall) 										//一次突发写结束,更改写地址
			begin
				if(sdram_wr_addr < (sdram_wr_e_addr - wr_burst_len))                       
					sdram_wr_addr   <=  sdram_wr_addr + wr_burst_len;	//未达到末地址,写地址累加
				else        
					sdram_wr_addr   <=  sdram_wr_b_addr;				//到达末地址,回到写起始地址
			end
	end		
	//sdram_rd_addr:sdram读地址
	always@(posedge sys_clk or negedge sys_rst_n)begin
		if(!sys_rst_n)
			sdram_rd_addr   <=  sdram_rd_b_addr;
		else if(sdram_rd_ack_fall) 										//一次突发读结束,更改读地址
			begin
				if(sdram_rd_addr < (sdram_rd_e_addr - rd_burst_len))                    
					sdram_rd_addr   <=  sdram_rd_addr + rd_burst_len;	//读地址未达到末地址,读地址累加
				else    
					sdram_rd_addr   <=  sdram_rd_b_addr;				//到达末地址,回到首地址
			end
	end
	 
	//sdram_wr_req,sdram_rd_req:读写请求信号 - 传到arbit模块
	always@(posedge sys_clk or negedge sys_rst_n)begin
		if(!sys_rst_n)
			begin
				sdram_wr_req <= 1'b0;
				sdram_rd_req <= 1'b0;
			end
		else if(init_end)   							//初始化完成后响应读写请求
			begin   									//优先执行写操作，防止写入SDRAM中的数据丢失
				//if(wr_fifo_num >= wr_burst_len)begin   	//写FIFO中的数据量达到写突发长度
				//if(wr_fifo_num >= wr_burst_len && wr_fifo_num <= 2*wr_burst_len)begin   	//写FIFO中的数据量达到写突发长度
				if(wr_fifo_num >= 'd1) begin
					sdram_wr_req <=  1'b1;   			//写请求有效
					sdram_rd_req <=  1'b0;
				end
				//else if((rd_fifo_num < rd_burst_len) && (read_valid))begin //读FIFO中的数据量小于读突发长度,且读使能信号有效
				//else if((rd_fifo_num < rd_burst_len) && wr_fifo_num == 'd0 && read_valid)begin //读FIFO中的数据量小于读突发长度,且读使能信号有效
				else if((rd_fifo_num < rd_burst_len) && sdram_wr_end == 1'b1)begin //读FIFO中的数据量小于读突发长度,且读使能信号有效
					sdram_wr_req <=  1'b0;
					sdram_rd_req <=  1'b1;   			//读请求有效
				end
				//// 23.7.25 add ////
				/* else if((rd_fifo_num >= rd_burst_len))begin //读FIFO中的数据量小于读突发长度,且读使能信号有效
					sdram_wr_req <=  1'b1;
					sdram_rd_req <=  1'b0;   			//读请求有效
				end */
				else begin
					sdram_wr_req <=  1'b0;
					sdram_rd_req <= 1'b0;
				end
			end
		else begin
			sdram_wr_req <= 1'b0;
			sdram_rd_req <= 1'b0;
		end
	end

	
	// 产生 sdram_wr_end 来切换 sdram 读写操作
	// assign sdram_wr_req_neg = ~sdram_wr_req_r1 & sdram_wr_req_r2;
	// always@(posedge sys_clk or negedge sys_rst_n) begin
		// if(!sys_rst_n) begin
			// sdram_wr_req_r1 <= 1'b0;
			// sdram_wr_req_r2 <= 1'b0;
		// end
		// else begin
			// sdram_wr_req_r1 <= sdram_wr_req;
			// sdram_wr_req_r2 <= sdram_wr_req_r1;
		// end
	// end
	// always@(posedge sys_clk or negedge sys_rst_n) begin
		// if(!sys_rst_n) begin
			// sdram_wr_end <= 1'b0;
		// end
		// else if(sdram_wr_req_neg) begin
			// sdram_wr_end <= 1'b1;
		// end
	// end

















	//// fifo_inst ////
	write_fifo	write_fifo_inst (
	.aclr 				( !sys_rst_n 			),
	.data 				( wr_fifo_wr_data 		),
	.rdclk 				( sys_clk 				),
	.rdreq 				( sdram_wr_ack 			), // 写fifo的读请求信号？ 当可以开始写sdram后就需要wr_fifo往外读数据
	.wrclk 				( sys_clk 				),
	.wrreq 				( wr_fifo_wr_req 		),
	.q 					( sdram_in_data 		),
	.rdempty 			(  						),
	.rdusedw 			( wr_fifo_num 			),
	.wrfull 			(  						),
	.wrusedw 			(  						)
	);

	read_fifo	read_fifo_inst (
	.aclr 				( !sys_rst_n 			),
	.data 				( sdram_out_data 		),
	.rdclk 				( sys_clk 				),
	.rdreq 				( rd_fifo_rd_req 		), 
	.wrclk 				( sys_clk 				),
	.wrreq 				( sdram_rd_ack 			),   // 读fifo的写请求信号？ 从sdram读出数据后就要将数据写进rd_fifo
	.q 					( rd_fifo_rd_data 		),
	.rdempty 			(  						),
	.rdusedw 			( 			 			),
	.wrfull 			( 						),
	.wrusedw 			( rd_fifo_num			)
	);







endmodule


