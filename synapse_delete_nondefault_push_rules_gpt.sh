#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# Config (set these)
# ---------------------------
HS_BASE_URL="https://YOUR_SYNAPSE_DOMAIN_HERE"
ACCESS_TOKEN="YOUR_ACCOUNT_ACCESS_TOKEN_HERE"

# ---------------------------
# Helpers
# ---------------------------
api_get() { curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "${HS_BASE_URL}$1"; }
api_del() { curl -s -X DELETE -H "Authorization: Bearer ${ACCESS_TOKEN}" "${HS_BASE_URL}$1"; }
api_put_json() { curl -s -X PUT -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "Content-Type: application/json" "${HS_BASE_URL}$1" -d "$2"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1" >&2; exit 1; }; }

need_cmd curl
need_cmd jq

echo "Fetching current push rules from ${HS_BASE_URL} ..."
RULES_JSON="$(api_get "/_matrix/client/v3/pushrules/")"

# Sanity check: ensure we got JSON with "global"
echo "${RULES_JSON}" | jq -e '.global' >/dev/null 2>&1 || { echo "ERROR: did not receive expected pushrules JSON. Response was:" >&2; echo "${RULES_JSON}" >&2; exit 1; }

# ---------------------------
# 1) Delete all non-default rules (default == false)
# ---------------------------
KINDS=(override content room sender underride postcontent)

echo "Deleting non-default (default=false) push rules..."
for kind in "${KINDS[@]}"; do
  mapfile -t RULE_IDS < <(echo "${RULES_JSON}" | jq -r --arg k "$kind" '.global[$k][]? | select(.default==false) | .rule_id')
  if [[ "${#RULE_IDS[@]}" -eq 0 ]]; then
    echo "  ${kind}: none"
    continue
  fi
  for rid in "${RULE_IDS[@]}"; do
    echo "  ${kind}: deleting ${rid}"
    api_del "/_matrix/client/v3/pushrules/global/${kind}/${rid}" >/dev/null || true
  done
done

# ---------------------------
# 2) Reset mutated default rule actions to match "fresh" behaviour (like jason)
#    (These values are taken from your jason/dino pushrules dumps.)
# ---------------------------

echo "Resetting key default rule actions..."

# Override rules (dino had dont_notify; jason has notify+highlight(+sound default for user/display name))
api_put_json "/_matrix/client/v3/pushrules/global/override/.m.rule.is_user_mention/actions" '{"actions":["notify",{"set_tweak":"highlight"},{"set_tweak":"sound","value":"default"}]}' >/dev/null
api_put_json "/_matrix/client/v3/pushrules/global/override/.m.rule.contains_display_name/actions" '{"actions":["notify",{"set_tweak":"highlight"},{"set_tweak":"sound","value":"default"}]}' >/dev/null
api_put_json "/_matrix/client/v3/pushrules/global/override/.m.rule.is_room_mention/actions" '{"actions":["notify",{"set_tweak":"highlight"}]}' >/dev/null
api_put_json "/_matrix/client/v3/pushrules/global/override/.m.rule.roomnotif/actions" '{"actions":["notify",{"set_tweak":"highlight"}]}' >/dev/null

# Content rule (dino had dont_notify; jason has notify+highlight+sound default)
api_put_json "/_matrix/client/v3/pushrules/global/content/.m.rule.contains_user_name/actions" '{"actions":["notify",{"set_tweak":"highlight"},{"set_tweak":"sound","value":"default"}]}' >/dev/null

# Underride rules (dino had actions []; jason has notify (with highlight false))
api_put_json "/_matrix/client/v3/pushrules/global/underride/.m.rule.message/actions" '{"actions":["notify",{"set_tweak":"highlight","value":false}]}' >/dev/null
api_put_json "/_matrix/client/v3/pushrules/global/underride/.m.rule.encrypted/actions" '{"actions":["notify",{"set_tweak":"highlight","value":false}]}' >/dev/null

# Member events: jason has actions []; dino had notify+highlight false in the file dump
api_put_json "/_matrix/client/v3/pushrules/global/override/.m.rule.member_event/actions" '{"actions":[]}' >/dev/null

echo "Done."
echo "Tip: log out/in on Element X / SchildiChat Next after this, then test an incoming call."

