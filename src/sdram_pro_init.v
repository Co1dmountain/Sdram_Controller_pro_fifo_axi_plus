/**** 
		初始化模块 
		根据sdram芯片手册提供的时序图使用状态机来实现
****/
`include "defines.v"

module sdram_pro_init(
		// input
		input					sys_clk					,
		input					sys_rst_n				,
		// output
		output	reg	[ 3:0]		init_cmd				,
		output	reg	[11:0]		init_addr				,
		output	reg	[ 1:0]		init_bank				,
		output	reg				init_end
);

	//// define ////
	// 状态机状态定义 //
	parameter	INIT_IDLE			= 3'd0;
	parameter	INIT_PRECHARGE		= 3'd1;
	parameter	INIT_AT_REFRESH_1	= 3'd2; // 第一次刷新
	parameter	INIT_Trc_1			= 3'd3; // 两次刷新间隔
	parameter	INIT_AT_REFRESH_2	= 3'd4; // 第二次刷新
	parameter	INIT_Trc_2			= 3'd5; // 第二次刷新与LOAD MODE REGISTER间隔
	parameter	INIT_MODE_RESGISTER	= 3'd6;
	parameter	INIT_END			= 3'd7;
	
	parameter	CNT_200US			= 10000;
	parameter	CNT_TRP				= 2; // SDRAM trp 18ns
	parameter	CNT_TRC				= 4; // SDRAM trc 58ns
	parameter	CNT_TMRD			= 3; // SDRAM tmrd 2clk
	reg [ 2:0] cur_state, next_state;
	
	reg	[13:0] cnt_wait_200us;
	wire flag_200us;
	reg [1:0] cnt_trp;
	wire flag_trp;
	reg [1:0] cnt_trc;
	wire flag_trc;
	reg [1:0] cnt_mrd;
	wire flag_mrd;
	
	//// main code ////
	// flags
	assign flag_200us = (cnt_wait_200us == CNT_200US - 1'b1) ? 1'b1 : 1'b0;	
	assign flag_trp = (cnt_trp == CNT_TRP - 1'b1) ? 1'b1 : 1'b0;
	assign flag_trc = (cnt_trc == CNT_TRC - 1'b1) ? 1'b1 : 1'b0;
	assign flag_mrd = (cnt_mrd == CNT_TMRD - 1'b1) ? 1'b1 : 1'b0;
	
	// cnts
	// cnt_wait_200us
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_wait_200us <= 'd0;
		end
		else if(cur_state == INIT_IDLE) begin
			if(cnt_wait_200us == CNT_200US - 1'b1) begin
				cnt_wait_200us <= CNT_200US;
			end
			else begin
				cnt_wait_200us <= cnt_wait_200us + 1'b1;
			end
		end
		else begin
			cnt_wait_200us <= 'd0;
		end
	end
	// cnt_trp
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trp <= 'd0;
		end
		else if(cur_state == INIT_PRECHARGE) begin
			cnt_trp <= cnt_trp + 1'b1;
		end
		else begin
			cnt_trp <= 'd0;
		end
	end
	// cnt_trc
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_trc <= 'd0;
		end
		else if(cur_state == INIT_Trc_1 || cur_state == INIT_Trc_2) begin
			cnt_trc <= cnt_trc + 1'b1;
		end
		else begin
			cnt_trc <= 'd0;
		end
	end
	// cnt_mrd
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cnt_mrd <= 'd0;
		end
		else if(cur_state == INIT_MODE_RESGISTER) begin
			cnt_mrd <= cnt_mrd + 1'b1;
		end
		else begin
			cnt_mrd <= 'd0;
		end
	end
	
	// 三段式状态机-第一段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			cur_state <= INIT_IDLE;
		end
		else begin
			cur_state <= next_state;
		end
	end

	// 三段式状态机-第二段
	always @(*) begin
		case(cur_state) 
			INIT_IDLE : begin
				if(flag_200us) begin
					next_state = INIT_PRECHARGE;
				end
				else begin
					next_state = INIT_IDLE;
				end
			end
			INIT_PRECHARGE : begin
				if(flag_trp) begin // 等待trp
					next_state = INIT_AT_REFRESH_1;
				end
				else begin
					next_state = INIT_PRECHARGE;
				end
			end
			INIT_AT_REFRESH_1 : begin
				next_state = INIT_Trc_1;
			end
			INIT_Trc_1 : begin
				if(flag_trc) begin // 等待trc
					next_state = INIT_AT_REFRESH_2;
				end
				else begin
					next_state = INIT_Trc_1;
				end
			end
			INIT_AT_REFRESH_2 : begin
				next_state = INIT_Trc_2;
			end
			INIT_Trc_2 : begin
				if(flag_trc) begin // 等待trc
					next_state = INIT_MODE_RESGISTER;
				end
				else begin
					next_state = INIT_Trc_2;
				end
			end
			INIT_MODE_RESGISTER : begin
					next_state = INIT_END;
			end
			INIT_END : begin
				next_state = INIT_END;
			end
			default : begin
				next_state = INIT_IDLE;
			end
		endcase
	end
	
	// 三段式状态机-第三段
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			init_cmd  <= `NO_OPERATION;
			init_addr <= 12'hfff;
			init_bank <= 2'b11;
			init_end  <= 1'b0;
		end
		else begin
			case(cur_state) 
				INIT_IDLE : begin
					init_cmd  <= `NO_OPERATION;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
					init_end  <= 1'b0;
				end
				INIT_PRECHARGE : begin
					init_cmd  <= `PRECHARGE;
					init_addr <= 12'hfff; // precharge需拉高A10
					init_bank <= 2'b11;
				end
				INIT_AT_REFRESH_1 : begin
					init_cmd  <= `AUTO_REFRESH;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
				end
				INIT_Trc_1 : begin
					init_cmd  <= `NO_OPERATION;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
				end
				INIT_AT_REFRESH_2 : begin
					init_cmd  <= `AUTO_REFRESH;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
				end
				INIT_Trc_2 : begin
					init_cmd  <= `NO_OPERATION;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
				end
				INIT_MODE_RESGISTER : begin
					init_cmd  <= `LOAD_MODE_REGISTER;
					init_addr <= 12'b00_0_00_011_0_111; // 根据sdram手册进行配置突发长度、类型、列选通潜伏期等
					init_bank <= 2'b00;
				end
				INIT_END : begin
					init_cmd  <= `NO_OPERATION;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
					init_end  <= 1'b1;
				end
				default : begin
					init_cmd  <= `NO_OPERATION;
					init_addr <= 12'hfff;
					init_bank <= 2'b11;
					init_end  <= 1'b0;
				end
			endcase
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

endmodule