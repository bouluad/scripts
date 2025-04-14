#!/bin/bash

# Input: namespaces listed line by line
namespace_file="namespaces.txt"

# Output CSV
output_file="argocd_instances_info.csv"
echo "namespace,argocd_url,cluster_name,app_name,last_deployment_time" > "$output_file"

# Loop over each namespace
while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue

  # Get Ingress host
  host=$(kubectl -n "$ns" get ingress argocd-server -o jsonpath="{.spec.rules[0].host}" 2>/dev/null)
  if [[ -z "$host" ]]; then
    echo "$ns,N/A,N/A,N/A,N/A" >> "$output_file"
    continue
  fi

  # Get ArgoCD admin password
  password=$(kubectl -n "$ns" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
  if [[ -z "$password" ]]; then
    echo "$ns,https://$host,N/A,N/A,N/A" >> "$output_file"
    continue
  fi

  # Login to ArgoCD
  argocd login "$host" --username admin --password "$password" --insecure --grpc-web >/dev/null 2>&1

  # Get clusters
  clusters=$(argocd cluster list --grpc-web -o json | jq -r '.[].name' | paste -sd ';' -)
  [[ -z "$clusters" ]] && clusters="N/A"

  # Get apps
  apps=$(argocd app list --grpc-web -o json)
  if [[ $(jq length <<< "$apps") -eq 0 ]]; then
    continue
  fi

  # Loop through apps
  jq -c '.[]' <<< "$apps" | while read -r app; do
    app_name=$(jq -r '.metadata.name' <<< "$app")
    last_deploy=$(jq -r '.status.operationState.finishedAt // "N/A"' <<< "$app")

    # Lowercase for case-insensitive match
    app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')

    # Filter: include only if app name contains prod/prd/production/uat
    if [[ "$app_name_lower" == *prod* ]] || [[ "$app_name_lower" == *production* ]] || [[ "$app_name_lower" == *prd* ]] || [[ "$app_name_lower" == *uat* ]]; then
      echo "$ns,https://$host,$clusters,$app_name,$last_deploy" >> "$output_file"
    fi
  done

done < "$namespace_file"

echo "✅ Filtered CSV report generated: $output_file"
