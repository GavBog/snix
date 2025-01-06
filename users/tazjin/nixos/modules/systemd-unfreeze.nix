# Workaround for disabling semi-broken systemd user slice freezing (whatever
# that is). This can cause machines to become unusable after resume.

let
  override.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
in
{
  systemd.services = {
    systemd-suspend = override;
    systemd-hibernate = override;
    systemd-hybrid-sleep = override;
    systemd-suspend-then-hibernate = override;
  };
}

