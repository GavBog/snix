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
    rev = "2f3a2ccc0a823d660d2366de2dbe65515e099c95";
    hash = "sha256-VIpGEln34uTdWozmzRN7mq+aYf294IHjtm7lfypHKj0=";
  };

  vendorHash = "sha256-m8YS9qoIxMHejgjSKglnIr1uln1LEaHh1b/WBlege8A=";
})
