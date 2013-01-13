# cinema_www_mkindex_movie_card

# Because of the huge amount of parameters, we use the global array
# movie_data to convey information from the main loop to the
# procedures.
#
# STRUCTURE OF INPUT RECORDS
#
# item|file|title|imdb|wikipedia1|wikipedia2|source|imdbtitle|year|director|writer|runtime|aspect|languages|stars|genre|storyline


BEGIN {
    FS="|";
}

function mkimdblink()
{
    answer = sprintf(						\
	"<a href=\"http://www.imdb.com/title/tt%s/\">IMDB</a>", \
	movie_data["imdb"]					\
	);
    return answer;
}

function mkwikipedialink()
{
    answer = sprintf(						\
	"<a href=\"http://%s.wikipedia.org/wiki/%s\">WIKI</a>", \
	movie_data["wikipedia1"],					\
	movie_data["wikipedia2"]					\
	);
    return answer;
}

function print_movie_poster()
{
    printf("<img alt=\"Movie poster for %s\" class=\"movie_poster\" src=\"%s.jpeg\">\n", movie_data["title"], movie_data["item"]);
}

function print_movie_span(class, content)
{
    printf("<span class=\"%s\">%s</span>\n", class, content);
}

function print_movie_div(class, content)
{
    printf("<div class=\"%s\">%s</div>\n", class, content);
}

function open_movie_div(class)
{
    printf("<div class=\"%s\">\n", class);
}

function open_movie_divid(class, id)
{
    printf("<div class=\"%s\" id=\"%s\">\n", class, id);
}

function close_movie_div()
{
    printf("</div>\n");
}

function print_movie_card()
{
    movie_card_id=movie_data["item"];
    gsub("_", "-", movie_card_id);
    open_movie_divid("movie_card_container", movie_card_id);

    open_movie_div("movie_card_poster");
    print_movie_poster();
    close_movie_div();

    open_movie_div("movie_card");
    print_movie_div("movie_title", movie_data["title"]);

    open_movie_div("movie_basics");
    print_movie_span("movie_director", movie_data["director"]);
    print_movie_span("movie_year", movie_data["year"]);    
    close_movie_div();

    print_movie_div("movie_stars", "starring " movie_data["stars"]);

    open_movie_div("movie_hints");
    print_movie_span("movie_languages", movie_data["languages"]);
    printf(" ✿ ");
    print_movie_span("movie_languages", movie_data["genre"]);
    printf(" ❀ ");
    print_movie_span("movie_imdb", mkimdblink());
    printf(" ❁ ");
    print_movie_span("movie_wikipedia", mkwikipedialink());
    close_movie_div();

    print_movie_div("movie_storyline", movie_data["storyline"]);
    close_movie_div();

    close_movie_div();
}
    

{
    movie_data["item"] = $1;
    movie_data["file"] = $2;
    movie_data["title"] = $3;
    movie_data["imdb"] = $4;
    movie_data["wikipedia1"] = $5;
    movie_data["wikipedia2"] = $6;
    movie_data["source"] = $7;
    movie_data["imdbtitle"] = $8;
    movie_data["year"] = $9;
    movie_data["director"] = $10;
    movie_data["writer"] = $11;
    movie_data["runtime"] = $12;
    movie_data["aspect"] = $13;
    movie_data["languages"] = $14;
    movie_data["stars"] = $15;
    movie_data["genre"] = $16;
    movie_data["storyline"] = $17;
    print_movie_card();
}


#       <div class="movie_card">
#       <div class="movie_record">
#       <div class="movie_title">Du rififi chez les hommes</div>
#       <div class="movie_basics">
#         <span class="movie_director">Jules Dassin</span>,
#         <span class="movie_year">1955</span>
#       </div>
#       <div class="movie_stars">
#       starring
#       Carl Möhner,
#       Robert Manuel and
#       Jean Servais
#       </div>
#       <div class="movie_extras">
#       FR — DRAMA, THRILLER, CRIME
#       </div>
#       <div class="movie_storyline"><p>After five years in prison, Tony le St&#xE9;phanois meets his dearest
# friends Jo and the Italian Mario Ferrati and they invite Tony to steal
# a couple of jewels from the show-window of the famous jewelry Mappin
# &#x26; Webb Ltd, but he declines. Tony finds his former girlfriend
# Mado, who became the lover of the gangster owner of the night-club
# L&#x27; &#xC2;ge d&#x27; Or Louis Grutter, and he humiliates her,
# beating on her back and taking her jewels. Then he calls Jo and Mario
# and proposes a burglary of the safe of the jewelry. They invite the
# Italian specialist in safes and elegant wolf Cesar to join their team
# and they plot a perfect heist. They are successful in their plan, but
# the D. Juan Cesar makes things go wrong when he gives a valuable ring
# to his mistress.</p></div>
#     </div>
