# A simple SMTP relay without the kitchen sink.
{ pkgs, lib, ... }:

pkgs.buildGoModule rec {
  pname = "smtprelay";
  version = "1.7.0";
  vendorHash = "sha256:00nb81hdg5pv5l0q7w5lv08dv4v72vml7jha351frani0gpg27pn";

  src = pkgs.fetchFromGitHub {
    owner = "decke";
    repo = "smtprelay";
    rev = "v${version}";
    sha256 = "0js18xhk64g0g82dx8ii8vhbbssj3pxf1hqv1zadnckdgwfwlj2r";
  };

  meta = with lib; {
    description = "Simple Golang SMTP relay/proxy server";
    homepage = "https://github.com/decke/smtprelay";
    license = licenses.mit;
  };
}
