### Thermal camera
The design aims to provide a termal camera, with the utilisation of old and cheap equipement.


### dependencies
The heat sensor code from : [heat_sens](/heat_sens/README.md)
The HDMI controller code from : [hdmi](/hdmi/README.md)

### User input
SW(0) : can be used to reset
SW(1) : swap the two bytes in the heatsensor data read back
 
### Wiring
The sensor is wired to the boards arduino header
* VCC => 3V3
* GND => GND
* SDA => IO:14
* SCL => IO:15 
HDMI connector just plugs in the HDMI socket on the board


### Example output
In the top left corner of your screen , the thermal imager output is shown.
By default the screen resolution is 800x600, while the sensor raw resolution is 8x8.
A linear interpolation is done on the pixels, resulting in a larger viewable area.


