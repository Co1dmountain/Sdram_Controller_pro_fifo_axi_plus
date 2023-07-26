/**** 
		初始化模块 
		根据sdram芯片手册提供的时序图使用状态机来实现
		刷新模块需要定时产生一个刷新请求信号 64ms刷新4096次，每15625ns刷新一次 (取15us)
		每次需要刷新是需要先进行一次precharge
****/
`include "defines.v"

module sdram_pro_autorefresh(
		// input
		input					sys_clk					,
		input					sys_rst_n				,
		input					init_end				,  // ? 是否需要这个信号？ 感觉可以放到top模块中
														   // 需要这个信号，初始化完成之后刷新计数器才能开始工作，每15625ns产生一次刷新请求
		// output
		output	reg	[ 3:0]		atref_cmd				,
		output	reg	[ 1:0]		atref_bank				,
		output	reg [11:0]		atref_addr				,
		output	reg				atref_end				,
		// arbit
		input					atref_en				,
		output	reg				atref_req
);

	//// define ////
	// 状态机状态定义
	parameter ATREF_IDLE		= 3'd0; 
	parameter ATREF_PRECHARGE	= 3'd1;
	parameter ATREF_ATREF 		= 3'd2;
	parameter ATREF_END 		= 3'd3;
	
	parameter CNT_15US			= 750;
	parameter CNT_TRP			= 2; // SDRAM trp 18ns
	parameter CNT_TRC			= 4; // SDRAM trc 58ns
	
	reg [2:0] cur_state, next_state;
	
	reg [9:0] cnt_15us;
	wire flag_cnt_15us;
	reg [1:0] cnt_trp;
	wire flag_trp;
	reg [1:0] cnt_trc;
	wire flag_trc;
	
	//// main code ////
	// flags
	assign flag_cnt_15us = (cnt_15us == CNT_15US - 1'b1) ? 1'b1 : 1'b0;
	assign flag_trp = (cnt_trp == CNT_TRP - 1'b1) ? 1'b1 : 1'b0;
	assign flag_trc = (cnt_trc == CNT_TRC - 1'b1) ? 1'b1 : 1'b0;
	// cnts
	// cnt_15us
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_15us <= 'd0;
		end
		else if(init_end) begin
			if(cnt_15us == CNT_15US - 1'b1) begin
				cnt_15us <= 'd0;
			end
			else begin
				cnt_15us <= cnt_15us + 1'b1;
			end
		end
	end
	// cnt_trp
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trp <= 'd0;
		end
		else if(cur_state == ATREF_PRECHARGE) begin
			cnt_trp <= cnt_trp + 1'b1;
		end
		else begin
			cnt_trp <= 'd0;
		end
	end
	// cnt_trc  感觉不需要trc，只刷新一次
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trc <= 'd0;
		end
		else if(cur_state == ATREF_END) begin
			cnt_trc <= cnt_trc + 1'b1;
		end
		else begin
			cnt_trc <= 'd0;
		end
	end
	
	
	// atref_req
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			atref_req <= 1'b0;
		end
		else if(flag_cnt_15us) begin  // 时间到，需要刷新，拉高请求信号
			atref_req <= 1'b1;
		end
		else if(atref_end) begin  // 刷新完成，拉低请求信号
			atref_req <= 1'b0;
		end
		else begin
			atref_req <= atref_req;
		end
	end

	// 三段式状态机-第一段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cur_state <= ATREF_IDLE;
		end
		else begin
			cur_state <= next_state;
		end
	end

	// 三段式状态机-第二段
	always @(*) begin
		case(cur_state)
			ATREF_IDLE : begin
				if(atref_en) begin  // 收到arbit的刷新使能
					next_state = ATREF_PRECHARGE;
				end
				else begin
					next_state = ATREF_IDLE;
				end
			end
			ATREF_PRECHARGE : begin
				if(flag_trp) begin
					next_state = ATREF_ATREF;
				end
				else begin
					next_state = ATREF_PRECHARGE;
				end
			end
			ATREF_ATREF : begin
				next_state = ATREF_END;
			end
			ATREF_END : begin
				if(flag_trc) begin
					next_state = ATREF_IDLE;
				end
				else begin
					next_state = ATREF_END;
				end
			end
			default : begin
				next_state = ATREF_IDLE;
			end
		endcase
	end

	// 三段式状态机-第三段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			atref_cmd	<= `NO_OPERATION;
			atref_bank	<= 2'b11;
			atref_addr	<= 12'hfff;
			atref_end	<= 1'b0;
		end
		else begin
			case(cur_state)
				ATREF_IDLE : begin
					atref_cmd	<= `NO_OPERATION;
					atref_bank	<= 2'b11;
					atref_addr	<= 12'hfff;
					atref_end	<= 1'b0;
				end
				ATREF_PRECHARGE : begin
					atref_cmd	<= `PRECHARGE;
					atref_bank	<= 2'b11;
					atref_addr	<= 12'hfff;
					atref_end	<= 1'b0;
				end
				ATREF_ATREF : begin
					atref_cmd	<= `AUTO_REFRESH;
					atref_bank	<= 2'b11;
					atref_addr	<= 12'hfff;
					atref_end	<= 1'b0;
				end
				ATREF_END : begin
					atref_cmd	<= `NO_OPERATION;
					atref_bank	<= 2'b11;
					atref_addr	<= 12'hfff;
					atref_end	<= 1'b1;
				end
				default : begin
					atref_cmd	<= `NO_OPERATION;
					atref_bank	<= 2'b11;
					atref_addr	<= 12'hfff;
					atref_end	<= 1'b0;
				end
			endcase
		end
	end


















































endmodule