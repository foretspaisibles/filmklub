/Title:/{
  s/^  *//
  s/ (\([0-9][0-9][0-9][0-9]\))/\
Year: \1/
  p
  n
}
/(original title)/{
  s/ (original title)//
  s/^ */Title: /
  p
  n
}
/^   See more »/d
/^   See full technical specs »/d
/^   Edit/d
/^Storyline/s/$/:/
/^[A-Z][A-Za-z ]*:/{
  N
  N
  s/\n/ /g
  s/	/ /g
  s/  */ /g
  s/\[[0-9][0-9]*\]//g
  s/ See more »//g
  s/ \| Add\/edit official sites »//g
  s/ \| See full cast and crew//g
  s/ \|$//
}
/^Storyline:/{
  s/ Written.*//
  s/' /'/g
  s/\.\.\./…/g
  s/"\([^"]*\)"/“\1”/g
  s/---/—/g
  # Fix the use of single quotes as quotes
  s/ '\([^']*\)'/ “\1”/g
  # Fix the position of punctuation
  s/”\([\.,]\)/\1”/g
}
/Add Full Plot/d
/Add Synopsis/d
/^Stars:/s/ and /, /g
/^Stars:/s/, / | /g
/^Filming Locations:/s/, / | /g
/^Production Co:/s/, / | /g
/^Aspect Ratio:/s/\([0-9][0-9]*\.[0-9]*\) *: *1/\1/
/^Quick Links:/d
/^Parents Guide:/d
/^[A-Z][A-Za-z ]*:/p
