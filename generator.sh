#!/bin/bash

usage='

    ./generator.sh --get-policies \"true\" --selected-policy \"policy_name"\ --show-id \"true\" --create-policy \"true\" --append \"true"\ --token-generate \"true\" --list-tokens \"true\" --revoke-token \"token\"

    --get-policies    - List all policies that exist in Vault Store
    --selected-policy - Name of policy that require to be created or work with
    --show-id         - Bool value. Return the vault_id and secret_id of policy.
    --create-policy   - Bool value. Required for creating new policies. Must be use with policy_name
    --append          - Appending path for secrets/list (for existing policies only)
    --token-generate  - Bool value. Require for generating new token
    --list-tokens     - Bool value. Return the list of tokens appended to policy_name
    --revoke-token    - Pass the token value for revoking (deleting)

    For correct usage, please export root vault token and forwarded vault address into runtime:

    export VAULT_TOKEN=<string>
    export VAULT_ADDR=http://127.0.0.1:8200

'

while [[ $#  -gt 0 ]];
do
    case $1 in
        --get-policies)
          shift
          get_pol=$1
          ;;
        --show-id)
          shift
          show_id=$1
          ;;
        --create-policy)
          shift
          create_pol=$1
          ;;
        --selected-policy)
          shift
          selected_pol=$1
          ;;
        --append)
          shift
          appender=$1
          ;;
        --token-generate)
          shift
          token_gen=$1
          ;;
        --list-tokens)
          shift
          list_tokens=$1
          ;;
        --revoke-token)
          shift
          revoke_token=$1
          ;;
        -h | --help)
          echo -e "$usage"
          exit
          ;;
        *)
          echo -e "$usage"
          exit 1
          ;;
    esac
    shift
done

if [[ -z "$VAULT_TOKEN" || -z "$VAULT_ADDR" ]]
    then
    echo -e "$usage"
fi

get_current_policies() {

    curl -XLIST --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/sys/policies/acl | jq '.data.keys[]' | sed -e 's/^"//' -e 's/"$//'

}

work_with_policies() {

    if [[ $create_policy == "true" ]]
        then
            echo 'Creating New Policy with correct paths'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{"policy":"  path \"secret/data/'"$selected_pol"'\" {\n    capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n  }\n  path \"secret/+/\" {\n    capabilities = [\"read\", \"list\"]\n  }\n"}' $VAULT_ADDR/v1/sys/policy/$selected_pol
            echo 'Created Succesfully, generating approle...'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{"policies": "'"$selected_pol"'"}' $VAULT_ADDR/v1/auth/approle/role/$selected_pol
            echo 'AppRole Created Successfully, test generating Secret-ID...'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/$selected_pol/secret-id
            echo 'Generating RO token...'
            token=$(curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{ "policies":\"'"$selected_pol"'" }' $VAULT_ADDR/v1/auth/token/create | jq -r ".auth.client_token")
            echo 'Successfully done!'
            
            echo 'Current Role-ID'
            curl -XGET --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/$selected_pol/role-id | jq '.data'
            echo 'Current Secret-ID'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/$selected_pol/secret-id | jq '.data'
    fi

    if [[ $appender == "true" ]]
        then
            echo 'Append existing policy to work with RO token...'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{"policy":"  path \"secret/data/'"$selected_pol"'\" {\n    capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n  }\n  path \"secret/+/\" {\n    capabilities = [\"read\", \"list\"]\n  }\n"}' $VAULT_ADDR/v1/sys/policy/$selected_pol
            echo 'Generating RO token...'
            token=$(curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{ "policies":"'"$selected_pol"'" }' $VAULT_ADDR/v1/auth/token/create | jq -r ".auth.client_token")
    fi

    if [[ $show_id == "true" ]]
        then
            echo 'Current Role-ID'
            curl -XGET --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/$selected_pol/role-id | jq '.data'
            echo 'Current Secret-ID'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/$selected_pol/secret-id | jq '.data'
    fi

}

work_with_tokens() {

    if [[ $token_gen == "true" ]]
        then
            echo 'Generating RO token...'
            token=$(curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{ "policies":"'"$selected_pol"'" }' $VAULT_ADDR/v1/auth/token/create | jq -r ".auth.client_token")
            echo 'Successfully done!'
    fi

    if [[ -z $revoke_token ]]
        then
            echo 'Revoking selected token...'
            curl -XPOST --header "X-Vault-Token: $VAULT_TOKEN" --data '{ "token": "$revoke_token" }' $VAULT_ADDR/v1/auth/token/revoke
    fi

}

    if [[ $get_pol == "true" ]]
        then
        get_current_policies
    fi
        work_with_policies
        work_with_tokens
        printf "\n\t$selected_pol    :   $token\n\t" >> ./tokens.output
