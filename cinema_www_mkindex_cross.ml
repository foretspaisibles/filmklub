open Printf

module Dictionary =
  Map.Make(String)

module Pool =
  Set.Make(String)

module Path =
struct
  let cinemadbdir =
    Sys.argv.(1)

  let cinemawwwdir =
    Sys.argv.(2)

  let cinemadb s =
    Filename.concat cinemadbdir s

  let cinemawww s =
    Filename.concat cinemawwwdir s

end

module Record =
struct
  let ifs = Str.regexp "|"

  let split s =
    Array.of_list(Str.split_delim ifs s)

end


module type DATABASE_RECORD =
sig
  val filename : string
  type t
  val split : string -> t
  val key : t -> string
end


module Database(R:DATABASE_RECORD) =
struct
  type record = R.t
  type t = record Dictionary.t

  let input_record_option c =
    let s = input_line c in
    try
      Some(R.split s)
    with
    | _ -> None

  let rec record_stream_f c n =
    try (
      match input_record_option c with
      | Some r -> Some r
      | None -> record_stream_f c n
    ) with End_of_file -> None

  let record_stream c =
    Stream.from (record_stream_f c)

  let iter f c =
    Stream.iter f (record_stream c)

  let iterfile f filename =
    let c = open_in filename in
    begin
      Stream.iter f (record_stream c);
      close_in c;
    end


  let read filename =
    let c = open_in filename in
    let d = ref Dictionary.empty in
    let rec loop a r =
      a := Dictionary.add (R.key r) r !a
    in
    begin
      iter (loop d) c;
      close_in c;
      !d
    end

  let slurp () =
    read R.filename

end


module DBIndex =
struct
  let filename = 
    Path.cinemadb "+DB-INDEX"

  type t = {
    item: string;
    path: string;
    title: string;
    imdb: string;
    wikipedia_lang: string;
    wikipedia_key: string;
    source: string;
  }

  let key x =
    x.item

  let split s =
    let a = Record.split s in
    {
      item = a.(0);
      path = a.(1);
      title = a.(2);
      imdb = a.(3);
      wikipedia_lang = a.(4);
      wikipedia_key = a.(5);
      source = a.(6);
    }

end

module IMDBIndex =
struct
  let filename = 
    Path.cinemadb "+IMDB-INDEX"

  type t = {
    item: string;
    title: string;
    year: string;
    director: string;
    writer: string;
    runtime: string;
    aspect: string;
  }

  let split s =
    let a = Record.split s in
    {
      item = a.(0);
      title = a.(1);
      year = a.(2);
      director = a.(3);
      writer = a.(4);
      runtime = a.(5);
      aspect = a.(6);
    }

  let key x =
    x.item

end


module IMDBGenre =
struct
  let filename = 
    Path.cinemadb "+IMDB-GENRE"

  type t = {
    item: string;
    genre: string;
  }

  let split s =
    let a = Record.split s in
    {
      item = a.(0);
      genre = a.(1);
    }

  let key x =
    x.item

end

module IMDBStars =
struct
  let filename = 
    Path.cinemadb "+IMDB-STARS"

  type t = {
    item: string;
    star: string;
  }

  let split s =
    let a = Record.split s in
    {
      item = a.(0);
      star = a.(1);
    }

  let key x =
    x.item

end


module Movie =
struct

  type t = {
    id: string;
    title: string;
  }

  let canonise_title x =
    if x.title = "" then
      sprintf "%s (title not defined)" x.id
    else
      x.title

  let canonise_id_replace =
    let re = Str.regexp "_" in
    function s -> Str.global_replace re "-" s

  let canonise_id x =
    canonise_id_replace (String.uppercase x.id)
    

  let compare x y =
    String.compare x.title y.title

  let print_endline x =
    printf "{ id = %S; title = %S; }\n%!" x.id x.title

  let output_anchor c x =
    fprintf c "<a href=\"#%s\">%s</a>\n" (canonise_id x) (canonise_title x)

  let print_anchor x =
    output_anchor stdout x

end


module HashedString =
struct
  type t = string
  let equal = (=)
  let hash = Hashtbl.hash
end

module Index =
  Hashtbl.Make(HashedString)


module Cross =
struct

  type t = {
    db_index: DBIndex.t Dictionary.t;
    imdb_index: IMDBIndex.t Dictionary.t;

    director: Movie.t Index.t;
    year: Movie.t Index.t;
    genre: Movie.t Index.t;
    stars: Movie.t Index.t;
  }

  let make () =
    let index_sz = 64 in
    let module DatabaseDBIndex = Database(DBIndex) in
    let module DatabaseIMDBIndex = Database(IMDBIndex) in
    let module DatabaseIMDBGenre = Database(IMDBGenre) in
    let module DatabaseIMDBStars = Database(IMDBStars) in

    {
      db_index = DatabaseDBIndex.slurp();
      imdb_index = DatabaseIMDBIndex.slurp();

      director = Index.create index_sz;
      year =  Index.create index_sz;
      genre = Index.create (8 * index_sz);
      stars = Index.create (4 * index_sz);
    }

  let movie c k = {
    Movie.id = k;
    Movie.title =
      try (Dictionary.find k c.db_index).DBIndex.title
      with Not_found -> k;
  }

  let populate_table f x index table =
    let loop k r a =
      Index.add a (f r) (movie x k); a
    in
    ignore(Dictionary.fold loop index table)

  let populate_director x =
    let get_director r =
      r.IMDBIndex.director
    in
    populate_table get_director x x.imdb_index x.director

  let populate_year x =
    let get_year r =
      r.IMDBIndex.year
    in
    populate_table get_year x x.imdb_index x.year

  let populate_attribute iterfile file key attribute x index =
    let loop r =
      Index.add index (attribute r) (movie x (key r))
    in
    iterfile loop file

  let populate_genre x =
    let module DatabaseIMDBGenre = Database(IMDBGenre) in
    let key r =
      r.IMDBGenre.item
    in
    let attribute r =
      r.IMDBGenre.genre
    in
    populate_attribute DatabaseIMDBGenre.iterfile (Path.cinemadb "+IMDB-GENRE") key attribute x x.genre

  let populate_stars x =
    let module DatabaseIMDBStars = Database(IMDBStars) in
    let key r =
      r.IMDBStars.item
    in
    let attribute r =
      r.IMDBStars.star
    in
    populate_attribute DatabaseIMDBStars.iterfile (Path.cinemadb "+IMDB-STARS") key attribute x x.stars


  let populate_all x =
    begin
      populate_director x;
      populate_year x;
      populate_genre x;
      populate_stars x;
    end

  let keys table =
    let loop k _ p =
      Pool.add k p
    in
    let pool =
      Index.fold loop table Pool.empty
    in
    Pool.elements pool

  let output_table c cls table =
    let loop k =
      let a = List.sort Movie.compare (Index.find_all table k) in
      let b = ref false in
      let output_anchor c m =
	begin
	  if !b then output_string c " ❖ ";
	  b := true;
	  Movie.output_anchor c m;
	end
      in
      begin
	fprintf c "<h2 class=\"%s\">%s</h2>\n" cls k;
	List.iter (output_anchor c) a;
      end
    in List.iter loop (keys table)

  let write_table file cls table =
    let c = open_out (Path.cinemawww file) in
    begin
      output_table c cls table;
      close_out c;
    end

  let write_all x =
    begin
      write_table "moviedirector.sgml" "movie_index_director" x.director;
      write_table "movieyear.sgml" "movie_index_year" x.year;
      write_table "moviegenre.sgml" "movie_index_genre" x.genre;
      write_table "moviestars.sgml" "movie_index_stars" x.stars;
    end

end

let main () =
  let c = Cross.make() in
  begin
    Cross.populate_all c;
    Cross.write_all c;
  end

let _ =
  main ()
