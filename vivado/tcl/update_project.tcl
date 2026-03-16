# tcl file for updating VHDL sources in an existing Vivado project
# source ./tcl/update_project.tcl

puts "Updating VHDL sources in Cora_Z7_PetaLinux_DMA_ADC"

# open project only if none is open
if {[string equal "" [current_project -quiet]]} {
    puts "Opening project..."
    open_project ./vivado/Cora_Z7_PetaLinux_DMA_ADC.xpr
} else {
    puts "Project already open: [current_project]"
}

set old_vhdl_files [get_files -quiet -of_objects [get_filesets sources_1] *.vhd]

if {[llength $old_vhdl_files] > 0} {
    puts "Removing old VHDL files from sources_1"
    remove_files $old_vhdl_files
}

# add current VHDL files from src/
puts "Adding VHDL files from src/"
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

# add current Verilog files from src
puts "Adding Verilog files from src/"
proc add_verilog_recursive {dir} {
    foreach f [glob -directory $dir *] {
        if {[file isdirectory $f]} {
            add_verilog_recursive $f
        } elseif {[string match "*.v" $f] || [string match "*.sv" $f]} {
            add_files $f
        }
    }
}
add_verilog_recursive ./src
update_compile_order -fileset sources_1

# remove existing VHDL testbench files from sim_1
set old_tb [get_files -quiet -of_objects [get_filesets sim_1] *.vhd]
if {[llength $old_tb] > 0} {
    remove_files $old_tb
}

# add testbench files
puts "Adding testbench VHDL files"
add_files [glob ./tb/*.vhd]
#set_property used_in_synthesis false [get_files ./tb/tb_qcsp.vhd]

# update compile order
update_compile_order -fileset sim_1

# Import reference text files for testbench
add_files -fileset sim_1 -norecurse [glob ./data/*.txt]

puts "VHDL sources updated successfully"
