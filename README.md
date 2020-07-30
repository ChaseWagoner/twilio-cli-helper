# twilio-cli-helper

### Purpose

Quickly fetch Twilio account balances and usage. Also works for subaccounts.

### Setup

1. Provide Twilio credentials for your project(s):

    ```sh
    cd twilio-cli-helper

    # `creds` directory is in .gitignore to prevent accidents
    mkdir creds

    # Retrieve project Account SID and Auth Token from the Twilio console
    echo "export TWILIO_ACCOUNT_SID='AC...'
    export TWILIO_AUTH_TOKEN='***...'" > creds/my-project.sh
    ```

1. Ensure the helper is available by sourcing it in your shell's rc file, e.g.

    ```sh
    source /path/to/twilio-cli-helper/twilio-cli-helper.sh
    ```

### Usage

After sourcing `twilio-cli-helper.sh` in your current shell, run `twilio_cli_helper help` to see usage information (note the underscores).

Tested only on Bash 5. At least major version 4 is required, I believe, as this script uses the `nosort` option for `complete`.
