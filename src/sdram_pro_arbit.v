/**** 
		仲裁模块 
		进行自动刷新、写、读调度
****/
`include "defines.v"

module sdram_pro_arbit(
		// input
		input					sys_clk					,
		input					sys_rst_n				,
		//sdram_init	
		input   wire    [3:0]   init_cmd    			,   //初始化阶段命令
		input   wire            init_end    			,   //初始化结束标志
		input   wire    [1:0]   init_bank				,   //初始化阶段Bank地址
		input   wire    [11:0]  init_addr   			,   //初始化阶段数据地址
		//sdram_auto_ref			
		input   wire            atref_req				,   //自刷新请求
		input   wire            atref_end				,   //自刷新结束
		input   wire    [3:0]   atref_cmd				,   //自刷新阶段命令
		input   wire    [1:0]   atref_bank				,   //自动刷新阶段Bank地址
		input   wire    [11:0]  atref_addr				,   //自刷新阶段数据地址
		//sdram_write		
		input   wire            wr_req     				,   //写数据请求
		input   wire    [1:0]   wr_bank					,   //写阶段Bank地址
		input   wire            wr_end     				,   //一次写结束信号
		input   wire    [3:0]   wr_cmd     				,   //写阶段命令
		input   wire    [11:0]  wr_addr    				,   //写阶段数据地址
		//input   wire			wr_data_valid			,   //写数据有效
		//input   wire    [15:0]  wr_sdram_data			,   //要写入sdram的数据
		//sdram_read		
		input   wire            rd_req      			,   //读数据请求
		input   wire            rd_end      			,   //一次读结束
		input   wire    [3:0]   rd_cmd      			,   //读阶段命令
		input   wire    [11:0]  rd_addr     			,   //读阶段数据地址
		input   wire    [1:0]   rd_bank					,   //读阶段Bank地址
				
		// output			
		output  reg             atref_en    			,   //自刷新使能
		output  reg             wr_en       			,   //写数据使能
		output  reg             rd_en       			,   //读数据使能	
		//sdram接口			
		output  wire            sdram_cke   			,   //SDRAM时钟使能
		// output  wire            sdram_cs_n  			,   //SDRAM片选信号
		// output  wire            sdram_ras_n 			,   //SDRAM行地址选通
		// output  wire            sdram_cas_n 			,   //SDRAM列地址选通
		// output  wire            sdram_we_n  			,   //SDRAM写使能
		//output	reg		[3:0]	sdram_cmd				,	//SDRAM合在一起
		//output  reg     [1:0]   sdram_bank				,   //SDRAM Bank地址
		//output  reg     [11:0]  sdram_addr  			    //SDRAM地址总线
		//inout   wire    [15:0]  sdram_dq    			    //SDRAM数据总线
		output	reg		[2:0]	cur_state				,
		output	reg		[2:0]	next_state				

);

	//// define ////
	// 状态机状态定义
	parameter INIT 			= 3'd0;
	parameter ARBIT 		= 3'd1;
	parameter AUTO_REFRESH 	= 3'd2;
	parameter WRITE 		= 3'd3;
	parameter READ 			= 3'd4;
	
	// reg [2:0] cur_state, next_state;
	
	
	//// main code ////
	//wr_sdram_data:写入 SDRAM 的数据
	//assign sdram_dq = (wr_data_valid == 1'b1) ? wr_sdram_data : 16'bz;
	//片选信号,行地址选通信号,列地址选通信号,写使能信号
	//assign  {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = sdram_cmd;

	// sdram_cke
	assign sdram_cke = 1'b1;

	// 三段式状态机
	// 三段式状态机-第一段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cur_state <= INIT;
		end
		else begin
			cur_state <= next_state;
		end
	end
	
	// 三段式状态机-第二段
	always @(*) begin
		case(cur_state)
			INIT :begin
				if(init_end) begin
					next_state = ARBIT;
				end
				else begin
					next_state = INIT;
				end
			end
			//////////////////////////////////// important //////////////////////////////////////
			ARBIT : begin // 仲裁状态-主要控制逻辑，按照自己思路写，把突发长度控制一下，不要太长
				if((atref_req && wr_end) || (atref_req && rd_end) || (atref_req && !wr_req && !rd_req)) begin // 注意atref_req信号在其模块内需要拉高的时间以及拉低的条件
					next_state = AUTO_REFRESH;
				end
				else if(wr_req && !atref_req) begin
					next_state = WRITE;
				end
				else if(rd_req && !atref_req) begin
					next_state = READ;
				end
				else begin
					next_state = ARBIT;
				end
			end
			////////////////////////////////////////////////////////////////////////////////////
			AUTO_REFRESH : begin
				if(atref_end) begin
					next_state = ARBIT;
				end
				else begin
					next_state = AUTO_REFRESH;
				end
			end	
			WRITE : begin
				if(wr_end) begin
					next_state = ARBIT;
				end
				else begin
					next_state = WRITE;
				end
			end
			READ : begin
				if(rd_end) begin
					next_state = ARBIT;
				end
				else begin
					next_state = READ;
				end
			end
			default : begin
				next_state = ARBIT;
			end
		endcase
	end

	// 三段式状态机-第三段 -- 输出各模块en信号
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			atref_en   <= 1'b0;
			wr_en      <= 1'b0;
			rd_en      <= 1'b0;
		end
		else begin
			case(cur_state)
				INIT : begin
					atref_en <= 1'b0;
					wr_en    <= 1'b0;
					rd_en    <= 1'b0;
				end
				ARBIT : begin
					atref_en <= 1'b0;
					wr_en    <= 1'b0;
					rd_en    <= 1'b0;
				end
				AUTO_REFRESH : begin
					atref_en <= 1'b1;
					wr_en    <= 1'b0;
					rd_en    <= 1'b0;
				end
				WRITE : begin
					atref_en <= 1'b0;
					wr_en    <= 1'b1;
					rd_en    <= 1'b0;					
				end
				READ : begin
					atref_en <= 1'b0;
					wr_en    <= 1'b0;
					rd_en    <= 1'b1;	
				end
				default : begin
					atref_en <= 1'b0;
					wr_en    <= 1'b0;
					rd_en    <= 1'b0;
				end
			endcase
		end
	end









































endmodule