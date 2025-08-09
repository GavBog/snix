{ depot, lib, ... }:

let
  /*
    Get the basename of a store path without
    the leading hash.

    Type: (path | drv | string) -> string

    Example:
      storePathName ./foo.c
      => "foo.c"

      storePathName (writeText "foo.c" "int main() { return 0; }")
      => "foo.c"

      storePathName "${hello}/bin/hello"
      => "hello"
  */
  storePathName =
    p:
    if lib.isDerivation p then
      p.name
    else if builtins.isPath p then
      builtins.baseNameOf p
    else if builtins.isString p || (builtins.isAttrs p && (p ? outPath || p ? __toString)) then
      let
        strPath = toString p;
        # strip leading storeDir and trailing slashes
        noStoreDir = lib.removeSuffix "/" (lib.removePrefix "${builtins.storeDir}/" strPath);
        # a basename of a child of a store path isn't really
        # referring to a store path, so removing the string
        # context is safe (e. g. "hello" for "${hello}/bin/hello").
        basename = builtins.unsafeDiscardStringContext (builtins.baseNameOf strPath);
      in
      # If p is a direct child of storeDir, we need to remove
      # the leading hash as well to make sure that:
      # `storePathName drv == storePathName (toString drv)`.
      if noStoreDir == basename then builtins.substring 33 (-1) basename else basename
    else
      builtins.throw "Don't know how to get (base)name of " + lib.generators.toPretty { } p;

  /*
    Query the type of a path exposing the same information as would be by
    `builtins.readDir`, but for a single, specific target path.

    The information is returned as a tagged value, i. e. an attribute set with
    exactly one attribute where the type of the path is encoded in the name
    of the single attribute. The allowed tags and values are as follows:

    * `regular`: is a regular file, always `true` if returned
    * `directory`: is a directory, always `true` if returned
    * `missing`: path does not exist, always `true` if returned
    * `symlink`: path is a symlink, always `true` if returned

    Type: path(-like) -> tag

    `tag` refers to the attribute set format of `//nix/tag`.

    Example:
      pathType ./foo.c
      => { regular = true; }

      pathType /home/lukas
      => { directory = true; }

      pathType ./result
      => { symlink = true; }

      pathType ./link-to-file
      => { symlink = true; }

      pathType /does/not/exist
      => { missing = true; }

      # Check if a path exists
      !(pathType /file ? missing)

      # Check if a path is a directory or a symlink to a directory
      # A handy shorthand for this is provided as `realPathIsDirectory`.
      pathType /path ? directory || (pathType /path).symlink or null == "directory"

      # Match on the result using //nix/tag
      nix.tag.match (nix.utils.pathType ./result) {
        symlink = _: "symlink";
        directory  = _: "directory";
        regular = _: "regular";
        missing = _: "path does not exist";
      }
      => "symlink"

      # Query path type
      nix.tag.tagName (pathType /path)
  */
  pathType =
    path:
    let
      # baseNameOf is very annoyed if we proceed with string context.
      # We need to call toString to prevent unsafeDiscardStringContext
      # from importing a path into store which messes with base- and
      # dirname of course.
      path' = builtins.unsafeDiscardStringContext (toString path);
      # To read the containing directory we absolutely need
      # to keep the string context, otherwise a derivation
      # would not be realized before our check (at eval time)
      containingDir = builtins.readDir (builtins.dirOf path);
      # Construct tag to use for the value
      thisPathType = containingDir.${builtins.baseNameOf path'} or "missing";
      # Trick to check if the symlink target exists and is a directory:
      # if we append a "/." to the string version of the path, Nix won't
      # canocalize it (which would strip any "/." in the path), so if
      # path' + "/." exists, we know that the symlink points to an existing
      # directory. If not, either the target doesn't exist or is a regular file.
      # TODO(sterni): is there a way to check reliably if the symlink target exists?
      isSymlinkDir = builtins.pathExists (path' + "/.");
    in
    {
      ${thisPathType} = true;
    };

  pathType' =
    path:
    let
      p = pathType path;
    in
    if p ? missing then builtins.throw "${lib.generators.toPretty { } path} does not exist" else p;

  /*
    Check whether the given path is a directory.
    Throws if the path in question doesn't exist.

    Type: path(-like) -> bool
  */
  isDirectory = path: pathType' path ? directory;

  /*
    Check whether the given path is a regular file.
    Throws if the path in question doesn't exist.

    Type: path(-like) -> bool
  */
  isRegularFile = path: pathType' path ? regular;

  /*
    Check whether the given path is a symbolic link.
    Throws if the path in question doesn't exist.

    Type: path(-like) -> bool
  */
  isSymlink = path: pathType' path ? symlink;

  /*
    Checks whether the given value is (or contains) a reference to a
    path that will be retained in the store path resulting from a derivation.
    So if isReferencablePath returns true, the given value may be used in a
    way that allows accessing it at runtime of any Nix built program.

    Returns true for:

    - Strings with context (if the string is/contains a single path is not verified!)
    - Path values
    - Derivations

    Note that the value still needs to used in a way that forces string context
    (and thus reference tracking) to be created, e.g. in string interpolation.

    Type: any -> bool
  */
  isReferencablePath =
    value:
    builtins.isPath value
    || lib.isDerivation value
    || (builtins.isString value && builtins.hasContext value);

in
{
  inherit
    storePathName
    pathType
    isDirectory
    isRegularFile
    isSymlink
    isReferencablePath
    ;
}
