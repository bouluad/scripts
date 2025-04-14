#!/bin/bash

# Input file: one namespace per line
namespace_file="namespaces.txt"

# Output CSV file
output_file="argocd_instances_info.csv"
echo "namespace,argocd_url,cluster_name,app_name,last_deployment_time" > "$output_file"

# Read each namespace
while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue

  # Get ArgoCD Ingress Host
  host=$(kubectl -n "$ns" get ingress argocd-server -o jsonpath="{.spec.rules[0].host}" 2>/dev/null)
  [[ -z "$host" ]] && echo "$ns,N/A,N/A,N/A,N/A" >> "$output_file" && continue

  # Get admin password
  password=$(kubectl -n "$ns" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
  [[ -z "$password" ]] && echo "$ns,https://$host,N/A,N/A,N/A" >> "$output_file" && continue

  # Login
  argocd login "$host" --username admin --password "$password" --insecure --grpc-web >/dev/null 2>&1

  # Get clusters
  clusters=$(argocd cluster list --grpc-web -o json | jq -r '.[].name')
  [[ -z "$clusters" ]] && clusters="N/A"

  # Get apps + last deployment
  apps=$(argocd app list --grpc-web -o json)

  if [[ $(jq length <<< "$apps") -eq 0 ]]; then
    echo "$ns,https://$host,$clusters,N/A,N/A" >> "$output_file"
    continue
  fi

  # Loop over each app
  jq -c '.[]' <<< "$apps" | while read -r app; do
    app_name=$(jq -r '.metadata.name' <<< "$app")
    last_deploy=$(jq -r '.status.operationState.finishedAt // "N/A"' <<< "$app")
    echo "$ns,https://$host,$clusters,$app_name,$last_deploy" >> "$output_file"
  done

done < "$namespace_file"

echo "✅ CSV report generated: $output_file"
