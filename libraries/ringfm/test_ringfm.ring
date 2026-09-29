# The library under test loads stdlibcore.ring, and the test needs only that plus md5(),
# which the OpenSSL extension registers. Loading the whole stdlib.ring would also pull in
# the ODBC, MySQL and PostgreSQL extensions, whose system libraries are missing on many
# machines, and the test would not start.
Load "stdlibcore.ring"
Load "openssllib.ring"
$npass = 0
$nfail = 0
$outdir = "test_fm/"
If ! direxists($outdir)
	If iswindows() system("mkdir "+left($outdir, 7)+" 2>nul") Else system("mkdir -p "+left($outdir, 7)) Ok 
Else 
	aexistingfiles = dir($outdir)
	For aexistingentry In aexistingfiles 
		cexistingname = aexistingentry[1]
		If cexistingname != "." And cexistingname != ".."
			If ! substr(lower(cexistingname), "checksum")
				remove($outdir+cexistingname)
			Ok 
		Ok 
	Next 
Ok 
plog("══════════════════════════════════════════════════════════")
plog("  [MODE 1] CLI (system + disk I/O)")
plog("══════════════════════════════════════════════════════════")
ring_run("ringfm.ring "+'"Hello World!"'+" arial 14 > "+$outdir+"_cli_capture.txt 2>&1")
If fexists($outdir+"_cli_capture.txt")
	For ccapturedline In str2list(read($outdir+"_cli_capture.txt")) plog("   │ "+ccapturedline) Next 
	remove($outdir+"_cli_capture.txt")
Ok 
If fexists("fm_lines.txt") rename("fm_lines.txt", $outdir+"m1_lines.txt") Ok 
If fexists("fm_widths.txt") rename("fm_widths.txt", $outdir+"m1_widths.txt") Ok 
If fexists("fm_stats.txt") rename("fm_stats.txt", $outdir+"m1_stats.txt") Ok 
For cexpectedfile In ["m1_lines.txt", "m1_widths.txt", "m1_stats.txt"]
	If fexists($outdir+cexpectedfile)
		tpass("[M1] file exists: "+cexpectedfile+"  ("+len(read($outdir+cexpectedfile))+" B)")
	Else 
		tfail("[M1] file exists: "+cexpectedfile, "not found — is ring in PATH?")
	Ok 
Next 
If fexists($outdir+"m1_lines.txt")
	creadline = read($outdir+"m1_lines.txt")
	areadlines = str2list(creadline)
	While len(areadlines) > 0 And trim(areadlines[len(areadlines)]) = "" del(areadlines, len(areadlines)) End 
	tchecklen(areadlines, 1, "[M1] lines: exactly 1 line for single-line input")
	tcheckstr(creadline, "[M1] lines contain expected text", "Hello")
Ok 
If fexists($outdir+"m1_widths.txt")
	cwidthsdata = read($outdir+"m1_widths.txt")
	awidthvalues = fm_parsefile(cwidthsdata)
	tchecklen(awidthvalues, 1, "[M1] widths: exactly 1 entry for single-line input")
	tchecknum(awidthvalues[1], "[M1] widths: single line has positive width")
Ok 
If fexists($outdir+"m1_stats.txt")
	cstatsfromfile = read($outdir+"m1_stats.txt")
	tcheckstr(cstatsfromfile, "[M1] stats has header", "Font Metrics Statistics")
	tcheckstr(cstatsfromfile, "[M1] stats has Size field", "14 pt")
	tcheckstr(cstatsfromfile, "[M1] stats has Lines field", "Lines:")
Ok 
plog("")
plog("══════════════════════════════════════════════════════════")
plog("  [MODE 2] Library (load + direct API)")
plog("══════════════════════════════════════════════════════════")
Load "ringfm.ring"
plog("")
ameasure = fm_measure("Hello World!", "arial", 14, 0, null)
write($outdir+"m2A_widths.txt", fm_createwidths(ameasure[:widths]))
write($outdir+"m2A_stats.txt", ameasure[:stats])
cm2alines = ""
For creadline In ameasure[:lines] cm2alines += creadline+nl Next 
write($outdir+"m2A_lines.txt", cm2alines)
tchecklen(ameasure, 4, "[M2-A] result list has exactly 4 keys (lines, widths, stats, info)")
tchecklen(ameasure[:lines], 1, "[M2-A] single line: exactly 1 entry in lines")
tcheckstr(sb_item(ameasure[:lines], 1), "[M2-A] lines[1] contains expected text", "Hello")
tchecklen(ameasure[:widths], 1, "[M2-A] single line: exactly 1 width entry")
tchecknum(sb_item(ameasure[:widths], 1), "[M2-A] single line: width is positive")
tcheckstr(ameasure[:stats], "[M2-A] stats has header", "Font Metrics Statistics")
tcheckstr(ameasure[:stats], "[M2-A] stats has Size field", "14 pt")
tcheckstr(ameasure[:stats], "[M2-A] stats has Lines field", "Lines: 1")
plog("")
cthreelines = "First line"+nl+""+nl+"Third line"
ameasure = fm_measure(cthreelines, "arial", 12, 0, ["widths"])
write($outdir+"m2B_widths.txt", fm_createwidths(ameasure[:widths]))
tchecklen(ameasure, 1, "[M2-B] result list has exactly 1 key")
tchecklen(ameasure[:widths], 3, "[M2-B] three lines: exactly 3 width entries")
tchecknum(sb_item(ameasure[:widths], 1), "[M2-B] first line has positive width")
tcheckzero(sb_item(ameasure[:widths], 2), "[M2-B] empty line has width 0")
tchecknum(sb_item(ameasure[:widths], 3), "[M2-B] third line has positive width")
plog("")
clong = "The quick brown fox jumps over the lazy dog"
anowrap = fm_measure(clong, "arial", 12, 0, ["widths"])
awrapped = fm_measure(clong, "arial", 12, 80, ["widths", "stats"])
write($outdir+"m2C_widths.txt", fm_createwidths(awrapped[:widths]))
write($outdir+"m2C_stats.txt", awrapped[:stats])
tchecklen(awrapped, 2, "[M2-C] result list has exactly 2 keys")
If len(awrapped[:widths]) > len(anowrap[:widths])
	tpass("[M2-C] wrap at 80 px produces more lines than no-wrap  ("+
	len(awrapped[:widths])+" vs "+len(anowrap[:widths])+")")
Else 
	tfail("[M2-C] wrap at 80 px produces more lines than no-wrap", 
	"got "+len(awrapped[:widths])+" vs "+len(anowrap[:widths]))
Ok 
tcheckstr(awrapped[:stats], "[M2-C] stats has Max Width field", "80 px")
nexceeds = 0
For nlinewidth In awrapped[:widths]
	If nlinewidth > 0 And nlinewidth > 80 nexceeds++ Ok 
Next 
If nexceeds = 0
	tpass("[M2-C] no wrapped line exceeds max width")
Else 
	tfail("[M2-C] no wrapped line exceeds max width", string(nexceeds)+" line(s) exceed 80 px")
Ok 
plog("")
ameasure = fm_measure("Ring!", "nonexistentfont_xyz", 16, 0, ["widths", "stats"])
write($outdir+"m2D_widths.txt", fm_createwidths(ameasure[:widths]))
write($outdir+"m2D_stats.txt", ameasure[:stats])
tchecklen(ameasure[:widths], 1, "[M2-D] unknown font: 1 width entry (no crash)")
tchecknum(sb_item(ameasure[:widths], 1), "[M2-D] unknown font: width is positive")
tcheckstr(ameasure[:stats], "[M2-D] stats shows estimate for unknown font", "estimate")
plog("")
cwraptext = "Pack my box with five dozen liquor jugs"
awrappedlines = fm_measure(cwraptext, "arial", 12, 60, ["lines", "widths"])
cm2elines = ""
For creadline In awrappedlines[:lines] cm2elines += creadline+nl Next 
write($outdir+"m2E_lines.txt", cm2elines)
write($outdir+"m2E_widths.txt", fm_createwidths(awrappedlines[:widths]))
tchecklen(awrappedlines, 2, "[M2-E] result list has exactly 2 keys (lines+widths)")
tchecklen(awrappedlines[:lines], len(awrappedlines[:widths]), 
"[M2-E] lines and widths have the same length")
If len(awrappedlines[:lines]) >= 2
	tpass("[M2-E] wrap at 60 px produces >= 2 lines  ("+len(awrappedlines[:lines])+")")
Else 
	tfail("[M2-E] wrap at 60 px produces >= 2 lines", "got "+len(awrappedlines[:lines]))
Ok 
nallstr = true 
For nlineindex = 1 To len(awrappedlines[:lines])
	If type(awrappedlines[:lines][nlineindex]) != "STRING" nallstr = false Ok 
Next 
If nallstr 
	tpass("[M2-E] all lines entries are strings")
Else 
	tfail("[M2-E] all lines entries are strings", "at least one entry is not a string")
Ok 
cjoined = ""
For creadline In awrappedlines[:lines] cjoined += creadline+" " Next 
cjoined = trim(cjoined)
nallwords = true 
For cwrappedword In split(cwraptext, " ")
	If ! substr(cjoined, cwrappedword) nallwords = false Exit Ok 
Next 
If nallwords 
	tpass("[M2-E] all words preserved after wrap")
Else 
	tfail("[M2-E] all words preserved after wrap", "at least one word missing")
Ok 
plog("")
ameasure = fm_measure("Hello World!", "times", 14, 0, ["widths", "stats"])
write($outdir+"m2F_widths.txt", fm_createwidths(ameasure[:widths]))
write($outdir+"m2F_stats.txt", ameasure[:stats])
tchecklen(ameasure[:widths], 1, "[M2-F] times: exactly 1 width entry")
tchecknum(sb_item(ameasure[:widths], 1), "[M2-F] times: width is positive")
tcheckstr(ameasure[:stats], "[M2-F] times stats has header", "Font Metrics Statistics")
If $fmloaded 
	If Not substr(ameasure[:stats], "estimate")
		tpass("[M2-F] times: loaded without fallback — real metrics")
	Else 
		tfail("[M2-F] times: loaded but shows estimate", "check font availability")
	Ok 
Ok 
plog("")
ameasure = fm_measure("Hello World!", "courier", 14, 0, ["widths", "stats"])
write($outdir+"m2G_widths.txt", fm_createwidths(ameasure[:widths]))
write($outdir+"m2G_stats.txt", ameasure[:stats])
tchecklen(ameasure[:widths], 1, "[M2-G] courier: exactly 1 width entry")
tchecknum(sb_item(ameasure[:widths], 1), "[M2-G] courier: width is positive")
tcheckstr(ameasure[:stats], "[M2-G] courier stats has header", "Font Metrics Statistics")
If $fmloaded 
	If Not substr(ameasure[:stats], "estimate")
		tpass("[M2-G] courier: loaded without fallback — real metrics")
	Else 
		tfail("[M2-G] courier: loaded but shows estimate", "check font availability")
	Ok 
Ok 
plog("")
aarial = fm_measure("Hello World!", "arial", 14, 0, ["widths", "stats"])
atimes = fm_measure("Hello World!", "times", 14, 0, ["widths", "stats"])
acourier = fm_measure("Hello World!", "courier", 14, 0, ["widths", "stats"])
barialloaded = Not substr(aarial[:stats], "estimate")
btimesloaded = Not substr(atimes[:stats], "estimate")
bcourierloaded = Not substr(acourier[:stats], "estimate")
If barialloaded And btimesloaded 
	If atimes[:widths][1] != aarial[:widths][1]
		tpass("[M2-H] times and arial have different widths  ("+
		atimes[:widths][1]+" vs "+aarial[:widths][1]+")")
	Else 
		tfail("[M2-H] times and arial have different widths", 
		"same value — one font may not be loaded")
	Ok 
Ok 
If barialloaded And bcourierloaded 
	If acourier[:widths][1] != aarial[:widths][1]
		tpass("[M2-H] courier and arial have different widths  ("+
		acourier[:widths][1]+" vs "+aarial[:widths][1]+")")
	Else 
		tfail("[M2-H] courier and arial have different widths", 
		"same value — one font may not be loaded")
	Ok 
Ok 
plog("")
plog("══════════════════════════════════════════════════════════")
plog("  [MODE 2R] Repeated use, substituted font and composition")
plog("══════════════════════════════════════════════════════════")
plog("")

# Many measurements in one run is how a label job normally uses this library. Each result
# must be its own, and repeating the first text must give the first answer back: the font
# tables live in file globals, so this is the check that they are rebuilt for every font
# asked and never carried over.
# The counter is not called i on purpose. This file runs at the top level, where an
# assignment creates a global, and the library uses a bare i as a loop counter inside its own
# functions. In Ring an assignment to a name that already exists as a global writes that
# global instead of making a local, so a counter called i here would be overwritten by the
# very call it is counting.
atexts = ["Hello World!", "Label 001", "A", "The quick brown fox jumps over the lazy dog", "12345"]
afonts = ["arial", "times", "courier", "arial", "arial"]
afirst = []
For nmeasure = 1 To len(atexts)
	ameasure = fm_measure(atexts[nmeasure], afonts[nmeasure], 12, 0, ["widths", "info"])
	If nmeasure = 1 afirst = ameasure[:widths] Ok 
	If len(ameasure[:widths]) >= 1 And ameasure[:widths][1] > 0
		tpass("[M2R] measurement "+nmeasure+" done ("+afonts[nmeasure]+", "+ameasure[:widths][1]+" px)")
	Else 
		tfail("[M2R] measurement "+nmeasure+" done", "no width came back")
	Ok 
Next 
aregenerated = fm_measure(atexts[1], afonts[1], 12, 0, ["widths"])
If len(afirst) = len(aregenerated[:widths]) And aregenerated[:widths][1] = afirst[1]
	tpass("[M2R] the first measurement, repeated after four others, gives the same width")
Else 
	tfail("[M2R] the first measurement, repeated after four others, gives the same width", "it differs")
Ok 
plog("")

# When the font asked for is not on this machine another one is used, and the widths are then
# the real metrics of another font. Those are two different facts, so [:info] keeps them
# apart: measured says the widths come from a font file, substituted says it was not the file
# that was asked for.
ameasure = fm_measure("Hello", "nosuchfont", 12, 0, ["widths", "info"])
If ameasure[:info][:substituted]
	tpass("[M2R] a font that is not installed is reported as substituted ("+ameasure[:info][:font]+")")
Else 
	tfail("[M2R] a font that is not installed is reported as substituted", "not reported")
Ok 
If len(ameasure[:info][:warnings]) >= 1
	tpass("[M2R] the substitution is reported in [:info][:warnings]")
Else 
	tfail("[M2R] the substitution is reported in [:info][:warnings]", "no warning reported")
Ok 
plog("")

# The other half of the same question: [:info][:measured] says whether the widths are real
# metrics or an estimate, and the estimate is a path of its own - what a caller gets when the
# font cannot be read at all. A name that is not installed does not reach it, because a system
# font is found and measured instead. A file that exists and is not a font does, and it is the
# one way of getting there that works the same on every machine.
cnotafont = $outdir+"notafont.ttf"
write(cnotafont, "this is not a font")
ameasure = fm_measure("Hi mm", cnotafont, 12, 0, ["widths", "info"])
If ameasure[:info][:measured] = 0
	tpass("[M2R] a file that is not a font gives estimated widths, and says so")
Else 
	tfail("[M2R] a file that is not a font gives estimated widths, and says so", "measured = "+ameasure[:info][:measured])
Ok 
If ameasure[:widths][1] > 0
	tpass("[M2R] the estimate still returns a usable width ("+ameasure[:widths][1]+" px)")
Else 
	tfail("[M2R] the estimate still returns a usable width", "got "+ameasure[:widths][1])
Ok 
aregenerated = fm_measure("Hi mm", cnotafont, 24, 0, ["widths"])
If aregenerated[:widths][1] = ameasure[:widths][1]*2
	tpass("[M2R] the estimate scales with the size like the metrics do")
Else 
	tfail("[M2R] the estimate scales with the size like the metrics do", ""+ameasure[:widths][1]+" -> "+aregenerated[:widths][1])
Ok 
# An estimate that gave every character the same width would pass the checks above and
# still be useless for laying out a label: the narrow letters have to come out narrower
# than the wide ones.
anarrow = fm_measure("iii", cnotafont, 12, 0, ["widths"])
awide = fm_measure("mmm", cnotafont, 12, 0, ["widths"])
If awide[:widths][1] > anarrow[:widths][1]
	tpass("[M2R] the estimate tells narrow characters from wide ones ("+anarrow[:widths][1]+" px vs "+awide[:widths][1]+" px)")
Else 
	tfail("[M2R] the estimate tells narrow characters from wide ones", ""+anarrow[:widths][1]+" vs "+awide[:widths][1])
Ok 
plog("")

# Labels are not written in ASCII only. A character outside it takes two, three or four
# bytes, and the measurement has to count characters: measured byte by byte, three accented
# letters would cost as much as six plain ones. That is the comparison below.
aaccented = fm_measure("aaa"+nl+"ààà"+nl+"aaaaaa", "arial", 12, 0, ["widths"])
If aaccented[:widths][2] = aaccented[:widths][1]
	tpass("[M2R] three accented letters measure as three letters, not six bytes")
Else 
	tfail("[M2R] three accented letters measure as three letters, not six bytes", ""+aaccented[:widths][2]+" against "+aaccented[:widths][1])
Ok 
If aaccented[:widths][3] = aaccented[:widths][1]*2
	tpass("[M2R] and six plain letters do measure twice three")
Else 
	tfail("[M2R] and six plain letters do measure twice three", ""+aaccented[:widths][3])
Ok 
athreebyte = fm_measure("€"+nl+"€€€", "arial", 12, 0, ["widths"])
If athreebyte[:widths][1] > 0 And athreebyte[:widths][2] = athreebyte[:widths][1]*3
	tpass("[M2R] a three byte character is one glyph, and three of them are three ("+athreebyte[:widths][1]+" px each)")
Else 
	tfail("[M2R] a three byte character is one glyph, and three of them are three", ""+athreebyte[:widths][1]+" then "+athreebyte[:widths][2])
Ok 
afourbyte = fm_measure("AA"+nl+"A😀A"+nl+"😀", "arial", 12, 0, ["widths"])
If afourbyte[:widths][2] = afourbyte[:widths][1]+afourbyte[:widths][3]
	tpass("[M2R] a four byte character adds exactly one glyph to the line")
Else 
	tfail("[M2R] a four byte character adds exactly one glyph to the line", ""+afourbyte[:widths][2]+" against "+afourbyte[:widths][1]+"+"+afourbyte[:widths][3])
Ok 
plog("")

# An empty line is a line: it has to survive the wrapping with a width of zero, because
# a caller stacking the lines needs the blank one to keep the spacing it asked for.
ablankline = fm_measure("A"+nl+nl+"B", "arial", 12, 0, ["lines", "widths"])
If len(ablankline[:lines]) = 3 And ablankline[:widths][2] = 0
	tpass("[M2R] an empty line comes back as a line of width zero")
Else 
	tfail("[M2R] an empty line comes back as a line of width zero", "got "+len(ablankline[:lines])+" lines")
Ok 
plog("")

# The estimate has its own table of widths, and a table is only useful if it tells the
# classes of characters apart: a digit is not as narrow as a full stop, and an accented
# letter has to be treated as the letter it is.
aestimated = fm_measure("2"+nl+"22"+nl+".."+nl+"à"+nl+"a", cnotafont, 12, 0, ["widths", "info"])
If aestimated[:info][:measured] = 0 And aestimated[:widths][2] = aestimated[:widths][1]*2
	tpass("[M2R] the estimate adds up character by character")
Else 
	tfail("[M2R] the estimate adds up character by character", ""+aestimated[:widths][2]+" against twice "+aestimated[:widths][1])
Ok 
If aestimated[:widths][3]*2 = aestimated[:widths][2]
	tpass("[M2R] the estimate keeps a full stop half the width of a digit")
Else 
	tfail("[M2R] the estimate keeps a full stop half the width of a digit", ""+aestimated[:widths][3]+" against "+aestimated[:widths][2])
Ok 
If aestimated[:widths][4] = aestimated[:widths][5]
	tpass("[M2R] the estimate treats an accented letter as a letter")
Else 
	tfail("[M2R] the estimate treats an accented letter as a letter", ""+aestimated[:widths][4]+" against "+aestimated[:widths][5])
Ok 
plog("")

# An empty line has to survive the wrapping too, and that is a different path from the plain
# split above: with a maximum width set the wrapper walks word by word, and the blank line
# has to come out of that walk as a line of its own.
awrapblank = fm_measure("a line long enough to be wrapped by force"+nl+nl+"tail", "arial", 12, 60, ["lines", "widths"])
If len(awrapblank[:lines]) > 3 And awrapblank[:widths][len(awrapblank[:lines])-1] = 0
	tpass("[M2R] wrapping keeps the empty line, with width zero ("+len(awrapblank[:lines])+" lines)")
Else 
	tfail("[M2R] wrapping keeps the empty line, with width zero", "got "+len(awrapblank[:lines])+" lines")
Ok 
plog("")

# A file that only claims to be a font collection: the 'ttcf' signature and nothing behind it.
# A real collection is read - the first font in it is taken - but this one carries no font at
# all, and what matters is that it says so through [:info][:measured] instead of pretending.
cfakecollection = $outdir+"collection.ttc"
write(cfakecollection, "ttcf"+copy(char(0), 16))
acollection = fm_measure("AB", cfakecollection, 12, 0, ["widths", "info"])
If acollection[:info][:measured] = 0 And acollection[:widths][1] > 0
	tpass("[M2R] a file that claims to be a collection but holds no font falls back to the estimate")
Else 
	tfail("[M2R] a file that claims to be a collection but holds no font falls back to the estimate", "measured = "+acollection[:info][:measured])
Ok 
# A byte that is not valid UTF-8 at all - a continuation byte on its own - must not stop
# the measurement nor invent a character: it is dropped, and the rest is measured.
astray = fm_measure("AB"+nl+"A"+char(128)+"B", "arial", 12, 0, ["widths"])
If astray[:widths][2] = astray[:widths][1]
	tpass("[M2R] a byte that is not valid UTF-8 is dropped, and the line still measures")
Else 
	tfail("[M2R] a byte that is not valid UTF-8 is dropped, and the line still measures", ""+astray[:widths][2]+" against "+astray[:widths][1])
Ok 
# The estimate table covers more than the Latin letters, and it does not give one width
# to everything it does not know: an Arabic letter and an ideograph come out different.
aarabic = fm_measure("ب", cnotafont, 12, 0, ["widths"])
aideographic = fm_measure("漢", cnotafont, 12, 0, ["widths"])
If aarabic[:widths][1] > 0 And aideographic[:widths][1] > 0 And aarabic[:widths][1] != aideographic[:widths][1]
	tpass("[M2R] the estimate has its own width for other scripts ("+aarabic[:widths][1]+" px and "+aideographic[:widths][1]+" px)")
Else 
	tfail("[M2R] the estimate has its own width for other scripts", ""+aarabic[:widths][1]+" and "+aideographic[:widths][1])
Ok 
plog("")

# What a caller really does with the widths: place the text. The library measures and
# stops there - where the words go, and in what box, is the caller's business, and it
# takes four lines out here.
ameasure = fm_measure("Label 001"+nl+"Batch 2026-08"+nl+"SKU 123456789012", "arial", 10, 0, ["lines", "widths"])
nwidestline = 0
For nline = 1 To len(ameasure[:widths])
	If ameasure[:widths][nline] > nwidestline nwidestline = ameasure[:widths][nline] Ok 
Next 
nover = 0
For nline = 1 To len(ameasure[:widths])
	If ameasure[:widths][nline] > nwidestline nover++ Ok 
Next 
nboxwidth = ceil(nwidestline)+20
ccomposed = '<svg xmlns="http://www.w3.org/2000/svg" width="'+nboxwidth+'" height="80">'+nl
For nline = 1 To len(ameasure[:lines])
	ccomposed += '<text x="10" y="'+(nline*20)+'">'+ameasure[:lines][nline]+'</text>'+nl
Next 
ccomposed += '</svg>'
tcheckstr(ccomposed, "[M2R] every measured line is placed in the drawing", "SKU 123456789012")
If nwidestline > 0 And nover = 0
	tpass("[M2R] the box is sized from the widest measured line ("+nwidestline+" px -> "+nboxwidth+" px)")
Else 
	tfail("[M2R] the box is sized from the widest measured line", "widest "+nwidestline)
Ok 
plog("")

# Widths scale with the point size: the same text at twice the size is twice as wide. It is
# the property a caller leans on to fit text into a box, and it is the first thing an estimate
# instead of a measurement would get wrong.
ameasure = fm_measure("Hello World!", "arial", 12, 0, ["widths"])
aregenerated = fm_measure("Hello World!", "arial", 24, 0, ["widths"])
If fabs(aregenerated[:widths][1]-2*ameasure[:widths][1]) < 0.01
	tpass("[M2R] doubling the size doubles the width ("+ameasure[:widths][1]+" -> "+aregenerated[:widths][1]+" px)")
Else 
	tfail("[M2R] doubling the size doubles the width", ""+ameasure[:widths][1]+" -> "+aregenerated[:widths][1])
Ok 

# Zero has to mean zero. In Ring null is the empty string and comparing the number 0 with it
# is true, so a default written as 'if x = null' swallows a zero the caller meant on purpose.
# Here the zero is not a margin but a meaning: nmaxwidth = 0 is how a caller says do not wrap.
# The default is zero as well, so the check moves the default out of the way first and puts
# it back after.
clongline = "A rather long single line of text that would wrap at sixty pixels"
$fmmaxwidth = 60
ameasure = fm_measure(clongline, "arial", 12, 0, ["lines"])
$fmmaxwidth = 0
If len(ameasure[:lines]) = 1
	tpass("[M2R] a maximum width of zero really means no wrapping, whatever the default holds")
Else 
	tfail("[M2R] a maximum width of zero really means no wrapping", "it wrapped into "+len(ameasure[:lines])+" lines")
Ok 
plog("")
plog("══════════════════════════════════════════════════════════")
plog("  [MODE 3A] Sandbox CLI/Disk (isolated subprocess)")
plog("══════════════════════════════════════════════════════════")
plog("")
ameasure = sb_run("m3a1", "Sandbox OK", "arial", 12, 0, null)
tchecklen(ameasure, 2, "[M3A-1] result has exactly 2 keys")
tchecklen(ameasure[:widths], 1, "[M3A-1] exactly 1 width entry")
tchecknum(sb_item(ameasure[:widths], 1), "[M3A-1] width is positive")
tcheckstr(ameasure[:stats], "[M3A-1] stats has header", "Font Metrics Statistics")
tcheckstr(ameasure[:stats], "[M3A-1] stats has Lines field", "Lines:")
plog("")
ameasure = sb_run("m3a2", "Hello Ring world font metrics test sandbox", "arial", 10, 60, ["widths", "stats"])
tchecklen(ameasure, 2, "[M3A-2] result has exactly 2 keys")
tcheckstr(ameasure[:stats], "[M3A-2] stats has Max Width field", "60 px")
If len(ameasure[:widths]) >= 2
	tpass("[M3A-2] narrow wrap produces >= 2 lines  ("+len(ameasure[:widths])+")")
Else 
	tfail("[M3A-2] narrow wrap produces >= 2 lines", "got "+len(ameasure[:widths]))
Ok 
plog("")
plog("══════════════════════════════════════════════════════════")
plog("  [MODE 3B] Sandbox In-Memory (ring_state_* API)")
plog("══════════════════════════════════════════════════════════")
plog("")
ameasure = sb_run_memory("m3b1", "Memory Test!", "arial", 14, 0, null)
tchecklen(ameasure, 2, "[M3B-1] result has exactly 2 keys (mem)")
tchecklen(ameasure[:widths], 1, "[M3B-1] exactly 1 width entry (mem)")
tchecknum(sb_item(ameasure[:widths], 1), "[M3B-1] width is positive (mem)")
tcheckstr(ameasure[:stats], "[M3B-1] stats has header (mem)", "Font Metrics Statistics")
tcheckstr(ameasure[:stats], "[M3B-1] stats has Lines field (mem)", "Lines:")
plog("")
ameasure = sb_run_memory("m3b2", "Alpha"+nl+""+nl+"Gamma", "arial", 12, 0, ["widths"])
tchecklen(ameasure, 1, "[M3B-2] result has exactly 1 key (mem)")
tchecklen(ameasure[:widths], 3, "[M3B-2] three lines (with empty): 3 width entries (mem)")
tchecknum(sb_item(ameasure[:widths], 1), "[M3B-2] first line has positive width (mem)")
tcheckzero(sb_item(ameasure[:widths], 2), "[M3B-2] empty line has width 0 (mem)")
tchecknum(sb_item(ameasure[:widths], 3), "[M3B-2] third line has positive width (mem)")
plog("")
plog("══════════════════════════════════════════════════════════")
If $nfail = 0
	plog("  ALL TESTS PASSED ("+$npass+"/"+($npass+$nfail)+")")
	plog("  Stats total checksum: "+statschecksum())
Else 
	plog("  PASSED : "+$npass)
	plog("  FAILED : "+$nfail+"  ← review output above")
Ok 
plog("══════════════════════════════════════════════════════════")
plog("")

Func tpass(label)

	plog("   [PASS] "+label)
	$npass++
	
Func tfail(label, reason)

	plog("   [FAIL] "+label+" — "+reason)
	$nfail++
	
Func tcheckstr(val, label, needle)

	If type(val) = "STRING" And len(val) > 0 And substr(val, needle)
		plog("   [PASS] "+label+"  ("+len(val)+" B)")
		$npass++
	Else 
		plog("   [FAIL] "+label+'  (needle="'+needle+'")')
		$nfail++
	Ok 
	
Func tchecklen(lst, n, label)

	If len(lst) = n 
		plog("   [PASS] "+label)
		$npass++
	Else 
		plog("   [FAIL] "+label+"  (got "+len(lst)+")")
		$nfail++
	Ok 
	
Func tchecknum(nvalue, clabel)

	nnumber = number(nvalue)
	If nnumber > 0
		plog("   [PASS] "+clabel+"  ("+nvalue+" px)")
		$npass++
	Else 
		plog("   [FAIL] "+clabel+"  (got "+string(nvalue)+")")
		$nfail++
	Ok 
	
Func tcheckzero(nvalue, clabel)

	nnumber = number(nvalue)
	If nnumber = 0
		plog("   [PASS] "+clabel)
		$npass++
	Else 
		plog("   [FAIL] "+clabel+"  (got "+string(nvalue)+")")
		$nfail++
	Ok 
	
Func fm_parsefile(ccontent)

	awidthvalues = []
	For cline In str2list(ccontent)
		cline = trim(cline)
		If cline != "" add(awidthvalues, number(cline)) Ok 
	Next 
	Return awidthvalues 
	
Func sb_run(ctag, ctext, cfont, nsize, nmaxwidth, awant)

	If nmaxwidth = null nmaxwidth = 0 Ok 
	If awant = null awant = ["widths", "stats"] Ok 
	cprefix = $outdir+ctag+"_"
	cdriverfile = $outdir+"_driver_"+ctag+".ring"
	ccapturefile = $outdir+"_cap_"+ctag+".txt"
	cdrivercode = 'load "ringfm.ring"'+nl 
	cdrivercode += "r = fm_measure("
	cdrivercode += sb_strexpr(ctext)+","
	cdrivercode += '"'+cfont+'",'
	cdrivercode += string(nsize)+","
	cdrivercode += string(nmaxwidth)+",null)"+nl 
	If find(awant, "widths")
		cdrivercode += 'write("'+cprefix+'widths.txt", fm_createwidths(r[:widths]))'+nl 
	Ok 
	If find(awant, "stats")
		cdrivercode += 'write("'+cprefix+'stats.txt",  r[:stats])'+nl 
	Ok 
	write(cdriverfile, cdrivercode)
	ring_run(cdriverfile+" > "+ccapturefile+" 2>&1")
	aresult = []
	If find(awant, "widths")
		If fexists(cprefix+"widths.txt")
			aresult[:widths] = fm_parsefile(read(cprefix+"widths.txt"))
		Else 
			tfail("["+ctag+"] sandbox wrote the widths file", "not produced")
			aresult[:widths] = []
		Ok 
	Ok 
	If find(awant, "stats")
		If fexists(cprefix+"stats.txt")
			aresult[:stats] = read(cprefix+"stats.txt")
		Else 
			tfail("["+ctag+"] sandbox wrote the stats file", "not produced")
			aresult[:stats] = ""
		Ok 
	Ok 
	If fexists(ccapturefile) remove(ccapturefile) Ok 
	If fexists(cdriverfile) remove(cdriverfile) Ok 
	Return aresult 
	
Func sb_run_memory(ctag, ctext, cfont, nsize, nmaxwidth, awant)

	If nmaxwidth = null nmaxwidth = 0 Ok 
	If awant = null awant = ["widths", "stats"] Ok 
	ostate = ring_state_init()
	ring_state_runcode(ostate, 'load "ringfm.ring"')
	ccallcode = "res = fm_measure("+sb_strexpr(ctext)+", "
	ccallcode += '"'+cfont+'", '
	ccallcode += string(nsize)+", "+string(nmaxwidth)+', ["'
	For nindex = 1 To len(awant)
		If nindex > 1 ccallcode += '", "' Ok 
		ccallcode += awant[nindex]
	Next 
	ccallcode += '"])'
	ring_state_runcode(ostate, ccallcode)
	areturned = ring_state_findvar(ostate, "res")
	ring_state_delete(ostate)
	If ! islist(areturned) Or len(areturned) < 3
		plog("   [FAIL] Sandbox retrieval failed for "+ctag)
		$nfail++
		Return sb_empty(awant)
	Ok 
	aresult = areturned[3]
	aoutput = []
	If find(awant, "widths")
		If sb_has(aresult, "widths") And islist(aresult[:widths])
			aoutput[:widths] = aresult[:widths]
			cwidthsdata = ""
			For nwidthvalue In aresult[:widths] cwidthsdata += string(nwidthvalue)+nl Next 
			write($outdir+ctag+"_widths.txt", cwidthsdata)
		Else 
			tfail("["+ctag+"] sandbox returned the widths", "missing or not a list")
			aoutput[:widths] = []
		Ok 
	Ok 
	If find(awant, "stats")
		If sb_has(aresult, "stats") And type(aresult[:stats]) = "STRING"
			aoutput[:stats] = aresult[:stats]
			write($outdir+ctag+"_stats.txt", aresult[:stats])
		Else 
			tfail("["+ctag+"] sandbox returned the stats", "missing or not a string")
			aoutput[:stats] = ""
		Ok 
	Ok 
	Return aoutput 
	
Func sb_strexpr(s)

	If len(s) = 0 Return '""' Ok 
	expr = "char("+ascii(s[1])+")"
	For i = 2 To len(s) expr += "+char("+ascii(s[i])+")" Next 
	Return expr 
	
# The service functions below are identical in the three test files of this family. They are
# copies on purpose: a library and its test must stand on their own, with nothing shared
# between them, and the price of that independence is three copies that stay the same word
# for word.
Func plog(ctext)

	? ctext 
	clogfile = $outdir+"output.txt"
	If fexists(clogfile)
		write(clogfile, read(clogfile)+ctext+nl)
	Else 
		write(clogfile, ctext+nl)
	Ok 
	
Func statschecksum()

	cchecksumfile = $outdir+"latest_stats_checksum.txt"
	aexistingfiles = dir(currentdir()+"/"+$outdir)
	astatfiles = []
	For afile In aexistingfiles 
		If len(afile[1]) > 10
			If lower(right(afile[1], 10)) = "_stats.txt"
				add(astatfiles, afile[1])
			Ok 
		Ok 
	Next 
	astatfiles = sort(astatfiles)
	ccumulativedata = ""
	For cfilename In astatfiles 
		ccumulativedata += read(currentdir()+"/"+$outdir+cfilename)
	Next 
	cnewmd5 = md5(ccumulativedata)
	If fexists(cchecksumfile)
		coldmd5 = trim(read(cchecksumfile))
		If coldmd5 != cnewmd5 
			plog("  !!!  WARNING: Stats checksum mismatch!")
			plog("	 previous : "+coldmd5)
			plog("	 current  : "+cnewmd5)
			See "  Update saved checksum with the new one? [y/N]: "
			Give canswer 
			canswer = lower(trim(canswer))
			If canswer = "y"
				write(cchecksumfile, cnewmd5)
				plog("  [CHECKSUM] Updated to: "+cnewmd5)
			Else 
				plog("  [CHECKSUM] Kept previous: "+coldmd5)
			Ok 
			Return cnewmd5 
		Ok 
	Ok 
	write(cchecksumfile, cnewmd5)
	Return cnewmd5 
	

# Runs a Ring script in a child process using the same interpreter that is running this test:
# exefilename() returns its full path (os_e.c), so "ring" does not have to be on the PATH.
# The path is quoted because it may contain spaces, and on Windows the whole command line is
# wrapped in one more pair of quotes, because cmd /c eats the first and the last one.
Func ring_run(cargs)
	ccmd = char(34) + exefilename() + char(34) + " " + cargs
	If iswindows()
		Return system(char(34) + ccmd + char(34))
	Ok 
	Return system(ccmd)

# True when the list holds the given key. Reading a key that is not there stops
# the program, so presence is asked before the value is read.
Func sb_has(alist, ckey)
	Return islist(alist) And find(alist, ckey, 1) > 0

# The n-th item of a list, or 0 when the list is shorter than expected. A mode that produced
# less than it should must be reported by the check that follows, not stop the whole run at
# that line.
Func sb_item(aitems, nindex)
	If islist(aitems) And len(aitems) >= nindex
		Return aitems[nindex]
	Ok 
	Return 0

# A result that carries every requested key, empty. It is what a failed mode returns, so the
# checks that follow report their own failure and the test goes on to the next mode.
Func sb_empty(awant)
	aresult = []
	If find(awant, "widths") aresult[:widths] = [] Ok 
	If find(awant, "stats") aresult[:stats] = "" Ok 
	Return aresult
