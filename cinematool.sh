# cinematool
#  Utilities for the cinema

cinemadbdir="./cinemadb"

cinema_imdb_index_list="+IMDB-INDEX +IMDB-PLOT +IMDB-STARS +IMDB-GENRE +IMDB-LOCATION"

cinema_awk()
{
    awk -F'|' -v OFS='|' "$@"
}


#
# Core utilities
#

# Core utilities work at the file level, they do not understand higher
# structured abstractions.

# cinema_identify FILE
#  Identify the given file.
#
#   Identifying the file causes a content index to be dumped on
#   stdout.  This content index describes the content of the file.
#   There is two types of records, for Tracks and for Attachments.
#
#     Track|INDEX|TYPE|CODEC
#     Attachment|INDEX|TYPE|SIZE|FILENAME
#
#   An output example is:
#
#     Track|0|video|V_MPEG4/ISO/AVC
#     Track|1|audio|A_VORBIS
#     Track|2|audio|A_VORBIS
#     Track|3|audio|A_VORBIS
#     Track|4|subtitles|S_VOBSUB
#     Track|5|subtitles|S_VOBSUB
#     Attachment|1|image/jpeg|93405|+POSTER
#     Attachment|2|text/plain|54|+INDEX

cinema_identify()
{
    env LANG=C mkvmerge --identify "$1" \
	| sed -e "s/'//g" -e '
/^File/{
  d
}
/^Track/{
  s/ ID /|/
  s/: /|/
  s/ (\(.*\))/|\1/
}
/^Attachment/{
  s/ ID /|/
  s/: type /|/
  s/. size /|/
  s/ bytes, file name /|/
}'
}


# cinema_has_index FILE
#  Predicate recognising a FILE having an embedded index

cinema_has_index()
{
    cinema_identify "$1" | awk -F'|' '
BEGIN { answer = 1 }
$1 == "Attachment" && $5 == "+INDEX" { answer = 0 }
END { exit answer }
'
    return $?
}


# cinema_extract_index_id FILE ATTACHMENT
#  Output the attachment id of ATTACHMENT file in FILE

cinema_extract_index_id()
{
    cinema_identify "$1" | awk -F'|' -v attachment="$2" '
$1 == "Attachment" && $5 == attachment { print $2 }
'
}


# cinema_extract_attachment FILE ATTACHMENT OUTPUT
#  Extract the ATTACHMENT from the FILE to OUTPUT
#
#   If OUTPUT is not given, it defaults to the value of ATTACHMENT.

cinema_extract_attachment()
{
    local id
    id=`cinema_extract_index_id "$1" "$2"`
    if [ -n "$id" ]; then
	mkvextract -q attachments "$1" "${id}${3:+:}$3"
    else
	false
    fi
    return $?
}


#
# Handling of cinemadb items
#

# A cinemadb item is represented by a directory in the cinemadbdir
# directory (this latter directory is called `repository'). The
# directory representing a cinemadb item may contain the following
# files:
#
#   - movie.mkv A symbolic link to the actual movie
#   - +INDEX
#   - +POSTER
#   - +FILENAME
#   - +IMDB

# cinema_db_list
#  List the content of the databank

cinema_db_list()
{
    ls "${cinemadbdir}" | grep -v '^+'
}

# cinema_db_import FILE
#  Import FILE in the cinemadb

cinema_db_import()
{
    local itemname
    local itemdir

    itemname=`basename -s .mkv "$1"`
    itemdir="${cinemadbdir}/${itemname}"
    install -d "${itemdir}"
    ln -s -f "$1" "${itemdir}"
    cinema_extract_attachment "$1" '+INDEX' "${itemdir}/+INDEX"
    rm -f  "${itemdir}/+FILENAME"
    touch "${itemdir}/+FILENAME"
    printf 'File: %s\n' "$1" >> "${itemdir}/+FILENAME"
    printf 'Item: %s\n' "${itemname}" >> "${itemdir}/+FILENAME"
}


# cinema_db_delete_item ITEM
#  Delete the given item from the cinema database

cinema_db_delete_item()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"
    rm -Rf "${itemdir}"
}


# cinema_db_mkindex_find ITEM
#  Find the files that should be catted together to obtain the DB record

cinema_db_mkindex_find()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"

    find "${itemdir}" -name '+FILENAME' -or -name '+INDEX'
}

# cinema_db_mkindex_item ITEM
#  Read the index file INDEX and output corresponding index lines on STDOUT

cinema_db_mkindex_item()
{
    cat `cinema_db_mkindex_find "$item"` | awk -F': ' '
BEGIN {
 OFS="|";
}

$1 == "Language" {
  split($2, language, "[, ]+");
  next;
}

$1 == "Wikipedia" {
  split($2, wikipedia, "[, ]+");
  next;
}

{
  data[$1] = $2;
}

END {
  for(lang in language)
  {
    print(\
      data["Item"],\
      data["File"],\
      data["Title"],\
      language[lang],\
      data["IMDB"],\
      wikipedia[1],\
      wikipedia[2],\
      data["Source"]\
    );
  }
}
'
}


# cinema_db_build_index
#  Build the index of the cinema database

cinema_db_build_index_loop()
{
    local item
    while read item; do
	cinema_db_mkindex_item "$item"
    done
}

cinema_db_build_index()
{
    cinema_db_list | cinema_db_build_index_loop > "${cinemadbdir}/+INDEX"
}


#
# IMDB interface
#


# cinema_imdb_index
#  Print the index of IMDB ids

cinema_imdb_index()
{
    awk -F'|' -v OFS='|' '{print($1,$5)}' < "${cinemadbdir}/+INDEX" \
	| sort -u
}


# cinema_imdb_find_id ITEM
#  Lookup the IMDB id associated to ITEM

cinema_imdb_find_id()
{
    awk -F'|' -v "item=$1" '$1 == item {print($5); exit}' \
	< "${cinemadbdir}/+INDEX" 
}


# cinema_imdb_fetch ITEM
#  Fetch the IMDB page associated with ITEM

cinema_imdb_fetch()
{
    local itemdir
    local imdbid

    imdbid=`cinema_imdb_find_id "$1"`
    itemdir="${cinemadbdir}/$1"

    fetch -o "${itemdir}/imdb.html" "http://www.imdb.com/title/tt${imdbid}"
}

cinema_imdb_maybe_fetch()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    if [ \! -e "${itemdir}/imdb.html" ]; then
	echo "$1: fetch IMDB data"
	cinema_imdb_fetch "$1"
    fi
}


cinema_imdb_maybe_fetch_all()
{
    for item in `cinema_db_list`; do
	cinema_imdb_maybe_fetch "$item"
    done
}


# cinema_imdb_mkindex_item ITEM
#  Update IMDB index files from the fetched page assocaited with ITEM

cinema_imdb_mkindex_item()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    echo "$1: making local index"

    lynx -nolist -width=1024 -dump "${itemdir}/imdb.html" \
	| iconv -f latin-9 -t utf-8 \
	| cinema_imdb_mkindex_item_filter \
	| cinema_imdb_mkindex_item_format "$1"    
}

cinema_imdb_mkindex_item_filter()
{
    sed -n -e '
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
/^Stars:/s/ and /, /g
/^Stars:/s/, / | /g
/^Filming Locations:/s/, / | /g
/^Production Co:/s/, / | /g
/^Aspect Ratio:/s/\([0-9][0-9]*\.[0-9]*\) *: *1/\1/
/^Quick Links:/d
/^Parents Guide:/d
/^[A-Z][A-Za-z ]*:/p
'
}

cinema_imdb_mkindex_item_format()
{
    awk -F': ' -v OFS='|' -v item="$1" -v cinemadbdir="${cinemadbdir}" '
function splitbars(data, variable)
{
   split(data, variable, " *[|] *");
}

function resource(name)
{
  return cinemadbdir "/" item "/" name;
}

function printarray(variable, file)
{
   for(i in variable)
     print(item, variable[i]) > (resource(file))
}

$1 == "Title" {
  if(data["Title"] != "")
  {
     next;
  }
  else
  {
     data["Title"] = $2;
  }
}

$1 == "Plot Keywords" {
   splitbars($2, plot_keywords);
   next;
}

$1 == "Genres" {
   splitbars($2, genres);
   next;
}

$1 == "Stars" {
   splitbars($2, stars);
   next;
}

$1 == "Filming Locations" {
   splitbars($2, filming_locations);
   next;
}

{ data[$1] = $2 }

END {
  print( \
    item, \
    data["Title"], \
    data["Year"], \
    data["Director"], \
    data["Writer"], \
    data["Language"], \
    data["Runtime"], \
    data["Country"], \
    data["Aspect Ratio"] \
  ) > (resource("+IMDB-INDEX"));
  printarray(plot_keywords, "+IMDB-PLOT");
  printarray(genres, "+IMDB-GENRE");
  printarray(stars, "+IMDB-STARS");
  printarray(filming_locations, "+IMDB-LOCATION");
}
'
}


# cinema_imdb_mkindex
#  Rebuild the IMDB indexes from fetched pages

cinema_imdb_build_index()
{
    local file
    local item

    for item in `cinema_db_list`; do
	cinema_imdb_mkindex_item "$item"
    done

    for file in $cinema_imdb_index_list; do
	cat ${cinemadbdir}/*/${file} > ${cinemadbdir}/${file}
    done
}


# cinema_imdb_clean ITEM
#  Clean IMDB files associated with ITEM

cinema_imdb_clean()
{
    local itemdir
    local file

    itemdir="${cinemadbdir}/$1"

    for file in $cinema_imdb_index_list; do
	rm -f "${itemdir}/${file}"
    done
}



#
# Cinema
#

cinema_find_fake()
{
    for file in Splendor_in_the_Grass.mkv Le_Promeneur_du_Champ_de_Mars.mkv Das_Leben_der_Anderen.mkv Du_rififi_chez_les_hommes.mkv; do
	echo "/library/video/cinema/${file}"
    done
}

cinema_find_true()
{
    find /library/video/cinema -name '*.mkv'
}

cinema_find()
{
    cinema_find_true
}

cinema_db_delete_all()
{
    local item
    for item in `cinema_db_list`; do
	cinema_db_delete_item "${item}"
    done
}

cinema_db_import_all()
{
    for file in `cinema_find`; do
	cinema_db_import "$file"
    done
}

cinema_db_delete_item Bunny_Lake_is_MIssing
cinema_db_import the cinemadb

cinema_db_import()
{
    local itemname
    local itemdir

    itemname=`basename -s .mkv "$1"`
    itemdir="${cinemadbdir}/${itemname}"
    install -d "${itemdir}"
    ln -s -f "$1" "${itemdir}"
    cinema_extract_attachment "$1" '+INDEX' "${itemdir}/+INDEX"
    rm -f  "${itemdir}/+FILENAME"
    touch "${itemdir}/+FILENAME"
    printf 'File: %s\n' "$1" >> "${itemdir}/+FILENAME"
    printf 'Item: %s\n' "${itemname}" >> "${itemdir}/+FILENAME"
}


# cinema_db_delete_item ITEM
#  Delete the given item from the cinema database
cinema_db_delete_item()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"
    rm -Rf "${itemdir}"
}


# cinema_db_mkindex_find ITEM
#  Find the files that should be catted together to obtain the DB record

cinema_db_mkindex_find()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"

    find "${itemdir}" -name '+FILENAME' -or -name '+INDEX'
}

# cinema_db_mkindex_item ITEM
#  Read the index file INDEX and output corresponding index lines on STDOUT

cinema_db_mkindex_item()
{
    cat `cinema_db_mkindex_find "$item"` | awk -F': ' '
BEGIN {
 OFS="|";
}

$1 == "Language" {
  split($2, language, "[, ]+");
  next;
}

$1 == "Wikipedia" {
  split($2, wikipedia, "[, ]+");
  next;
}

{
  data[$1] = $2;
}

END {
  for(lang in language)
  {
    print(data["Item"], data["File"], data["Title"], language[lang], data["IMDB"], wikipedia[1], wikipedia[2], data["Source"]);
  }
}
'
}

# cinema_db_build_index
#  Build the index of the cinema database

cinema_db_build_index_loop()
{
    local item
    while read item; do
	cinema_db_mkindex_item "$item"
    done
}

cinema_db_build_index()
{
    cinema_db_list | cinema_db_build_index_loop > "${cinemadbdir}/+INDEX"
}


#
# IMDB interface
#


# cinema_imdb_index
#  Print the index of IMDB ids

cinema_imdb_index()
{
    awk -F'|' -v OFS='|' '{print($1,$5)}' < "${cinemadbdir}/+INDEX" \
	| sort -u
}


# cinema_imdb_find_id ITEM
#  Lookup the IMDB id associated to ITEM

cinema_imdb_find_id()
{
    awk -F'|' -v "item=$1" '$1 == item {print($5); exit}' \
	< "${cinemadbdir}/+INDEX" 
}


# cinema_imdb_fetch ITEM
#  Fetch the IMDB page associated with ITEM

cinema_imdb_fetch()
{
    local itemdir
    local imdbid

    imdbid=`cinema_imdb_find_id "$1"`
    itemdir="${cinemadbdir}/$1"

    fetch -o "${itemdir}/imdb.html" "http://www.imdb.com/title/tt${imdbid}"
}

cinema_imdb_maybe_fetch()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    if [ \! -e "${itemdir}/imdb.html" ]; then
	echo "$1: fetch IMDB data"
	cinema_imdb_fetch "$1"
    fi
}


cinema_imdb_maybe_fetch_all()
{
    for item in `cinema_db_list`; do
	cinema_imdb_maybe_fetch "$item"
    done
}


# cinema_imdb_mkindex_item ITEM
#  Update IMDB index files from the fetched page assocaited with ITEM

cinema_imdb_mkindex_item()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    lynx -nolist -width=1024 -dump "${itemdir}/imdb.html" \
	| iconv -f latin-9 -t utf-8 \
	| cinema_imdb_mkindex_item_filter \
	| cinema_imdb_mkindex_item_format "$1"    
}

cinema_imdb_mkindex_item_filter()
{
    sed -n -e '
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
/^Stars:/s/ and /, /g
/^Stars:/s/, / | /g
/^Filming Locations:/s/, / | /g
/^Production Co:/s/, / | /g
/^Aspect Ratio:/s/\([0-9][0-9]*\.[0-9]*\) *: *1/\1/
/^Quick Links:/d
/^Parents Guide:/d
/^[A-Z][A-Za-z ]*:/p
'
}

cinema_imdb_mkindex_item_format()
{
    awk -F': ' -v OFS='|' -v item="$1" -v cinemadbdir="${cinemadbdir}" '
function splitbars(data, variable)
{
   split(data, variable, " *[|] *");
}

function resource(name)
{
  return cinemadbdir "/" item "/" name;
}

function printarray(variable, file)
{
   for(i in variable)
     print(item, variable[i]) > (resource(file))
}

$1 == "Title" {
  if(data["Title"] != "")
  {
     next;
  }
  else
  {
     data["Title"] = $2;
  }
}

$1 == "Plot Keywords" {
   splitbars($2, plot_keywords);
   next;
}

$1 == "Genres" {
   splitbars($2, genres);
   next;
}

$1 == "Stars" {
   splitbars($2, stars);
   next;
}

$1 == "Filming Locations" {
   splitbars($2, filming_locations);
   next;
}

{ data[$1] = $2 }

END {
  print( \
    item, \
    data["Title"], \
    data["Year"], \
    data["Director"], \
    data["Writer"], \
    data["Language"], \
    data["Runtime"], \
    data["Country"], \
    data["Aspect Ratio"] \
  ) > (resource("+IMDB-INDEX"));
  printarray(plot_keywords, "+IMDB-PLOT");
  printarray(genres, "+IMDB-GENRE");
  printarray(stars, "+IMDB-STARS");
  printarray(filming_locations, "+IMDB-LOCATION");
}
'
}


# cinema_imdb_mkindex
#  Rebuild the IMDB indexes from fetched pages

cinema_imdb_build_index()
{
    local file
    local item

    for item in `cinema_db_list`; do
	cinema_imdb_mkindex_item "$item"
    done

    for file in $cinema_imdb_index_list; do
	cat ${cinemadbdir}/*/${file} > ${cinemadbdir}/${file}
    done
}


# cinema_imdb_clean ITEM
#  Clean IMDB files associated with ITEM

cinema_imdb_clean()
{
    local itemdir
    local file

    itemdir="${cinemadbdir}/$1"

    for file in $cinema_imdb_index_list; do
	rm -f "${itemdir}/${file}"
    done
}



#
# Cinema
#

cinema_find_fake()
{
    for file in Splendor_in_the_Grass.mkv Le_Promeneur_du_Champ_de_Mars.mkv Das_Leben_der_Anderen.mkv Du_rififi_chez_les_hommes.mkv; do
	echo "/library/video/cinema/${file}"
    done
}

cinema_find_true()
{
    find /library/video/cinema -name '*.mkv'
}

cinema_find()
{
    cinema_find_true
}

cinema_db_delete_all()
{
    local item
    for item in `cinema_db_list`; do
	cinema_db_delete_item "${item}"
    done
}

cinema_db_import_all()
{
    for file in `cinema_find`; do
	cinema_db_import "$file"
    done
}

cinema_db_delete_item Bunny_Lake_is_MIssing
cinema_db_import the cinemadb

cinema_db_import()
{
    local itemname
    local itemdir

    itemname=`basename -s .mkv "$1"`
    itemdir="${cinemadbdir}/${itemname}"
    install -d "${itemdir}"
    ln -s -f "$1" "${itemdir}"
    cinema_extract_attachment "$1" '+INDEX' "${itemdir}/+INDEX"
    rm -f  "${itemdir}/+FILENAME"
    touch "${itemdir}/+FILENAME"
    printf 'File: %s\n' "$1" >> "${itemdir}/+FILENAME"
    printf 'Item: %s\n' "${itemname}" >> "${itemdir}/+FILENAME"
}


# cinema_db_delete_item ITEM
#  Delete the given item from the cinema database
cinema_db_delete_item()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"
    rm -Rf "${itemdir}"
}


# cinema_db_mkindex_find ITEM
#  Find the files that should be catted together to obtain the DB record

cinema_db_mkindex_find()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"

    find "${itemdir}" -name '+FILENAME' -or -name '+INDEX'
}

# cinema_db_mkindex_item ITEM
#  Read the index file INDEX and output corresponding index lines on STDOUT

cinema_db_mkindex_item()
{
    cat `cinema_db_mkindex_find "$item"` | awk -F': ' '
BEGIN {
 OFS="|";
}

$1 == "Language" {
  split($2, language, "[, ]+");
  next;
}

$1 == "Wikipedia" {
  split($2, wikipedia, "[, ]+");
  next;
}

{
  data[$1] = $2;
}

END {
  for(lang in language)
  {
    print(data["Item"], data["File"], data["Title"], language[lang], data["IMDB"], wikipedia[1], wikipedia[2], data["Source"]);
  }
}
'
}

# cinema_db_build_index
#  Build the index of the cinema database

cinema_db_build_index_loop()
{
    local item
    while read item; do
	cinema_db_mkindex_item "$item"
    done
}

cinema_db_build_index()
{
    cinema_db_list | cinema_db_build_index_loop > "${cinemadbdir}/+INDEX"
}


#
# IMDB interface
#


# cinema_imdb_index
#  Print the index of IMDB ids

cinema_imdb_index()
{
    awk -F'|' -v OFS='|' '{print($1,$5)}' < "${cinemadbdir}/+INDEX" \
	| sort -u
}


# cinema_imdb_find_id ITEM
#  Lookup the IMDB id associated to ITEM

cinema_imdb_find_id()
{
    awk -F'|' -v "item=$1" '$1 == item {print($5); exit}' \
	< "${cinemadbdir}/+INDEX" 
}


# cinema_imdb_fetch ITEM
#  Fetch the IMDB page associated with ITEM

cinema_imdb_fetch()
{
    local itemdir
    local imdbid

    imdbid=`cinema_imdb_find_id "$1"`
    itemdir="${cinemadbdir}/$1"

    fetch -o "${itemdir}/imdb.html" "http://www.imdb.com/title/tt${imdbid}"
}

cinema_imdb_maybe_fetch()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    if [ \! -e "${itemdir}/imdb.html" ]; then
	cinema_imdb_fetch "$1"
    fi
}


cinema_imdb_maybe_fetch_all()
{
    for item in `cinema_db_list`; do
	cinema_imdb_maybe_fetch "$item"
    done
}


# cinema_imdb_mkindex_item ITEM
#  Update IMDB index files from the fetched page assocaited with ITEM

cinema_imdb_mkindex_item()
{
    local itemdir

    itemdir="${cinemadbdir}/$1"

    lynx -nolist -width=1024 -dump "${itemdir}/imdb.html" \
	| iconv -f latin-9 -t utf-8 \
	| cinema_imdb_mkindex_item_filter \
	| cinema_imdb_mkindex_item_format "$1"    
}

cinema_imdb_mkindex_item_filter()
{
    sed -n -e '
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
/^Stars:/s/ and /, /g
/^Stars:/s/, / | /g
/^Filming Locations:/s/, / | /g
/^Production Co:/s/, / | /g
/^Aspect Ratio:/s/\([0-9][0-9]*\.[0-9]*\) *: *1/\1/
/^Quick Links:/d
/^Parents Guide:/d
/^[A-Z][A-Za-z ]*:/p
'
}

cinema_imdb_mkindex_item_format()
{
    awk -F': ' -v OFS='|' -v item="$1" -v cinemadbdir="${cinemadbdir}" '
function splitbars(data, variable)
{
   split(data, variable, " *[|] *");
}

function resource(name)
{
  return cinemadbdir "/" item "/" name;
}

function printarray(variable, file)
{
   for(i in variable)
     print(item, variable[i]) > (resource(file))
}

$1 == "Title" {
  if(data["Title"] != "")
  {
     next;
  }
  else
  {
     data["Title"] = $2;
  }
}

$1 == "Plot Keywords" {
   splitbars($2, plot_keywords);
   next;
}

$1 == "Genres" {
   splitbars($2, genres);
   next;
}

$1 == "Stars" {
   splitbars($2, stars);
   next;
}

$1 == "Filming Locations" {
   splitbars($2, filming_locations);
   next;
}

{ data[$1] = $2 }

END {
  print( \
    item, \
    data["Title"], \
    data["Year"], \
    data["Director"], \
    data["Writer"], \
    data["Language"], \
    data["Runtime"], \
    data["Country"], \
    data["Aspect Ratio"] \
  ) > (resource("+IMDB-INDEX"));
  printarray(plot_keywords, "+IMDB-PLOT");
  printarray(genres, "+IMDB-GENRE");
  printarray(stars, "+IMDB-STARS");
  printarray(filming_locations, "+IMDB-LOCATION");
}
'
}


# cinema_imdb_mkindex
#  Rebuild the IMDB indexes from fetched pages

cinema_imdb_build_index()
{
    local file
    local item

    for item in `cinema_db_list`; do
	cinema_imdb_mkindex_item "$item"
    done

    for file in $cinema_imdb_index_list; do
	cat ${cinemadbdir}/*/${file} > ${cinemadbdir}/${file}
    done
}


# cinema_imdb_clean ITEM
#  Clean IMDB files associated with ITEM

cinema_imdb_clean()
{
    local itemdir
    local file

    itemdir="${cinemadbdir}/$1"

    for file in $cinema_imdb_index_list; do
	rm -f "${itemdir}/${file}"
    done
}



#
# Cinema
#

cinema_find_fake()
{
    for file in Splendor_in_the_Grass.mkv Le_Promeneur_du_Champ_de_Mars.mkv Das_Leben_der_Anderen.mkv Du_rififi_chez_les_hommes.mkv; do
	echo "/library/video/cinema/${file}"
    done
}

cinema_find_true()
{
    find /library/video/cinema -name '*.mkv'
}

cinema_find()
{
    cinema_find_true
}

cinema_db_delete_all()
{
    local item
    for item in `cinema_db_list`; do
	cinema_db_delete_item "${item}"
    done
}

cinema_db_import_all()
{
    for file in `cinema_find`; do
	cinema_db_import "$file"
    done
}

cinema_db_build_index
cinema_imdb_maybe_fetch_all
cinema_imdb_build_index
