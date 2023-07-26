/**** sdram_pro 需要的命令 ****/

// 各种命令
//                            cs ras cas we
`define	NO_OPERATION			4'b0111
`define	PRECHARGE				4'b0010
`define	AUTO_REFRESH			4'b0001
`define LOAD_MODE_REGISTER		4'b0000
`define	WRITE					4'b0100
`define	READ					4'b0101
`define ACTIVE					4'b0011
`define BURST_TERMINATE			4'b0110

// 地址信号是否需要定义？
