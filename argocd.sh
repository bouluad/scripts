#!/bin/bash

# Input file containing namespaces (one per line)
namespace_file="namespaces.txt"

# Output file
output_file="argocd_instances_info.txt"
echo "" > "$output_file"

# Read each namespace from the file
while IFS= read -r ns; do
  if [[ -z "$ns" ]]; then
    continue
  fi

  echo "Namespace: $ns" >> "$output_file"

  # Get Ingress host for the Argo CD server
  host=$(kubectl -n "$ns" get ingress argocd-server -o jsonpath="{.spec.rules[0].host}" 2>/dev/null)

  if [ -z "$host" ]; then
    echo "❌ Could not find ingress for namespace: $ns" >> "$output_file"
    echo "--------------------------------------" >> "$output_file"
    continue
  fi

  echo "ArgoCD URL: https://$host" >> "$output_file"

  # Get the admin password
  password=$(kubectl -n "$ns" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)

  if [ -z "$password" ]; then
    echo "❌ Could not find admin password for namespace: $ns" >> "$output_file"
    echo "--------------------------------------" >> "$output_file"
    continue
  fi

  # Login using argocd CLI
  argocd login "$host" --username admin --password "$password" --insecure --grpc-web >/dev/null 2>&1

  # Get clusters
  echo "Clusters:" >> "$output_file"
  argocd cluster list --grpc-web | tail -n +2 >> "$output_file"

  # Get last deployment times
  echo "Last Deployments:" >> "$output_file"
  argocd app list --grpc-web -o json | jq -r '.[] | "\(.metadata.name) - Last Deployed: \(.status.operationState.finishedAt // "N/A")"' >> "$output_file"

  echo "--------------------------------------" >> "$output_file"

done < "$namespace_file"

echo "✅ Done. Results saved to $output_file"
