# Copyright 1991-2016 Mentor Graphics Corporation
# 
# Modification by Oklahoma State University
# Use with Testbench 
# James Stine, 2008
# Go Cowboys!!!!!!
#
# All Rights Reserved.
#
# THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION
# WHICH IS THE PROPERTY OF MENTOR GRAPHICS CORPORATION
# OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.

# Use this run.do file to run this example.
# Either bring up ModelSim and type the following at the "ModelSim>" prompt:
#     do run.do
# or, to run from a shell, type the following at the shell prompt:
#     vsim -do fma.do -c
# (omit the "-c" to see the GUI while running from the shell)

onbreak {resume}

# create library
if [file exists work] {
    vdel -all
}
vlib work

# compile source files
vlog ../../cvw.sv fma.sv fmaadd.sv fmaalign.sv fmaexpadd.sv fmalza.sv fmamult.sv fmasign.sv tb_fma.sv +incdir+../../../config/rv32gc +incdir+../../../config/shared
vlog ../../generic/lzc.sv

# start and run simulation
vsim -voptargs=+acc work.stimulus

view list
view wave

-- display input and output signals as hexidecimal values
# Diplays All Signals recursively
#add wave -hex -r /stimulus/*

#Inputs
add wave -noupdate -divider -height 32 "Inputs"
add wave -hex /stimulus/Xs 
add wave -hex /stimulus/Ys 
add wave -hex /stimulus/Zs
add wave -hex /stimulus/Xe 
add wave -hex /stimulus/Ye 
add wave -hex /stimulus/Ze
add wave -hex /stimulus/Xm 
add wave -hex /stimulus/Ym 
add wave -hex /stimulus/Zm
add wave -hex /stimulus/XZero 
add wave -hex /stimulus/YZero 
add wave -hex /stimulus/ZZero
add wave -hex /stimulus/OpCtrl 

#Output
add wave -noupdate -divider -height 32 "Outputs"
add wave -hex /stimulus/ASticky
add wave -hex /stimulus/Sm  
add wave -hex /stimulus/InvA          
add wave -hex /stimulus/As         
add wave -hex /stimulus/Ps         
add wave -hex /stimulus/Ss           
add wave -hex /stimulus/Se               
add wave -hex /stimulus/SCnt


# add list -hex -r /tb/*
# add log -r /*

-- Set Wave Output Items 
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ps} {75 ns}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

-- Run the Simulation
run 250 ns

