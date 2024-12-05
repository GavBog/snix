{ depot, lib, ... }:

let
  # TODO(sterni): find a better place for this: is dot time //fun?

  # get the email address of a depot user from //ops/users
  findEmail = user:
    let
      res = builtins.filter ({ username, ... }: username == user) depot.ops.users;
      len = builtins.length res;
    in
    if len == 1
    then (builtins.head res).email
    else builtins.throw "findEmail: got ${toString len} results instead of 1";

  # dot-time(7) man page, ported from dotti.me
  dot-time = rec {
    name = "dot-time";
    section = 7;
    content = ''
      .Dd $Mdocdate$
      .Dt ${lib.toUpper name} ${toString section}
      .Os
      .Sh NAME
      .Nm ${name}
      .Nd a universal convention for conveying time
      .Sh DESCRIPTION
      For those of us who travel often or coordinate across many timezones,
      working with local time is frequently impractical.
      ISO8601, in all its wisdom, allows for time zone designators,
      but still represents the hours and minutes as local time,
      thus making it inconvenient for quickly comparing timestamps from
      different locations.
      .Pp
      Dot time instead uses UTC for all date, hour, and minute indications,
      and while it allows for time zone designators, they are optional
      information that can be dropped without changing the indicated time.
      It uses an alternate hour separator to make it easy to distinguish from
      regular ISO8601.
      When a time zone designator is provided, one can easily obtain
      the matching local time by adding the UTC offset to the UTC time.
      .Sh EXAMPLES
      These timestamps all represent the same point in time.
      .TS
      allbox tab(|);
      lb | lb | lb
      l  | l  | l.
      dot time|ISO8601|RFC3339
      2019-06-19T22·13-04|2019-06-19T18:13-04|2019-06-19T18:13:00-04:00
      2019-06-19T22·13+00|2019-06-19T22:13+00|2019-06-19T22:13:00Z
      2019-06-19T22·13+02|2019-06-20T00:13+02|2019-06-20T00:13:00+02:00
      .TE
      .Sh SEE ALSO
      .Lk https://dotti.me dotti.me
      .Sh AUTHORS
      .An -nosplit
      .Sy dot time
      has been proposed and documented by
      .An edef Aq Mt ${findEmail "edef"}
      and ported to
      .Xr mdoc 7
      by
      .An sterni Aq Mt ${findEmail "sterni"} .
    '';
  };

in
depot.users.sterni.nix.build.manPages "dot-time" { } [
  dot-time
]
