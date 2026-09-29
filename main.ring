# The Main File - shown by: ringpm run ringfm
# ringfm is a library, not an application. This file only says where the
# library is and how to call it.

func main

	cLine = copy("=", 78)
	cRingFolder = exefolder()
	cRingFolder = left(cRingFolder, len(cRingFolder)-1)
	if len(cRingFolder) > 3 and lower(right(cRingFolder, 3)) = "bin"
		cRingFolder = left(cRingFolder, len(cRingFolder)-4)
	ok

	? cLine
	? "The ringfm Package"
	? cLine
	? "Text measurement in pure Ring - real metrics read from a TrueType file."
	? ""
	? "AS A LIBRARY, from any folder:"
	? char(9) + 'load "ringfm.ring"'
	? char(9) + 'aResult = fm_measure("Hello, Ring!", "arial", 14, 200, ["lines","widths","info"])'
	? ""
	? "AS A COMMAND LINE TOOL, the same file run directly:"
	? char(9) + "ring " + cRingFolder + "/libraries/ringfm/ringfm.ring " + '"Hello World!" arial 14 200'
	? char(9) + "(run with no arguments for the usage screen)"
	? ""
	? "Library : " + cRingFolder + "/libraries/ringfm"
	? "Samples : " + cRingFolder + "/samples/UsingRingFM"
	? "Readme  : " + cRingFolder + "/libraries/ringfm/README.md"
	? ""
	? "THE TEST SUITE is installed beside the library and is the longest worked"
	? "example there is - one section per way of driving it. Read it, and run it:"
	? char(9) + "cd " + cRingFolder + "/libraries/ringfm"
	? char(9) + "ring test_ringfm.ring"
	? cLine
