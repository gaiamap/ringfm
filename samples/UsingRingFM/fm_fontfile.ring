# A path to a .ttf or .ttc file is measured directly. A family name that
# cannot be found is substituted, and the substitution is reported, so the
# two flags in [:info] answer different questions.

load "ringfm.ring"

aResult = fm_measure("Kerning and advances", "no-such-font-here", 16, 0, ["widths", "info"])

? "Asked for   : no-such-font-here"
? "Font used   : " + aResult[:info][:font]
? "Read from   : " + aResult[:info][:path]
? "Substituted : " + aResult[:info][:substituted]
? "Measured    : " + aResult[:info][:measured]
? "Width       : " + aResult[:widths][1] + " px"
