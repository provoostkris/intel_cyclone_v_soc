# intel_cyclone_v_soc


### Hardware
The developement board is a DE10 nano board from terrasic.
It features a Cyclone V SOC (FPGA + CPU)
The FPGA fabric contains 40.000 ALM's, 5Mbits RAM and 112 DSP blocks.

### [HDMI](/hdmi)
Drive the on board HDMI controller 
[ADV7513](https://www.analog.com/en/products/adv7513.html) 
to produce a screen output for a HDMI capable monitor.

### [Thermal camera](/heat_cam)
A very low resolution budget thermal camera can be made by combining the two projects [Thermal imager](/heat_sens) and [HDMI](/hdmi)

### [Thermal imager](/heat_sens)
A driver and controller for the 
[AMG8833](https://industry.panasonic.eu/components/sensors/industrial-sensors/grid-eye/amg88xx-high-performance-type/amg8833-amg8833)
module. Supporting component initialisation, read out and averaging.

### [Serial to SpaceWire](/uart_spw)
UART to spacewire bridge. Combines the following projects 
[SpaceWireCODECIP_100MHz](https://github.com/provoostkris/SpaceWireCODECIP_100MHz) and 
[vhdl-axis-uart](https://github.com/provoostkris/vhdl-axis-uart)
