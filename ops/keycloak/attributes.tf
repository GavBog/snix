resource "keycloak_realm_user_profile" "user_profile" {
  realm_id = keycloak_realm.snix.id

  # Username attribute
  attribute {
    name         = "username"
    display_name = "$${username}"
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
    validator {
      name = "length"
      config = {
        min = "3"
        max = "255"
      }
    }
    validator {
      name = "username-prohibited-characters"
    }
    validator {
      name = "up-username-not-idn-homograph"
    }
  }

  # Email attribute
  attribute {
    name         = "email"
    display_name = "$${email}"
    required_for_roles = ["user"]
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
    validator {
      name = "email"
    }
    validator {
      name = "length"
      config = {
        max = "255"
      }
    }
  }

  # First Name attribute
  attribute {
    name         = "firstName"
    display_name = "$${firstName}"
    required_for_roles = ["user"]
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
    validator {
      name = "length"
      config = {
        max = "255"
      }
    }
    validator {
      name = "person-name-prohibited-characters"
    }
  }

  # Last Name attribute
  attribute {
    name         = "lastName"
    display_name = "$${lastName}"
    # NOTE(edef): explicitly not required, to accommodate mononymy
    # required_for_roles = ["user"]
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
    validator {
      name = "length"
      config = {
        max = "255"
      }
    }
    validator {
      name = "person-name-prohibited-characters"
    }
  }

  # User metadata group
  group {
    name                = "user-metadata"
    display_header      = "User metadata"
    display_description = "Attributes, which refer to user metadata"
  }
}
