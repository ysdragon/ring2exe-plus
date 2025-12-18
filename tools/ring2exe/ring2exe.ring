/*
**	Application : Ring2EXE Plus
**	Version     : 1.2.0
**	Purpose     : Convert Ring project source code to executable file
**	              (Windows, Linux, macOS & FreeBSD)
**	Author      : Mahmoud Fayed <msfclipper@yahoo.com>
**	Fork by     : Youssef Saeed <youssefelkholey@gmail.com>
**	Date        : 2017.11.06
**	Fork Date   : 2025
*/

/*
	===================================================================================
	USAGE
	===================================================================================

		ring ring2exe.ring filename.ring [Options]

		Or after building ring2exe:
		  Windows:              ring2exe filename.ring [Options]
		  Linux/macOS/FreeBSD:  ./ring2exe filename.ring [Options]

	===================================================================================
	GENERATED FILES
	===================================================================================

		filename.ringo        - Ring Object File (compiled bytecode)
		filename.c            - C Source code (embeds the .ringo content)
		filename_build_*.bat  - Build script for Windows (cl, gcc, clang, tcc)
		filename_build_*.sh   - Build script for Unix (gcc, clang)
		filename.exe          - Executable (Windows)
		filename              - Executable (Linux, macOS, FreeBSD)

	===================================================================================
	OPTIONS
	===================================================================================

	BUILD OPTIONS:
		-keep              Don't delete temporary files (.c, .ringo, build scripts)
		-static            Build standalone executable (no shared libraries)
		-gui               Build GUI application (hide console on Windows)
		-cc=<compiler>     Specify C compiler (gcc, clang, tcc, cl)
		-cflags=<flags>    Specify C compiler flags
		-output=<name>     Specify custom output filename
		-icon=<file>       Custom application icon (.ico/.icns/.png/.svg)
		-compress          Compress executable with UPX
		-auto-libs         Auto-detect required libraries from source code

	BUILD PRESETS:
		-debug             Build with debug symbols (-g -O0)
		-release           Build optimized release (-O3 -DNDEBUG)
		-size              Optimize for size (-Os)

	OUTPUT CONTROL:
		-verbose           Show detailed compiler output
		-quiet             Suppress all output except errors

	DISTRIBUTION OPTIONS:
		-dist              Prepare application for distribution
		-allruntime        Include all libraries in distribution
		-mobileqt          Prepare Qt project for mobile platforms
		-webassemblyqt     Prepare Qt project for WebAssembly

	PACKAGE METADATA (used with -dist):
		-version=<ver>     Package version (default: 1.0)
		-description=<t>   Package description
		-maintainer=<e>    Maintainer name/email
		-license=<type>    License type (default: MIT)
		-homepage=<url>    Project homepage URL

	PACKAGE FORMATS (use with -dist):
		-scripts           Generate installation scripts only (default)

		Linux:
		  -deb             Generate Debian package (.deb)
		  -rpm             Generate RPM package (.rpm)
		  -appimage        Generate AppImage
		  -flatpak         Generate Flatpak package
		  -snap            Generate Snap package

		macOS:
		  -appbundle       Generate App Bundle (.app)
		  -dmg             Generate DMG disk image

		FreeBSD:
		  -pkg             Generate pkg package (.pkg)

		Windows:
		  -nsis            Generate NSIS installer
		  -inno            Generate Inno Setup installer
		  -msi             Generate MSI installer (WiX)

	LIBRARY FLAGS:
		-<library>         Include library (e.g., -qt, -allegro, -mysql)
		-no<library>       Exclude library (e.g., -noqt, -noallegro)

	COMMANDS:
		--list-libs        Show all available libraries
		--help, -h         Show help message
		--version, -v      Show version number

	===================================================================================
	CONFIGURATION FILE
	===================================================================================

	Create 'ring2exe.conf' in your project directory to set default options:

		aProjectConfig = [
		    :version = "1.0.0",
		    :description = "My Ring Application",
		    :maintainer = "Developer <dev@example.com>",
		    :license = "MIT",
		    :homepage = "https://example.com",
		    :icon = "icon.png"
		]

	Command-line options override configuration file settings.

	===================================================================================
	EXAMPLES
	===================================================================================

	Basic build:
		ring2exe myapp.ring

	Release build with custom name:
		ring2exe myapp.ring -release -output=MyApplication

	Debug build with verbose output:
		ring2exe myapp.ring -debug -verbose

	Auto-detect libraries and create distribution:
		ring2exe myapp.ring -auto-libs -dist

	Create Debian package with metadata:
		ring2exe myapp.ring -dist -deb -version=2.0.0 -maintainer="dev@example.com"

	Create multiple Linux packages:
		ring2exe myapp.ring -dist -deb -rpm -appimage

	===================================================================================
*/

load "stdlibcore.ring"
load "tokenslib.ring"
load "utils/cli.ring"

# Ring2EXE Plus Version
VERSION = "1.2.0"

# Global Configuration (can be overridden by options or config file)
G_CONFIG = [
	:version = "1.0",
	:description = "Ring Application",
	:maintainer = "Developer <developer@example.com>",
	:license = "MIT",
	:homepage = "https://ring-lang.net",
	:icon = "",
	:verbose = false,
	:quiet = false,
	:compress = false,
	:autolibs = false
]

# Library to load-statement mapping for auto-detection
G_LIBMAP = [
	["guilib.ring", "qt"],
	["lightguilib.ring", "lightguilib"],
	["mysqllib.ring", "mysql"],
	["sqlitelib.ring", "sqlite"],
	["postgresqllib.ring", "postgresql"],
	["allegro.ring", "allegro"],
	["openssllib.ring", "openssl"],
	["libcurl.ring", "libcurl"],
	["internetlib.ring", "internetlib"],
	["odbclib.ring", "odbc"],
	["opengl.ring", "opengl"],
	["opengl21lib.ring", "opengl"],
	["freeglut.ring", "freeglut"],
	["ziplib.ring", "libzip"],
	["libuv.ring", "libuv"],
	["consolecolors.ring", "consolecolors"],
	["murmurhashlib.ring", "murmurhash"],
	["webview.ring", "webview"],
	["raylib.ring", "raylib"],
	["sdllib.ring", "sdl"],
	["socketslib.ring", "sockets"],
	["jsonlib.ring", "jsonlib"],
	["threads.ring", "threads"],
	["stbimage.ring", "stbimage"]
]

# Load Libraries information
	aLibsInfo = []
	LoadLibrariesInfo()
	LoadProjectConfig()

func LoadLibrariesInfo
	aLibsFiles = ListAllFiles(exefolder()+"/../tools/ring2exe/libs","ring")
	for cLibFile in aLibsFiles 
		cLibFileContent = read(cLibFile)
		if ! checkRingCode([:code = cLibFileContent])
			PrintError("The file " + cLibFile + " doesn't pass the security check!")
			loop
		ok
		eval(cLibFileContent)
		aLibsInfo + aLibrary 
	next 

func LoadProjectConfig
	# Check for ring2exe.conf in current directory
	cConfigFile = "ring2exe.conf"
	if fexists(cConfigFile)
		cContent = read(cConfigFile)
		if checkRingCode([:code = cContent])
			eval(cContent)
			try
				if isList(aProjectConfig)
					MergeConfig(aProjectConfig)
				ok
			catch
				# Variable doesn't exist or isn't a list - ignore
			done
		ok
	ok

func MergeConfig aConfig
	if aConfig[:version] != NULL G_CONFIG[:version] = aConfig[:version] ok
	if aConfig[:description] != NULL G_CONFIG[:description] = aConfig[:description] ok
	if aConfig[:maintainer] != NULL G_CONFIG[:maintainer] = aConfig[:maintainer] ok
	if aConfig[:license] != NULL G_CONFIG[:license] = aConfig[:license] ok
	if aConfig[:homepage] != NULL G_CONFIG[:homepage] = aConfig[:homepage] ok
	if aConfig[:icon] != NULL G_CONFIG[:icon] = aConfig[:icon] ok

func AutoDetectLibraries cSourceFile, aOptions
	# Scan source file for load statements and detect required libraries
	aDetected = []
	if not fexists(cSourceFile)
		return aDetected
	ok
	cContent = read(cSourceFile)
	
	for aMap in aLibList
		cLoadFile = aMap[1]
		cLibName = aMap[2]
		# Check for various load statement formats
		if substr(cContent, 'load "' + cLoadFile + '"') > 0 or
		   substr(cContent, "load '" + cLoadFile + "'") > 0 or
		   substr(cContent, 'load "' + lower(cLoadFile) + '"') > 0
			# Only add if not already in options and not excluded
			if not find(aDetected, cLibName) and not find(aOptions, "-no" + cLibName)
				aDetected + cLibName
			ok
		ok
	next
	
	return aDetected

func CommandExists cCommand
	# Check if a command exists in PATH
	if isWindows()
		cResult = SystemCmd("where " + cCommand + " 2>nul")
		return len(trim(cResult)) > 0
	else
		cResult = SystemCmd("command -v " + cCommand + " 2>/dev/null")
		return len(trim(cResult)) > 0
	ok

func systemSilentEx cCmd
	# Execute command respecting verbose/quiet settings
	if G_CONFIG[:verbose]
		if not G_CONFIG[:quiet]
			? C_DIM + "    $ " + cCmd + C_RESET
		ok
		return system(cCmd)
	else
		if isWindows()
			return system(cCmd + " > nul 2>&1")
		else
			return system(cCmd + " 2>/dev/null")
		ok
	ok

func CompressWithUPX cExecutable
	# Compress executable with UPX if available
	if not G_CONFIG[:compress]
		return false
	ok
	if CommandExists("upx")
		PrintSubStep("Compressing with UPX: " + cExecutable)
		systemSilentEx("upx --best -q " + cExecutable)
		return true
	else
		PrintWarning("UPX not found, skipping compression. Install UPX for smaller executables.")
		return false
	ok

func PrintAvailableLibraries
	# Display all available libraries
	DrawLine()
	? C_BOLD + C_BCYAN + "  Available Libraries" + C_RESET
	? C_DIM + "  Loaded from: " + exefolder() + "/../tools/ring2exe/libs/" + C_RESET
	DrawLine()
	see nl
	for aLibrary in aLibsInfo
		see "  " + C_GREEN + PadRight(aLibrary[:name], 18) + C_RESET
		? C_DIM + aLibrary[:title] + C_RESET
	next
	see nl
	? C_DIM + "  Total: " + len(aLibsInfo) + " libraries" + C_RESET
	see nl
	DrawLine()

func Main 
	aPara = sysargv
	aOptions = []
	cCompiler = ""
	cCompilerFlags = ""
	cOutputFileName = ""
	
	# Get Options
		for x = len(aPara) to 1 step -1
			cOption = trim(aPara[x])
			cOptionLower = lower(cOption)
			if left(cOptionLower,1) = "-"
				# Compiler options
				if left(cOptionLower,4) = "-cc="
					cCompiler = substr(cOption, 5)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,8) = "-cflags="
					cCompilerFlags = substr(cOption, 9)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,8) = "-output="
					cOutputFileName = substr(cOption, 9)
					aOptions + cOption
					del(aPara,x)
				# Verbose/Quiet modes
				but cOptionLower = "-verbose"
					G_CONFIG[:verbose] = true
					del(aPara,x)
				but cOptionLower = "-quiet"
					G_CONFIG[:quiet] = true
					del(aPara,x)
				# Build presets
				but cOptionLower = "-debug"
					if cCompilerFlags = ""
						cCompilerFlags = "-g -O0"
					ok
					aOptions + cOption
					del(aPara,x)
				but cOptionLower = "-release"
					if cCompilerFlags = ""
						cCompilerFlags = "-O3 -DNDEBUG"
					ok
					aOptions + cOption
					del(aPara,x)
				but cOptionLower = "-size"
					if cCompilerFlags = ""
						cCompilerFlags = "-Os"
					ok
					aOptions + cOption
					del(aPara,x)
				# Compression
				but cOptionLower = "-compress"
					G_CONFIG[:compress] = true
					aOptions + cOption
					del(aPara,x)
				# Auto-detect libraries
				but cOptionLower = "-auto-libs" or cOptionLower = "-autolibs"
					G_CONFIG[:autolibs] = true
					aOptions + cOption
					del(aPara,x)
				# Package metadata options
				but left(cOptionLower,9) = "-version="
					G_CONFIG[:version] = substr(cOption, 10)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,13) = "-description="
					G_CONFIG[:description] = substr(cOption, 14)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,12) = "-maintainer="
					G_CONFIG[:maintainer] = substr(cOption, 13)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,9) = "-license="
					G_CONFIG[:license] = substr(cOption, 10)
					aOptions + cOption
					del(aPara,x)
				but left(cOptionLower,10) = "-homepage="
					G_CONFIG[:homepage] = substr(cOption, 11)
					aOptions + cOption
					del(aPara,x)
				# Custom icon
				but left(cOptionLower,6) = "-icon="
					G_CONFIG[:icon] = substr(cOption, 7)
					aOptions + cOption
					del(aPara,x)
				# List libraries command
				but cOptionLower = "--list-libs" or cOptionLower = "-list-libs"
					PrintAvailableLibraries()
					bye
				# Help command
				but cOptionLower = "--help" or cOptionLower = "-help" or cOptionLower = "-h"
					PrintHelp()
					bye
				# Version command
				but cOptionLower = "--version" or cOptionLower = "-v"
					? "Ring2EXE Plus v" + VERSION
					bye
				else
					aOptions + cOption
					del(aPara,x)
				ok
			ok
		next
	nParaCount = len(aPara)
	if (nParaCount > 2) or ( nParaCount = 2 and aPara[1] != "ring" )
		cFile = aPara[nParaCount]
		if not fexists(cFile)
			PrintError("File " + cFile + " doesn't exist!")
			bye
		ok
		chdir(justfilepath(cFile))
		cFile = JustFileName(cFile)
		# Reload config from source file's directory (overrides initial config)
		LoadProjectConfig()
		BuildApp(cFile,aOptions,cCompiler,cCompilerFlags,cOutputFileName)
	else
		PrintHelp()
	ok

func PrintHelp
	DrawLine()
	# Title
	see C_BOLD + C_BCYAN + "  Ring2EXE Plus" + C_RESET 
	? C_DIM + " v" + VERSION + " - Convert Ring Application To Executable File" + C_RESET
	see nl
	# Credits
	? C_DIM + "  Original: " + C_RESET + "Mahmoud Fayed <msfclipper@yahoo.com> (2017-2025)"
	?  C_DIM + "  Fork by:  " + C_RESET + C_BGREEN + "Youssef Saeed" + C_RESET + " <youssefelkholey@gmail.com> (2025)"
	see nl
	# Usage
	see C_BOLD + C_WHITE + "  Usage: " + C_RESET 
	? C_YELLOW + "ring2exe " + C_CYAN + "filename.ring " + C_DIM + "[options]" + C_RESET
	DrawLine()
	see nl

	# Build Options
	PrintSection("Build Options")
	PrintOption("-keep", "Don't delete Temp. Files")
	PrintOption("-static", "Build standalone executable")
	PrintOption("-gui", "Build GUI Application")
	PrintOption("-cc=<compiler>", "Specify C compiler")
	PrintOption("-cflags=<flags>", "Specify C compiler flags")
	PrintOption("-output=<name>", "Specify output filename")
	PrintOption("-icon=<file>", "Custom application icon")
	PrintOption("-compress", "Compress executable with UPX")
	PrintOption("-auto-libs", "Auto-detect required libraries")
	see nl

	# Build Presets
	PrintSection("Build Presets")
	PrintOption("-debug", "Build with debug symbols (-g -O0)")
	PrintOption("-release", "Build optimized release (-O3)")
	PrintOption("-size", "Optimize for size (-Os)")
	see nl

	# Output Control
	PrintSection("Output Control")
	PrintOption("-verbose", "Show detailed compiler output")
	PrintOption("-quiet", "Suppress all output except errors")
	see nl

	# Distribution Options
	PrintSection("Distribution Options")
	PrintOption("-dist", "Prepare for distribution")
	PrintOption("-allruntime", "Include all libraries")
	PrintOption("-mobileqt", "Qt Project for Mobile")
	PrintOption("-webassemblyqt", "Qt Project for WebAssembly")
	see nl

	# Package Metadata
	PrintSection("Package Metadata")
	PrintOption("-version=<ver>", "Package version " + C_DIM + "(default: 1.0)" + C_RESET)
	PrintOption("-description=<t>", "Package description")
	PrintOption("-maintainer=<e>", "Maintainer email")
	PrintOption("-license=<type>", "License type " + C_DIM + "(default: MIT)" + C_RESET)
	PrintOption("-homepage=<url>", "Project homepage URL")
	see nl

	# Package Formats
	PrintSection("Package Formats " + C_DIM + "(with -dist)" + C_RESET)
	PrintOption("-scripts", "Install scripts " + C_DIM + "(default)" + C_RESET)
	PrintOption("-deb", "Debian package " + C_BBLUE + "[Linux]" + C_RESET)
	PrintOption("-rpm", "RPM package " + C_BRED + "[Linux]" + C_RESET)
	PrintOption("-appimage", "AppImage " + C_BMAGENTA + "[Linux]" + C_RESET)
	PrintOption("-flatpak", "Flatpak package " + C_BCYAN + "[Linux]" + C_RESET)
	PrintOption("-snap", "Snap package " + C_BYELLOW + "[Linux]" + C_RESET)
	PrintOption("-appbundle", "App Bundle " + C_WHITE + "[macOS]" + C_RESET)
	PrintOption("-dmg", "DMG disk image " + C_WHITE + "[macOS]" + C_RESET)
	PrintOption("-pkg", "pkg package " + C_BRED + "[FreeBSD]" + C_RESET)
	PrintOption("-nsis", "NSIS installer " + C_BBLUE + "[Windows]" + C_RESET)
	PrintOption("-inno", "Inno Setup installer " + C_BBLUE + "[Windows]" + C_RESET)
	PrintOption("-msi", "MSI installer " + C_BBLUE + "[Windows]" + C_RESET)
	see nl

	# Library Flags
	PrintSection("Library Flags")
	PrintOption("-<lib>", "Include library (e.g., " + C_GREEN + "-qt" + C_RESET + ")")
	PrintOption("-no<lib>", "Exclude library (e.g., " + C_RED + "-noqt" + C_RESET + ")")
	see nl

	# Commands
	PrintSection("Commands")
	PrintOption("--list-libs", "Show all available libraries")
	PrintOption("--help, -h", "Show this help message")
	PrintOption("--version, -v", "Show version number")
	see nl

	# Config File Info
	? C_DIM + "  Config: Place 'ring2exe.conf' in project directory for default options" + C_RESET
	see nl

	DrawLine()

func GetOutputName aOptions, cDefault
	# Helper to extract -output= value from options
	for x = len(aOptions) to 1 step -1
		cOption = lower(trim(aOptions[x]))
		if left(cOption, 8) = "-output="
			return substr(aOptions[x], 9)
		ok
	next
	return cDefault

func BuildApp cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName
	if not G_CONFIG[:quiet]
		PrintHeader("Ring2EXE Plus v" + VERSION)
		PrintStatus("Processing", cFileName)
		see nl
	ok
	
	# Auto-detect libraries if requested
	if G_CONFIG[:autolibs]
		aDetected = AutoDetectLibraries(cFileName, aOptions)
		if len(aDetected) > 0
			if not G_CONFIG[:quiet]
				PrintSubStep("Auto-detected libraries: " + list2str(aDetected))
			ok
			for cLib in aDetected
				if not find(aOptions, "-" + cLib)
					aOptions + ("-" + cLib)
				ok
			next
		ok
	ok
	
	nTotalSteps = 4
	if find(aOptions, "-dist") nTotalSteps++ ok
	if G_CONFIG[:compress] nTotalSteps++ ok

	# 1. Generate Object File
		if not G_CONFIG[:quiet]
			PrintStep(1, nTotalSteps, "Compiling to Ring Object", "")
		ok
		# Temporarily rename ring.ringo if it exists to prevent interference
		# The Ring compiler may try to load ring.ringo from the current directory
		# which can cause hangs or unexpected behavior during compilation
		lRingoRenamed = false
		if fexists("ring.ringo")
			rename("ring.ringo", "ring.ringo.tmp")
			lRingoRenamed = true
		ok
		systemSilent('"' + exefolder()+"../bin/ring" + '" ' + cFileName + " -go -norun")
		# Restore ring.ringo if we renamed it
		if lRingoRenamed and fexists("ring.ringo.tmp")
			# Only restore if the compilation didn't create a new ring.ringo
			if not fexists("ring.ringo")
				rename("ring.ringo.tmp", "ring.ringo")
			else
				# Compilation created a new ring.ringo (source was ring.ring)
				# Remove the backup as it's now outdated
				remove("ring.ringo.tmp")
			ok
		ok
		
	# 2. Generate C Source Code File
		if not G_CONFIG[:quiet]
			PrintStep(2, nTotalSteps, "Generating C Source", "")
		ok
		cFile = substr(cFileName,".ring","")
		GenerateCFile(cFile,aOptions)
		
	# 3. Generate the Batch File
		cBatchMode = "Dynamic"
		if find(aOptions,"-static") cBatchMode = "Static" ok
		if not G_CONFIG[:quiet]
			PrintStep(3, nTotalSteps, "Preparing Build Scripts", "(" + cBatchMode + ")")
		ok
		cBatch = GenerateBatch(cFile,aOptions,cCompiler,cCompilerFlags,cOutputFileName)
		
	# 4. Build the Executable File
		# Delete the output file locally if it exists (to ensure build failure detection)
		cDeleteOutput = cFile
		if cOutputFileName != ""
			cDeleteOutput = cOutputFileName
		else
			cDeleteOutput = substr(cDeleteOutput, " ", "_")
		ok
		if isWindows() cDeleteOutput += ".exe" ok
		
		if fexists(cDeleteOutput)
			remove(cDeleteOutput)
		ok

		if not G_CONFIG[:quiet]
			PrintStep(4, nTotalSteps, "Compiling & Linking", "")
		ok
		if cBatch != NULL
			if G_CONFIG[:verbose]
				system(cBatch)
			else
				if isWindows()
					systemSilent(cBatch + " 2>nul")
				else
					systemSilent(cBatch + " 2>/dev/null")
				ok
			ok
		ok
	
	# Track current step for proper numbering
	nCurrentStep = 5
		
	# Prepare Application for distribution
		if find(aOptions,"-dist")
			if not G_CONFIG[:quiet]
				PrintStep(nCurrentStep, nTotalSteps, "Preparing Distribution", "")
			ok
			nCurrentStep++
			Distribute(cFile,aOptions)
			
			# Success Message for Distribution
			if isWindows()
				cTarget = "target\windows"
			else 
				cTarget = "target/linux (or other platform output)"
				if isLinux() cTarget = "target/linux" ok
				if isMacOSX() cTarget = "target/macosx" ok
				if isFreeBSD() cTarget = "target/freebsd" ok
			ok
			
			# Clean Temp Files
			if not find(aOptions,"-keep")
				ClearTempFiles(1)
			ok

			if not G_CONFIG[:quiet]
				PrintSuccess("Distribution ready in " + cTarget)
			ok
		else
			lFallback = CheckNoCCompiler(currentdir(),cFile,aOptions)
			
			# Compress executable if requested (only if not using fallback)
			if G_CONFIG[:compress] and not lFallback
				if not G_CONFIG[:quiet]
					PrintStep(nCurrentStep, nTotalSteps, "Compressing Executable", "")
				ok
				nCurrentStep++
				CompressWithUPX(cDeleteOutput)
			ok
			
			# Clear Temp Files
			if not find(aOptions,"-keep")
				# If fallback (lFallback=True), use mode 2 (keep ringo)
				# If compiled (lFallback=False), use mode 1 (delete ringo)
				if lFallback
					ClearTempFiles(2)
				else
					ClearTempFiles(1)
				ok
			ok

			# Success Message for Executable
			cFinalOutput = GetOutputName(aOptions, cFile)
			if isWindows() 
				cFinalOutput += ".exe" 
			else
				cFinalOutput = "./" + cFinalOutput
			ok
			if not G_CONFIG[:quiet]
				PrintSuccess("Executable ready: " + cFinalOutput)
			ok
		ok

func GenerateCFile cFileName,aOptions
	# Display Message
	nTime = clock()
	# Convert the Ring Object File to Hex.
		cRingoFile = cFileName+".ringo"
		if not fexists(cRingoFile)
			PrintError("File " + cRingoFile + " doesn't exist!")
			PrintError("Check the source code files for compiler errors")
			bye
		ok
		cFile = read(cRingoFile)
		cHex  = str2hexCStyle(cFile)
	fp = fopen(cFileName+".c","w+")
	# Start writing the C source code - Main Function 
	if isWindows() and find(aOptions,"-gui")
		cCode = '#include "windows.h"' 	+ nl +
			'#include "stdio.h"' 	+ nl +
			'#include "stdlib.h"' 	+ nl +
			'#include "conio.h"' 	+ nl +  
			'#include "ring.h"' 	+ nl +  nl +
		'int WINAPI WinMain ( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd )' + nl +  "{" + nl + nl +
		char(9) + 'int argc;' + nl + char(9) + 'char **argv ;' + nl + 
		char(9) + 'argc = __argc ; ' + nl + char(9) + 'argv = __argv ;' + nl + nl +
		char(9) + 'static const unsigned char bytecode[] = { 
			  '
	else
		cCode = '#include "ring.h"' + nl + nl +
		'int main( int argc, char *argv[])' + nl +  "{" + nl + nl +
		char(9) + 'static const unsigned char bytecode[] = { 
			  '
	ok
	fputs(fp,cCode)
	# Add the Object File Content		
		fputs(fp,cHex)
	fputs(fp, ", EOF" + char(9) + "};"+substr(
	'

	RingState *pRingState ;
	pRingState = ring_state_new();	
	pRingState->nArgc = argc;
	pRingState->pArgv = argv;
	ring_state_runobjectstring(pRingState,(char *) bytecode,"#{f1}");
	ring_state_delete(pRingState);

	return 0;',"#{f1}",cFileName+".ring") + nl + 
	"}")
	fclose(fp)	
	PrintSubStep("Source generated in " + ((clock()-nTime)/clockspersecond()) + "s")

func GenerateBatch cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName
	if find(aOptions,"-static")
		return GenerateBatchStatic(cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName)
	else
		return GenerateBatchDynamic(cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName)
	ok

func GenerateBatchDynamic cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName
	return GenerateBatchGeneral([
		:file = cFileName ,
		:ringlib = [
			:windows = exefolder() + "..\lib\ring.lib" ,
			:linux   = "-L "+exefolder()+"/../lib -lring",
			:macosx	 = exefolder() + "/../lib/libring.dylib",
			:freebsd = "-L "+exefolder()+"/../lib -lring"
		]
	],aOptions,cCompiler,cCompilerFlags,cOutputFileName)

func GenerateBatchStatic cFileName,aOptions,cCompiler,cCompilerFlags,cOutputFileName
	return GenerateBatchGeneral([
		:file = cFileName ,
		:ringlib = [
			:windows = exefolder()+"..\lib\ringstatic.lib" ,
			:linux   = "-static -L "+exefolder()+"/../lib -lringstatic",
			:macosx	 = "-L "+exefolder()+"/../lib -lringstatic",
			:freebsd = "-static -L "+exefolder()+"/../lib -lringstatic"
		]
	],aOptions,cCompiler,cCompilerFlags,cOutputFileName)


func GenerateBatchGeneral aPara,aOptions,cCompiler,cCompilerFlags,cOutputFileName
	cFileName = aPara[:file]
	cFile = substr(cFileName," ","_")
	# Determine output filename
	cOutput = cFile
	if cOutputFileName != NULL
		cOutput = cOutputFileName
	ok
	# Generate Windows Batch
	if isWindows()
		cBuildtarget = getarch()
		if cBuildtarget = "unknown"
			cBuildtarget = "x86"
		ok
		cComp = "cl"
		if cCompiler != NULL
			cComp = cCompiler
		ok
		
		# Check if using MSVC (cl) or other compilers (gcc, clang, tcc)
		if cComp = "cl"
			# Visual C++ syntax
			cFlags = "/O2"
			if cCompilerFlags != NULL
				cFlags = cCompilerFlags
			ok
			cCode = "setlocal enableextensions enabledelayedexpansion" + nl + 'call "'+exefolder()+'../language/build/locatevc.bat" ' + cBuildtarget + nl +
				"#{f3}" + nl +
				cComp + ' ' + cFlags + ' "#{f1}.c" "#{f2}" #{f4} -I"#{f6}..\language\include" -I"#{f6}../language/src/" /link #{f5} /out:"#{f7}"' + nl +
				"endlocal" + nl
			# GUI Application
			if find(aOptions,"-gui")
				cLinkFlags = 'advapi32.lib shell32.lib /STACK:8388608 /SUBSYSTEM:WINDOWS,"5.01" '
			else
				cLinkFlags = ' /STACK:8388608 /SUBSYSTEM:CONSOLE,"5.01" '
			ok
		else
			# GCC/Clang/TCC syntax
			
			cFlags = "-O2"
			if cCompilerFlags != NULL
				cFlags = cCompilerFlags
			ok
			cCode = cComp + ' ' + cFlags + ' "#{f1}.c" "#{f2}" #{f4} -I"#{f6}../language/include" -I"#{f6}../language/src/" -o "#{f7}" #{f5}' + nl
			# GUI Application
			if find(aOptions,"-gui")
				cLinkFlags = '-ladvapi32 -lshell32 -mwindows'
			else
				cLinkFlags = ''
			ok
		ok
		
		cCode = substr(cCode,"#{f1}",cFile)
		cCode = substr(cCode,"#{f2}",aPara[:ringlib][:windows])
		# Resource File - Auto-generate from -icon option if no .rc exists
			cResourceFile = cFile + ".rc"
			cIconFile = G_CONFIG[:icon]
			if cIconFile != "" and not fexists(cResourceFile)
				# Auto-generate .rc file with icon
				if fexists(cIconFile)
					PrintSubStep("Generating resource file with icon: " + cIconFile)
					cRCContent = "// Auto-generated by Ring2EXE Plus" + nl
					cRCContent += "1 ICON " + '"' + cIconFile + '"' + nl
					write(cResourceFile, cRCContent)
				else
					PrintWarning("Icon file not found: " + cIconFile)
				ok
			ok
			if fexists(cResourceFile)
				if cComp = "cl"
					cCode = substr(cCode,"#{f3}","rc " + cResourceFile)
					cCode = substr(cCode,"#{f4}",cFile + ".res")
				else
					cCode = substr(cCode,"#{f3}","windres " + cResourceFile + " -o " + cFile + ".res")
					cCode = substr(cCode,"#{f4}",cFile + ".res")
				ok
			else
				cCode = substr(cCode,"#{f3}","")
				cCode = substr(cCode,"#{f4}","")
			ok
		cCode = substr(cCode,"#{f5}",cLinkFlags)
		cCode = substr(cCode,"#{f6}",exefolder())
		cCode = substr(cCode,"#{f7}",cOutput + ".exe")
		cWindowsBatch = cFile+"_build_"+JustFileName(cComp)+".bat"
		write(cWindowsBatch,cCode)
	# Generate Linux Script (GNU C/C++)
	but isLinux()
		cComp = "gcc"
		if cCompiler != NULL
			cComp = cCompiler
		ok

		cFlags = "-O2"
		if cCompilerFlags != NULL
			cFlags = cCompilerFlags
		ok
		cCode = cComp + ' ' + cFlags + ' #{f1}.c -o #{f4} #{f2} -lm -ldl  -I #{f3}/../language/include  '
		cCode = substr(cCode,"#{f1}",cFile)
		cCode = substr(cCode,"#{f2}",aPara[:ringlib][:linux])
		cCode = substr(cCode,"#{f3}",exefolder())
		cCode = substr(cCode,"#{f4}",cOutput)
		cLinuxBatch = cFile+"_build_"+JustFileName(cComp)+".sh"
		write(cLinuxBatch,cCode)
	# Generate macOS Script (CLang C/C++)
	but isMacosx()
		cComp = "clang"
		if cCompiler != NULL
			cComp = cCompiler
		ok

		cFlags = "-O2"
		if cCompilerFlags != NULL
			cFlags = cCompilerFlags
		ok
		cCode = cComp + ' ' + cFlags + ' #{f1}.c #{f2} -o #{f4} -lm -ldl  -I #{f3}/../language/include  '
		cCode = substr(cCode,"#{f1}",cFile)
		cCode = substr(cCode,"#{f2}",aPara[:ringlib][:macosx])
		cCode = substr(cCode,"#{f3}",exefolder())
		cCode = substr(cCode,"#{f4}",cOutput)
		cMacOSXBatch = cFile+"_build_"+JustFileName(cComp)+".sh"
		write(cMacOSXBatch,cCode)
	# Generate FreeBSD Script (CLang C/C++)
	but isFreeBSD()
		cComp = "clang"
		if cCompiler != NULL
			cComp = cCompiler
		ok

		cFlags = "-O2"
		if cCompilerFlags != NULL
			cFlags = cCompilerFlags
		ok
		cCode = cComp + ' ' + cFlags + ' #{f1}.c #{f2} -o #{f4} -lm -ldl  -I #{f3}/../language/include  '
		cCode = substr(cCode,"#{f1}",cFile)
		cCode = substr(cCode,"#{f2}",aPara[:ringlib][:freebsd])
		cCode = substr(cCode,"#{f3}",exefolder())
		cCode = substr(cCode,"#{f4}",cOutput)
		cFreeBSDBatch = cFile+"_build_"+JustFileName(cComp)+".sh"
		write(cFreeBSDBatch,cCode)
	ok
	# Return the script/batch file name
		if isWindows()
			return cWindowsBatch
		but isLinux()
			systemSilent("chmod +x " + cLinuxBatch)
			return "./"+cLinuxBatch
		but isMacosx()
			systemSilent("chmod +x " + cMacOSXBatch)
			return "./"+cMacOSXBatch
		but isFreeBSD()
			systemSilent("chmod +x " + cFreeBSDBatch)
			return "./"+cFreeBSDBatch
		ok

func ClearTempFiles nPara
	PrintSubStep("Cleaning temporary files...")
	
	# Get list of files to clean up
	aFiles = dir(currentdir())
	
	for aFile in aFiles
		if aFile[2] = 0
			cFileName = aFile[1]
			
			# Remove C source file
			if right(cFileName, 2) = ".c"
				cBaseName = substr(cFileName, 1, len(cFileName)-2)
				cRingoFile = cBaseName + ".ringo"
				if fexists(cRingoFile)
					remove(cFileName)
				ok
				loop
			ok
			
			# Remove build scripts based on compiler (e.g., test_build_gcc.sh, test_build_cl.bat)
			if (right(cFileName, 4) = ".bat" or right(cFileName, 3) = ".sh") and substr(cFileName, "_build_")
				remove(cFileName)
				loop
			ok
			
			# Windows-specific files
			if isWindows()
				cExt = lower(right(cFileName, 4))
				if cExt = ".obj" or cExt = ".exp" or cExt = ".lib" or cExt = ".res"
					remove(cFileName)
					loop
				ok
				# Remove auto-generated .rc files (from -icon option)
				if right(cFileName, 3) = ".rc"
					cBaseName = substr(cFileName, 1, len(cFileName)-3)
					cRingoFile = cBaseName + ".ringo"
					if fexists(cRingoFile)
						remove(cFileName)
						loop
					ok
				ok
			ok
		ok
	next

	if nPara = 1
		for aFile in aFiles
			if aFile[2] = 0
				cFileName = aFile[1]
				if right(cFileName, 6) = ".ringo"
					remove(cFileName)
				ok
			ok
		next
	ok


func Distribute cFileName,aOptions
	cBaseFolder = currentdir()
	# Get custom output filename if specified
	cOutput = GetOutputName(aOptions, cFileName)
	OSCreateOpenFolder(:target)
	if find(aOptions,"-mobileqt")
		# Prepare Application for Mobile (RingQt)
		DistributeForMobileQt(cBaseFolder,cFileName,aOptions)
	but find(aOptions,"-webassemblyqt")
		# Prepare Application for WebAssembly (RingQt)
		DistributeForWebAssemblyQt(cBaseFolder,cFileName,aOptions)
	but isWindows()
		DistributeForWindows(cBaseFolder,cFileName,aOptions)
	but isLinux()
		DistributeForLinux(cBaseFolder,cFileName,aOptions)
	but isMacOSX()
		DistributeForMacOSX(cBaseFolder,cFileName,aOptions)
	but isFreeBSD()
		DistributeForFreeBSD(cBaseFolder,cFileName,aOptions)
	ok
	# Delete the executable file
		if isWindows()
			cFileForDel = cBaseFolder+"\"+cOutput+".exe"
			if fexists(cFileForDel) remove(cFileForDel) ok
		else
			cFileForDel = cBaseFolder+"/"+cOutput
			if fexists(cFileForDel) remove(cFileForDel) ok
		ok
	chdir(cBaseFolder)

func DistributeForWindows cBaseFolder,cFileName,aOptions
	# Delete Files 
	if direxists(:windows)
		OSDeleteFolder(:windows)
	ok
	OSCreateOpenFolder(:windows)
	cWindowsDir = currentdir()
	cOutput = GetOutputName(aOptions, cFileName)
	
	# Create dist_using_scripts for base files (like Linux structure)
	OSCreateOpenFolder("dist_using_scripts")
	cScriptsDir = currentdir()
	
	# copy the executable file
		PrintSubStep("Copying executable to target/windows/dist_using_scripts")
		cSrcFile = cBaseFolder+"\"+cOutput+".exe"
		if fexists(cSrcFile)
			OSCopyFile(cSrcFile)
		ok
		CheckNoCCompiler(cBaseFolder,cFileName,aOptions)
	# Check ring.dll
		if not find(aOptions,"-static")	
			PrintSubStep("Copying ring.dll to target/windows/dist_using_scripts")	
			OSCopyFile(exefolder()+"\ring.dll")
		ok
	# Check All Runtime 
		if find(aOptions,"-allruntime")	
			PrintSubStep("Copying all libraries to target/windows/dist_using_scripts")	
			for aLibrary in aLibsInfo 
				if not find(aOptions,"-no"+aLibrary[:name])
					PrintSubStep("Copying library files: "+aLibrary[:title])
					if islist(aLibrary[:windowsfolders])
						for cLibFolder in aLibrary[:windowsfolders]
							PrintSubStep("Copying folder: "+cLibFolder)
							OSCopyFolder(exefolder(),cLibFolder)
						next
					ok
					if islist(aLibrary[:windowsfiles])
						for cLibFile in aLibrary[:windowsfiles]
							PrintSubStep("Copying file: "+cLibFile)
							custom_OSCopyFile(exefolder(),cLibFile)
						next
					ok
				else 
					PrintSubStep("Skipping library "+aLibrary[:title])
				ok
			next  	
		else	# No -allruntime
			for aLibrary in aLibsInfo 
				if find(aOptions,"-"+aLibrary[:name])
					PrintSubStep("Adding "+aLibrary[:title]+" to target/windows/dist_using_scripts")
					if islist(aLibrary[:windowsfolders])
						for cLibFolder in aLibrary[:windowsfolders]
							PrintSubStep("Copying folder: "+cLibFolder)
							OSCopyFolder(exefolder(),cLibFolder)
						next
					ok
					if islist(aLibrary[:windowsfiles])
						for cLibFile in aLibrary[:windowsfiles]
							PrintSubStep("Copying file: "+cLibFile)
							custom_OSCopyFile(exefolder(),cLibFile)
						next
					ok
				ok
			next 				
		ok
	# Copy Files (Images, etc) in Resources File
		CheckQtResourceFile(cBaseFolder,cFileName,aOptions)
	
	
	# Return to windows directory for installer generation
	chdir(cWindowsDir)
	
	# Generate Windows installers
	if ShouldGeneratePackage(aOptions, "nsis")
		CreateNSISInstaller(cOutput, aOptions, cWindowsDir)
	ok
	
	if ShouldGeneratePackage(aOptions, "inno")
		CreateInnoInstaller(cOutput, aOptions, cWindowsDir)
	ok
	
	if ShouldGeneratePackage(aOptions, "msi")
		CreateMSIInstaller(cOutput, aOptions, cWindowsDir)
	ok

func ShouldGeneratePackage aOptions, cPackageType
	# Check if any specific package format flag is provided
	lHasSpecificFlag = find(aOptions,"-scripts") or find(aOptions,"-deb") or
	                   find(aOptions,"-rpm") or find(aOptions,"-appimage") or
	                   find(aOptions,"-flatpak") or find(aOptions,"-snap") or
	                   find(aOptions,"-appbundle") or find(aOptions,"-dmg") or
	                   find(aOptions,"-pkg") or find(aOptions,"-nsis") or
	                   find(aOptions,"-inno") or find(aOptions,"-msi")
	if lHasSpecificFlag
		# User specified explicit package types
		return find(aOptions, "-" + cPackageType)
	else
		# Default behavior: only generate scripts
		return cPackageType = "scripts"
	ok

func DistributeForLinux cBaseFolder,cFileName,aOptions
	# Delete Files
	if direxists(:linux)
		OSDeleteFolder(:linux)
	ok
	OSCreateOpenFolder(:linux)
	cLinuxDir = currentdir()
	cAppName = substr(cFileName," ","_")
	cDebDir = ""
	cRpmDir = ""
	# Conditionally create package directories
	if ShouldGeneratePackage(aOptions, "deb")
		OSCreateOpenFolder("dist_using_deb_package")
		cDebDir = currentdir()
		chdir(cLinuxDir)
	ok
	if ShouldGeneratePackage(aOptions, "rpm")
		OSCreateOpenFolder("dist_using_rpm_package")
		cRpmDir = currentdir()
		chdir(cLinuxDir)
	ok
	# Always create scripts directory (needed as base for other packages too)
	OSCreateOpenFolder("dist_using_scripts")
	cDir = currentdir()
	OSCreateOpenFolder(:bin)
	# copy the executable file
		PrintSubStep("Copying executable to target/linux/bin")
		cOutput = GetOutputName(aOptions, cFileName)
		cSrcFile = cBaseFolder+"/"+cOutput
		if fexists(cSrcFile)
			OSCopyFile(cSrcFile)
		ok
		CheckNoCCompiler(cBaseFolder,cFileName,aOptions)
	# Copy Files (Images, etc) in Resources File
		CheckQtResourceFile(cBaseFolder,cFileName,aOptions)
	chdir(cDir)
	OSCreateOpenFolder(:lib)
	cInstallUbuntu = "sudo apt-get install"
	cInstallFedora = "sudo dnf install"
	cInstallLibs   = ""
	cDebianPackageDependency = ""
	# Check ring.so
		if not find(aOptions,"-static")	
			PrintSubStep("Copying libring.so to target/linux/lib")	
			OSCopyFile(exefolder()+"/../lib/libring.so")
		ok
		cInstallLibs = InstallLibLinux(cInstallLibs,"libring.so")
	# Check All Runtime 
		if find(aOptions,"-allruntime")	
			PrintSubStep("Copying all libraries to target/linux/lib")
			OSCopyFile(exefolder()+"/../lib/libring.so")	
			for aLibrary in aLibsInfo 
				if not find(aOptions,"-no"+aLibrary[:name])
					if islist(aLibrary[:linuxfiles])
						for cLibFile in aLibrary[:linuxfiles]
							PrintSubStep("Copying file: "+cLibFile)
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)					
							cInstallLibs = InstallLibLinux(cInstallLibs,cLibFile)
						next
					ok
					cInstallUbuntu += (" " + aLibrary[:ubuntudep])
					cInstallFedora += (" " + aLibrary[:fedoradep])
					if aLibrary[:ubuntudep] != NULL
						cDebianPackageDependency += (" " + aLibrary[:ubuntudep])			
					ok
				else 
					PrintSubStep("Skipping library "+aLibrary[:title])
				ok
			next  	
		else	# No -allruntime
			for aLibrary in aLibsInfo 
				if find(aOptions,"-"+aLibrary[:name])
					PrintSubStep("Adding "+aLibrary[:title]+" to target/linux/lib")
					if islist(aLibrary[:linuxfiles])
						for cLibFile in aLibrary[:linuxfiles]
							PrintSubStep("Copying file: "+cLibFile)
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)
							cInstallLibs = InstallLibLinux(cInstallLibs,cLibFile)
						next
					ok
					cInstallUbuntu += (" " + aLibrary[:ubuntudep])
					cInstallFedora += (" " + aLibrary[:fedoradep])					
					if aLibrary[:ubuntudep] != NULL
						cDebianPackageDependency += (" " + aLibrary[:ubuntudep])			
					ok
				ok
			next 				
		ok
	# Script to install the application
	chdir(cDir)
	# Create installation script content
	cInstallApp = "
	echo 'Installing application...'
	sudo mkdir -p /usr/local/bin
	sudo mkdir -p /usr/local/lib
	sudo cp -r bin/* /usr/local/bin/
	echo 'Executable installed to /usr/local/bin/'
	" + cInstallLibs + "
	echo 'Installation completed successfully!'
	echo 'You can now run: " + cOutput + "'
	"
	cInstallApp = RemoveFirstTabs(cInstallApp,1)
	
	# Always create installation scripts with full installation commands
	if cInstallUbuntu != "sudo apt-get install"
		cInstallUbuntu += nl + cInstallApp
	else
		cInstallUbuntu = "#!/bin/bash" + nl + "echo 'Installing dependencies...'" + nl + "echo 'No additional dependencies required.'" + nl + cInstallApp
	ok
	write("install_ubuntu.sh",cInstallUbuntu)
	SystemSilent("chmod +x install_ubuntu.sh")
	
	if cInstallFedora != "sudo dnf install"
		cInstallFedora += nl + cInstallApp
	else
		cInstallFedora = "#!/bin/bash" + nl + "echo 'Installing dependencies...'" + nl + "echo 'No additional dependencies required.'" + nl + cInstallApp
	ok
	write("install_fedora.sh",cInstallFedora)
	SystemSilent("chmod +x install_fedora.sh")
	# Create the AppImage package
	if ShouldGeneratePackage(aOptions, "appimage")
		chdir(cLinuxDir)
		CreateAppImage(cOutput, aOptions)
	ok
	
	# Create the debian package
	if ShouldGeneratePackage(aOptions, "deb")
	PrintSubStep("Preparing files to create the Debian package")
	chdir(cDebDir)
	# Get custom output filename for package name
	cPackageName = cAppName
	cPackageName = GetOutputName(aOptions, cPackageName)
	cPackageName = substr(cPackageName," ","_")
	# Build version string for folder name (e.g., "2.0.0-1")
	cDebVersion = G_CONFIG[:version] + "-1"
	cBuildDeb = "dpkg-deb --build #{f1}_#{f2}"
	cBuildDeb = substr(cBuildDeb,"#{f1}",cPackageName)
	cBuildDeb = substr(cBuildDeb,"#{f2}",cDebVersion)
	write("builddeb.sh",cBuildDeb)
	SystemSilent("chmod +x builddeb.sh")
	OSCreateOpenFolder(cPackageName+"_"+cDebVersion)
	cAppFolder = currentdir()
	OSCreateOpenFolder("DEBIAN")
	cControl = RemoveFirstTabs("Package: #{f1}
		Version: " + G_CONFIG[:version] + "-1
		Section: base
		Priority: optional
		Architecture: #{f3}
		Depends: #{f2}
		Maintainer: " + G_CONFIG[:maintainer] + "
		Homepage: " + G_CONFIG[:homepage] + "
		Description: " + G_CONFIG[:description],2) + nl
	cDebianPackageDependency = trim(cDebianPackageDependency)
	if cDebianPackageDependency != NULL
		cDebianPackageDependency = substr(cDebianPackageDependency," "," (>=0) ,")
		cDebianPackageDependency += " (>=0) "
	ok
	cControl = substr(cControl,"#{f1}",cPackageName)
	cControl = substr(cControl,"#{f2}",cDebianPackageDependency)
	cControl = substr(cControl,"#{f3}",GetPackageArch("deb"))
	write("control",cControl)
	chdir(cAppFolder)
	OSCreateOpenFolder("usr")
		cUsrFolder = currentdir()
		OSCreateOpenFolder("bin")
		chdir(cUsrFolder)
		OSCreateOpenFolder("lib")
	chdir(cAppFolder)
	systemSilent("cp -a ../../dist_using_scripts/lib/. usr/lib/")
	systemSilent("cp -a ../../dist_using_scripts/bin/. usr/bin/")
	ok
	
	# Create the RPM package
	if ShouldGeneratePackage(aOptions, "rpm")
		PrintSubStep("Preparing files to create the RPM package")
		chdir(cRpmDir)
		# Get custom output filename for package name
		cRpmPackageName = cAppName
		cRpmPackageName = GetOutputName(aOptions, cRpmPackageName)
		cRpmPackageName = substr(cRpmPackageName," ","_")
		cBuildRpm = "rpmbuild -bb --define '_topdir #{f1}' --define '_builddir #{f1}/BUILD' --define '_rpmdir #{f1}/RPMS' --define '_sourcedir #{f1}/SOURCES' --define '_specdir #{f1}/SPECS' --define '_srcrpmdir #{f1}/SRPMS' --target #{f3} #{f2}.spec"
		cBuildRpm = substr(cBuildRpm,"#{f1}",currentdir())
		cBuildRpm = substr(cBuildRpm,"#{f2}",cRpmPackageName)
		cBuildRpm = substr(cBuildRpm,"#{f3}",GetPackageArch("rpm"))
		write("buildrpm.sh",cBuildRpm)
		SystemSilent("chmod +x buildrpm.sh")
		
		# Create RPM directory structure
		OSCreateOpenFolder("BUILD")
		chdir(cRpmDir)
		OSCreateOpenFolder("RPMS")
		chdir(cRpmDir)
		OSCreateOpenFolder("SOURCES")
		chdir(cRpmDir)
		OSCreateOpenFolder("SPECS")
		chdir(cRpmDir)
		OSCreateOpenFolder("SRPMS")
		chdir(cRpmDir)
		OSCreateOpenFolder("BUILDROOT")
		cRpmVersion = G_CONFIG[:version] + "-1"
		cBuildRootDir = currentdir() + "/" + cRpmPackageName + "-" + cRpmVersion + "." + GetPackageArch("rpm")
		OSCreateOpenFolder(cRpmPackageName + "-" + cRpmVersion + "." + GetPackageArch("rpm"))
		chdir(cBuildRootDir)
		OSCreateOpenFolder("usr")
		chdir(cBuildRootDir + "/usr")
		OSCreateOpenFolder("bin")
		chdir(cBuildRootDir + "/usr/bin")
		# Copy executable and potential ring.ringo
		OSCopyFile(cLinuxDir + "/dist_using_scripts/bin/" + cOutput)
		if fexists(cLinuxDir + "/dist_using_scripts/bin/ring.ringo")
			OSCopyFile(cLinuxDir + "/dist_using_scripts/bin/ring.ringo")
		ok
		chdir(cBuildRootDir + "/usr")
		OSCreateOpenFolder("lib64")
		chdir(cBuildRootDir + "/usr/lib64")
		# Copy libraries
		systemSilent("cp -a " + cLinuxDir + "/dist_using_scripts/lib/. .")
		
		# Generate RPM dependencies list
		cRpmRequires = ""
		if find(aOptions,"-allruntime")
			for aLibrary in aLibsInfo
				if not find(aOptions,"-no"+aLibrary[:name])
					if aLibrary[:fedoradep] != NULL
						if len(cRpmRequires) > 0 cRpmRequires += ", " ok
						cRpmRequires += aLibrary[:fedoradep]
					ok
				ok
			next
		else	# No -allruntime
			for aLibrary in aLibsInfo
				if find(aOptions,"-"+aLibrary[:name])
					if aLibrary[:fedoradep] != NULL
						if cRpmRequires != NULL cRpmRequires += ", " ok
						cRpmRequires += aLibrary[:fedoradep]
					ok
				ok
			next
		ok
		
		# Generate RPM spec file
		chdir(cRpmDir)
		# Build requires line conditionally
		cRequiresLine = ""
		if len(cRpmRequires) > 0
			cRequiresLine = "Requires: " + cRpmRequires + nl
		ok
		
		# Prepare files list for Spec
		cSpecFiles = "/usr/bin/" + cOutput + nl
		if fexists(cLinuxDir + "/dist_using_scripts/bin/ring.ringo")
			cSpecFiles += "/usr/bin/ring.ringo" + nl
		ok
		cSpecFiles += "/usr/lib64/*"
		
		cRpmSpec = RemoveFirstTabs("Name: #{f1}
			Version: " + G_CONFIG[:version] + "
			Release: 1%{?dist}
			Summary: " + G_CONFIG[:description] + "
			License: " + G_CONFIG[:license] + "
			URL: " + G_CONFIG[:homepage] + "
			BuildArch: %{_arch}
			Prefix: /usr
			AutoReq: no
			#{f2}
			%description
			Ring Application built with Ring2EXE
			
			%files
			#{f5}
			
			%changelog
			* #{f4}
			- Initial RPM package
		",3)
		
		# Get current date for changelog
		aTimeList = TimeList()
		cCurrentDate = aTimeList[1] + " " + aTimeList[3] + " " + aTimeList[6] + " " + aTimeList[19]
		
		# Format: * Day Mon DD YYYY Name <email> - Version-Release
		cChangelogLine = cCurrentDate + " " + G_CONFIG[:maintainer] + " - " + G_CONFIG[:version] + "-1"
		
		cRpmSpec = substr(cRpmSpec,"#{f1}",cRpmPackageName)
		cRpmSpec = substr(cRpmSpec,"#{f2}",cRequiresLine)
		cRpmSpec = substr(cRpmSpec,"#{f3}",cOutput)
		cRpmSpec = substr(cRpmSpec,"#{f4}",cChangelogLine)
		cRpmSpec = substr(cRpmSpec,"#{f5}",cSpecFiles)
		write(cRpmPackageName + ".spec",cRpmSpec)
	ok
	
	# Create Flatpak package
	if ShouldGeneratePackage(aOptions, "flatpak")
		chdir(cLinuxDir)
		CreateFlatpak(cOutput, aOptions, cLinuxDir)
	ok
	
	# Create Snap package
	if ShouldGeneratePackage(aOptions, "snap")
		chdir(cLinuxDir)
		CreateSnap(cOutput, aOptions, cLinuxDir)
	ok

func InstallLibLinux cInstallLib,cLibFile 
	cCode = "
		if [ -f lib/#{f1} ];
		then
			sudo cp lib/#{f1} /usr/lib
			sudo cp lib/#{f1} /usr/lib64
		fi
	"
	cCode = SubStr(cCode,"#{f1}",cLibFile)
	cCode = RemoveFirstTabs(cCode,2)
	return cInstallLib + cCode

func RemoveFirstTabs cString,nCount
	aList = str2list(cString)
	for item in aList 
		if left(item,nCount) = Copy(char(9),nCount)
			if len(item) > nCount
				item = substr(item,nCount+1)
			ok
		ok
	next
	return list2str(aList)

func DistributeForMacOSX cBaseFolder,cFileName,aOptions
	# Delete Files
	if direxists(:macosx)
		OSDeleteFolder(:macosx)
	ok
	OSCreateOpenFolder(:macosx)
	cMacosxDir = currentdir()
	OSCreateOpenFolder("dist_using_scripts")
	cDistScriptsDir = currentdir()
	OSCreateOpenFolder(:bin)
	# copy the executable file
		PrintSubStep("Copying executable to target/macosx/dist_using_scripts/bin")
		cOutput = GetOutputName(aOptions, cFileName)
		cSrcFile = cBaseFolder+"/"+cOutput
		if fexists(cSrcFile)
			OSCopyFile(cSrcFile)
		ok
		CheckNoCCompiler(cBaseFolder,cFileName,aOptions)
	# Copy Files (Images, etc) in Resources File
		CheckQtResourceFile(cBaseFolder,cFileName,aOptions)
	chdir(cDistScriptsDir)
	OSCreateOpenFolder(:lib)
	cInstallmacosx = "brew install -k"
	cInstallLibs   = ""
	# Check ring.dylib
		if not find(aOptions,"-static")
			PrintSubStep("Copying libring.dylib to target/macosx/dist_using_scripts/lib")
			OSCopyFile(exefolder()+"/../lib/libring.dylib")
		ok
		cInstallLibs = InstallLibMacOSX(cInstallLibs,"libring.dylib")
	# Check All Runtime
		if find(aOptions,"-allruntime")
			PrintSubStep("Copying all libraries to target/macosx/dist_using_scripts/lib")
			OSCopyFile(exefolder()+"/../lib/libring.dylib")
			for aLibrary in aLibsInfo
				if not find(aOptions,"-no"+aLibrary[:name])
					if islist(aLibrary[:macosxfiles])
						for cLibFile in aLibrary[:macosxfiles]
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)
							cInstallLibs = InstallLibMacOSX(cInstallLibs,cLibFile)
						next
					ok
					cInstallmacosx += (" " + aLibrary[:macosxdep])
				else
					PrintSubStep("Skipping library "+aLibrary[:title])
				ok
			next
		else	# No -allruntime
			for aLibrary in aLibsInfo
				if find(aOptions,"-"+aLibrary[:name])
					PrintSubStep("Adding "+aLibrary[:title]+" to target/macosx/dist_using_scripts/lib")
					if islist(aLibrary[:macosxfiles])
						for cLibFile in aLibrary[:macosxfiles]
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)
							cInstallLibs = InstallLibMacOSX(cInstallLibs,cLibFile)
						next
					ok
					cInstallmacosx += (" " + aLibrary[:macosxdep])
				ok
			next
		ok
	# Script to install the application
	chdir(cMacosxDir+"/dist_using_scripts")
	cInstallApp = "
	echo 'Installing application...'
	sudo mkdir -p /usr/local/bin
	sudo mkdir -p /usr/local/lib
	sudo cp bin/" + cOutput + " /usr/local/bin/
	echo 'Executable installed to /usr/local/bin/" + cOutput + "'
	" + cInstallLibs + "
	echo 'Installation completed successfully!'
	echo 'You can now run: " + cOutput + "'
	"
	cInstallApp = RemoveFirstTabs(cInstallApp,1)
	if cInstallmacosx != "brew install -k"
		cInstallmacosx += nl + cInstallApp
	else
		cInstallmacosx = "#!/bin/bash" + nl + "echo 'Installing dependencies...'" + nl + "echo 'No additional dependencies required.'" + nl + cInstallApp
	ok
	write("install.sh",cInstallmacosx)
	SystemSilent("chmod +x install.sh")
	
	# Create App Bundle with distribution (if -appbundle flag is specified or no specific flags)
	if ShouldGeneratePackage(aOptions, "appbundle")
		chdir(cMacosxDir)
		CreateAppBundle(cOutput, aOptions)
	ok
	
	# Create DMG disk image (requires appbundle to be created first)
	if ShouldGeneratePackage(aOptions, "dmg")
		# Ensure appbundle exists first
		if not ShouldGeneratePackage(aOptions, "appbundle")
			chdir(cMacosxDir)
			CreateAppBundle(cOutput, aOptions)
		ok
		chdir(cMacosxDir)
		CreateDMG(cOutput, aOptions, cMacosxDir)
	ok

func InstallLibMacOSX cInstallLib,cLibFile
	cCode = "
		if [ -f lib/#{f1} ];
		then
			sudo cp lib/#{f1} /usr/local/lib
		fi
	"
	cCode = SubStr(cCode,"#{f1}",cLibFile)
	cCode = RemoveFirstTabs(cCode,2)
	return cInstallLib + cCode

func InstallLibFreeBSD cInstallLib,cLibFile
	cCode = "
		if [ -f lib/#{f1} ];
		then
			sudo cp lib/#{f1} /usr/local/lib
		fi
	"
	cCode = SubStr(cCode,"#{f1}",cLibFile)
	cCode = RemoveFirstTabs(cCode,2)
	return cInstallLib + cCode

func DistributeForFreeBSD cBaseFolder,cFileName,aOptions
	cAppName = substr(cFileName," ","_")
	# Delete Files
	if direxists(:freebsd)
		OSDeleteFolder(:freebsd)
	ok
	OSCreateOpenFolder(:freebsd)
	cFreeBSDDir = currentdir()
	cPkgDir = ""
	# Conditionally create pkg directory
	if ShouldGeneratePackage(aOptions, "pkg")
		OSCreateOpenFolder("dist_using_pkg")
		cPkgDir = currentdir()
		chdir(cFreeBSDDir)
	ok
	# Always create scripts directory
	OSCreateOpenFolder("dist_using_scripts")
	cDir = currentdir()
	OSCreateOpenFolder(:bin)
	# copy the executable file
		PrintSubStep("Copying executable to target/freebsd/dist_using_scripts/bin")
		cOutput = GetOutputName(aOptions, cAppName)
		cSrcFile = cBaseFolder+"/"+cOutput
		if fexists(cSrcFile)
			OSCopyFile(cSrcFile)
		ok
		CheckNoCCompiler(cBaseFolder,cFileName,aOptions)
	# Copy Files (Images, etc) in Resources File
		CheckQtResourceFile(cBaseFolder,cAppName,aOptions)
	chdir(cDir)
	OSCreateOpenFolder(:lib)
	cInstallFreeBSD = "sudo pkg install -y"
	cInstallLibs   = ""
	cPkgDepString = ""
	# Check libring.so
		if not find(aOptions,"-static")
			PrintSubStep("Copying libring.so to target/freebsd/dist_using_scripts/lib")
			OSCopyFile(exefolder()+"/../lib/libring.so")
		ok
		cInstallLibs = InstallLibFreeBSD(cInstallLibs,"libring.so")
	# Check All Runtime
		if find(aOptions,"-allruntime")
			PrintSubStep("Copying all libraries to target/freebsd/dist_using_scripts/lib")
			OSCopyFile(exefolder()+"/../lib/libring.so")
			for aLibrary in aLibsInfo
				if not find(aOptions,"-no"+aLibrary[:name])
					if islist(aLibrary[:freebsdfiles])
						for cLibFile in aLibrary[:freebsdfiles]
							PrintSubStep("Copying file: "+cLibFile)
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)
							cInstallLibs = InstallLibFreeBSD(cInstallLibs,cLibFile)
						next
					else
						if islist(aLibrary[:linuxfiles])
							for cLibFile in aLibrary[:linuxfiles]
								PrintSubStep("Copying file: "+cLibFile)
								OSCopyFile(exefolder()+"/../lib/"+cLibFile)
								cInstallLibs = InstallLibFreeBSD(cInstallLibs,cLibFile)
							next
						ok
					ok
					if aLibrary[:freebsddep] != NULL
						cInstallFreeBSD += (" " + aLibrary[:freebsddep])
						if cPkgDepString != NULL cPkgDepString += "," ok
						cPkgDepString += '"' + aLibrary[:freebsddep] + '": { "origin": "misc/' + aLibrary[:freebsddep] + '" }'
					ok
				else
					PrintSubStep("Skipping library "+aLibrary[:title])
				ok
			next
		else	# No -allruntime
			for aLibrary in aLibsInfo
				if find(aOptions,"-"+aLibrary[:name])
					PrintSubStep("Adding "+aLibrary[:title]+" to target/freebsd/dist_using_scripts/lib")
					if islist(aLibrary[:freebsdfiles])
						for cLibFile in aLibrary[:freebsdfiles]
							PrintSubStep("Copying file: "+cLibFile)
							OSCopyFile(exefolder()+"/../lib/"+cLibFile)
							cInstallLibs = InstallLibFreeBSD(cInstallLibs,cLibFile)
						next
					else
						if islist(aLibrary[:linuxfiles])
							for cLibFile in aLibrary[:linuxfiles]
								PrintSubStep("Copying file: "+cLibFile)
								OSCopyFile(exefolder()+"/../lib/"+cLibFile)
								cInstallLibs = InstallLibFreeBSD(cInstallLibs,cLibFile)
							next
						ok
					ok
					if aLibrary[:freebsddep] != NULL
						cInstallFreeBSD += (" " + aLibrary[:freebsddep])
						if cPkgDepString != NULL cPkgDepString += "," ok
						cPkgDepString += '"' + aLibrary[:freebsddep] + '": { "origin": "misc/' + aLibrary[:freebsddep] + '" }'
					ok
				ok
			next
		ok
	# Script to install the application
	chdir(cDir)
	if cInstallFreeBSD != "sudo pkg install -y"
		cInstallFreeBSD += (nl+cInstallLibs)
		write("install.sh",cInstallFreeBSD)
		SystemSilent("chmod +x install.sh")
	ok
	# Create the pkg package
	if ShouldGeneratePackage(aOptions, "pkg")
	PrintSubStep("Preparing files to create the pkg package")
	chdir(cPkgDir)
	cBuildPkg = "pkg create -m . -r stage -o ."
	write("buildpkg.sh",cBuildPkg)
	SystemSilent("chmod +x buildpkg.sh")
	OSCreateOpenFolder("stage")
	chdir(cPkgDir+"/stage")
	OSCreateOpenFolder("usr")
	chdir(cPkgDir+"/stage/usr")
	OSCreateOpenFolder("local")
	chdir(cPkgDir+"/stage/usr/local")
	cLocalDir = currentdir()
	OSCreateOpenFolder("bin")
	chdir(cLocalDir+"/bin")
	cOutput = GetOutputName(aOptions, cAppName)
	OSCopyFile(cFreeBSDDir+"/dist_using_scripts/bin/"+cOutput)
	# Copy ring.ringo if it exists (for fallback execution without C compiler)
	if fexists(cFreeBSDDir+"/dist_using_scripts/bin/ring.ringo")
		OSCopyFile(cFreeBSDDir+"/dist_using_scripts/bin/ring.ringo")
	ok
	chdir(cLocalDir)
	OSCreateOpenFolder("lib")
	chdir(cLocalDir+"/lib")
	systemSilent("cp -a "+cFreeBSDDir+"/dist_using_scripts/lib/. .")
	chdir(cPkgDir)
	# Generate files list
	# Get custom output filename for FreeBSD package
	cPkgExecName = cOutput
	cFilesString = '"/usr/local/bin/' + cPkgExecName + '": "0755"'
	# Include ring.ringo in package if it exists
	if fexists(cFreeBSDDir+"/dist_using_scripts/bin/ring.ringo")
		cFilesString += ',"/usr/local/bin/ring.ringo": "0644"'
	ok
	cLibDir = cFreeBSDDir+"/dist_using_scripts/lib/"
	aLibFiles = dir(cLibDir)
	for item in aLibFiles
		if not item[1]
			cLibFile = item[2]
			if cLibFile = "." or cLibFile = ".." continue ok
			cFilesString += ',"/usr/local/lib/' + cLibFile + '": "0644"'
		ok
	next
	# Generate +MANIFEST
	cDesc = G_CONFIG[:description]
	cManifest = '
{
	"name": "' + cPkgExecName + '",
	"version": "' + G_CONFIG[:version] + '",
	"origin": "misc/' + cPkgExecName + '",
	"arch": "' + GetPackageArch("pkg") + '",
	"comment": "' + G_CONFIG[:description] + '",
	"desc": "' + cDesc + '",
	"maintainer": "' + G_CONFIG[:maintainer] + '",
	"www": "' + G_CONFIG[:homepage] + '",
	"prefix": "/usr/local",
	"licenselogic": "single",
	"licenses": [ "' + G_CONFIG[:license] + '" ],
	"files": {
		' + cFilesString + '
	},
	"deps": {
		' + cPkgDepString + '
	}
}
'
	write("+MANIFEST", cManifest)
	write("+DESC", cDesc)
	ok

func DistributeForMobileQt cBaseFolder,cFileName,aOptions
	PrintSubStep("Preparing RingQt project to distribute for Mobile")
	# Get custom output filename if specified
	cOutput = GetOutputName(aOptions, cFileName)
	# Delete Files
	if(direxists(:mobile))
		OSDeleteFolder(:mobile)
	ok
	OSCreateOpenFolder(:mobile)
	OSCreateOpenFolder(:qtproject)
	PrintSubStep("Copying RingQt for Mobile project files...")
	OSCopyFile(exefolder() + "../extensions/android/ringqt/project/*.*" )
	if fexists("project.pro.user")
		remove("project.pro.user")
	ok
	PrintSubStep("Preparing the Ring Object (*.ringo) file...")
	remove("ringapp.ring")
	remove("ringapp.ringo")
	# Use original filename for .ringo file (generated by Ring compiler)
	cRINGOFile = cBaseFolder+"/"+cFileName+".ringo"
	PrintSubStep("Getting the Ring Object File")
	OSCopyFile(cRINGOFile)
	# But use custom output name in Qt project files
	cProjectRingoName = cOutput+".ringo"
	# Only rename if the names are different
	if cFileName+".ringo" != cProjectRingoName
		rename(cFileName+".ringo", cProjectRingoName)
	ok
	write("main.cpp",substr(read("main.cpp"),"ringapp.ringo",cProjectRingoName))
	write("project.qrc",substr(read("project.qrc"),"ringapp.ringo",cProjectRingoName))
	CheckQtResourceFile(cBaseFolder,cOutput,aOptions)
	cMainFile = cBaseFolder+"/"+"main.cpp"
	if fexists(cMainFile)
		PrintSubStep("We have the Main File : " + cMainFile)
		PrintSubStep("Copying the Main file to target/mobile/qtproject")
		remove("main.cpp")
		OSCopyFile(cMainFile)
	ok
	PrintSubStep("Copying Ring and RingQt folders...")
	if isWindows()
		OSCopyFolder(exefolder() + "..\extensions\android\ringqt\project\","ring" )
		OSCopyFolder(exefolder() + "..\extensions\android\ringqt\project\","ringqt" )
	else
		OSCopyFolder(exefolder() + "../extensions/android/ringqt/project/","ring" )
		OSCopyFolder(exefolder() + "../extensions/android/ringqt/project/","ringqt" )
	ok

func DistributeForWebAssemblyQt cBaseFolder,cFileName,aOptions
	PrintSubStep("Preparing RingQt project to distribute for Web (WebAssembly)")
	# Get custom output filename if specified
	cOutput = GetOutputName(aOptions, cFileName)
	# Delete Files
	if(direxists(:webassembly))
		OSDeleteFolder(:webassembly)
	ok
	OSCreateOpenFolder(:webassembly)
	OSCreateOpenFolder(:qtproject)
	PrintSubStep("Copying RingQt for WebAssembly project files...")
	OSCopyFile(exefolder() + "../extensions/webassembly/ringqt/project/*.*" )
	if fexists("project.pro.user")
		remove("project.pro.user")
	ok
	PrintSubStep("Preparing the Ring Object (*.ringo) file...")
	remove("ringapp.ring")
	remove("ringapp.ringo")
	# Use original filename for .ringo file (generated by Ring compiler)
	cRINGOFile = cBaseFolder+"/"+cFileName+".ringo"
	PrintSubStep("Getting the Ring Object File")
	OSCopyFile(cRINGOFile)
	# But use custom output name in Qt project files
	cProjectRingoName = cOutput+".ringo"
	# Only rename if the names are different
	if cFileName+".ringo" != cProjectRingoName
		rename(cFileName+".ringo", cProjectRingoName)
	ok
	write("main.cpp",substr(read("main.cpp"),"ringapp.ringo",cProjectRingoName))
	write("project.qrc",substr(read("project.qrc"),"ringapp.ringo",cProjectRingoName))
	CheckQtResourceFile(cBaseFolder,cOutput,aOptions)
	cMainFile = cBaseFolder+"/"+"main.cpp"
	if fexists(cMainFile)
		PrintSubStep("We have the Main File : " + cMainFile)
		PrintSubStep("Copying the Main file to target/webassembly/qtproject")
		remove("main.cpp")
		OSCopyFile(cMainFile)
	ok
	PrintSubStep("Copying Ring and RingQt folders...")
	if isWindows()
		OSCopyFolder(exefolder() + "..\extensions\webassembly\ringqt\project\","ring" )
		OSCopyFolder(exefolder() + "..\extensions\webassembly\ringqt\project\","ringqt" )
	else
		OSCopyFolder(exefolder() + "../extensions/webassembly/ringqt/project/","ring" )
		OSCopyFolder(exefolder() + "../extensions/webassembly/ringqt/project/","ringqt" )
	ok

func CheckQtResourceFile cBaseFolder,cFileName,aOptions
	cResourceFile = cBaseFolder+"/"+"project.qrc"
	if fexists(cResourceFile)
		PrintSubStep("We have Qt Resource File : " + cResourceFile)
		PrintSubStep("Copying the resource file to the Qt project folder")
		remove("project.qrc")
		OSCopyFile(cResourceFile)
		PrintSubStep("Copying files added to the Resource file")
		cResourceFileContent = read(cResourceFile)
		aResourceFileContent = str2list(cResourceFileContent)
		aFiles = []
		for cItem in aResourceFileContent
			if substr(cItem,"<file>") and substr(cItem,"</file>")
				cFile = cItem 
				cFile = trim(cFile)
				cFile = substr(cFile,char(9),"")
				cFile = substr(cFile,"<file>","")
				cFile = substr(cFile,"</file>","")
				if right(cFile,5) != "ringo"
					aFiles + cFile
				ok
			ok
		next
		for cFile in aFiles 
			PrintSubStep("Copying File : " + cFile)
			custom_OSCopyFile(cBaseFolder,cFile)
		next
	ok

func custom_OSCopyFile cBaseFolder,cFile
	cDir = currentdir()
	cFolder = justfilepath(cFile)
	if cFolder != NULL
		# Remove last / in the path
		cFolder = left(cFolder,len(cFolder)-1)
		OSCreateOpenFolder(cFolder)
	ok
	OSCopyFile(cBaseFolder+"/"+cFile)
	chdir(cDir)



func CheckNoCCompiler cBaseFolder,cFileName,aOptions
	# If we don't have a C compiler 
	# We copy ring.exe to be app.exe 
	# Then we change app.ringo to ring.ringo 
	cOutput = GetOutputName(aOptions, cFileName)
	cCustomCompiler = ""
	for x = len(aOptions) to 1 step -1
		cOption = lower(trim(aOptions[x]))
		if left(cOption,4) = "-cc="
			cCustomCompiler = substr(aOptions[x], 5)
			exit
		ok
	next
	if isWindows()
		cExeFile = cBaseFolder+"\"+cOutput+".exe"
	else 
		cExeFile = cBaseFolder+"/"+cOutput
	ok
	if fexists(cExeFile)
		return False
	ok
	if isWindows()
		cRingOFile = cBaseFolder+"\"+cFileName+".ringo"
	else 
		cRingOFile = cBaseFolder+"/"+cFileName+".ringo"
	ok
	if fexists(cRingOFile)
		if cCustomCompiler != NULL
			PrintWarning("C Compiler '" + cCustomCompiler + "' not found.")
		else 
			PrintWarning("C Compiler not found.")
		ok
	else 
		PrintError("No Ring Object File!")
		return False
	ok
	PrintSubStep("Using Ring execution (no C compiler)")
	cRingExeFile = exefolder() + "/ring"
	if isWindows() 
		if find(aOptions,"-gui")
			# use ringw.exe if -gui specified
			cRingExeFile += "w.exe"
		else 
			cRingExeFile += ".exe"
		ok
	ok
	OSCopyFile(cRingExeFile)
	if isWindows()
		if find(aOptions,"-gui")
			rename("ringw.exe",cOutput+".exe")
		else
			rename("ring.exe",cOutput+".exe")
		ok
		if cBaseFolder != currentdir()
			OSCopyFile(cBaseFolder+"\"+cFileName+".ringo")
		ok
	else 
		rename("ring",cOutput)
		if cBaseFolder != currentdir()
			OSCopyFile(cBaseFolder+"/"+cFileName+".ringo")
		ok
	ok
	if fexists("ring.ringo")
		remove("ring.ringo")
	ok
	rename(cFileName+".ringo","ring.ringo")
	# Clean up the C source file since we are using Ring execution
	if not find(aOptions, "-keep")
		cCFile = cBaseFolder + "\" + cFileName + ".c"
		if not isWindows() cCFile = cBaseFolder + "/" + cFileName + ".c" ok
		if fexists(cCFile) remove(cCFile) ok
	ok
	return True

func removeTabs cStr
	cOutput = ""
	aList = str2list(cStr)
	for item in aList
		if trim(item) = NULL loop ok
		while left(item,1) = tab
			item = substr(item,2)
		end
		cOutput += item + nl
	next
	return cOutput

# AppImage and App Bundle Functions

func CreateAppImage cAppName, aOptions
	PrintSubStep("Preparing files to create the AppImage package")
	
	# Go back to the linux directory first
	cLinuxDir = currentdir()
	OSCreateOpenFolder("dist_using_appimage")
	cAppImageDir = currentdir()
	
	# Create AppDir structure
	cAppDirName = cAppName + ".AppDir"
	OSCreateOpenFolder(cAppDirName)
	cAppDirPath = currentdir()
	
	# Create standard directories
	OSCreateOpenFolder("usr")
	cUsrPath = currentdir()
	OSCreateOpenFolder("bin")
	chdir(cUsrPath)
	OSCreateOpenFolder("lib")
	chdir(cAppDirPath)
	
	# Copy executable (go back to linux dir to access dist_using_scripts)
	chdir(cLinuxDir)
	cScriptsPath = "dist_using_scripts"
	if fexists(cScriptsPath + "/bin/" + cAppName)
		chdir(cAppDirPath)
		systemSilent("cp " + cLinuxDir + "/" + cScriptsPath + "/bin/" + cAppName + " usr/bin/")
		systemSilent("chmod +x usr/bin/" + cAppName)
	else
		PrintError("Could not find executable at " + cScriptsPath + "/bin/" + cAppName)
		chdir(cAppDirPath)
	ok
	
	# Copy ring.ringo if it exists (for fallback execution without C compiler)
	if fexists(cLinuxDir + "/" + cScriptsPath + "/bin/ring.ringo")
		OSCopyFile(cLinuxDir + "/" + cScriptsPath + "/bin/ring.ringo")
		rename("ring.ringo", "usr/bin/ring.ringo")
	ok
	
	# Copy libraries
	chdir(cLinuxDir)
	if direxists(cScriptsPath + "/lib")
		chdir(cAppDirPath)
		systemSilent("cp -a " + cLinuxDir + "/" + cScriptsPath + "/lib/. usr/lib/")
	else
		PrintError("Could not find libraries at " + cScriptsPath + "/lib")
		chdir(cAppDirPath)
	ok
	
	# Create desktop file (properly formatted)
	cDesktopFile = "[Desktop Entry]" + nl +
		"Type=Application" + nl +
		"Name=" + cAppName + nl +
		"Exec=" + cAppName + nl +
		"Icon=" + cAppName + nl +
		"Categories=Development;" + nl +
		"Comment=Ring Application" + nl
	write(cAppName + ".desktop", cDesktopFile)
	
	# Create AppRun script
	cAppRunScript = '#!/bin/bash' + nl +
		'HERE="$(dirname "$(readlink -f "${0}")")"/usr' + nl +
		'BIN=${HERE}/bin' + nl +
		'export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"' + nl +
		'export PATH="${HERE}/bin:${PATH}"' + nl +
		'cd "${BIN}"' + nl +
		'exec "${BIN}/' + cAppName + '" "$@"' + nl
	write("AppRun", cAppRunScript)
	systemSilent("chmod +x AppRun")
	
	# Create a simple SVG icon directly
	cSvgIcon = RemoveFirstTabs('
		<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
		  <rect width="64" height="64" fill="#4CAF50" rx="8"/>
		  <text x="32" y="40" font-family="Arial" font-size="36" fill="white" text-anchor="middle">R</text>
		</svg>
	',2)
	write(cAppName + ".svg", cSvgIcon)
	
	# Create build script for AppImage
	chdir(cAppImageDir)
	cBuildAppImage = RemoveFirstTabs('
		#!/bin/bash
		echo "Building AppImage for ' + cAppName + '..."

		# Use global appimagetool if available, else download local copy
		if command -v appimagetool >/dev/null 2>&1; then
			APPIMAGETOOL=$(command -v appimagetool)
			echo "Using global appimagetool: $APPIMAGETOOL"
		else
			if [ ! -f appimagetool ]; then
				echo "Downloading appimagetool..."
				wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
				chmod +x appimagetool
			fi
			APPIMAGETOOL=./appimagetool
			echo "Using local appimagetool: $APPIMAGETOOL"
		fi

		# Create AppImage
		echo "Creating AppImage..."
		ARCH=' + GetPackageArch("appimage") + ' $APPIMAGETOOL ' + cAppDirName + ' ' + cAppName + '-' + GetPackageArch("appimage") + '.AppImage

		if [ $? -eq 0 ]; then
			echo "AppImage created successfully: ' + cAppName + '-' + GetPackageArch("appimage") + '.AppImage"
			ls -la ' + cAppName + '-' + GetPackageArch("appimage") + '.AppImage
		else
			echo "Failed to create AppImage"
			echo "Note: You may need to install appimagetool manually"
			echo "Alternative: Use the prepared ' + cAppDirName + ' directory"
		fi
	',2)
	write("build_appimage.sh", cBuildAppImage)
	systemSilent("chmod +x build_appimage.sh")
	
func CreateAppBundle cAppName, aOptions
	PrintSubStep("Preparing files to create the App Bundle package")
	
	# Store the parent macOS directory before creating the appbundle folder
	cParentDir = currentdir()
	
	OSCreateOpenFolder("dist_using_appbundle")
	cAppBundleDir = currentdir()
	
	# Create .app bundle structure
	cAppBundleName = cAppName + ".app"
	OSCreateOpenFolder(cAppBundleName)
	cAppPath = currentdir()
	
	# Create Contents directory and subdirectories
	OSCreateOpenFolder("Contents")
	cContentsPath = currentdir()

	OSCreateOpenFolder("MacOS")
	chdir(cContentsPath)
	OSCreateOpenFolder("Resources")
	chdir(cContentsPath)
	OSCreateOpenFolder("Frameworks")
	
	# Copy executable to MacOS directory
	chdir(cContentsPath + "/MacOS")
	# Go back to the parent macOS directory to access the bin folder
	chdir(cParentDir)
	if fexists("dist_using_scripts/bin/" + cAppName)
		# Copy from bin directory to MacOS directory
		systemSilent("cp dist_using_scripts/bin/" + cAppName + " " + cContentsPath + "/MacOS/" + cAppName + " 2>/dev/null || true")
		if !fexists(cContentsPath + "/MacOS/" + cAppName)
			PrintError("Failed to copy executable to App Bundle")
		ok
	else
		PrintError("Could not find executable at dist_using_scripts/bin/" + cAppName)
	ok
	# Copy ring.ringo if it exists (for fallback execution without C compiler)
	if fexists("dist_using_scripts/bin/ring.ringo")
		systemSilent("cp dist_using_scripts/bin/ring.ringo " + cContentsPath + "/MacOS/ring.ringo 2>/dev/null || true")
	ok
	
	# Copy libraries to Frameworks directory
	chdir(cContentsPath + "/Frameworks")
	
	# Go back to the parent macOS directory to access the lib folder
	chdir(cParentDir)
	if direxists("dist_using_scripts/lib")
		systemSilent("cp -r dist_using_scripts/lib/* " + cContentsPath + "/Frameworks/ 2>/dev/null || true")
	else
		PrintError("Could not find libraries at dist_using_scripts/lib")
	ok
	
	# Create Info.plist file
	chdir(cContentsPath)
	cInfoPlist = RemoveFirstTabs('
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
		    <key>CFBundleDevelopmentRegion</key>
		    <string>English</string>
		    <key>CFBundleExecutable</key>
		    <string>' + cAppName + '</string>
		    <key>CFBundleGetInfoString</key>
		    <string>' + G_CONFIG[:description] + '</string>
		    <key>CFBundleIconFile</key>
		    <string>' + cAppName + '.icns</string>
		    <key>CFBundleIdentifier</key>
		    <string>net.ring-lang.' + cAppName + '</string>
		    <key>CFBundleInfoDictionaryVersion</key>
		    <string>6.0</string>
		    <key>CFBundleName</key>
		    <string>' + cAppName + '</string>
		    <key>CFBundlePackageType</key>
		    <string>APPL</string>
		    <key>CFBundleShortVersionString</key>
		    <string>' + G_CONFIG[:version] + '</string>
		    <key>CFBundleSignature</key>
		    <string>????</string>
		    <key>CFBundleVersion</key>
		    <string>' + G_CONFIG[:version] + '</string>
		    <key>NSHighResolutionCapable</key>
		    <true/>
		    <key>LSMinimumSystemVersion</key>
		    <string>10.12</string>
		    <key>NSHumanReadableCopyright</key>
		    <string>' + G_CONFIG[:license] + ' License</string>
		</dict>
		</plist>
	',2)
	write("Info.plist", cInfoPlist)
	
	# Create a simple icon (ICNS format placeholder)
	chdir(cContentsPath + "/Resources")
	cResourcesPath = currentdir()
	cIconSetScript = RemoveFirstTabs('
		#!/bin/bash
		echo "Creating App Icon..."

		# Set working directory to Resources path
		cd "#{f1}"

		# Create iconset directory in Resources folder
		mkdir -p ' + cAppName + '.iconset

		# Create a base SVG template
		cat > base_icon.svg <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
	 <rect width="512" height="512" fill="#4CAF50" rx="64"/>
	 <text x="256" y="350" font-family="Arial" font-size="256" fill="white" text-anchor="middle">R</text>
</svg>
EOF

		# Try to convert with available tools
		if command -v rsvg-convert >/dev/null 2>&1; then
			echo "Using rsvg-convert to create icons..."
			for size in 16 32 64 128 256 512 1024; do
				rsvg-convert -w ${size} -h ${size} base_icon.svg > ' + cAppName + '.iconset/icon_${size}x${size}.png 2>/dev/null
				if [ ${size} -le 512 ]; then
					rsvg-convert -w $((size*2)) -h $((size*2)) base_icon.svg > ' + cAppName + '.iconset/icon_${size}x${size}@2x.png 2>/dev/null
				fi
			done
		elif command -v convert >/dev/null 2>&1; then
			echo "Using ImageMagick convert to create icons..."
			for size in 16 32 64 128 256 512 1024; do
				convert base_icon.svg -resize ${size}x${size} ' + cAppName + '.iconset/icon_${size}x${size}.png 2>/dev/null
				if [ ${size} -le 512 ]; then
					convert base_icon.svg -resize $((size*2))x$((size*2)) ' + cAppName + '.iconset/icon_${size}x${size}@2x.png 2>/dev/null
				fi
			done
		else
			echo "Neither rsvg-convert nor convert found. Creating minimal icon set..."
			# Create a simple 16x16 icon using basic tools
			echo "Creating minimal 16x16 icon..."
			# Create a simple PPM format image
			cat > ' + cAppName + '.iconset/icon_16x16.ppm <<EOF
P3
16 16
255
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80 76 175 80
EOF
			# Convert PPM to PNG if possible
			if command -v convert >/dev/null 2>&1; then
				convert ' + cAppName + '.iconset/icon_16x16.ppm ' + cAppName + '.iconset/icon_16x16.png 2>/dev/null
				rm -f ' + cAppName + '.iconset/icon_16x16.ppm
			fi
		fi

		# Create ICNS file if iconutil is available
		if command -v iconutil >/dev/null 2>&1; then
			echo "Creating ICNS file..."
			iconutil -c icns ' + cAppName + '.iconset 2>/dev/null
			if [ $? -eq 0 ]; then
				rm -rf ' + cAppName + '.iconset
				echo "Icon created: ' + cAppName + '.icns"
			else
				echo "Failed to create ICNS file, removing iconset directory"
				rm -rf ' + cAppName + '.iconset
			fi
		else
			echo "iconutil not found - removing iconset directory"
			rm -rf ' + cAppName + '.iconset
		fi

		rm -f base_icon.svg
	',2)
	cIconSetScript = substr(cIconSetScript, "#{f1}", cResourcesPath)
	write("create_icon.sh", cIconSetScript)
	systemSilent("chmod +x create_icon.sh")
	systemSilent("./create_icon.sh")
	remove("create_icon.sh")
	
	# Set executable permissions
	chdir(cContentsPath + "/MacOS")
	if fexists(cAppName)
		systemSilent("chmod +x " + cAppName)
	else
		PrintError("Could not find " + cAppName + " to set permissions")
	ok
	
	# Create build script
	chdir(cAppBundleDir)
	cBuildBundle = RemoveFirstTabs("#!/bin/bash
		echo
		echo macOS App Bundle created: " + cAppBundleName + "
		echo
		echo To sign the app bundle \(optional\):
		echo '  codesign --force --deep --sign - " + cAppBundleName + "'
		echo
		echo To test the app:
		echo '  open " + cAppBundleName + "'
		echo
		echo To create a DMG installer:
		echo '  hdiutil create -volname '" + cAppName + "' -srcfolder . -ov -format UDZO " + cAppName + ".dmg'
		echo
		ls -la " + cAppBundleName + "
	",2)
	write("bundle_info.sh", cBuildBundle)
	systemSilent("chmod +x bundle_info.sh")

func GetPackageArch cPackageType
	cArch = GetArch()
	switch cArch
	on "x64"
		switch cPackageType
		on "deb" return "amd64"
		on "rpm" return "x86_64"
		on "appimage" return "x86_64"
		on "pkg" return "amd64"
		on "flatpak" return "x86_64"
		on "snap" return "amd64"
		off
	on "arm64"
		switch cPackageType
		on "deb" return "arm64"
		on "rpm" return "aarch64"
		on "appimage" return "aarch64"
		on "pkg" return "aarch64"
		on "flatpak" return "aarch64"
		on "snap" return "arm64"
		off
	on "x86"
		switch cPackageType
		on "deb" return "i386"
		on "rpm" return "i686"
		on "appimage" return "i686"
		on "pkg" return "i386"
		on "flatpak" return "i386"
		on "snap" return "i386"
		off
	on "arm"
		switch cPackageType
		on "deb" return "armhf"
		on "rpm" return "armhfp"
		on "appimage" return "armhf"
		on "pkg" return "armv7"
		on "flatpak" return "arm"
		on "snap" return "armhf"
		off
	other
		return "unknown"
	off
	return "unknown"

# ============================================
# Windows Installer Functions
# ============================================

func CreateNSISInstaller cAppName, aOptions, cWindowsDir
	PrintSubStep("Preparing files to create NSIS installer")
	
	cNsisDir = cWindowsDir + "/dist_using_nsis"
	OSCreateOpenFolder("dist_using_nsis")
	
	cVersion = G_CONFIG[:version]
	cDescription = G_CONFIG[:description]
	cMaintainer = G_CONFIG[:maintainer]
	cLicense = G_CONFIG[:license]
	cHomepage = G_CONFIG[:homepage]
	cBS = "\"  # Backslash
	
	# Generate NSIS script
	cNSI = '
; NSIS Installer Script for ' + cAppName + '
; Generated by Ring2EXE Plus

!include "MUI2.nsh"

; General
Name "' + cAppName + '"
OutFile "' + cAppName + '_setup.exe"
InstallDir "$PROGRAMFILES' + cBS + cAppName + '"
InstallDirRegKey HKLM "Software' + cBS + cAppName + '" "Install_Dir"
RequestExecutionLevel admin

; Interface Settings
!define MUI_ABORTWARNING

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Languages
!insertmacro MUI_LANGUAGE "English"

; Installer Section
Section "Install"
    SetOutPath $INSTDIR
    
    ; Copy files from dist_using_scripts directory
    File /r "..' + cBS + 'dist_using_scripts' + cBS + '*.*"
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR' + cBS + 'uninstall.exe"
    
    ; Create Start Menu shortcuts
    CreateDirectory "$SMPROGRAMS' + cBS + cAppName + '"
    CreateShortCut "$SMPROGRAMS' + cBS + cAppName + cBS + cAppName + '.lnk" "$INSTDIR' + cBS + cAppName + '.exe"
    CreateShortCut "$SMPROGRAMS' + cBS + cAppName + cBS + 'Uninstall.lnk" "$INSTDIR' + cBS + 'uninstall.exe"
    
    ; Registry
    WriteRegStr HKLM "Software' + cBS + 'Microsoft' + cBS + 'Windows' + cBS + 'CurrentVersion' + cBS + 'Uninstall' + cBS + cAppName + '" "DisplayName" "' + cAppName + '"
    WriteRegStr HKLM "Software' + cBS + 'Microsoft' + cBS + 'Windows' + cBS + 'CurrentVersion' + cBS + 'Uninstall' + cBS + cAppName + '" "UninstallString" "$INSTDIR' + cBS + 'uninstall.exe"
    WriteRegStr HKLM "Software' + cBS + 'Microsoft' + cBS + 'Windows' + cBS + 'CurrentVersion' + cBS + 'Uninstall' + cBS + cAppName + '" "DisplayVersion" "' + cVersion + '"
    WriteRegStr HKLM "Software' + cBS + 'Microsoft' + cBS + 'Windows' + cBS + 'CurrentVersion' + cBS + 'Uninstall' + cBS + cAppName + '" "Publisher" "' + cMaintainer + '"
SectionEnd

; Uninstaller Section
Section "Uninstall"
    ; Remove files
    RMDir /r "$INSTDIR"
    
    ; Remove shortcuts
    RMDir /r "$SMPROGRAMS' + cBS + cAppName + '"
    
    ; Remove registry keys
    DeleteRegKey HKLM "Software' + cBS + 'Microsoft' + cBS + 'Windows' + cBS + 'CurrentVersion' + cBS + 'Uninstall' + cBS + cAppName + '"
    DeleteRegKey HKLM "Software' + cBS + cAppName + '"
SectionEnd
'
	write(cAppName + ".nsi", cNSI)
	
	# Create a placeholder license file
	if not fexists("LICENSE.txt")
		write("LICENSE.txt", cAppName + " - " + cLicense + " License" + nl + nl + cDescription)
	ok
	
	# Create build script
	cBuildScript = "@echo off" + nl +
		"echo Building NSIS installer for " + cAppName + "..." + nl +
		"makensis " + cAppName + ".nsi" + nl +
		"if exist " + cAppName + "_setup.exe (" + nl +
		"    echo Installer created: " + cAppName + "_setup.exe" + nl +
		") else (" + nl +
		"    echo Failed to create installer. Make sure NSIS is installed." + nl +
		"    echo Download from: https://nsis.sourceforge.io/" + nl +
		")" + nl
	write("build_installer.bat", cBuildScript)
	
	chdir(cWindowsDir)

func CreateInnoInstaller cAppName, aOptions, cWindowsDir
	PrintSubStep("Preparing files to create Inno Setup installer")
	
	OSCreateOpenFolder("dist_using_inno")
	
	cVersion = G_CONFIG[:version]
	cDescription = G_CONFIG[:description]
	cMaintainer = G_CONFIG[:maintainer]
	cHomepage = G_CONFIG[:homepage]
	cBS = "\"  # Backslash
	
	# Generate Inno Setup script
	cISS = '
; Inno Setup Script for ' + cAppName + '
; Generated by Ring2EXE Plus

[Setup]
AppName=' + cAppName + '
AppVersion=' + cVersion + '
AppPublisher=' + cMaintainer + '
AppPublisherURL=' + cHomepage + '
DefaultDirName={autopf}' + cBS + cAppName + '
DefaultGroupName=' + cAppName + '
OutputDir=.
OutputBaseFilename=' + cAppName + '_setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..' + cBS + 'dist_using_scripts' + cBS + '*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}' + cBS + cAppName + '"; Filename: "{app}' + cBS + cAppName + '.exe"
Name: "{group}' + cBS + '{cm:UninstallProgram,' + cAppName + '}"; Filename: "{uninstallexe}"
Name: "{autodesktop}' + cBS + cAppName + '"; Filename: "{app}' + cBS + cAppName + '.exe"; Tasks: desktopicon

[Run]
Filename: "{app}' + cBS + cAppName + '.exe"; Description: "{cm:LaunchProgram,' + cAppName + '}"; Flags: nowait postinstall skipifsilent
'
	write(cAppName + ".iss", cISS)
	
	# Create build script
	cBuildScript = "@echo off" + nl +
		"echo Building Inno Setup installer for " + cAppName + "..." + nl +
		"iscc " + cAppName + ".iss" + nl +
		"if exist " + cAppName + "_setup.exe (" + nl +
		"    echo Installer created: " + cAppName + "_setup.exe" + nl +
		") else (" + nl +
		"    echo Failed to create installer. Make sure Inno Setup is installed." + nl +
		"    echo Download from: https://jrsoftware.org/isinfo.php" + nl +
		")" + nl
	write("build_installer.bat", cBuildScript)
	
	chdir(cWindowsDir)

func CreateMSIInstaller cAppName, aOptions, cWindowsDir
	PrintSubStep("Preparing files to create MSI installer (WiX)")
	
	OSCreateOpenFolder("dist_using_msi")
	
	cVersion = G_CONFIG[:version]
	cDescription = EscapeXML(G_CONFIG[:description])
	cMaintainer = EscapeXML(G_CONFIG[:maintainer])
	cAppNameXML = EscapeXML(cAppName)
	
	# Generate a GUID for the product
	cUpgradeGUID = GenerateGUID()
	
	# Scan dist_using_scripts folder for all files
	cBS = "\"  # Backslash
	cDistDir = cWindowsDir + cBS + "dist_using_scripts"
	aFiles = dir(cDistDir)
	
	# Build component entries for all files
	cComponents = ""
	nFileCount = 0
	for aFile in aFiles
		if aFile[2] = 0  # It's a file, not a directory
			cFileName = aFile[1]
			nFileCount++
			cFileId = "File" + nFileCount + "_" + substr(substr(cFileName, ".", "_"), "-", "_")
			cCompId = "Comp" + nFileCount + "_" + substr(substr(cFileName, ".", "_"), "-", "_")
			
			# Determine if this is the main executable (KeyPath)
			cKeyPath = ""
			if lower(cFileName) = lower(cAppName + ".exe")
				cKeyPath = ' KeyPath="yes"'
			ok
			
			cComponents += '            <Component Id="' + cCompId + '">' + nl
			cComponents += '                <File Id="' + cFileId + '" Source="..' + cBS + 'dist_using_scripts' + cBS + cFileName + '"' + cKeyPath + ' />' + nl
			cComponents += '            </Component>' + nl
		ok
	next
	
	# If no files found, add at least the main executable
	if nFileCount = 0
		cComponents = '            <Component Id="MainExecutable">' + nl
		cComponents += '                <File Id="' + cAppName + 'EXE" Source="..' + cBS + 'dist_using_scripts' + cBS + cAppName + '.exe" KeyPath="yes" />' + nl
		cComponents += '            </Component>' + nl
	ok
	
	# Generate WiX XML
	cWXS = '<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
    <Package Name="' + cAppNameXML + '"
             Language="1033"
             Version="' + cVersion + '"
             Manufacturer="' + cMaintainer + '"
             UpgradeCode="' + cUpgradeGUID + '">

        <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
        <MediaTemplate EmbedCab="yes" />

        <Feature Id="ProductFeature" Title="' + cAppNameXML + '" Level="1">
            <ComponentGroupRef Id="ProductComponents" />
        </Feature>

        <StandardDirectory Id="ProgramFilesFolder">
            <Directory Id="INSTALLFOLDER" Name="' + cAppNameXML + '" />
        </StandardDirectory>

        <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
' + cComponents + '        </ComponentGroup>
    </Package>
</Wix>
'
	write(cAppName + ".wxs", cWXS)
	
	PrintSubStep("Including " + nFileCount + " files in MSI package")
	
	# Create build script for WiX
	cBuildScript = "@echo off" + nl +
		"echo Building MSI installer for " + cAppName + "..." + nl +
		"wix build -o " + cAppName + ".msi " + cAppName + ".wxs" + nl +
		"if exist " + cAppName + ".msi (" + nl +
		"    echo MSI installer created: " + cAppName + ".msi" + nl +
		") else (" + nl +
		"    echo Failed to create MSI. Make sure WiX Toolset is installed." + nl +
		"    echo Download from: https://github.com/wixtoolset/wix/releases/latest" + nl +
		")" + nl
	write("build_msi.bat", cBuildScript)
	
	chdir(cWindowsDir)

# ============================================
# Linux Packaging Functions (Flatpak, Snap)
# ============================================

func CreateFlatpak cAppName, aOptions, cLinuxDir
	PrintSubStep("Preparing files to create Flatpak package")
	
	chdir(cLinuxDir)
	OSCreateOpenFolder("dist_using_flatpak")
	cFlatpakDir = currentdir()
	
	cVersion = G_CONFIG[:version]
	cDescription = G_CONFIG[:description]
	cMaintainer = G_CONFIG[:maintainer]
	cHomepage = G_CONFIG[:homepage]
	cLicense = G_CONFIG[:license]
	
	# Create app ID (reverse domain notation)
	cAppID = "net.ring_lang." + substr(cAppName, " ", "_")
	
	# Generate Flatpak manifest
	cManifest = '{
    "app-id": "' + cAppID + '",
    "runtime": "org.freedesktop.Platform",
    "runtime-version": "23.08",
    "sdk": "org.freedesktop.Sdk",
    "command": "' + cAppName + '",
    "finish-args": [
        "--share=ipc",
        "--socket=x11",
        "--socket=wayland",
        "--socket=pulseaudio",
        "--share=network",
        "--filesystem=home"
    ],
    "modules": [
        {
            "name": "' + cAppName + '",
            "buildsystem": "simple",
            "build-commands": [
                "install -D bin/' + cAppName + ' /app/bin/' + cAppName + '",
                "install -D -t /app/lib/ lib/*"
            ],
            "sources": [
                {
                    "type": "dir",
                    "path": "../dist_using_scripts"
                }
            ]
        }
    ]
}
'
	write(cAppID + ".json", cManifest)
	
	# Create desktop file
	cDesktopFile = "[Desktop Entry]" + nl +
		"Type=Application" + nl +
		"Name=" + cAppName + nl +
		"Exec=" + cAppName + nl +
		"Icon=" + cAppID + nl +
		"Categories=Development;" + nl +
		"Comment=" + cDescription + nl
	write(cAppID + ".desktop", cDesktopFile)
	
	# Create build script
	cBuildScript = "#!/bin/bash" + nl +
		"echo 'Building Flatpak for " + cAppName + "...'" + nl +
		"" + nl +
		"# Install Flatpak SDK if needed" + nl +
		"flatpak install -y flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08 2>/dev/null" + nl +
		"" + nl +
		"# Build the Flatpak" + nl +
		"flatpak-builder --force-clean build-dir " + cAppID + ".json" + nl +
		"" + nl +
		"# Create repository and bundle" + nl +
		"flatpak-builder --repo=repo --force-clean build-dir " + cAppID + ".json" + nl +
		"flatpak build-bundle repo " + cAppName + ".flatpak " + cAppID + nl +
		"" + nl +
		"if [ -f " + cAppName + ".flatpak ]; then" + nl +
		"    echo 'Flatpak created: " + cAppName + ".flatpak'" + nl +
		"    echo 'Install with: flatpak install " + cAppName + ".flatpak'" + nl +
		"else" + nl +
		"    echo 'Failed to create Flatpak. Make sure flatpak-builder is installed.'" + nl +
		"fi" + nl
	write("build_flatpak.sh", cBuildScript)
	systemSilent("chmod +x build_flatpak.sh")
	
	chdir(cLinuxDir)

func CreateSnap cAppName, aOptions, cLinuxDir
	PrintSubStep("Preparing files to create Snap package")
	
	chdir(cLinuxDir)
	OSCreateOpenFolder("dist_using_snap")
	cSnapDir = currentdir()
	
	cVersion = G_CONFIG[:version]
	cDescription = G_CONFIG[:description]
	cLicense = G_CONFIG[:license]
	
	# Create snap directory structure
	OSCreateOpenFolder("snap")
	
	# Generate snapcraft.yaml
	cSnapcraft = "name: " + lower(substr(cAppName, " ", "-")) + nl +
		"base: core22" + nl +
		"version: '" + cVersion + "'" + nl +
		"summary: " + cAppName + " - Ring Application" + nl +
		"description: |" + nl +
		"  " + cDescription + nl +
		"grade: stable" + nl +
		"confinement: strict" + nl +
		"" + nl +
		"apps:" + nl +
		"  " + lower(substr(cAppName, " ", "-")) + ":" + nl +
		"    command: bin/" + cAppName + nl +
		"    plugs:" + nl +
		"      - home" + nl +
		"      - network" + nl +
		"      - x11" + nl +
		"      - wayland" + nl +
		"      - desktop" + nl +
		"      - desktop-legacy" + nl +
		"      - audio-playback" + nl +
		"" + nl +
		"parts:" + nl +
		"  " + lower(substr(cAppName, " ", "-")) + ":" + nl +
		"    plugin: dump" + nl +
		"    source: ../../dist_using_scripts" + nl +
		"    organize:" + nl +
		"      bin/*: bin/" + nl +
		"      lib/*: lib/" + nl
	write("snapcraft.yaml", cSnapcraft)
	
	chdir(cSnapDir)
	
	# Create build script
	cBuildScript = "#!/bin/bash" + nl +
		"echo 'Building Snap for " + cAppName + "...'" + nl +
		"" + nl +
		"cd snap" + nl +
		"snapcraft" + nl +
		"" + nl +
		"if ls ../*.snap 1> /dev/null 2>&1; then" + nl +
		"    echo 'Snap package created successfully!'" + nl +
		"    echo 'Install with: sudo snap install --dangerous *.snap'" + nl +
		"else" + nl +
		"    echo 'Failed to create Snap. Make sure snapcraft is installed.'" + nl +
		"    echo 'Install with: sudo snap install snapcraft --classic'" + nl +
		"fi" + nl
	write("build_snap.sh", cBuildScript)
	systemSilent("chmod +x build_snap.sh")
	
	chdir(cLinuxDir)

# ============================================
# macOS DMG Function
# ============================================

func CreateDMG cAppName, aOptions, cMacDir
	PrintSubStep("Preparing files to create DMG disk image")
	
	chdir(cMacDir)
	OSCreateOpenFolder("dist_using_dmg")
	cDmgDir = currentdir()
	
	cVersion = G_CONFIG[:version]
	cQ = char(34)  # Double quote character
	
	# Create build script that uses the app bundle
	cBuildScript = "#!/bin/bash" + nl +
		"echo 'Creating DMG for " + cAppName + "...'" + nl +
		"" + nl +
		"APP_BUNDLE=" + cQ + "../dist_using_appbundle/" + cAppName + ".app" + cQ + nl +
		"" + nl +
		"if [ ! -d " + cQ + "$APP_BUNDLE" + cQ + " ]; then" + nl +
		"    echo 'Error: App bundle not found at $APP_BUNDLE'" + nl +
		"    echo 'Make sure to build with -appbundle first'" + nl +
		"    exit 1" + nl +
		"fi" + nl +
		"" + nl +
		"# Create a temporary directory for DMG contents" + nl +
		"mkdir -p dmg_contents" + nl +
		"cp -r " + cQ + "$APP_BUNDLE" + cQ + " dmg_contents/" + nl +
		"" + nl +
		"# Create symbolic link to Applications folder" + nl +
		"ln -sf /Applications dmg_contents/Applications" + nl +
		"" + nl +
		"# Create the DMG" + nl +
		"hdiutil create -volname " + cQ + cAppName + cQ + " -srcfolder dmg_contents -ov -format UDZO " + cQ + cAppName + "-" + cVersion + ".dmg" + cQ + nl +
		"" + nl +
		"# Cleanup" + nl +
		"rm -rf dmg_contents" + nl +
		"" + nl +
		"if [ -f " + cQ + cAppName + "-" + cVersion + ".dmg" + cQ + " ]; then" + nl +
		"    echo 'DMG created: " + cAppName + "-" + cVersion + ".dmg'" + nl +
		"    ls -la " + cQ + cAppName + "-" + cVersion + ".dmg" + cQ + nl +
		"else" + nl +
		"    echo 'Failed to create DMG'" + nl +
		"fi" + nl
	write("build_dmg.sh", cBuildScript)
	systemSilent("chmod +x build_dmg.sh")
	
	chdir(cMacDir)

# ============================================
# Utility Functions
# ============================================

# Pad string on the right with spaces to reach desired width
func PadRight cStr, nWidth
	nLen = len(cStr)
	if nLen >= nWidth
		return cStr
	ok
	return cStr + copy(" ", nWidth - nLen)

# Escape special XML characters for use in XML attributes/content
func EscapeXML cStr
	cStr = substr(cStr, "&", "&amp;")
	cStr = substr(cStr, "<", "&lt;")
	cStr = substr(cStr, ">", "&gt;")
	cStr = substr(cStr, '"', "&quot;")
	cStr = substr(cStr, "'", "&apos;")
	return cStr

# Generate a valid GUID in format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
func GenerateGUID
	cHex = "0123456789ABCDEF"
	cGUID = ""
	for i = 1 to 32
		cGUID += cHex[random(15) + 1]
		if i = 8 or i = 12 or i = 16 or i = 20
			cGUID += "-"
		ok
	next
	return cGUID