# Deploy from Artifact Registry to GKE

This repo now includes code-based deployment assets for GKE:

- `k8s/deployment.yaml` - Kubernetes Deployment for the Flask app
- `k8s/service.yaml` - LoadBalancer Service exposing port 80 -> 8080
- `k8s/kustomization.yaml` - Kustomize base; image name/tag can be overridden
- `scripts/deploy-gke.ps1` - local/manual deploy script
- `.github/workflows/deploy-gke.yml` - CI/CD build, push, deploy workflow

## Prerequisites

- GCP project with billing enabled
- APIs enabled: `artifactregistry.googleapis.com`, `container.googleapis.com`
- Artifact Registry Docker repo exists (default in config: `python-repo`)
- GKE cluster exists
- GCP service account key in GitHub secret `GCP_SA_KEY` with permissions to push images and deploy to GKE (e.g. Artifact Registry Writer + Kubernetes Engine Developer, or narrower roles)
- GKE node service account has `roles/artifactregistry.reader` on the Artifact Registry repo

Grant node pull access if needed:

```bash
gcloud artifacts repositories add-iam-policy-binding python-repo \
  --location=asia-south1 \
  --project=nifty-charter-463213-u8 \
  --member="serviceAccount:NODE_SA_EMAIL" \
  --role="roles/artifactregistry.reader"
```

## Local/manual deploy

From repo root, with Docker, gcloud, and kubectl configured:

```powershell
./scripts/deploy-gke.ps1 `
  -ProjectId nifty-charter-463213-u8 `
  -Cluster YOUR_GKE_CLUSTER `
  -Region asia-south1 `
  -Repository python-repo `
  -ImageName python-app
```

The script builds, pushes to Artifact Registry, gets cluster credentials, applies `k8s/`, sets the deployment image, and waits for rollout.

## GitHub Actions deploy

Workflow: `.github/workflows/deploy-gke.yml`

Before using it, set:

- `env.CLUSTER` to your GKE cluster name
- `env.PROJECT_ID`, `REGION`, `REPOSITORY`, `IMAGE_NAME`, `NAMESPACE` as needed
- GitHub secret `GCP_SA_KEY`

It triggers on pushes to `main` and manual `workflow_dispatch`. It builds/pushes `.../python-app:${{ github.sha }}` and deploys that exact image.

## Manual kubectl deploy

If the image is already in Artifact Registry:

```bash
gcloud container clusters get-credentials CLUSTER --region asia-south1 --project nifty-charter-463213-u8
kubectl apply -k k8s
kubectl set image deployment/python-app python-app=asia-south1-docker.pkg.dev/nifty-charter-463213-u8/python-repo/python-app:TAG
kubectl rollout status deployment/python-app
kubectl get svc python-app
```

## Notes

- `k8s/kustomization.yaml` contains a default image; CI/local script overrides it with `kubectl set image` for immutable SHA/tag deploys.
- The app listens on `$PORT` (default 8080), matching the container and probes.
- Existing Cloud Run workflows were left in place; use `deploy-gke.yml` for GKE. Consider disabling overlapping workflows to avoid unintended deploys on `main`.
