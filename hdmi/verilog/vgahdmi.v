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

localparam H_VIDEO =  640;    // 640;   1280,
localparam H_FP    =   16;    //  16;     72,
localparam H_SYNC  =   96;    //  96;     80,
localparam H_BP    =   48;    //  48;    216,
localparam H_TOTAL =  800;    // 800;   1648,
localparam V_VIDEO =  480;    // 480;    720,
localparam V_FP    =   10;    //  10;      3,
localparam V_SYNC  =    2;    //   2;      5,
localparam V_BP    =   33;    //  33;     22,
localparam V_TOTAL =  525;    // 525;    750,
          // H_POL               '1',    '1',
          // V_POL               '1',    '1',
          // ACTIVE              '1'     '1'
    
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