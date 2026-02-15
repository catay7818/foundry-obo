#!/usr/bin/env bash
#
# assign-user-roles.sh
# Assigns Cosmos DB RBAC role to a specific user

set -euo pipefail

readonly DATABASE_NAME="DemoDatabase"

usage() {
  cat <<EOF
Usage: ${0##*/} --resource-group <rg> --cosmos-account <name> --user-oid <oid> [--role <role>]

Assigns a Cosmos DB RBAC role to a user.

Required Arguments:
  --resource-group, -g    Resource group name
  --cosmos-account, -c    Cosmos DB account name
  --user-oid, -u          User Object ID from Entra ID

Optional Arguments:
  --role, -r              Role to assign:
                            sales, hr, finance    - Data plane container access
                            all                   - All data plane containers
                            control-plane         - Control plane (Azure RBAC) access
                            admin                 - Control plane + all data plane
                          (interactive selection if not provided)
  --help, -h              Show this help message

Examples:
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def -r sales
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def -r admin
EOF
  exit 1
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

assign_role() {
  local role_id="$1"
  local role_name="$2"
  local container="$3"
  local scope="${COSMOS_ACCOUNT_ID}/dbs/${DATABASE_NAME}/colls/${container}"

  printf "Assigning %s access to container %s...\n" "$role_name" "$container"
  az cosmosdb sql role assignment create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --role-definition-id "$role_id" \
    --principal-id "$USER_OID" \
    --scope "$scope"
}

assign_control_plane_role() {
  printf "Assigning control plane (Azure RBAC) access...\n"

  # Assign Built-in Reader role (control plane access) to the Cosmos DB account
  az role assignment create \
    --assignee "$USER_OID" \
    --role "acdd72a7-3385-48ef-bd42-f606fba81ae7" \
    --scope "$COSMOS_ACCOUNT_ID"
}

main() {
  local RESOURCE_GROUP=""
  local COSMOS_ACCOUNT_NAME=""
  local USER_OID=""
  local ROLE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --resource-group|-g)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--resource-group requires an argument"
        fi
        RESOURCE_GROUP="$2"
        shift 2
        ;;
      --cosmos-account|-c)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--cosmos-account requires an argument"
        fi
        COSMOS_ACCOUNT_NAME="$2"
        shift 2
        ;;
      --user-oid|-u)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--user-oid requires an argument"
        fi
        USER_OID="$2"
        shift 2
        ;;
      --role|-r)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--role requires an argument"
        fi
        ROLE="$2"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        ;;
    esac
  done

  if [[ -z "$RESOURCE_GROUP" ]] || [[ -z "$COSMOS_ACCOUNT_NAME" ]] || [[ -z "$USER_OID" ]]; then
    err "Missing required arguments"
  fi

  printf "Configuring Cosmos DB RBAC for account: %s\n" "$COSMOS_ACCOUNT_NAME"

  local COSMOS_ACCOUNT_ID
  COSMOS_ACCOUNT_ID=$(az cosmosdb show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$COSMOS_ACCOUNT_NAME" \
    --query id \
    --output tsv)

  if [[ -z "$COSMOS_ACCOUNT_ID" ]]; then
    err "Failed to retrieve Cosmos DB account ID"
  fi

  printf "Retrieving role definitions...\n"

  local SALES_ROLE_ID
  local HR_ROLE_ID
  local FINANCE_ROLE_ID

  SALES_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='Sales Container Reader'].id" \
    --output tsv)

  HR_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='HR Container Reader'].id" \
    --output tsv)

  FINANCE_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='Finance Container Reader'].id" \
    --output tsv)

  if [[ -z "$SALES_ROLE_ID" ]] || [[ -z "$HR_ROLE_ID" ]] || [[ -z "$FINANCE_ROLE_ID" ]]; then
    err "Failed to retrieve custom role definitions"
  fi

  if [[ -z "$ROLE" ]]; then
    printf "\nSelect role to assign:\n"
    printf "  1) Sales (data plane)\n"
    printf "  2) HR (data plane)\n"
    printf "  3) Finance (data plane)\n"
    printf "  4) All data plane containers\n"
    printf "  5) Control plane access only\n"
    printf "  6) Admin (control plane + all data plane)\n"
    read -rp "Enter choice [1-6]: " choice

    case "$choice" in
      1) ROLE="sales" ;;
      2) ROLE="hr" ;;
      3) ROLE="finance" ;;
      4) ROLE="all" ;;
      5) ROLE="control-plane" ;;
      6) ROLE="admin" ;;
      *) err "Invalid choice" ;;
    esac
  fi

  ROLE="$(echo "$ROLE" | tr '[:upper:]' '[:lower:]')"

  printf "\nAssigning role(s) to user: %s\n" "$USER_OID"

  case "$ROLE" in
    sales)
      assign_role "$SALES_ROLE_ID" "Sales" "Sales"
      ;;
    hr)
      assign_role "$HR_ROLE_ID" "HR" "HR"
      ;;
    finance)
      assign_role "$FINANCE_ROLE_ID" "Finance" "Finance"
      ;;
    all)
      assign_role "$SALES_ROLE_ID" "Sales" "Sales"
      assign_role "$HR_ROLE_ID" "HR" "HR"
      assign_role "$FINANCE_ROLE_ID" "Finance" "Finance"
      ;;
    control-plane)
      assign_control_plane_role
      ;;
    admin)
      assign_control_plane_role
      assign_role "$SALES_ROLE_ID" "Sales" "Sales"
      assign_role "$HR_ROLE_ID" "HR" "HR"
      assign_role "$FINANCE_ROLE_ID" "Finance" "Finance"
      ;;
    *)
      err "Invalid role: $ROLE (must be sales, hr, finance, all, control-plane, or admin)"
      ;;
  esac

  printf "\n✅ RBAC configuration complete!\n"
}

main "$@"
