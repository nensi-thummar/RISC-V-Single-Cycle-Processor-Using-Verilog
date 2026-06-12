`timescale 1ns/1ps

module tb;

reg clk;
reg rst;

top uut(
    .clk(clk),
    .rst(rst)
);

initial
begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial
begin
    rst = 0;
    #20 rst = 1;
end

initial
begin

   #100;
#50;

$display("--------------------");
$display("x1 = %h", uut.reg_file.registers[1]);
$display("x2 = %h", uut.reg_file.registers[2]);
$display("x3 = %h", uut.reg_file.registers[3]);
  
  $display("x4 = %h", uut.reg_file.registers[4]);
  $display("x5 = %h", uut.reg_file.registers[5]);
  $display("x6 = %h", uut.reg_file.registers[6]);
  
  $display("x7 = %h", uut.reg_file.registers[7]);
  $display("x8 = %h", uut.reg_file.registers[8]);
  $display("x9 = %h", uut.reg_file.registers[9]);
  
  $display("x10 = %h", uut.reg_file.registers[10]);
  $display("x11 = %h", uut.reg_file.registers[11]);
  $display("x12 = %h", uut.reg_file.registers[12]);
  $display("x13 = %h", uut.reg_file.registers[13]);
  
  $display("x14 = %h", uut.reg_file.registers[14]);
  $display("x15 = %h", uut.reg_file.registers[15]);
  $display("x16= %h", uut.reg_file.registers[16]);
  
  $display("x17 = %h", uut.reg_file.registers[17]);
  $display("x18 = %h", uut.reg_file.registers[18]);
  $display("x19= %h", uut.reg_file.registers[19]);
  
  $display("x20= %h", uut.reg_file.registers[20]);
  $display("x21 = %h", uut.reg_file.registers[21]);
  $display("x22 = %h", uut.reg_file.registers[22]);
  $display("x23 = %h", uut.reg_file.registers[23]);
  
  $display("x24 = %h", uut.reg_file.registers[24]);
  $display("x25= %h", uut.reg_file.registers[25]);
  $display("x26 = %h", uut.reg_file.registers[26]);
  
  $display("x27= %h", uut.reg_file.registers[27]);
  $display("x28= %h", uut.reg_file.registers[28]);
$display("--------------------");
  
  #500;

$finish;
end

initial
begin
    $dumpfile("dump.vcd");
  $dumpvars(0, tb);
end

endmodule
