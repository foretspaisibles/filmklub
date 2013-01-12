# cinematool
#  Utilities for the cinema

#
# Configuration
#

# cinema_makeprefix
#  Make installation prefix

cinema_makeprefix()
{
    echo "@@PREFIX@@" | sed -e 's/@@.*@@//'
}

cinema_maketool()
{
    echo "${cinematooldir}${cinematooldir:+/}$1"
}

cinemaprefix=`cinema_makeprefix`
cinemadbdir="${cinemaprefix}cinemadb"
cinematooldir="${cinemaprefix}${cinemaprefix:+libexec/cinema}"
cinemawwwdir="${cinemaprefix}${cinemaprefix:+var/cinema/}www"

# cinema_print_configuration
#  Print important configuration values

cinema_print_configuration()
{
    cat<<EOF
cinemaprefix="${cinemaprefix}"
cinemadbdir="${cinemadbdir}"
cinematooldir="${cinematooldir}"
cinemawwwdir="${cinemawwwdir}"
EOF
}


cinema_imdb_index_list="+IMDB-INDEX +IMDB-PLOT +IMDB-STARS +IMDB-GENRE +IMDB-LOCATION +IMDB-STORYLINE"

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
	| sed -f `cinema_maketool cinema_identify.sed`
}


# cinema_extract_attachment_id FILE ATTACHMENT
#  Output the attachment id of ATTACHMENT file in FILE

cinema_extract_attachment_id()
{
    cinema_identify "$1" | cinema_awk -v attachment="$2" '
$1 == "Attachment" && $5 == attachment { print $2 }
'
}

# cinema_has_attachment_id FILE ATTACHMENT
#  Predicate recognising FILE having the given ATTACHMENT

cinema_has_attachment()
{
    local id
    id=`cinema_extract_attachment_id "$1" "$2"`
    test -n "$id"
    return $?
}


# cinema_extract_attachment FILE ATTACHMENT OUTPUT
#  Extract the ATTACHMENT from the FILE to OUTPUT
#
#   If OUTPUT is not given, it defaults to the value of ATTACHMENT.

cinema_extract_attachment()
{
    local id
    id=`cinema_extract_attachment_id "$1" "$2"`
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
#   - +LANG
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
    local charset

    itemname=`basename -s .mkv "$1"`
    itemdir="${cinemadbdir}/${itemname}"
    install -d "${itemdir}"
    ln -s -f "$1" "${itemdir}/movie.mkv"
    cinema_extract_attachment "$1" '+INDEX' "${itemdir}/+INDEX.raw"
    charset=`file -i "${itemdir}/+INDEX.raw" | sed -e 's/.*charset=//'`
    iconv -f "${charset}" -t UTF-8 \
	< "${itemdir}/+INDEX.raw" \
	> "${itemdir}/+INDEX"
    rm -f "${itemdir}/+INDEX.raw"
    if cinema_has_attachment "$1" "+POSTER"; then
	cinema_extract_attachment "$1" "+POSTER" "${itemdir}/+POSTER"
    fi
    rm -f  "${itemdir}/+FILENAME"
    touch "${itemdir}/+FILENAME"
    printf 'File: %s\n' "$1" >> "${itemdir}/+FILENAME"
    printf 'Item: %s\n' "${itemname}" >> "${itemdir}/+FILENAME"
}

cinema_db_maybe_import()
{
    local itemname
    local itemdir

    itemname=`basename -s .mkv "$1"`
    itemdir="${cinemadbdir}/${itemname}"

    # If the directory for itemdir exists, the file has already been
    # imported, so we do not need to do anything.

    if [ -d "${itemdir}" ]; then
	true
    else
	cinema_db_import "$1"
    fi
 
    return $?
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
    cat `cinema_db_mkindex_find "$1"` \
	| awk -v "item=$1" -v "cinemadbdir=${cinemadbdir}" -f `cinema_maketool cinema_db_mkindex_item.awk`
}


# cinema_db_build_index
#  Build the index of the cinema database

cinema_db_build_index()
{
    local file
    local item

    cinema_db_list | while read item; do
	cinema_db_mkindex_item "$item"
    done

    for file in +DB-INDEX +DB-LANG; do
	cat ${cinemadbdir}/*/${file} > ${cinemadbdir}/${file}
    done
}


#
# IMDB interface
#


# cinema_imdb_index
#  Print the index of IMDB ids

cinema_imdb_index()
{
    cinema_awk '{print($1,$5)}' < "${cinemadbdir}/+DB-INDEX" \
	| sort -u
}


# cinema_imdb_find_id ITEM
#  Lookup the IMDB id associated to ITEM

cinema_imdb_find_id()
{
    cinema_awk -v "item=$1" '$1 == item {print($5); exit}' \
	< "${cinemadbdir}/+DB-INDEX" 
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
    local item

    cinema_db_list | while read item; do
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
    sed -n -f `cinema_maketool cinema_imdb_mkindex_item_filter.sed`
}

cinema_imdb_mkindex_item_format()
{
    awk -v item="$1" -v cinemadbdir="${cinemadbdir}" \
	-f `cinema_maketool cinema_imdb_mkindex_item_format.awk`
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
# WWW
#

# cinema_www_install_poster ITEM
#  Install poster for the given ITEM

cinema_www_install_poster()
{
    local itemdir
    itemdir="${cinemadbdir}/$1"
    if [ -r "${itemdir}/+POSTER" ]; then
	install -m444 "${itemdir}/+POSTER" "${cinemawwwdir}/$1.jpeg"
    else
	false
    fi
    return $?
}

cinema_www_install_poster_all()
{
    local item

    cinema_db_list | while read item; do
	cinema_www_install_poster "${item}"
    done
}

# cinema_www_mkindex
#  Generate the index file
cinema_www_mkindex()
{
    cinema_www_mkindex_movie_card
}

cinema_www_mkindex_movie_card()
{
    join -t'|' "${cinemadbdir}/+DB-INDEX" "${cinemadbdir}/+IMDB-STORYLINE" \
	| cat
#	| awk -f "${cinematooldir}/cinema_www_mkindex_movie_card.awk"
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

    cinema_db_list | while read item; do
	cinema_db_delete_item "${item}"
    done
}

cinema_db_import_all()
{
    local file

    cinema_find | while read file; do
	cinema_db_import "$file"
    done
}

#cinema_db_delete_all
#cinema_db_import_all
cinema_db_build_index
#cinema_imdb_maybe_fetch_all
#cinema_imdb_build_index
#cinema_www_install_poster_all

cinema_www_mkindex_movie_card
