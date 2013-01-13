BEGIN {
    FS="|";
    OFS="|";
    last_seen_item=""
}

function starsreset()
{
    delete stars;
    stars_n = 0;
}

function starspush(name)
{
    stars[stars_n] = name;
    ++stars_n;
}

function starsconcat()
{
    answer = "";
    if(stars_n == 0)
    {
	answer = "";
    }
    else if(stars_n == 1)
    {
	answer = stars[0];
    }
    else
    {
	answer = stars[0];
	for(i = 1; i < stars_n - 1; ++i)
	{
	    answer = answer ", " stars[i];
	}
	answer = answer " and " stars[stars_n - 1];
    }
    return answer;
}

{
    if($1 == last_seen_item)
    {
	starspush($2);
    }
    else
    {
	if(last_seen_item != "")
	{
	    print(last_seen_item, starsconcat());
	}
	last_seen_item=$1;
	starsreset();
	starspush($2);
    }
}

END {
    print(last_seen_item, starsconcat());
}
