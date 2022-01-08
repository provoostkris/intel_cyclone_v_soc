### UART SPW
The design is a bridge between a regular UART and SpW node.
For now the top level file internally loops the spw tx and rx, so the uart interface part can be tested

### dependencies
[SpaceWireCODECIP_100MHz](https://github.com/provoostkris/SpaceWireCODECIP_100MHz)
 
[vhdl-axis-uart](https://github.com/provoostkris/vhdl-axis-uart)

### User interface
UART terminal
with the settings
- 115200 bps
- 8 bits
- none parity
- 1 stop bits
 
SW(0)
  reset the design

LED(0)
  blink : PLL locked and running
LED(1)
  all KEY buttons OR-ed
  
### Wiring
````
USB2TTL <> GPIO header
-------    -----------
UART RX <> GPIO1(1)
UART TX <> GPIO0(40)
GND     <> GPIO1(12)
````
note : the GPIO as mentioned on the PCD silk screen
### Resources

```
Logic utilization (in ALMs)	266 / 41,910 ( < 1 % )
Total registers	442
Total pins	19 / 314 ( 6 % )
Total virtual pins	0
Total block memory bits	1,024 / 5,662,720 ( < 1 % )
Total DSP Blocks	0 / 112 ( 0 % )
```

### Example output

We send the alphabet and some random characters, terminated with a 'CR' and the console shows the echo-ed value
```
abcdefghijklmnopqrstuvwxyz
abcdefghijklmnopqrstuvwxyz
mixed123456789+-*/?
mixed123456789+-*/?
```