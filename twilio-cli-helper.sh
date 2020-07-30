#!/bin/bash

_twilio_cli_helper_this_file="${BASH_SOURCE[0]}"
_twilio_cli_helper_dir=$(dirname "$_twilio_cli_helper_this_file")
_twilio_cli_helper_dir_creds="$_twilio_cli_helper_dir/creds"

echo "$_twilio_cli_helper_dir_creds"

_twilio_cli_helper_api="https://api.twilio.com/2010-04-01"

if ! command -v jq &>/dev/null; then
  echo "twilio_cli_helper: please install jq, e.g. 'brew install jq'. Expect errors otherwise."
  if ! command -v brew &>/dev/null; then
    echo "Homebrew is also not installed. Wow!"
  fi
fi

_twilio_cli_helper_out() {
  _twilio_cli_helper_output="$1"
  shift
  if command -v jq &>/dev/null; then
    echo "$_twilio_cli_helper_output" | jq "$@"
  else
    echo "$_twilio_cli_helper_output"
  fi

  unset _twilio_cli_helper_output
}

_twilio_cli_helper_api_get() {
  _twilio_cli_helper_accountSid="$1"
  _twilio_cli_helper_authToken="$2"

  curl -s -G "$_twilio_cli_helper_api/$3" \
    -u "$_twilio_cli_helper_accountSid:$_twilio_cli_helper_authToken"
}

_twilio_cli_helper_subaccounts_list() {
  _twilio_cli_helper_api_get "$@" "Accounts.json?PageSize=1000" |
    jq -c '.accounts | map(select(.sid != "'"$1"'")) | map(.friendly_name) | .[]'

}

_twilio_cli_helper_balance() {
  _twilio_cli_helper_out "$(_twilio_cli_helper_api_get "$@" "Accounts/$1/Balance.json")"
}

_twilio_cli_helper_usage() {
  _twilio_cli_helper_usage_period="$3"

  if [ -z "$_twilio_cli_helper_usage_period" ]; then
    _twilio_cli_helper_usage_period="AllTime"
  fi

  # All usage categories: https://www.twilio.com/docs/usage/api/usage-record#usage-all-categories
  _twilio_cli_helper_usage_sms_outbound="$(_twilio_cli_helper_api_get "$1" "$2" "Accounts/$1/Usage/Records/$_twilio_cli_helper_usage_period.json?Category=sms-outbound-longcode")"
  _twilio_cli_helper_usage_sms_inbound="$(_twilio_cli_helper_api_get "$1" "$2" "Accounts/$1/Usage/Records/$_twilio_cli_helper_usage_period.json?Category=sms-inbound-longcode")"
  _twilio_cli_helper_usage_phonenumbers="$(_twilio_cli_helper_api_get "$1" "$2" "Accounts/$1/Usage/Records/$_twilio_cli_helper_usage_period.json?Category=phonenumbers")"

  _twilio_cli_helper_out "[$_twilio_cli_helper_usage_sms_outbound,$_twilio_cli_helper_usage_sms_inbound,$_twilio_cli_helper_usage_phonenumbers]"
}

_twilio_cli_helper_creds_list() {
  for _twilio_cli_helper_file in "$_twilio_cli_helper_dir_creds"/*; do
    _twilio_cli_helper_filename=$(basename "$_twilio_cli_helper_file")

    _twilio_cli_helper_accName="${_twilio_cli_helper_filename%.sh}"
    echo "$_twilio_cli_helper_accName"
  done
}

_twilio_cli_helper_creds_use() {
  source "$_twilio_cli_helper_dir_creds/$1.sh"
}

_twilio_cli_helper_subaccount_use() {
  _twilio_cli_helper_res=$(_twilio_cli_helper_api_get "$1" "$2" "Accounts.json?PageSize=1&FriendlyName=$3")
  _twilio_cli_helper_accountSid=$(echo "$_twilio_cli_helper_res" | jq -r '.accounts[0].sid')
  _twilio_cli_helper_authToken=$(echo "$_twilio_cli_helper_res" | jq -r '.accounts[0].auth_token')

  export TWILIO_ACCOUNT_SID="$_twilio_cli_helper_accountSid"
  export TWILIO_AUTH_TOKEN="$_twilio_cli_helper_authToken"

  unset _twilio_cli_helper_res
  unset _twilio_cli_helper_accountSid
  unset _twilio_cli_helper_authToken
}

_twilio_cli_helper_help() {
  cat <<EOF
------------------------------

Notes
- This tool relies heavily on the program 'jq' for parsing and formatting.
  It can be installed with Homebrew, e.g. 'brew install jq'
- Highly recommended: make these functions always available.
  E.g. add the following to ~/.bash_profile, ~/.bashrc, etc.:
    source "$_twilio_cli_helper_this_file"

------------------------------

Usage: twilio_cli_helper <project_name> <command>
  - Project names are auto-completed from .sh files in "$_twilio_cli_helper_dir"

------------------------------

Commands:

balance: twilio_cli_helper micro-int balance
  - Displays the current balance for the provided project
  - Cannot be used for subaccounts (see "usage" instead)

subaccounts: twilio_cli_helper micro-int subaccounts
  - Lists the friendly names of subaccounts under the provided project
  - See below for sub-commands

usage: twilio_cli_helper micro-int usage <usage_period>
  - Fetches usage in these categories:
    - sms-outbound-longcode
    - sms-inbound-longcode
    - phonenumbers
  - Twilio provides many more categories:
      https://www.twilio.com/docs/usage/api/usage-record#usage-all-categories
    They can be added to this script (see _twilio_cli_helper_usage)
  - Usage periods and descriptions:
      https://www.twilio.com/docs/usage/api/usage-record#list-subresources
  - Usage periods are auto-completed
  - If none is provided, AllTime is used by default

help: twilio_cli_helper help
  - Displays this help text

------------------------------

Subaccount sub-commands:

  twilio_cli_helper <project_name> subaccounts <subaccount_name> <sub-command>

The only supported sub-command is "usage" because
  - Subaccounts do not have a "balance" endpoint in Twilio
  - Multi-level nested subaccounts not yet supported

usage: twilio_cli_helper micro-int subaccounts bagdttoeuktajtm usage <usage_period>
  - Usage periods and descriptions:
      https://www.twilio.com/docs/usage/api/usage-record#list-subresources
  - Usage periods are auto-completed
  - If none is provided, AllTime is used by default

  Example: twilio_cli_helper micro-int subaccounts bagdttoeuktajtm usage Monthly

------------------------------
EOF
}

twilio_cli_helper() {
  if [ "$1" == "help" ]; then
    _twilio_cli_helper_help
    return
  fi

  _twilio_cli_helper_accountName="$1"
  _twilio_cli_helper_cmd="$2"

  if [ ! -f "$_twilio_cli_helper_dir_creds/$_twilio_cli_helper_accountName.sh" ]; then
    echo "No credentials for '$_twilio_cli_helper_accountName'. Exiting"
    return
  fi

  if [ -z "$_twilio_cli_helper_cmd" ]; then
    echo "No command. Exiting"
    return
  fi

  _twilio_cli_helper_prevAccountSid="$TWILIO_ACCOUNT_SID"
  _twilio_cli_helper_prevAuthToken="$TWILIO_AUTH_TOKEN"

  _twilio_cli_helper_creds_use "$_twilio_cli_helper_accountName"

  if [ "$#" -ge 4 ]; then
    _twilio_cli_helper_subaccount_use "$TWILIO_ACCOUNT_SID" "$TWILIO_AUTH_TOKEN" "$3"
    shift
    shift
  fi

  _twilio_cli_helper_accountName="$1"
  _twilio_cli_helper_cmd="$2"

  case $_twilio_cli_helper_cmd in
  balance)
    _twilio_cli_helper_balance "$TWILIO_ACCOUNT_SID" "$TWILIO_AUTH_TOKEN"
    ;;
  subaccounts)
    _twilio_cli_helper_subaccounts_list "$TWILIO_ACCOUNT_SID" "$TWILIO_AUTH_TOKEN"
    ;;
  usage)
    _twilio_cli_helper_usage "$TWILIO_ACCOUNT_SID" "$TWILIO_AUTH_TOKEN" "$3"
    ;;
  *)
    echo "Unknown command '$2'"
    return 1
    ;;
  esac

  TWILIO_ACCOUNT_SID="$_twilio_cli_helper_prevAccountSid"
  TWILIO_AUTH_TOKEN="$_twilio_cli_helper_prevAuthToken"

  unset _twilio_cli_helper_prevAccountSid
  unset _twilio_cli_helper_prevAuthToken
  unset _twilio_cli_helper_accountSid
  unset _twilio_cli_helper_authToken
}

function _twilio_cli_helper_list() {
  local _twilio_cli_helper_cur=${COMP_WORDS[COMP_CWORD]}
  local _twilio_cli_helper_prev=${COMP_WORDS[COMP_CWORD - 1]}
  local _twilio_cli_helper_prev_2=${COMP_WORDS[COMP_CWORD - 2]}

  if [ "$_twilio_cli_helper_prev" == "usage" ]; then
    COMPREPLY=($(compgen -W "Daily Monthly Yearly AllTime Today Yesterday ThisMonth LastMonth" -- "$_twilio_cli_helper_cur"))
  elif [ "$COMP_CWORD" -eq 1 ]; then
    local IFS=$'\n'

    COMPREPLY=($(compgen -W "$(_twilio_cli_helper_creds_list)" -- "$_twilio_cli_helper_cur"))
  elif [ "$COMP_CWORD" -eq 2 ]; then
    COMPREPLY=($(compgen -W "balance subaccounts usage" -- "$_twilio_cli_helper_cur"))
  elif [ "$COMP_CWORD" -eq 3 ]; then
    if [ "$_twilio_cli_helper_prev" == "subaccounts" ]; then
      COMPREPLY=($(compgen -W "$(twilio_cli_helper "$_twilio_cli_helper_prev_2" "$_twilio_cli_helper_prev")" -- "$_twilio_cli_helper_cur"))
    fi
  elif [ "$COMP_CWORD" -eq 4 ]; then
    # Subaccounts don't have a Balance endpoint
    # Could add support for multi-level subaccounts
    COMPREPLY=($(compgen -W "usage" -- "$_twilio_cli_helper_cur"))
  fi
}

complete -o nosort -F _twilio_cli_helper_list twilio_cli_helper
