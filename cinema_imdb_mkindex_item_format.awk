BEGIN {
    FS=": ";
    OFS="|";
}

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

{
    data[$1] = $2;
}

END {
    print(					\
	item,					\
	data["Title"],				\
	data["Year"],				\
	data["Director"],			\
	data["Writer"],				\
	data["Language"],			\
	data["Runtime"],			\
	data["Country"],			\
	data["Aspect Ratio"]			\
	) > (resource("+IMDB-INDEX"));
    if(data["Storyline"] != "")
    {
	print(item, data["Storyline"]) > (resource("+IMDB-STORYLINE"));
    }
    printarray(plot_keywords, "+IMDB-PLOT");
    printarray(genres, "+IMDB-GENRE");
    printarray(stars, "+IMDB-STARS");
    printarray(filming_locations, "+IMDB-LOCATION");
}
