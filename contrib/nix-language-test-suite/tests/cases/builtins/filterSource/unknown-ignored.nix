# filter all unknown types, so ingestion should succeed
builtins.filterSource (p: t: t != "unknown") ./import_fixtures
