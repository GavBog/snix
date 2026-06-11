{
  buildGoModule,
  fetchFromCodeberg,
}:

buildGoModule (finalAttrs: {
  pname = "watch-store";
  version = "0.0.0";

  src = fetchFromCodeberg {
    owner = "flokli";
    repo = "watch-store-go";
    rev = "c586348b519e6c3b6f02b2ac63ba2279d81d4041";
    hash = "sha256-bJgcKLaa41FAqi9M+IN8zKuDIs48hePbVXyYQrZskQI=";
  };

  vendorHash = "sha256-m8YS9qoIxMHejgjSKglnIr1uln1LEaHh1b/WBlege8A=";
})
