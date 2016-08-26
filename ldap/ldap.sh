#!/usr/bin/env bash
# Utility functions for accessing AD from the shell. Requires the OpenLDAP
# command-line tools (ldapsearch, etc.)

# Get the LDAP URL from the environment, or default to known value
: "${AD_LDAP_URL:=ldap://ldap.turner.com}"

# Demonstration code
main() {
  local samaccountname dn tel
  read -p 'Enter username to find: ' samaccountname
  IFS=$'\n' read -d '' dn tel <<<"$(ad_ldap search -b cn=users,dc=turner,dc=com \
                   "samaccountname=$samaccountname" telephoneNumber |
                   sed -n 's/^\(dn\|telephoneNumber\): //p')"
  printf "DN: %s\nPhone: %s\n" "$dn" "$tel"
}

ad_ldap () {
  # generic front-end function; first argument is the name of the command to run,
  # minus the 'ldap' part. Requires credentials to be set in environment variables.
  local cmd=ldap$1
  shift

  type -P "$cmd" >/dev/null || {
    printf >&2 "%s: %s: command not found" "$0" "$cmd"
    return 1
  }

  # make sure credentials are set
  ad_check_credentials || return 1

  # this allows OpenLDAP-based commands to use SSL or TLS for encryption
  # without requiring that they be able to validate the server certificate
  export LDAPTLS_REQCERT=never

  "$cmd" -H "$AD_LDAP_URL" -ZZ \
     -x -D "$AD_LDAP_BIND_DN" -w "$AD_LDAP_BIND_PASSWORD" "$@"
}

# Make sure credentials are set
ad_check_credentials()
{
  [[ -n $AD_LDAP_BIND_DN && -n $AD_LDAP_BIND_PASSWORD ]] && return 0

  # not set.  If we're not being run interactively, fail
  if [[ ! -t 0 ]]; then
    printf >&2 "%s: no credentials supplied" "$0"
    return 1
  fi

  # Otherwise, prompt
  ad_get_credentials
}

# Get credentials for bind
ad_get_credentials() {
  local bind_user old_stty
  read -p 'Enter LDAP Username: ' bind_user >/dev/tty
  if [[ $bind_user =~ ^[^\\,]*$ ]]; then # simple username
    AD_LDAP_BIND_DN=Turner\\$bind_user
  else
    AD_LDAP_BIND_DN=$bind_user
  fi

  # turn off echo to read password
  old_stty="$(stty -f /dev/tty -a | grep -ow -e '-\?echo')"
  stty -f /dev/tty -echo
  read -p 'Enter LDAP Password: ' AD_LDAP_BIND_PASSWORD >/dev/tty
  stty -f /dev/tty "$old_stty"
  printf $'\n' >/dev/tty
}

main "$@"
