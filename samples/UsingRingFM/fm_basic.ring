# How wide is this text, set in this font, at this size?

load "ringfm.ring"

aResult = fm_measure("Hello, Ring!", "arial", 14, 0, ["lines", "widths", "info"])

? "Line      : " + aResult[:lines][1]
? "Width     : " + aResult[:widths][1] + " px"
? "Font used : " + aResult[:info][:font]
? "Measured  : " + aResult[:info][:measured] + "   (0 = built-in estimate, no font read)"
