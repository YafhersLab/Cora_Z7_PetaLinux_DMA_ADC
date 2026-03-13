# tcl file for creating a Vivado project in the vivado tcl console,
# go in the repo project folder, then source ./tcl/create_project.tcl

# initial message
puts "creating project Cora_Z7_PetaLinux_DMA_ADC"

# create project
create_project Cora_Z7_PetaLinux_DMA_ADC ./vivado/
set_property board_part digilentinc.com:cora-z7-07s:part0:1.1 [current_project]

# set language and simulator
set_property Target_Language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property target_simulator XSim [current_project]

# import VHDL files
proc add_vhdl_recursive {dir} {
    foreach f [glob -directory $dir *] {
        if {[file isdirectory $f]} {
            add_vhdl_recursive $f
        } elseif {[string match "*.vhd" $f]} {
            add_files $f
        }
    }
}
add_vhdl_recursive ./src
update_compile_order -fileset sources_1

#Import testbench files
add_files [glob ./tb/*.vhd]
#set_property used_in_synthesis false [get_files ./tb/tb_qcsp.vhd]

# Import reference text files for testbench
add_files -fileset sim_1 -norecurse [glob ./data/*.txt]

# add constrain file
add_files -fileset constrs_1 ./tcl/constraints.xdc

# creation of Block Diagram
create_bd_design "design_zynq"
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
save_bd_design