![Reflow Soldering Process](https://github.com/harryHatesCPEN211/ELEC291_project_1/blob/eb1a9bda3876f7ce5a50482ae54d57ed98568fc2/Picture%201.png)
![Reflow Soldering Process](https://github.com/harryHatesCPEN211/ELEC291_project_1/blob/4ad491b80fbd7e23051242375f895bce1a59a06a/IMG_0236.png)
## About

Reflow soldering is used to assemble surface-mounted-technology (SMT) devices onto printed circuit boards (PCBs). The process utilizes solder paste (a mixture of solder flux and pellets with adhesive properties) to attach micro-components onto the PCBs. Once components are moderately secured on the pads, the board is then placed into an oven, which is gradually heated based on a predetermined soldering profile. This profile includes a customizable reflow time, reflow temperature, and soak time. During the heating process, the flux is activated, and the solder paste melts, soldering the components onto the PCB.

Reflow soldering provides a more accurate and hands-free approach than manual soldering, which can be challenging when working with small components on a small surface area.

## Objective

This project investigates and executes all aspects of reflow soldering: design, hardware, software, testing, and application. The following requirements are strictly followed:

- **Software**  
  - The software will be written in Assembly from the 8051 instruction set.  
  - Data validation and plotting will be done in real-time via Python Matplotlib.  

- **Reflow Oven Requirements**  
  - Must be capable of measuring temperatures between **25℃ and 240℃** with **±3℃ accuracy**.  

- **User Interface and Feedback**  
  - Customizable parameters via pushbuttons:  
    - Reflow temperature  
    - Reflow time  
    - Soak temperature  
    - Soak time  
  - LCD accurately displays and updates:  
    - Reflow states  
    - Oven/ambient temperature  
    - Running time (both total elapsed time and total time at each state) throughout the reflow process based on user input  
  - Start/Stop button for initiating and canceling the reflow process at any time.  

- **Automatic Abort on Error**  
  - The reflow process should terminate under the following conditions:  
    - Improper thermocouple placement in the oven.  
    - If the oven fails to reach at least **50℃ within the first 60 seconds** of operation.  


