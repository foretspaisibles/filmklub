# cinema_www_mkindex_movie_card

# Because of the huge amount of parameters, we use the global array
# movie_data to convey information from the main loop to the
# procedures.

BEGIN {
    FS="|";
}

function print_movie_poster()
{
    printf("<img class=\"movie_poster\" src=\"%s.jpeg\" />\n", movie_data["item"]);
}

function print_movie_div(class, content)
{
    printf("<div class=\"%s\">%s</div>\n", class, content);
}

function print_movie_title()
{
    print_movie_div("movie_title", movie_data["title"]);
}

function print_movie_storyline()
{
    print_movie_div("movie_storyline", movie_data["storyline"]);
}


function print_card()
{
    print
      <div class="movie_card">
      <div class="movie_record">
      <div class="movie_title">Du rififi chez les hommes</div>
      <div class="movie_basics">
        <span class="movie_director">Jules Dassin</span>,
        <span class="movie_year">1955</span>
      </div>
      <div class="movie_stars">
      starring
      Carl Möhner,
      Robert Manuel and
      Jean Servais
      </div>
      <div class="movie_extras">
      FR — DRAMA, THRILLER, CRIME
      </div>
      <div class="movie_storyline"><p>After five years in prison, Tony le St&#xE9;phanois meets his dearest
friends Jo and the Italian Mario Ferrati and they invite Tony to steal
a couple of jewels from the show-window of the famous jewelry Mappin
&#x26; Webb Ltd, but he declines. Tony finds his former girlfriend
Mado, who became the lover of the gangster owner of the night-club
L&#x27; &#xC2;ge d&#x27; Or Louis Grutter, and he humiliates her,
beating on her back and taking her jewels. Then he calls Jo and Mario
and proposes a burglary of the safe of the jewelry. They invite the
Italian specialist in safes and elegant wolf Cesar to join their team
and they plot a perfect heist. They are successful in their plan, but
the D. Juan Cesar makes things go wrong when he gives a valuable ring
to his mistress.</p></div>
    </div>

    
}
