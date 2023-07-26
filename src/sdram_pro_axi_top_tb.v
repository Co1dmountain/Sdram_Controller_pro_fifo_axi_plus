`timescale  1ns/1ns
 
module  sdram_pro_axi_top_tb();
 
//********************************************************************//
//****************** Internal Signal and Defparam ********************//
//********************************************************************//
	//defparam
	//重定义仿真模型中的相关参数
	defparam sdram_model_plus_inst.addr_bits = 12;          //地址位宽
	defparam sdram_model_plus_inst.data_bits = 16;          //数据位宽
	defparam sdram_model_plus_inst.col_bits  = 9;           //列地址位宽
	defparam sdram_model_plus_inst.mem_sizes = 2*1024*1024; //L-Bank容量
	//// define ////
	reg sys_clk;
	reg sys_rst_n;
	//reg [22:0] addr;
	//reg [7:0] burst_len;
	//reg rd_fifo_rd_req;
	reg	read_valid;
	
	wire [15:0] sdram_dq;
	wire [9:0] rd_fifo_num;
	wire [9:0] wr_fifo_num;
	wire [15:0] rd_fifo_rd_data;
	wire init_end;
	wire sdram_cke  ;
	wire sdram_cs_n ;
	wire sdram_ras_n;
	wire sdram_cas_n;
	wire sdram_we_n ;
	wire [1:0] sdram_bank	;
	wire [11:0] sdram_addr ;
	wire [1:0] sdram_dqm  ;
	
	//// main code ////
	initial begin
		sys_clk <= 1'b0;
		sys_rst_n <= 1'b0;
		#200 sys_rst_n <= 1'b1;
	end
	
	always #10 sys_clk <= ~sys_clk;
	

	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			//rd_fifo_rd_req <= 1'b0;
			read_valid <= 1'b0;
		end
		else if(wr_fifo_num >= 'd0) begin
			//rd_fifo_rd_req <= 1'b1;
			read_valid <= 1'b1;
		end
		else begin
			//rd_fifo_rd_req <= 1'b0;
			read_valid <= 1'b0;
		end
	end
	


//// inst ////
sdram_pro_axi_top u_sdram_pro_axi_top(
	.sys_clk		 (sys_clk		 ),
	.sys_rst_n		 (sys_rst_n		 ),
	.addr			 (addr			 ),
	//.burst_len    	 (burst_len    	 ),
	//.rd_fifo_rd_req	 (rd_fifo_rd_req ),
	.wr_fifo_num     (wr_fifo_num    ),
	.rd_fifo_rd_data (rd_fifo_rd_data),
	.rd_fifo_num     (rd_fifo_num    ),
	.read_valid      (read_valid     ),
	.init_end        (init_end       ),
	.sdram_cke       (sdram_cke      ),
	.sdram_cs_n      (sdram_cs_n     ),
	.sdram_ras_n     (sdram_ras_n    ),
	.sdram_cas_n     (sdram_cas_n    ),
	.sdram_we_n      (sdram_we_n     ),
	.sdram_bank		 (sdram_bank	 ),
	.sdram_addr      (sdram_addr     ),
	.sdram_dqm       (sdram_dqm      ),
	.sdram_dq        (sdram_dq       )
);


 
//-------------sdram_model_plus_inst-------------
sdram_model_plus    sdram_model_plus_inst(
    .Dq     (sdram_dq       ),
    .Addr   (sdram_addr     ),
    .Ba     (sdram_bank		),
    .Clk    (sys_clk		),
    .Cke    (sdram_cke      ),
    .Cs_n   (sdram_cs_n     ),
    .Ras_n  (sdram_ras_n    ),
    .Cas_n  (sdram_cas_n    ),
    .We_n   (sdram_we_n     ),
    .Dqm    (4'b0           ),
    .Debug  (1'b1           )
 
);
 
endmodule