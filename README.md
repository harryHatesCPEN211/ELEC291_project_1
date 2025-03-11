## About
Reflow soldering is used to assemble surface-mounted-technology (SMTs) devices onto printed circuit boards (PCBs). The process utilizes solder paste (a mixture of solder flux and pellets with adhesive properties) to attach micro-components onto the PCBs. Once components are moderately secured on the pads, the board is then placed into an oven, which is then gradually heated up based on a pre-determined soldering profile. Such profile includes a customizable reflow time, reflow temperature, and soak time. During this heating process, the flux is activated, and the solder paste melts, soldering the components onto the PCB.

Reflow soldering provides a more accurate and hands-free approach than manual soldering, which could prove challenging when soldering small components on a small surface area.

## Objective
This project investigates and executes all aspects of Reflow Soldering: design, hardware, software, testing and application. The following requirements are strictly followed:
•	The software will be written in Assembly from the 8051 instructional set, with data validation and plotting done in real time via Python Matplotlib
•	The reflow oven must be capable of measuring temperatures between 25℃ and 240℃ with ±3℃ accuracy
•	User interface and feedback:
o	Customizable parameters via pushbuttons: reflow temperature, reflow time, soak temperature and soak time
o	LCD accurately displays and updates reflow states, oven/ambient temperature, running time (both total time elapsed and total time at each state) throughout the reflow process and as per user’s input
o	Start/Stop button for starting and cancelling the reflow process at any given time
•	Automatic abort on error. The reflow process should terminate on the following conditions:
o	Improper thermocouple placement in oven
o	If the oven fails to reach at least 50℃ within the first 60 seconds of operations


