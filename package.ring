aPackageInfo = [
	:name = "The Ring2EXE Plus Package",
	:description = "Our Ring2EXE Plus package using the Ring programming language",
	:folder = "ring2exe-plus",
	:developer = "Mahmoud Fayed, Youssef Saeed",
	:email = "msfclipper@yahoo.com, youssefelkholey@gmail.com",
	:license = "MIT License",
	:version = "1.1.0",
	:ringversion = "1.24",
	:versions = 	[
		[
			:version = "1.1.0",
			:branch = "master"
		]
	],
	:libs = 	[
		[
			:name = "stdlib",
			:version = "1.0",
			:providerusername = ""
		],
		[
			:name = "tokenslib",
			:version = "1.0",
			:providerusername = ""
		]
	],
	:files = 	[
		"main.ring",
		"README.md"
	],
	:ringfolderfiles = 	[
		"tools/ring2exe/build.bat",
		"tools/ring2exe/build.sh",
		"tools/ring2exe/README.md",
		"tools/ring2exe/ring2exe.ring",
		"tools/ring2exe/utils/clicolors.ring",
		"tools/ring2exe/tests/test.ring",
		"tools/ring2exe/tests/test2.ring",
		"tools/ring2exe/tests/test3.ring"
	],
	:windowsfiles = 	[

	],
	:linuxfiles = 	[

	],
	:macosfiles = 	[

	],
	:freebsdfiles = 	[

	],
	:windowsringfolderfiles = 	[
		"bin/ring2exe.exe"
	],
	:linuxringfolderfiles = 	[
		"bin/ring2exe"
	],
	:macosringfolderfiles = 	[
		# "bin/ring2exe"
	],
	:freebsdfolderfiles =		[
		# "bin/ring2exe"
	],
	:run = "ring main.ring",
	:setup = "",
	:windowssetup = "",
	:linuxsetup = "",
	:macossetup = "",
	:ubuntusetup = "",
	:fedorasetup = "",
	:remove = "",
	:windowsremove = "",
	:linuxremove = "",
	:macosremove = "",
	:ubunturemove = "",
	:fedoraremove = ""
]