/**
Descripcion,
Modulo que sincroniza las senales (hsync y vsync)
de un controlador VGA de 640x480 60hz, funciona con un reloj de 25Mhz

Ademas tiene las coordenadas de los pixeles H (eje x),
y de los pixeles V (eje y). Para enviar la senal RGB correspondiente
a cada pixel

-----------------------------------------------------------------------------
Author : Nicolas Hasbun, nhasbun@gmail.com
File   : vgaHdmi.v
Create : 2017-06-15 15:07:05
Editor : sublime text3, tab size (2)
-----------------------------------------------------------------------------
*/

// **Info Source**
// https://eewiki.net/pages/viewpage.action?pageId=15925278

module vgaHdmi(
  // **input**
  input clock, clock50, reset,
  input switchR, switchG, switchB,

  // **output**
  output reg hsync, vsync,
  output reg dataEnable,
  output reg vgaClock,
  output [23:0] RGBchannel
);

reg [9:0]pixelH, pixelV; // estado interno de pixeles del modulo

initial begin
  hsync      = 1;
  vsync      = 1;
  pixelH     = 0;
  pixelV     = 0;
  dataEnable = 0;
  vgaClock   = 0;
end

// Common used resolutions
// http://martin.hinner.info/vga/timing.html
// resolution                 // 640x480 - 800x600    - 1024x768
//pixel clock                 // 25.175  - 40.000     - 65.000 
localparam H_VIDEO =   800;    // 640;       800;        1024;
localparam H_FP    =    40;    //  16;        40;          24;
localparam H_SYNC  =   128;    //  96;       128;         136;
localparam H_BP    =    88;    //  48;        88;         160;
localparam H_TOTAL =  1056;    // 800;      1056;        1688;
localparam V_VIDEO =   600;    // 480;       600;         768;
localparam V_FP    =     1;    //  10;         1;           3;
localparam V_SYNC  =     4;    //   2;         4;           6;
localparam V_BP    =    23;    //  33;        23;          29;
localparam V_TOTAL =   628;    // 525;       628;         806;
localparam H_POL   =     1;    //   0;         1;           0;
localparam V_POL   =     1;    //   0;         1;           0;
    
// Manejo de Pixeles y Sincronizacion

always @(posedge clock or posedge reset) begin
  if(reset) begin
    hsync  <= 1;
    vsync  <= 1;
    pixelH <= 0;
    pixelV <= 0;
  end
  else begin
    // Display Horizontal
    if(pixelH==0 && pixelV!=(V_TOTAL-1)) begin
      pixelH<=pixelH+1'b1;
      pixelV<=pixelV+1'b1;
    end
    else if(pixelH==0 && pixelV==(V_TOTAL-1)) begin
      pixelH <= pixelH + 1'b1;
      pixelV <= 0; // pixel 525
    end
    else if(pixelH<=H_VIDEO) pixelH <= pixelH + 1'b1;
    // Front Porch
    else if(pixelH<=(H_VIDEO+H_FP)) pixelH <= pixelH + 1'b1;
    // Sync Pulse
    else if(pixelH<=(H_TOTAL-H_BP)) begin
      pixelH <= pixelH + 1'b1;
      hsync  <= 0;
    end
    // Back Porch
    else if(pixelH<(H_TOTAL-1)) begin
      pixelH <= pixelH+1'b1;
      hsync  <= 1;
    end
    else pixelH<=0; // pixel 800

    // Manejo Senal Vertical
    // Sync Pulse
    if( pixelV > (V_VIDEO+V_FP) || pixelV < (V_VIDEO+V_FP+V_SYNC+1))
      vsync <= 0;
    else
      vsync <= 1;
  end
end

// dataEnable signal
always @(posedge clock or posedge reset) begin
  if(reset) dataEnable<= 0;

  else begin
    if(pixelH >= 0 && pixelH <H_VIDEO && pixelV >= 0 && pixelV < V_VIDEO)
      dataEnable <= 1;
    else
      dataEnable <= 0;
  end
end

// VGA pixeClock signal
// Los clocks no deben manejar salidas directas, se debe usar un truco
initial vgaClock = 0;

always @(posedge clock50 or posedge reset) begin
  if(reset) vgaClock <= 0;
  else      vgaClock <= ~vgaClock;
end

// **************************************************************
// Screen colors using de10nano switches for test

assign RGBchannel[23:16] = (switchR)? 8'd255 : 8'd0;
assign RGBchannel [15:8] = (switchG)? 8'd255 : 8'd0;
assign RGBchannel  [7:0] = (switchB)? 8'd255 : 8'd0;

endmodule