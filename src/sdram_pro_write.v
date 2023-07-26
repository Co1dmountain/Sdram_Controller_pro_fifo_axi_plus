/**** 
		写数据模块 
		根据sdram芯片手册提供的时序图使用状态机来实现
		页突发写 full page burst -> 突发长度最大只能写一行512个数据
****/
`include "defines.v"

module sdram_pro_write(
		// input
		input					sys_clk						,
		input					sys_rst_n					,
		input		[7:0]		wr_burst_len				, // 突发长度
		input		[15:0]		wr_data						, // 写数据，从fifo来的数据，要写入sdram
		input		[22:0]		wr_addr						, // 包括9位行地址，11位列地址，2位bank地址
		input					init_end					, // 初始化完成信号，所有操作需要在初始化完成之后进行
		// output
		output	reg	[3:0]		wr_sdram_cmd				,
		output	reg	[11:0]		wr_sdram_addr				,
		output	reg	[1:0]		wr_sdram_bank				,
		output	reg				wr_end						,
		output					wr_ack						, // 写操作响应信号，表示该模块对SDRAM进行了写操作（因为写操作的数据来源是FIFO，所以该信号可以作为FIFO的读使能，所以要提前一个时钟周期）
		// output 输出给sdram的数据
		output		[15:0]		wr_sdram_data				, // 要写入sdram的数据
		output	reg				wr_sdram_en					, // 数据总线输出使能,用于后续仲裁模块输出
		// arbit
		input					wr_en						  // 写使能信号

);

	//// define ////
	// 状态机状态定义
	parameter WR_IDLE 			= 'd0;
	parameter WR_ACTIVE 		= 'd1;
	parameter WR_TRCD 			= 'd2;
	parameter WR_WRITE_BEGIN 	= 'd3; // 这个状态发送写命令、写地址以及第一个数据
	parameter WR_WRITE_DATA 	= 'd4; // 这个状态发送剩下的数据
	parameter WR_TERMINATE 		= 'd5; // 突发写终止
	parameter WR_PRECHARGE 		= 'd6; // 
	parameter WR_TRP 			= 'd7; // 
	parameter WR_END 			= 'd8; // 
	
	parameter	CNT_TRP			= 2; // SDRAM trp 18ns
	parameter	CNT_TRC			= 4; // SDRAM trc 58ns
	
	reg [3:0] cur_state, next_state;

	
	reg [1:0] cnt_trp;
	wire flag_trp;
	reg [1:0] cnt_trc;
	wire flag_trc;
	reg [9:0] cnt_burst;
	wire flag_burst_end;
	wire flag_ack;
	
	//// main code ////
	// wr_ack
	//assign wr_ack = flag_ack;
	assign wr_ack = (cnt_burst <= wr_burst_len - 'd2) && 
						(cur_state == WR_WRITE_DATA || cur_state == WR_WRITE_BEGIN) 
						? 1'b1 : 1'b0;
	// wr_sdram_data
	assign wr_sdram_data = flag_ack ? wr_data : 16'd999;
	// wr_sdram_en
	// assign wr_sdram_en = wr_ack;
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			wr_sdram_en <= 1'b0;
		end
		else begin
			wr_sdram_en <= wr_ack;
		end
	end
	// flags
	assign flag_trc = (cnt_trc == CNT_TRC - 1'b1) ? 1'b1 : 1'b0;
	assign flag_trp = (cnt_trp == CNT_TRP - 1'b1) ? 1'b1 : 1'b0;
	assign flag_burst_end = (cnt_burst == wr_burst_len - 'd1) ? 1'b1 : 1'b0;
	assign flag_ack = (cnt_burst <= wr_burst_len - 'd1) && 
						(cur_state == WR_WRITE_DATA || cur_state == WR_WRITE_BEGIN) 
						? 1'b1 : 1'b0;
	
	// cnts
	// cnt_trc
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trc <= 'd0;
		end
		else if(cur_state == WR_TRCD) begin
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
		else if(cur_state == WR_TRP) begin
			cnt_trp <= cnt_trp + 1'b1;
		end
		else begin
			cnt_trp <= 'd0;
		end
	end
	
	// cnt_burst
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_burst <= 'd0;
		end
		//else if(cur_state == WR_WRITE_BEGIN || cur_state == WR_WRITE_DATA) begin
		else if(cur_state == WR_WRITE_DATA) begin
			cnt_burst <= cnt_burst + 1'b1;
		end
		else begin
			cnt_burst <= 'd0;
		end
	end
	
	// 三段式状态机-第一段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cur_state <= WR_IDLE;
		end
		else begin
			cur_state <= next_state;
		end
	end

	// 三段式状态机-第二段
	always @(*) begin
		case(cur_state)
			WR_IDLE : begin
				if(init_end && wr_en) begin	// 初始化完成且写使能有效
					next_state = WR_ACTIVE;
				end
				else begin
					next_state = WR_IDLE;
				end
			end
			WR_ACTIVE : begin
				next_state = WR_TRCD;
			end
			WR_TRCD : begin // 需要trcd计数器，即需要间隔Trc进入下一状态
				if(flag_trc) begin
					next_state = WR_WRITE_BEGIN;
				end
				else begin
					next_state = WR_TRCD;
				end
			end
			WR_WRITE_BEGIN : begin // 写命令、写地址以及第一个数据
				next_state = WR_WRITE_DATA;
			end
			WR_WRITE_DATA : begin // 写剩余数据
				if(flag_burst_end) begin
					next_state = WR_TERMINATE;
				end
				else begin
					next_state = WR_WRITE_DATA;
				end
			end
			WR_TERMINATE : begin
				next_state = WR_PRECHARGE;
			end
			WR_PRECHARGE : begin // 写完数据之后进行预充电
				next_state = WR_TRP;
			end
			WR_TRP : begin
				if(flag_trp) begin
					next_state = WR_END;
				end
				else begin
					next_state = WR_TRP;
				end
			end
			WR_END : begin
				if(wr_en) begin
					next_state = WR_IDLE;
				end
				else begin
					next_state = WR_END;
				end
			end
			default : begin
				next_state = WR_IDLE;
			end
		endcase
	end

	// 三段式状态机-第三段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			wr_sdram_cmd	<= `NO_OPERATION;
			wr_sdram_addr	<= 12'hfff;
			wr_sdram_bank	<= 2'b11;
			wr_end			<= 1'b0;
		end
		else begin
			case(cur_state) 
				WR_IDLE : begin
					wr_sdram_cmd	<= `PRECHARGE;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b0;
				end
				WR_ACTIVE : begin
					wr_sdram_cmd	<= `ACTIVE;
					wr_sdram_addr	<= wr_addr[20:9];
					wr_sdram_bank	<= wr_addr[22:21];
					wr_end			<= 1'b0;
				end
				WR_TRCD : begin
					wr_sdram_cmd	<= `NO_OPERATION;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b0;
				end
				WR_WRITE_BEGIN : begin
					wr_sdram_cmd	<= `WRITE;
					wr_sdram_addr	<= {3'd0, wr_addr[8:0]};
					wr_sdram_bank	<= wr_addr[22:21];
					wr_end			<= 1'b0;
				end
				WR_WRITE_DATA : begin
					if(cnt_burst == wr_burst_len - 'd1) begin
						wr_sdram_cmd	<= `BURST_TERMINATE;
						wr_sdram_addr	<= 12'hfff;
						wr_sdram_bank	<= 2'b11;
						wr_end			<= 1'b0;
					end
					else begin
						wr_sdram_cmd	<= `NO_OPERATION;
						wr_sdram_addr	<= 12'hfff;
						wr_sdram_bank	<= 2'b11;
						wr_end			<= 1'b0;
					end
				end
				WR_TERMINATE : begin
					wr_sdram_cmd	<= `BURST_TERMINATE;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b0;
				end
				WR_PRECHARGE : begin
					wr_sdram_cmd	<= `PRECHARGE;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= wr_addr[22:21];
					wr_end			<= 1'b0;
				end
				WR_TRP : begin
					wr_sdram_cmd	<= `NO_OPERATION;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b1;  // 提前拉高wr_end
				end
				WR_END : begin
					wr_sdram_cmd	<= `NO_OPERATION;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b1;
				end
				default : begin
					wr_sdram_cmd	<= `NO_OPERATION;
					wr_sdram_addr	<= 12'hfff;
					wr_sdram_bank	<= 2'b11;
					wr_end			<= 1'b0;
				end
			endcase
		end
	end




































endmodule