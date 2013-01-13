BEGIN {
    FS="|";
    OFS="|";
    last_seen_item=""
}

{
    if($1 == last_seen_item)
    {
	lang = lang ", " $2;
    }
    else
    {
	if(last_seen_item != "")
	{
	    print(last_seen_item, lang);
	}
	last_seen_item=$1;
	lang=$2;
    }
}

END {
    print(last_seen_item, lang);
}
