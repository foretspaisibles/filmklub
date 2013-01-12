BEGIN {
    FS=": ";
    OFS="|";
    if(cinemadbdir == "" || item == "")
	exit 64;
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
    print(					\
	data["Item"],				\
	data["File"],				\
	data["Title"],				\
	data["IMDB"],				\
	wikipedia[1],				\
	wikipedia[2],				\
	data["Source"]				\
	) > (resource("+DB-INDEX"));
    printarray(language, "+DB-LANG");
}
