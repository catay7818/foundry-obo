#!/usr/bin/env bash
#
# assign-media-roles.sh
# Assigns Cosmos DB RBAC roles for media containers to a specific user

set -euo pipefail

readonly DEFAULT_DATABASE_NAME="DemoDatabase"

usage() {
  cat <<EOF
Usage: ${0##*/} --resource-group <rg> --cosmos-account <name> --user-oid <oid> [--role <role>] [--database-name <name>]

Assigns Cosmos DB RBAC roles for media containers (Stellar Horizons and Crown & Chaos) to a user.

Required Arguments:
  --resource-group, -g    Resource group name
  --cosmos-account, -c    Cosmos DB account name
  --user-oid, -u          User Object ID from Entra ID

Optional Arguments:
  --database-name, -d     Database name (default: ${DEFAULT_DATABASE_NAME})
  --role, -r              Role to assign:
                            sh-show           - Stellar Horizons Show container
                            sh-production     - Stellar Horizons Production container
                            sh-costume        - Stellar Horizons Costume container
                            sh-all            - All Stellar Horizons containers
                            cc-show           - Crown & Chaos Show container
                            cc-production     - Crown & Chaos Production container
                            cc-costume        - Crown & Chaos Costume container
                            cc-all            - All Crown & Chaos containers
                            all               - All media containers
                            control-plane     - Control plane (Azure RBAC) access
                            admin             - Control plane + all media containers
                          (interactive selection if not provided)
  --help, -h              Show this help message

Examples:
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def -r sh-all
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def -r admin
  ${0##*/} -g foundry-dev-rg -c foundry-cosmos -u abc-123-def -r cc-production -d MediaDatabase
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
  local DATABASE_NAME="$DEFAULT_DATABASE_NAME"

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
      --database-name|-d)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--database-name requires an argument"
        fi
        DATABASE_NAME="$2"
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

  printf "Configuring Cosmos DB media RBAC for account: %s\n" "$COSMOS_ACCOUNT_NAME"

  local COSMOS_ACCOUNT_ID
  COSMOS_ACCOUNT_ID=$(az cosmosdb show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$COSMOS_ACCOUNT_NAME" \
    --query id \
    --output tsv)

  if [[ -z "$COSMOS_ACCOUNT_ID" ]]; then
    err "Failed to retrieve Cosmos DB account ID"
  fi

  printf "Retrieving media role definitions...\n"

  local SH_SHOW_ROLE_ID SH_PRODUCTION_ROLE_ID SH_COSTUME_ROLE_ID
  local CC_SHOW_ROLE_ID CC_PRODUCTION_ROLE_ID CC_COSTUME_ROLE_ID

  SH_SHOW_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='SH Show Container Reader'].id" \
    --output tsv)

  SH_PRODUCTION_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='SH Production Container Reader'].id" \
    --output tsv)

  SH_COSTUME_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='SH Costume Container Reader'].id" \
    --output tsv)

  CC_SHOW_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='CC Show Container Reader'].id" \
    --output tsv)

  CC_PRODUCTION_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='CC Production Container Reader'].id" \
    --output tsv)

  CC_COSTUME_ROLE_ID=$(az cosmosdb sql role definition list \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?roleName=='CC Costume Container Reader'].id" \
    --output tsv)

  if [[ -z "$SH_SHOW_ROLE_ID" ]] || [[ -z "$SH_PRODUCTION_ROLE_ID" ]] || [[ -z "$SH_COSTUME_ROLE_ID" ]] || \
     [[ -z "$CC_SHOW_ROLE_ID" ]] || [[ -z "$CC_PRODUCTION_ROLE_ID" ]] || [[ -z "$CC_COSTUME_ROLE_ID" ]]; then
    err "Failed to retrieve one or more custom media role definitions"
  fi

  if [[ -z "$ROLE" ]]; then
    printf "\nSelect role to assign:\n"
    printf "  1)  Stellar Horizons — Show\n"
    printf "  2)  Stellar Horizons — Production\n"
    printf "  3)  Stellar Horizons — Costume\n"
    printf "  4)  Stellar Horizons — All containers\n"
    printf "  5)  Crown & Chaos — Show\n"
    printf "  6)  Crown & Chaos — Production\n"
    printf "  7)  Crown & Chaos — Costume\n"
    printf "  8)  Crown & Chaos — All containers\n"
    printf "  9)  All media containers\n"
    printf "  10) Control plane access only\n"
    printf "  11) Admin (control plane + all media containers)\n"
    read -rp "Enter choice [1-11]: " choice

    case "$choice" in
      1)  ROLE="sh-show" ;;
      2)  ROLE="sh-production" ;;
      3)  ROLE="sh-costume" ;;
      4)  ROLE="sh-all" ;;
      5)  ROLE="cc-show" ;;
      6)  ROLE="cc-production" ;;
      7)  ROLE="cc-costume" ;;
      8)  ROLE="cc-all" ;;
      9)  ROLE="all" ;;
      10) ROLE="control-plane" ;;
      11) ROLE="admin" ;;
      *)  err "Invalid choice" ;;
    esac
  fi

  ROLE="$(echo "$ROLE" | tr '[:upper:]' '[:lower:]')"

  printf "\nAssigning role(s) to user: %s\n" "$USER_OID"

  case "$ROLE" in
    sh-show)
      assign_role "$SH_SHOW_ROLE_ID" "SH Show Container Reader" "sh-show"
      ;;
    sh-production)
      assign_role "$SH_PRODUCTION_ROLE_ID" "SH Production Container Reader" "sh-production"
      ;;
    sh-costume)
      assign_role "$SH_COSTUME_ROLE_ID" "SH Costume Container Reader" "sh-costume"
      ;;
    sh-all)
      assign_role "$SH_SHOW_ROLE_ID" "SH Show Container Reader" "sh-show"
      assign_role "$SH_PRODUCTION_ROLE_ID" "SH Production Container Reader" "sh-production"
      assign_role "$SH_COSTUME_ROLE_ID" "SH Costume Container Reader" "sh-costume"
      ;;
    cc-show)
      assign_role "$CC_SHOW_ROLE_ID" "CC Show Container Reader" "cc-show"
      ;;
    cc-production)
      assign_role "$CC_PRODUCTION_ROLE_ID" "CC Production Container Reader" "cc-production"
      ;;
    cc-costume)
      assign_role "$CC_COSTUME_ROLE_ID" "CC Costume Container Reader" "cc-costume"
      ;;
    cc-all)
      assign_role "$CC_SHOW_ROLE_ID" "CC Show Container Reader" "cc-show"
      assign_role "$CC_PRODUCTION_ROLE_ID" "CC Production Container Reader" "cc-production"
      assign_role "$CC_COSTUME_ROLE_ID" "CC Costume Container Reader" "cc-costume"
      ;;
    all)
      assign_role "$SH_SHOW_ROLE_ID" "SH Show Container Reader" "sh-show"
      assign_role "$SH_PRODUCTION_ROLE_ID" "SH Production Container Reader" "sh-production"
      assign_role "$SH_COSTUME_ROLE_ID" "SH Costume Container Reader" "sh-costume"
      assign_role "$CC_SHOW_ROLE_ID" "CC Show Container Reader" "cc-show"
      assign_role "$CC_PRODUCTION_ROLE_ID" "CC Production Container Reader" "cc-production"
      assign_role "$CC_COSTUME_ROLE_ID" "CC Costume Container Reader" "cc-costume"
      ;;
    control-plane)
      assign_control_plane_role
      ;;
    admin)
      assign_control_plane_role
      assign_role "$SH_SHOW_ROLE_ID" "SH Show Container Reader" "sh-show"
      assign_role "$SH_PRODUCTION_ROLE_ID" "SH Production Container Reader" "sh-production"
      assign_role "$SH_COSTUME_ROLE_ID" "SH Costume Container Reader" "sh-costume"
      assign_role "$CC_SHOW_ROLE_ID" "CC Show Container Reader" "cc-show"
      assign_role "$CC_PRODUCTION_ROLE_ID" "CC Production Container Reader" "cc-production"
      assign_role "$CC_COSTUME_ROLE_ID" "CC Costume Container Reader" "cc-costume"
      ;;
    *)
      err "Invalid role: $ROLE (must be sh-show, sh-production, sh-costume, sh-all, cc-show, cc-production, cc-costume, cc-all, all, control-plane, or admin)"
      ;;
  esac

  printf "\n✅ Media RBAC configuration complete!\n"
}

main "$@"
