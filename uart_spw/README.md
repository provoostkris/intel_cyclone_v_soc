### UART SPW
The design is a bridge between a regular UART and SpW node.
For now the top level file internally loops the spw tx and rx, so the uart interface part can be tested

### dependencies
[SpaceWireCODECIP_100MHz](https://github.com/provoostkris/SpaceWireCODECIP_100MHz)
 
[vhdl-axis-uart](https://github.com/provoostkris/vhdl-axis-uart)

### User input
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
UART RX
UART TX
````
### Resources

```
Logic utilization (in ALMs)	263 / 41,910 ( < 1 % )
Total registers	443
Total pins	19 / 314 ( 6 % )
Total virtual pins	0
Total block memory bits	1,024 / 5,662,720 ( < 1 % )
Total DSP Blocks	0 / 112 ( 0 % )
```

### Example output

We send 'hello world.' 4 times in the terminal with CR or LF and immediatly print what is recieved
```
hello world.hhell  wrrldhello world.heeloo wrrl—hello world.helll wwrlldhello world.heell wooldd
```
It is obvious that there is something wrong in the design as the data coming back is different from the data transmitted.