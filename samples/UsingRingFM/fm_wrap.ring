# Give a maximum width and the text is laid out into lines.
# A width of zero means no wrapping: the text splits on its own newlines only.

load "ringfm.ring"

cText = "Text measurement in pure Ring, with real font metrics read from a TrueType file."

aResult = fm_measure(cText, "arial", 12, 220, ["lines", "widths"])

for i = 1 to len(aResult[:lines])
	? "" + aResult[:widths][i] + " px" + char(9) + aResult[:lines][i]
next
