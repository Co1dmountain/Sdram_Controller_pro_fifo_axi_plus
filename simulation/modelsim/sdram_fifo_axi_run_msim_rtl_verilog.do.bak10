transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog -vlog01compat -work altera_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/altera_primitives.v}

vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog -vlog01compat -work lpm_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog -vlog01compat -work sgate_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog -vlog01compat -work altera_mf_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_lnsim_ver
vmap altera_lnsim_ver ./verilog_libs/altera_lnsim_ver
vlog -sv -work altera_lnsim_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/altera_lnsim.sv}

vlib verilog_libs/cycloneii_ver
vmap cycloneii_ver ./verilog_libs/cycloneii_ver
vlog -vlog01compat -work cycloneii_ver {d:/altera/13.0sp1/quartus/eda/sim_lib/cycloneii_atoms.v}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_model_plus.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_top.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/defines.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/ip {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/ip/write_fifo.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/ip {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/ip/read_fifo.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_sdram_ctrl.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_fifo_ctrl.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_write.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_read.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_init.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_autorefresh.v}
vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_arbit.v}

vlog -vlog01compat -work work +incdir+D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src {D:/ic/project/Sdram_Controler_pro/sdram_fifo_axi/src/sdram_pro_top_tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneii_ver -L rtl_work -L work -voptargs="+acc"  tb_sdram_pro_top

add wave *
view structure
view signals
run -all
