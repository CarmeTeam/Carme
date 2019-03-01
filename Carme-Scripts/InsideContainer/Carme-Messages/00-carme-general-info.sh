#!/bin/bash
printf "Welcome to\n\n"
printf " ██████╗ █████╗ ██████╗ ███╗   ███╗███████╗\n"
printf "██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝\n"
printf "██║     ███████║██████╔╝██╔████╔██║█████╗\n"
printf "██║     ██╔══██║██╔══██╗██║╚██╔╝██║██╔══╝\n"
printf "╚██████╗██║  ██║██║  ██║██║ ╚═╝ ██║███████╗\n"
printf " ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝\n"
#printf "\n"
#printf "You are using CARME $CARME_VERSION\n" 
printf "
A general documentation can be found in /home/CarmeDocumentation/.
This includes examples stored as Jupyter-Notebooks and md-files.
"
printf "
If you are using the terminal to start simulations and want to
stop your program before it has finished you are adviced to use
$ carme_canceljob \"python <NAME>.py\"
or
$ carme_canceljob PID
in a new terminal.
"
printf "\n"

