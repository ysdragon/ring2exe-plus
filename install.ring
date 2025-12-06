# Store current directory
cDir = currentDir()

# Change the current directory to the folder where the Ring executable is located
chdir(exefolder())

# Rename the executable to ring2exe based on the architecture and the OS
if isWindows() and getarch() = "x86"
	rename("ring2exe-x86.exe", "ring2exe.exe")
but isLinux()
	system("chmod +x ring2exe")
but isLinux() and getarch() = "arm64"
	rename("ring2exe-linux-arm64", "ring2exe")
	system("chmod +x ring2exe")
but isMacOSX() and getarch() = "arm64"
	rename("ring2exe-macos-arm", "ring2exe")
	system("chmod +x ring2exe")
but isMacOSX() and (getarch() = "x86" or getarch() = "x64")
	rename("ring2exe-macos-intel", "ring2exe")
	system("chmod +x ring2exe")
ok

# Change the current directory back to the original directory
chdir(cDir)