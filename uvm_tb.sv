`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.08.2022 14:19:27
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 

`include "uvm_macros.svh"
import uvm_pkg::*;
//////////////////////////////////////////////////////////////////////////////////
//////////////TRANSACTION CLASS//////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////
class transaction extends uvm_sequence_item;

rand bit rd,wr;
rand bit[7:0]data_in;
bit[7:0]data_out;
bit full,empty;

constraint rd_wr{
rd!=wr; wr dist{0:/50, 1:/50}; rd dist{0:/50, 1:/50};
}

constraint data_con{
data_in>1; data_in<5;}

function new(input string inst="tran");
super.new(inst);
this.rd=rd;
this.wr=wr;
this.data_in=data_in;
this.data_out=data_out;
this.full=full;
this.empty=empty;
endfunction

`uvm_object_utils_begin(transaction)
`uvm_field_int(rd,UVM_DEFAULT)
`uvm_field_int(wr,UVM_DEFAULT)
`uvm_field_int(data_in,UVM_DEFAULT)
`uvm_field_int(data_out,UVM_DEFAULT)
`uvm_field_int(full,UVM_DEFAULT)
`uvm_field_int(empty,UVM_DEFAULT)
`uvm_object_utils_end
endclass

/////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////GENERATOR CLASS/////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
class generator extends uvm_sequence#(transaction);
`uvm_object_utils(generator)
transaction t;
integer i;
//event next;
function new(input string inst="gen");
super.new(inst);
endfunction

virtual task body();
t=transaction::type_id::create("tran");
for(i=0;i<50;i++)begin
start_item(t);
t.randomize();
`uvm_info("gen",$sformatf("Data send to driver wr: %0b, rd: %0b, data_in: %0b",t.wr,t.rd,t.data_in),UVM_NONE)
t.print(uvm_default_line_printer);
finish_item(t);
#10;
//@(next);
end
endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////INTERFACE/////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////
interface fifo_if;
logic rd,wr,clock,reset;
logic[7:0]data_in;
logic[7:0]data_out;
logic full,empty;
endinterface

////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////DRIVER CLASS/////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
class driver extends uvm_driver#(transaction);
`uvm_component_utils(driver)

function new(input string inst="drv",uvm_component c);
super.new(inst,c);
endfunction

transaction t;
virtual fifo_if fif;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
t=transaction::type_id::create("tran");
if(!uvm_config_db #(virtual fifo_if)::get(this,"","fif",fif))
`uvm_info("drv","Unable to access",UVM_NONE)
endfunction


virtual task rst();
fif.reset=1'b1;
fif.rd=1'b0;
fif.wr=1'b0;
fif.data_in=0;
repeat(5)@(posedge fif.clock);
fif.reset=1'b0;
endtask


virtual task run_phase(uvm_phase phase);
forever begin
seq_item_port.get_next_item(t);
@(posedge fif.clock);
fif.rd=t.rd;
fif.wr=t.wr;
fif.data_in=t.data_in;
`uvm_info("drv",$sformatf("trigger DUT wr: %0b, rd: %0b, data_in: %0b",t.wr,t.rd,t.data_in),UVM_NONE);
t.print(uvm_default_line_printer);
repeat(2)@(posedge fif.clock);
seq_item_port.item_done();
end
endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////MONITOR CLASS/////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////
class monitor extends uvm_monitor;
`uvm_component_utils(monitor)

uvm_analysis_port#(transaction)send;
function new(input string inst="drv",uvm_component c);
super.new(inst,c);
send=new("write",this);
endfunction

virtual fifo_if fif;
transaction t;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
t=transaction::type_id::create("tran");
if(!uvm_config_db #(virtual fifo_if)::get(this,"","fif",fif))
`uvm_info("mon","Unable to access",UVM_NONE)
endfunction

virtual task run_phase(uvm_phase phase);
forever begin
repeat(2)@(posedge fif.clock);
t.rd=fif.rd;
t.wr=fif.wr;
t.data_in=fif.data_in;
t.data_out=fif.data_out;
t.full=fif.full;
t.empty=fif.empty;
`uvm_info("mon",$sformatf("trigger DUT wr: %0b, rd: %0b, data_in: %0b",t.wr,t.rd,t.data_in),UVM_NONE);
t.print(uvm_default_line_printer);
send.write(t);
end
endtask
endclass

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////SCOREBOARD CLASS//////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class scoreboard extends uvm_scoreboard;
`uvm_component_utils(scoreboard)

uvm_analysis_imp#(transaction,scoreboard)recv;
function new(input string inst="drv",uvm_component c);
super.new(inst,c);
recv=new("read",this);
endfunction
///////////////////creating a queue
bit [7:0]din[$];
bit [7:0]temp;
//////////////////////////tempoeary variable where we have to store data  that we read from the queue
transaction t;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
t=transaction::type_id::create("tran");
endfunction

virtual function void write(input transaction data);
t=data;
`uvm_info("sco","data recv from monitor ",UVM_NONE)
t.print(uvm_default_line_printer);

if(t.wr==1'b1)begin
din.push_front(t.data_in);
`uvm_info("sco","DATA STORE IN QUEUE",UVM_NONE)
end


if(t.rd==1'b1)begin
  if(t.empty==1'b0)begin
  temp=din.pop_back();
    if(t.data_out==temp)
    `uvm_info("sco","DATA MATCHED",UVM_NONE)
    else
    `uvm_info("sco","DATA NOT MATCHED",UVM_NONE) 
  end
  else
    begin
    `uvm_info("sco","FIFO EMPTY",UVM_NONE)
    end
end
endfunction
endclass

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////AGENT CLASS//////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class agent extends uvm_agent;
`uvm_component_utils(agent)
 
 
function new(input string inst = "AGENT", uvm_component c);
super.new(inst, c);
endfunction
 
monitor m;
driver d;
uvm_sequencer #(transaction) seq;
 
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
m = monitor::type_id::create("MON",this);
d = driver::type_id::create("DRV",this);
seq = uvm_sequencer #(transaction)::type_id::create("SEQ",this);
endfunction
 
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
d.seq_item_port.connect(seq.seq_item_export);
endfunction


virtual task pre_test();
d.rst();
endtask


endclass
 
/////////////////////////////////////////////////////
 
class env extends uvm_env;
`uvm_component_utils(env)
 
 
function new(input string inst = "ENV", uvm_component c);
super.new(inst, c);
endfunction
 
scoreboard s;
agent a;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
s = scoreboard::type_id::create("SCO",this);
a = agent::type_id::create("AGENT",this);
endfunction
 
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
a.m.send.connect(s.recv);
endfunction
 
 
endclass
 
////////////////////////////////////////////
 
class test extends uvm_test;
`uvm_component_utils(test)
 
 
function new(input string inst = "TEST", uvm_component c);
super.new(inst, c);
endfunction
 
generator gen;
env e;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
gen = generator::type_id::create("GEN",this);
e = env::type_id::create("ENV",this);
endfunction
 
virtual task run_phase(uvm_phase phase);
phase.raise_objection(phase);
gen.start(e.a.seq);
phase.drop_objection(phase);
endtask
endclass
//////////////////////////////////////
 
module add_tb();
test t;
fifo_if fif();
 
fifo dut (.clock(fif.clock), .rd(fif.rd),.wr(fif.wr), .full(fif.full), .empty(fif.empty), .data_in(fif.data_in), .data_out(fif.data_out), .reset(fif.reset));

initial 

begin
		fif.clock = 1'b1;
		fif.reset = 1'b1;
		repeat (3) @(posedge fif.clock);
		#5
		fif.reset = 1'b0;
	end
 
always #10 fif.clock = ~fif.clock; 
initial begin
t = new("TEST",null);
uvm_config_db #(virtual fifo_if)::set(null, "*", "fif", fif);
run_test();
end
 
endmodule

