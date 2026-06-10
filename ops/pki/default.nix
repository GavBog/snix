{ lib, ... }:

{
  ca_certificate = ./minica.pem;
  host_certificates =
    let
      dir = ./.;
    in
    lib.mapAttrs' (name: _: lib.nameValuePair name (dir + "/${name}/cert.pem")) (
      lib.filterAttrs (
        name: kind: kind == "directory" && builtins.pathExists (dir + "/${name}/cert.pem")
      ) (builtins.readDir dir)
    );
}
