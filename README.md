This bash script resets push rules for a specific account in a Matrix Synapse server DB.
This can be useful in cases where stuck push rules create problems with missing notifications on Matrix clients.

It does this by searching for non-default push rules and deleting them.

Requirements:

- a running Synapse server, accessible via a URL
- an API Access Token for the Synapse account you want to modify
- curl and jq installed on the machine where the script will run

How to run:

- Place both the script file and the .env file in the same directory
- Edit the .env file to add your Synapse server URL and your account API Access Token
- Make the script file executable if needed, and run it

Provided as-is without any guarantee, use at your own risk.
