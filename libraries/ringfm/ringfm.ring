# ringfm.ring - Text measurement in pure Ring: real font metrics read from a TrueType file,
# with a built-in estimate as a fallback when no font can be read.
#
# USAGE
#   aresult = fm_measure(ctext, cfont, nsize, nmaxwidth, awant)
#     ctext      the text to measure; newlines in it always split it into lines
#     cfont      a path to a .ttf or .ttc file, or one of the family names this file knows
#                (arial, times, courier, helvetica), looked up in the usual places on
#                Windows, macOS and Linux. A name that is not found is substituted, and the
#                substitution is reported
#     nsize      the point size the text will be set at
#     nmaxwidth  the width to wrap at, in pixels; zero means no wrapping, and the text is
#                split on its own newlines only
#     awant      parts to build: "lines", "widths", "stats", "info"
#   Pass null for any argument to take its global default.
#
# RESULT, one key per part asked for:
#   :lines   the text as laid out, one entry per line, wrapping included
#   :widths  the width in pixels of each of those lines, in the same order; an empty line
#            measures zero
#   :stats   the same numbers as a report to read, with every line listed
#   :info    [:font] the family actually read, [:path] the file it came from, [:measured]
#            false when the widths are the built-in estimate rather than real metrics,
#            [:substituted] true when the font asked for was not found, [:warnings].
#            The two flags answer different questions: the widths can be the real metrics of
#            a font other than the one asked for, and one flag could not tell that case
#
# The library prints nothing and writes no file. Warnings go to [:info][:warnings], and the
# caller decides whether to show them. Only the command-line block below writes to disk.
#
# Optional arguments are tested with isnull(), not with '= null': in Ring null is the empty
# string and 0 = "" is true, so '= null' would read nmaxwidth zero - no wrapping - as "not
# given" and wrap the text anyway.
#
# HOW THE WIDTHS ARE OBTAINED. The font file is read directly: the table directory, then
# 'head' for the design grid, 'hhea' and 'hmtx' for the advance widths, 'cmap' format 4 to
# turn characters into glyph numbers, and 'name' for the family. A character's width is its
# advance in font units scaled by size/unitsPerEm. When no font can be read the widths come
# from fm_approxadvance, a table of typical proportions: good enough for layout, not exact,
# and [:info][:measured] says which of the two the caller got.
#
# GLOBALS holding the defaults: $fmtext, $fmfont, $fmsize, $fmmaxwidth, $fmstats. The other
# $fm globals hold the state of the font currently loaded. Requires stdlibcore.ring.
Load "stdlibcore.ring"
$fmtext = "Hello World!"
$fmfont = "arial"
$fmsize = 12
$fmmaxwidth = 0
$fmstats = 1
$fmloaded = false 
$fmfallback = false 
$fmpath = ""
$fmfamily = ""
$fmunitsperem = 1000
$fmnumhmetrics = 0
$fmadvwidths = []
$fmcmapsegs = []
$fmcmapst = ""
# Run this file directly and it works as a small tool, so the library can be tried without
# writing a program:  ring ringfm.ring "Hello World!" arial 14 200
# With no arguments it prints the current defaults and uses them. It writes fm_lines.txt,
# fm_widths.txt and, when $fmstats is on, fm_stats.txt into the current folder.
If ismainsourcefile()
	aarguments = apparguments()
	nargumentcount = len(aarguments)
	If nargumentcount = 0
		? "" ? "--- FONT METRICS: Tutorial & Usage ---"
		? 'Usage: ring ringfm.ring ["text"] [font] [size] [maxwidth]'
		? 'Example: ring ringfm.ring "Hello World!" arial 14 200'
		? "" ? " - Note: maxwidth=0 means no wrapping (splits on embedded newlines only)."
		? "" ? "Applying current default settings:"
		? " - Text: "+'"'+$fmtext+'"'
		? " - Font: "+$fmfont+" (path or: arial | times | courier | helvetica)"
		? " - Size: "+$fmsize+" pt"
		? " - Max Width: "+$fmmaxwidth+" px (0 = no wrap)"
		? "---------------------------------------"
	Else 
		If nargumentcount >= 1 $fmtext = aarguments[1] Ok 
		If nargumentcount >= 2 $fmfont = aarguments[2] Ok 
		If nargumentcount >= 3 $fmsize = number(aarguments[3]) Ok 
		If nargumentcount >= 4 $fmmaxwidth = number(aarguments[4]) Ok 
	Ok 
	awantedparts = ["lines", "widths", "info"]
	If $fmstats add(awantedparts, "stats") Ok 
	aoutput = fm_measure($fmtext, $fmfont, $fmsize, $fmmaxwidth, awantedparts)
	For cwarning In aoutput[:info][:warnings] ? cwarning Next 
	clinescontent = ""
	For ctextline In aoutput[:lines] clinescontent += ctextline+nl Next 
	write("fm_lines.txt", clinescontent)
	write("fm_widths.txt", fm_createwidths(aoutput[:widths]))
	If $fmstats write("fm_stats.txt", aoutput[:stats]) Ok 
	? "Font metrics complete."
	? "Files created:"
	? " - fm_lines.txt"
	? " - fm_widths.txt"
	If $fmstats ? " - fm_stats.txt" Ok 
Ok 

# Loads a font and leaves everything the measurement needs in the globals: the design grid,
# the advance widths, the character-to-glyph map and the family name. Returns false, without
# raising, whenever the file cannot be used - missing, too short, not a font, or without one
# of the tables that matter - and the caller falls back to the estimate. Every step is checked
# before the next, so that a malformed font cannot read past the end of its own data.
Func fm_init(cpathorname)

	$fmloaded = false 
	$fmfallback = false 
	$fmadvwidths = []
	$fmcmapsegs = []
	$fmcmapst = ""
	$fmfamily = ""
	$fmpath = ""
	cpath = fm_resolvepath(cpathorname)
	If cpath = "" Return false Ok 
	cdata = read(cpath)
	If len(cdata) < 16 Return false Ok 
	nfontbase = fm_detectfontbase(cdata)
	If nfontbase < 0 Return false Ok 
	atables = fm_parsetabledir(cdata, nfontbase)
	If len(atables) = 0 Return false Ok 
	chead = fm_gettable(cdata, atables, "head")
	If len(chead) < 20 Return false Ok 
	$fmunitsperem = fm_ru16(chead, 19)
	If $fmunitsperem < 16 $fmunitsperem = 1000 Ok 
	chhea = fm_gettable(cdata, atables, "hhea")
	If len(chhea) < 36 Return false Ok 
	$fmnumhmetrics = fm_ru16(chhea, 35)
	chmtx = fm_gettable(cdata, atables, "hmtx")
	If len(chmtx) = 0 Return false Ok 
	$fmadvwidths = fm_parsehmtx(chmtx, $fmnumhmetrics)
	ccmap = fm_gettable(cdata, atables, "cmap")
	If len(ccmap) = 0 Return false Ok 
	aresult = fm_parsecmap4(ccmap)
	$fmcmapsegs = aresult[1]
	$fmcmapst = aresult[2]
	cname = fm_gettable(cdata, atables, "name")
	If len(cname) > 0 $fmfamily = fm_extractfontfamily(cname) Ok 
	$fmpath = cpath 
	$fmloaded = true 
	Return true 
	
# The width of one line in pixels: each character is turned into a glyph, and the glyph's
# advance is read in font units and scaled by size/unitsPerEm. With no font loaded the whole
# line goes to the estimate instead.
Func fm_measureline(ctext, nsize)

	If Not $fmloaded Return fm_estimatewidth(ctext, nsize) Ok 
	nscale = nsize/$fmunitsperem 
	nwidth = 0.0
	acp = fm_utf8decode(ctext)
	For ncp In acp 
		nglyph = fm_glyphlookup($fmcmapsegs, $fmcmapst, ncp)
		nwidth += fm_getadv($fmadvwidths, $fmnumhmetrics, nglyph)*nscale 
	Next 
	Return nwidth 
	
# Breaks the text into lines no wider than nmaxwidth, measuring as it goes: words are added
# to the current line while they fit and start a new one when they do not. The text's own
# newlines are paragraph breaks and are always kept, empty lines included. A single word
# longer than the limit is left on its own line rather than cut.
Func fm_wraptext(ctext, nsize, nmaxwidth)

	aresult = []
	aparagraphs = str2list(ctext)
	For cpara In aparagraphs 
		If cpara = ""
			add(aresult, "")
			Loop 
		Ok 
		awords = split(cpara, " ")
		cline = ""
		For cword In awords 
			If cword = "" Loop Ok 
			ctest = cline 
			If ctest != "" ctest += " " Ok 
			ctest += cword 
			If fm_measureline(ctest, nsize) <= nmaxwidth 
				cline = ctest 
			Else 
				If cline != "" add(aresult, cline) Ok 
				cline = cword 
			Ok 
		Next 
		If cline != "" add(aresult, cline) Ok 
	Next 
	Return aresult 
	
# The widths as text, one per line: the form the command-line block writes to file, and the
# one a caller can hand to anything that reads numbers.
Func fm_createwidths(awidths)

	cout = ""
	For nwidth In awidths cout += string(nwidth)+nl Next 
	Return cout 
	
# The measurement as a report to read: what was asked for, which font file was really used,
# whether the widths are metrics or an estimate, and the totals. Returns the text; only the
# command-line block writes it out.
Func fm_buildstats(ctext, cfont, nsize, nmaxwidth, awidths)

	nlines = len(awidths)
	ntotal = 0.0
	For nwidth In awidths ntotal += nwidth Next 
	cloaded = "yes"
	If $fmfallback cloaded = "yes (estimate)" Elseif Not $fmloaded cloaded = "no (estimate)" Ok 
	cstats = "Font Metrics Statistics"+nl 
	cstats += "======================="+nl 
	cstats += "Text: "+ctext+nl 
	cstats += "Font: "+cfont+nl 
	cstats += "Path: "+$fmpath+nl 
	cstats += "Family: "+$fmfamily+nl 
	cstats += "Loaded: "+cloaded+nl 
	cstats += "Size: "+nsize+" pt"+nl 
	cstats += "Max Width: "+nmaxwidth+" px"+nl 
	cstats += "Lines: "+nlines+nl 
	cstats += "Total Width: "+ntotal+" px"+nl 
	Return cstats 
	
# What the measurement rested on, as data: the family that was read, the file it came from,
# whether the widths are real metrics or an estimate, and whether the font asked for had to
# be substituted. A caller receiving estimated widths has no other way of knowing it. The
# warnings carry the same facts in words.
Func fm_buildinfo(cfont)

	ainfo = []
	ainfo[:font] = $fmfamily 
	ainfo[:path] = $fmpath 
	ainfo[:measured] = $fmloaded 
	ainfo[:substituted] = $fmfallback 
	awarnings = []
	If $fmfallback 
		add(awarnings, "Warning: font '"+cfont+"' was not found, a substitute was used.")
	Ok 
	If Not $fmloaded 
		add(awarnings, "Warning: no font file could be read, the widths are estimated.")
	Ok 
	ainfo[:warnings] = awarnings 
	Return ainfo 
	
# The report of fm_buildstats plus the laid-out text itself, line by line with its width.
# This is what [:stats] returns: after wrapping, the lines are a result and not just the
# input echoed back.
Func fm_buildstatsext(ctext, cfont, nsize, nmaxwidth, alines, awidths)

	cstats = fm_buildstats(ctext, cfont, nsize, nmaxwidth, awidths)
	cstats += "--- Wrapped Text Content ---"+nl 
	For nindex = 1 To len(alines)
		cstats += "["+nindex+"] ("+awidths[nindex]+" px): "+alines[nindex]+nl 
	Next 
	Return cstats 
	
# Turns what the caller asked for into a file that exists: an existing path is taken as it
# is, otherwise the name is looked up among the known families. If the name is unknown, or
# none of its candidates exist, the search falls back to helvetica and records the
# substitution, so that a caller can find out it is measuring a font it did not ask for.
Func fm_resolvepath(cpathorname)

	cname = trim(cpathorname)
	$fmfallback = false 
	If cname != "" And fexists(cname) Return cname Ok 
	clower = lower(cname)
	acandidates = fm_syscandidates(clower)
	If len(acandidates) = 0
		$fmfallback = true 
		acandidates = fm_syscandidates("helvetica")
	Ok 
	For cpath In acandidates 
		If fexists(cpath) Return cpath Ok 
	Next 
	Return ""
	
# Where the four known families usually live on Windows, macOS and Linux, in the order they
# should be tried. The Liberation faces come last: they stand in for the Microsoft ones and
# have the same advance widths.
Func fm_syscandidates(cname)

	If cname = "arial"
		Return [
			"C:/Windows/Fonts/arial.ttf", 
			"C:/Windows/Fonts/Arial.ttf", 
			"/Library/Fonts/Arial.ttf", 
			"/System/Library/Fonts/Supplemental/Arial.ttf", 
			"/usr/share/fonts/truetype/msttcorefonts/Arial.ttf", 
			"/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 
			"/usr/share/fonts/liberation/LiberationSans-Regular.ttf", 
			"/usr/share/fonts/TTF/arial.ttf"
		]
	Elseif cname = "times" Or cname = "times new roman"
		Return [
			"C:/Windows/Fonts/times.ttf", 
			"C:/Windows/Fonts/Times New Roman.ttf", 
			"/Library/Fonts/Times New Roman.ttf", 
			"/System/Library/Fonts/Supplemental/Times New Roman.ttf", 
			"/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf", 
			"/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf", 
			"/usr/share/fonts/liberation/LiberationSerif-Regular.ttf"
		]
	Elseif cname = "courier" Or cname = "courier new"
		Return [
			"C:/Windows/Fonts/cour.ttf", 
			"C:/Windows/Fonts/Courier New.ttf", 
			"/Library/Fonts/Courier New.ttf", 
			"/System/Library/Fonts/Supplemental/Courier New.ttf", 
			"/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf", 
			"/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf", 
			"/usr/share/fonts/liberation/LiberationMono-Regular.ttf"
		]
	Elseif cname = "helvetica"
		Return [
			"/System/Library/Fonts/Helvetica.ttc", 
			"/Library/Fonts/Helvetica.ttf", 
			"C:/Windows/Fonts/arial.ttf", 
			"C:/Windows/Fonts/Arial.ttf", 
			"/System/Library/Fonts/Supplemental/Arial.ttf", 
			"/Library/Fonts/Arial.ttf", 
			"/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 
			"/usr/share/fonts/liberation/LiberationSans-Regular.ttf", 
			"/usr/share/fonts/truetype/msttcorefonts/Arial.ttf"
		]
	Ok 
	Return []
	
# Where the font actually starts inside the file. A plain .ttf starts at zero, while a 'ttcf'
# collection holds several fonts behind a directory of their offsets, and the first one is
# taken. Returns -1 for anything that is not a font at all.
Func fm_detectfontbase(cdata)

	If len(cdata) < 4 Return -1 Ok 
	cmagic = substr(cdata, 1, 4)
	If cmagic = "ttcf"
		If len(cdata) < 16 Return -1 Ok 
		Return fm_ru32(cdata, 13)
	Ok 
	Return 0
	
# The font's table of contents: for every table its four-letter tag, where it starts and how
# long it is. Every record is checked against the real length of the file before it is read,
# so a truncated font stops the scan instead of reading past its end.
Func fm_parsetabledir(cdata, nfontbase)

	atables = []
	nbase = nfontbase+1
	If len(cdata) < nbase+11 Return atables Ok 
	nnumtables = fm_ru16(cdata, nbase+4)
	npos = nbase+12
	For nindex = 1 To nnumtables 
		If npos+15 > len(cdata) Exit Ok 
		ctag = substr(cdata, npos, 4)
		noffset = fm_ru32(cdata, npos+8)
		nlength = fm_ru32(cdata, npos+12)
		atables+[ctag, noffset, nlength]
		npos += 16
	Next 
	Return atables 
	
# The bytes of one table, by tag, clipped to what the file really contains: a length declared
# longer than the file is a malformed font and must not become a read past the end. Returns
# an empty string when the table is not there.
Func fm_gettable(cdata, atables, ctag)

	For aentry In atables 
		If aentry[1] = ctag 
			nstart = aentry[2]+1
			nlength = aentry[3]
			If nstart > len(cdata) Return "" Ok 
			nend = nstart+nlength-1
			If nend > len(cdata) nend = len(cdata) Ok 
			Return substr(cdata, nstart, nend-nstart+1)
		Ok 
	Next 
	Return ""
	
# The advance widths, one per glyph, out of the horizontal metrics table. Each record is four
# bytes and only the first two are the advance. The count comes from another table, so it is
# clamped to what this one can hold.
Func fm_parsehmtx(chmtx, nmetrics)

	aadv = []
	npos = 1
	nmax = floor(len(chmtx)/4)
	If nmetrics > nmax nmetrics = nmax Ok 
	For nindex = 1 To nmetrics 
		If npos+1 > len(chmtx) Exit Ok 
		aadv+fm_ru16(chmtx, npos)
		npos += 4
	Next 
	Return aadv 
	
# The character-to-glyph map, format 4, which covers the whole Basic Multilingual Plane. A
# file can carry several maps: the Windows Unicode one is preferred, any Unicode one is the
# fallback. What comes back is the list of segments - start, end, delta and range offset -
# plus the subtable bytes themselves, because the range part of a lookup reads glyph numbers
# straight out of them.
Func fm_parsecmap4(ccmap)

	nnumsub = fm_ru16(ccmap, 3)
	npos = 5
	nsuboff = 0
	nfallbackoff = 0
	For nindex = 1 To nnumsub 
		If npos+7 > len(ccmap) Exit Ok 
		nplatform = fm_ru16(ccmap, npos)
		nencoding = fm_ru16(ccmap, npos+2)
		noff = fm_ru32(ccmap, npos+4)
		If nplatform = 3 And nencoding = 1
			nsuboff = noff+1
			Exit 
		Ok 
		If nplatform = 0 And nfallbackoff = 0
			nfallbackoff = noff+1
		Ok 
		npos += 8
	Next 
	If nsuboff = 0 nsuboff = nfallbackoff Ok 
	asegs = []
	If nsuboff = 0 Or nsuboff > len(ccmap)
		Return [asegs, ""]
	Ok 
	csubtable = substr(ccmap, nsuboff, len(ccmap)-nsuboff+1)
	If len(csubtable) < 14 Return [asegs, ""] Ok 
	If fm_ru16(csubtable, 1) != 4 Return [asegs, ""] Ok 
	nsegcount = fm_ru16(csubtable, 7)/2
	nendbase = 15
	nstartbase = nendbase+2+nsegcount*2
	ndeltabase = nstartbase+nsegcount*2
	nrangebase = ndeltabase+nsegcount*2
	For nindex = 0 To nsegcount-1
		nend = fm_ru16(csubtable, nendbase+nindex*2)
		nstart = fm_ru16(csubtable, nstartbase+nindex*2)
		ndelta = fm_ri16(csubtable, ndeltabase+nindex*2)
		nrange = fm_ru16(csubtable, nrangebase+nindex*2)
		If nend = 65535 Exit Ok 
		nrangefieldpos = nrangebase+nindex*2
		asegs+[nstart, nend, ndelta, nrange, nrangefieldpos]
	Next 
	Return [asegs, csubtable]
	
# The glyph number for one character. Format 4 has two ways of saying it and both are here: a
# segment with range offset zero adds a delta to the character code, otherwise the glyph is
# read from an array inside the subtable, at a position measured from the range field itself,
# which is why that field's position is kept with the segment. A character in no segment is
# glyph 0, the font's own 'missing' glyph.
Func fm_glyphlookup(acmapsegs, csubtable, ncode)

	For aseg In acmapsegs 
		nstart = aseg[1]
		nend = aseg[2]
		If ncode < nstart Loop Ok 
		If ncode > nend Loop Ok 
		ndelta = aseg[3]
		nrange = aseg[4]
		nrangefieldpos = aseg[5]
		If nrange = 0
			Return (ncode+ndelta)%65536
		Else 
			nglyphpos = nrangefieldpos+nrange+(ncode-nstart)*2
			If nglyphpos+1 <= len(csubtable)
				nglyphid = fm_ru16(csubtable, nglyphpos)
				If nglyphid != 0 Return (nglyphid+ndelta)%65536 Ok 
			Ok 
			Return 0
		Ok 
	Next 
	Return 0
	
# The advance width of one glyph. Fonts list the metrics only up to the last glyph whose
# width differs, and everything past that repeats the final entry, so a glyph beyond the end
# takes that last width rather than being an error. With no metrics at all, a neutral value
# keeps the measurement going.
Func fm_getadv(aadvwidths, nnumhmetrics, nglyphid)

	If len(aadvwidths) = 0 Return 556 Ok 
	nindex = nglyphid+1
	If nindex < 1 nindex = 1 Ok 
	If nindex > len(aadvwidths) Return aadvwidths[len(aadvwidths)] Ok 
	Return aadvwidths[nindex]
	
# The characters of the text as code points. Ring strings are bytes, so a text from a file or
# a source literal may hold multi-byte UTF-8: measured byte by byte, one accented letter would
# count as two and one ideograph as three. A byte that starts no valid sequence is skipped.
Func fm_utf8decode(ctext)

	acp = []
	npos = 1
	nlength = len(ctext)
	While npos <= nlength 
		nbyte0 = ascii(ctext[npos])
		If nbyte0 < 128
			acp+nbyte0 
			npos++
		Elseif nbyte0 >= 192 And nbyte0 < 224 And npos+1 <= nlength 
			nbyte1 = ascii(ctext[npos+1])
			acp+(((nbyte0&31)<<6)|(nbyte1&63))
			npos += 2
		Elseif nbyte0 >= 224 And nbyte0 < 240 And npos+2 <= nlength 
			nbyte1 = ascii(ctext[npos+1])
			nbyte2 = ascii(ctext[npos+2])
			acp+(((nbyte0&15)<<12)|((nbyte1&63)<<6)|(nbyte2&63))
			npos += 3
		Elseif nbyte0 >= 240 And nbyte0 < 248 And npos+3 <= nlength 
			nbyte1 = ascii(ctext[npos+1])
			nbyte2 = ascii(ctext[npos+2])
			nbyte3 = ascii(ctext[npos+3])
			acp+(((nbyte0&7)<<18)|((nbyte1&63)<<12)|((nbyte2&63)<<6)|(nbyte3&63))
			npos += 4
		Else 
			npos++
		Ok 
	End 
	Return acp 
	
# The width of a line when no font could be read: the same walk over code points, with the
# typical proportions of fm_approxadvance instead of real metrics.
Func fm_estimatewidth(ctext, nsize)

	acp = fm_utf8decode(ctext)
	nwidth = 0.0
	For ncp In acp nwidth += fm_approxadvance(ncp)*(nsize/1000.0) Next 
	Return nwidth 
	
# Typical advance widths in the usual thousand-unit grid, by class of character: the narrow
# punctuation and the i and l, the wide m and w and their capitals, the ordinary lower and
# upper case, digits, accented Latin and Arabic. Good enough to lay a label out, never exact;
# [:info][:measured] is what tells the caller these were used.
Func fm_approxadvance(ncp)

	If ncp = 32 Return 278 Ok 
	If ncp = 33 Or ncp = 46 Or ncp = 44 Or ncp = 58 Or ncp = 59
		Return 278
	Ok 
	If ncp = 105 Or ncp = 108 Or ncp = 49 Return 278 Ok 
	If ncp = 102 Or ncp = 114 Or ncp = 116 Return 333 Ok 
	If ncp = 109 Or ncp = 119 Return 778 Ok 
	If ncp >= 97 And ncp <= 122 Return 556 Ok 
	If ncp = 77 Or ncp = 87 Return 889 Ok 
	If ncp >= 65 And ncp <= 90 Return 667 Ok 
	If ncp >= 48 And ncp <= 57 Return 556 Ok 
	If ncp >= 192 And ncp <= 383 Return 556 Ok 
	If ncp >= 0x0600 And ncp <= 0x06ff Return 500 Ok 
	Return 556
	
# The family name out of the 'name' table, which holds the same strings several times over
# for different platforms and encodings. Name id 1 is the family: the Windows record is
# preferred and returned at once, any other is kept as a candidate in case no Windows one
# turns up. Every offset is checked against the real length before it is read.
Func fm_extractfontfamily(cnamedata)

	If len(cnamedata) < 6 Return "" Ok 
	nformat = fm_ru16(cnamedata, 1)
	ncount = fm_ru16(cnamedata, 3)
	nstroff = fm_ru16(cnamedata, 5)
	cbestresult = ""
	nbestplatform = -1
	For i = 0 To ncount-1
		nrecoff = 7+i*12
		If nrecoff+12 > len(cnamedata) Exit Ok 
		nplatform = fm_ru16(cnamedata, nrecoff)
		nencoding = fm_ru16(cnamedata, nrecoff+2)
		nnameid = fm_ru16(cnamedata, nrecoff+6)
		nlength = fm_ru16(cnamedata, nrecoff+8)
		noff = fm_ru16(cnamedata, nrecoff+10)
		If nnameid = 1
			nstrstart = nstroff+noff 
			If nstrstart+nlength <= len(cnamedata)
				cstr = substr(cnamedata, nstrstart+1, nlength)
				If nplatform = 3 And (nencoding = 1 Or nencoding = 10)
					cstr = fm_utf16be(cstr)
				Elseif nplatform = 0
					cstr = fm_utf16be(cstr)
				Else 
					cstr = fm_latin1(cstr)
				Ok 
				If cstr != ""
					If nplatform = 3 Return cstr Ok 
					If nbestplatform != 3
						cbestresult = cstr 
						nbestplatform = nplatform 
					Ok 
				Ok 
			Ok 
		Ok 
	Next 
	Return cbestresult 
	
# Text stored as UTF-16 big endian, which is how the Windows and Unicode name records hold
# it, turned into the bytes Ring works with. Characters below the space are dropped rather
# than passed through into a name.
Func fm_utf16be(cdata)

	cresult = ""
	npos = 1
	While npos <= len(cdata)-1
		ncp = ascii(cdata[npos])*256+ascii(cdata[npos+1])
		If ncp >= 32 cresult += char(ncp) Ok 
		npos += 2
	End 
	Return cresult 
	
# Text stored one byte per character, which is how the older Macintosh name records hold it.
# Characters below the space are dropped, as above.
Func fm_latin1(cdata)

	cresult = ""
	For npos = 1 To len(cdata)
		nbyte = ascii(cdata[npos])
		If nbyte >= 32 cresult += char(nbyte) Ok 
	Next 
	Return cresult 
	
# Two bytes at a position, read as an unsigned number, big endian, which is the byte order
# every field in a font file uses. Positions are 1-based, like every index in Ring.
Func fm_ru16(cdata, npos)

	Return ascii(cdata[npos])*256+ascii(cdata[npos+1])
	
# The same two bytes read as a signed number. The delta of a cmap segment is signed, and
# reading it unsigned would send a whole range of characters to the wrong glyphs.
Func fm_ri16(cdata, npos)

	nvalue = fm_ru16(cdata, npos)
	If nvalue >= 32768 nvalue -= 65536 Ok 
	Return nvalue 
	
# Four bytes at a position, unsigned, big endian: the offsets and lengths in the table
# directory are this wide.
Func fm_ru32(cdata, npos)

	Return ascii(cdata[npos])*16777216+
	ascii(cdata[npos+1])*65536+
	ascii(cdata[npos+2])*256+
	ascii(cdata[npos+3])
	
# Entry point. Fills in the arguments left out from the globals, loads the font, lays the
# text out - wrapped if a width was given, split on its own newlines otherwise - measures
# every line, then builds only the parts asked for.
Func fm_measure(ctext, cfont, nsize, nmaxwidth, awant)

	If isnull(ctext) ctext = $fmtext Ok 
	If isnull(cfont) cfont = $fmfont Ok 
	If isnull(nsize) nsize = $fmsize Ok 
	If isnull(nmaxwidth) nmaxwidth = $fmmaxwidth Ok 
	If isnull(awant) awant = ["lines", "widths", "stats", "info"] Ok 
	fm_init(cfont)
	If nmaxwidth > 0
		alines = fm_wraptext(ctext, nsize, nmaxwidth)
	Else 
		alines = str2list(ctext)
	Ok 
	awidths = []
	For cline In alines 
		If cline = ""
			add(awidths, 0)
		Else 
			add(awidths, fm_measureline(cline, nsize))
		Ok 
	Next 
	aresult = []
	If find(awant, "lines") aresult[:lines] = alines Ok 
	If find(awant, "widths") aresult[:widths] = awidths Ok 
	If find(awant, "stats") aresult[:stats] = fm_buildstatsext(ctext, cfont, nsize, nmaxwidth, alines, awidths) Ok 
	If find(awant, "info") aresult[:info] = fm_buildinfo(cfont) Ok 
	Return aresult 
	