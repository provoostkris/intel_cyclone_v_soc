### Thermal imager
The design captures the heat map from the thermal imager AMG8833

### dependencies
none

(Inspired by https://github.com/karpour/AMG88XX-Arduino)

### User input
none

### Example output
Automatically after reset the design will continue to read out the sensor. 
A signal tap is added that contains all the RAW pixel values.
A calculation sheet is added , where you can copy the raw values.
A 2D and 3D plot are rendered in the sheet.
An example below shows my finger in front of the sensor (+/- 10 cm)
![finger_2d](/heat_sens/img/finger_2d.png)
![finger_3d](/heat_sens/img/finger_3d.png)