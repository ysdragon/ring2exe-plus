/*
**	Application : Ring2EXE Plus Package
**	Purpose	    : Main entry point for the Ring2EXE Plus package
**	Original    : Mahmoud Fayed <msfclipper@yahoo.com>
**	Fork by	    : Youssef Saeed <youssefelkholey@gmail.com>
**	Date	    : 2025
*/

load "/../tools/ring2exe/utils/clicolors.ring"

func main
	see nl
	DrawLine()
	# Title
	see C_BOLD() + C_BCYAN() + "  Ring2EXE Plus" + C_RESET() 
	see C_DIM() + " - Package Information" + C_RESET() + nl
	see nl
	# Credits
	see C_DIM() + "  Original: " + C_RESET() + "Mahmoud Fayed <msfclipper@yahoo.com> (2017-2025)" + nl
	see C_DIM() + "  Fork by:  " + C_RESET() + C_BGREEN() + "Youssef Saeed" + C_RESET() + " <youssefelkholey@gmail.com> (2025)" + nl
	see nl
	DrawLine()
	see nl

	# Description
	PrintSection("About")
	see "    " + C_DIM() + "Ring2EXE Plus is a fork of the Ring2EXE tool for the Ring" + C_RESET() + nl
	see "    " + C_DIM() + "programming language. It converts Ring source code to native" + C_RESET() + nl
	see "    " + C_DIM() + "executables for Windows, Linux, macOS & FreeBSD." + C_RESET() + nl
	see nl

	# Quick Start
	PrintSection("Quick Start")
	PrintCommand("ring2exe myapp.ring", "Build executable")
	PrintCommand("ring2exe myapp.ring -static", "Build standalone executable")
	PrintCommand("ring2exe myapp.ring -dist", "Prepare for distribution")
	see nl

	# Location
	PrintSection("Location")
	see "    " + C_DIM() + "Tool location: " + C_RESET() + C_CYAN() + "ring/tools/ring2exe" + C_RESET() + nl
	see "    " + C_DIM() + "Run command:  " + C_RESET() + C_YELLOW() + "ring2exe" + C_RESET() + nl
	see nl

	DrawLine()
	see nl

func PrintSection cTitle
	see "  " + C_BOLD() + C_BYELLOW() + "● " + cTitle + C_RESET() + nl

func PrintCommand cCommand, cDesc
	see "    " + C_CYAN() + cCommand + C_RESET()
	# Pad to align descriptions
	nPad = 35 - len(cCommand)
	if nPad > 0 see copy(" ", nPad) ok
	see C_DIM() + cDesc + C_RESET() + nl

func DrawLine 
	see C_DIM() + copy("─",75) + C_RESET() + nl