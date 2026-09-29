# The same numbers as a report to read, one line per line of text.

load "ringfm.ring"

aResult = fm_measure("Una riga" + nl + "" + nl + "e un'altra riga piu lunga", "arial", 12, 0, ["stats"])

? aResult[:stats]
