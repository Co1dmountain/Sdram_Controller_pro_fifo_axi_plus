/**** 
		读数据模块 
		根据sdram芯片手册提供的时序图使用状态机来实现
		页突发写 full page burst -> 突发长度最大只能写一行512个数据
****/
`include "defines.v"

module sdram_pro_read(
		// input
		input					sys_clk					,
		input					sys_rst_n				,
		input					init_end				, // ?
		//input					wr_end					, // ?
		input		[22:0]		rd_addr					, // 包括行地址、列地址、bank地址 9 + 12 + 2 = 23
		input		[7:0]		rd_burst_len			,
		input		[15:0]		rd_sdram_data			, // 从sdram读出的信号 
		// output
		output	reg				rd_data_valid			, // 拉高表示此时读出数据有效，可以被后续模块使用
		output					rd_ack					, // 与写模块一样，拉高表示此时正在读数据
		output	reg				rd_end					,
		output	reg	[15:0]		rd_data_out				,
		output	reg	[3:0]		rd_sdram_cmd			,
		output	reg	[11:0]		rd_sdram_addr			,
		output	reg	[1:0]		rd_sdram_bank			,
		// arbit
		input					rd_en					
);

	//// define ////
	// 状态机状态定义
	parameter RD_IDLE 			= 'd0;
	parameter RD_ACTIVE 		= 'd1;
	parameter RD_TRCD 			= 'd2;
	parameter RD_READ_CMD 		= 'd3;
	parameter RD_CAS_LATENCY 	= 'd4;
	parameter RD_READ_DATA 		= 'd5;
	parameter RD_TERMINATE 		= 'd6;
	parameter RD_PRECHARGE 		= 'd7;
	parameter RD_TRP 			= 'd8;
	parameter RD_END 			= 'd9;
	parameter RD_PLUS			= 'd10; // 在RD_READ_DATA和RD_TERMINATE间加一个冗余状态，以确保数据有效以及正确获取从SDRAM中读出的数据
	
	reg [3:0] cur_state, next_state;
	
	parameter	CNT_TRP			= 2; // SDRAM trp 18ns
	parameter	CNT_TRC			= 4; // SDRAM trc 58ns
	parameter	CNT_CAS_LATENCY	= 3; // cas latency = 3
	
	reg [1:0] cnt_trp;
	wire flag_trp;
	reg [1:0] cnt_trc;
	wire flag_trc;
	reg [1:0] cnt_cas_latency;
	wire flag_cas_latency;
	reg [9:0] cnt_burst;
	wire flag_burst_end;
	reg [9:0] cnt_plus;
	wire flag_plus_end;
	
	//// main code ////
	// flags
	assign flag_trc = (cnt_trc == CNT_TRC - 1'b1) ? 1'b1 : 1'b0;
	assign flag_trp = (cnt_trp == CNT_TRP - 1'b1) ? 1'b1 : 1'b0;
	assign flag_cas_latency = (cnt_cas_latency == CNT_CAS_LATENCY - 1'b1) ? 1'b1 : 1'b0;
	assign flag_burst_end = (cnt_burst == rd_burst_len - 'd4) ? 1'b1 : 1'b0;
	assign flag_plus_end = (cnt_plus == rd_burst_len - 1'b1) ? 1'b1 : 1'b0;
	
	// rd_ack
	assign rd_ack = rd_data_valid;
	
	// cnts
	// cnt_trc
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trc <= 'd0;
		end
		else if(cur_state == RD_TRCD) begin
			cnt_trc <= cnt_trc + 1'b1;
		end
		else begin
			cnt_trc <= 'd0;
		end
	end
	
	// cnt_trp
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trp <= 'd0;
		end
		else if(cur_state == RD_TRP) begin
			cnt_trp <= cnt_trp + 1'b1;
		end
		else begin
			cnt_trp <= 'd0;
		end
	end
	
	// cnt_cas_latency
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_cas_latency <= 'd0;
		end
		else if(cur_state == RD_CAS_LATENCY) begin
			cnt_cas_latency <= cnt_cas_latency + 1'b1;
		end
		else begin
			cnt_cas_latency <= 'd0;
		end
	end
	
	// cnt_burst
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_burst <= 'd0;
		end
		else if(cur_state == RD_READ_DATA) begin
			cnt_burst <= cnt_burst + 1'b1;
		end
		else begin
			cnt_burst <= 'd0;
		end
	end
	
	// cnt_plus
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_plus <= 'd0;
		end
		else if(cur_state == RD_READ_DATA || cur_state == RD_PLUS) begin
			cnt_plus <= cnt_plus + 1'b1;
		end
		else begin
			cnt_plus <= 'd0;
		end
	end
	
	// 状态机
	// 三段式状态机-第一段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cur_state <= RD_IDLE;
		end	
		else begin
			cur_state <= next_state;
		end
	end
	
	// 三段式状态机-第二段
	always @(*) begin
		case(cur_state) 
			RD_IDLE : begin
				if(rd_en) begin
					next_state = RD_ACTIVE;
				end
				else begin
					next_state = RD_IDLE;
				end
			end
			RD_ACTIVE : begin
				next_state = RD_TRCD;
			end
			RD_TRCD : begin
				if(flag_trc) begin
					next_state = RD_READ_CMD;
				end
				else begin
					next_state = RD_TRCD;
				end
			end
			RD_READ_CMD : begin // CAS Latency = 3
				next_state = RD_CAS_LATENCY;
			end
			RD_CAS_LATENCY : begin // CAS Latency = 3
				if(flag_cas_latency) begin
					next_state = RD_READ_DATA;
				end
				else begin
					next_state = RD_CAS_LATENCY;
				end
			end
			RD_READ_DATA : begin
				if(flag_burst_end) begin
					next_state = RD_PLUS;
				end
				else begin
					next_state = RD_READ_DATA;
				end
			end
			RD_PLUS : begin
				if(flag_plus_end) begin
					next_state = RD_TERMINATE;
				end
				else begin
					next_state = RD_PLUS;
				end
			end
			RD_TERMINATE : begin
				next_state = RD_PRECHARGE;
			end
			RD_PRECHARGE : begin
				next_state = RD_TRP;
			end
			RD_TRP : begin
				if(flag_trp) begin
					next_state = RD_END;
				end
				else begin
					next_state = RD_TRP;
				end
			end
			RD_END : begin // 需要保持在END状态
				if(rd_en) begin
					next_state = RD_IDLE;
				end
				else begin
					next_state = RD_END;
				end
			end
			default : begin
				next_state = RD_IDLE;
			end
		endcase
	end
	
	// 三段式状态机-第三段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			rd_sdram_cmd  <= `NO_OPERATION;
			rd_sdram_addr <= 12'hfff;
			rd_sdram_bank <= 2'b11;
			rd_end        <= 1'b0;
			rd_data_out   <= 16'dz;
			rd_data_valid <= 1'b0;
		end
		else begin
			case(cur_state) 
				RD_IDLE : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
				end
				RD_ACTIVE : begin
					rd_sdram_cmd  <= `ACTIVE;
					rd_sdram_addr <= rd_addr[20:9];
					rd_sdram_bank <= rd_addr[22:21];
					rd_end        <= 1'b0;
				end
				RD_TRCD : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
				end
				RD_READ_CMD : begin
					rd_sdram_cmd  <= `READ;
					rd_sdram_addr <= {3'd0, rd_addr[8:0]};
					rd_sdram_bank <= rd_addr[22:21];
					rd_end        <= 1'b0;
				end
				RD_CAS_LATENCY : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
				end
				RD_READ_DATA : begin
					if(cnt_burst == rd_burst_len - 'd4) begin
						rd_sdram_cmd	<= `BURST_TERMINATE;
						rd_sdram_addr	<= 12'hfff;
						rd_sdram_bank	<= 2'b11;
						rd_end			<= 1'b0;
						rd_data_out     <= rd_sdram_data;
						rd_data_valid   <= 1'b1; // 数据有效
					end
					else begin
						rd_sdram_cmd	<= `NO_OPERATION;
						rd_sdram_addr   <= 12'hfff;
						rd_sdram_bank   <= 2'b11;
						rd_end          <= 1'b0;
						rd_data_out     <= rd_sdram_data;
						rd_data_valid   <= 1'b1; // 数据有效
					end
				end
				RD_PLUS : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
					rd_data_out   <= rd_sdram_data;
					rd_data_valid <= 1'b1; // 数据有效
				end
				RD_TERMINATE : begin
					rd_sdram_cmd  <= `BURST_TERMINATE;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
					rd_data_out   <= 16'dz;
					rd_data_valid <= 1'b0; // 数据无效
				end
				RD_PRECHARGE : begin
					rd_sdram_cmd  <= `PRECHARGE;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= rd_addr[22:21];
					rd_end        <= 1'b0;
				end
				RD_TRP : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b1;
				end
				RD_END : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b1;
				end
				default : begin
					rd_sdram_cmd  <= `NO_OPERATION;
					rd_sdram_addr <= 12'hfff;
					rd_sdram_bank <= 2'b11;
					rd_end        <= 1'b0;
				end
			endcase
		end
	end






































endmodule