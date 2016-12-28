#!/bin/bash
# A menu driven shell script sample template
## ----------------------------------
# variables
# ----------------------------------
echo -e "\n enter password"
read -s -p "PASSWORD: " PASSWORD

EDITOR=vim
PASSWD=/etc/passwd

V_RED='\033[0;31m'
V_UNDERLINE=`tput smul`
V_RESET=`tput sgr0`

source vertica_functions.sh
# function to display menus
show_menus() {
        clear
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo " Vertica Utilities for troubleshooting"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo " 1. Status of Down Node and Host"
        echo " 2. Check In-Memory Catalog size"
        echo " 3. Check Partitions which are contributing to large catalog size"
        echo " 4. Performance of vertica per node"
        echo " 5. AHM lag and it's possible reason"
        echo " 6. Disk_utilization"
        echo " 7. Vertica System Information"
        echo " 8. Check running Queries in Database"
        echo " 9. Check Queries taking highest execution and queue wait time"
        echo "10. Check Queries taking highest execution and queue wait time in last 6 hour"
        echo "11. Check Resource Pool usage"
        echo "12. Check Lock usage and Queries Failed due to unable to get lock"
        echo "13. Check Deleted data"
        echo "14. Run scrutinize for Database"
        echo "15. Exit"
}
# read input from the keyboard and take a action
# invoke the one() when the user select 1 from the menu option.
# invoke the two() when the user select 2 from the menu option.
# Exit when user the user select 3 form the menu option.
read_options(){
	local choice
	read -p "Enter choice [ 1 - 15] : " choice
	case $choice in
	    1) Node_down ;;
	    2) Catalog_Size ;;
	    3) Partition_size;;
	    4) Performance_Vertica;;
	    5) AHM_lag;;
	    6) Disk_utilization;;
	    7) Vertica_System_Information;;
	    8) Running_queries;;
	    9) Top_queries_by_execution_wait_time;;
	   10) Top_queries_by_execution_wait_time_in_last_6_hr;;
	   11) Resource_Pools_usage;;
	   12) Locks_checking;;
	   13) Delete_vector_rows;;
	   14) scrutinize;;
	   15) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}
 
# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP
 
# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------

while true
do
 
	show_menus
	read_options
done
