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
- GKE cluster exists, and its name/region match `env.CLUSTER` / `env.REGION` in the workflow
- GCP service account key in GitHub secret `GCP_SA_KEY` with permissions to push images and deploy to GKE (e.g. Artifact Registry Writer + Kubernetes Engine Developer, or narrower roles)
- GKE node service account has `roles/artifactregistry.reader` on the Artifact Registry repo

### One-time GCP setup (run as a project owner/admin)

The CI service account cannot enable APIs or grant itself roles, so run these manually:

```bash
# Required by `gcloud container clusters get-credentials`; without it you get
# "403 ... Kubernetes Engine API has not been used in project ... or it is disabled".
gcloud services enable container.googleapis.com --project=nifty-charter-463213-u8

# Lets the CI service account get cluster credentials and deploy workloads.
gcloud projects add-iam-policy-binding nifty-charter-463213-u8 \
  --member="serviceAccount:artifact-registry-writer@nifty-charter-463213-u8.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Confirm the cluster name/location used in the workflow.
gcloud container clusters list --project=nifty-charter-463213-u8 --region=asia-south1
```

Allow a few minutes for API activation and IAM changes to propagate, then re-run the workflow. If an enablement was recent, simply re-running may fix the 403.

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

It triggers on pushes to `main`, `Feature-*`/`feature/*` branches, and manual `workflow_dispatch`. It builds/pushes `.../python-app:${{ github.sha }}` and deploys that exact image.

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

- `Dockerfile` uses a multi-stage build: dependencies are installed into `/install` in the builder stage, then copied into a clean runtime image. The runtime stage contains no pip/build cache.
- `k8s/kustomization.yaml` contains a default image; CI/local script overrides it with `kubectl set image` for immutable SHA/tag deploys.
- The app listens on `$PORT` (default 8080), matching the container and probes.
- CI uses `google-github-actions/get-gke-credentials@v3`, which writes a kubeconfig with a short-lived token. Do not replace it with `gcloud container clusters get-credentials` + `gke-gcloud-auth-plugin`: with gcloud >= 571 and `CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE` set by the auth action, `gcloud config config-helper` crashes with `'Credentials' object has no attribute 'private_key_id'` and every `kubectl` command fails.
- The local script still uses `gcloud container clusters get-credentials`, so it needs `gke-gcloud-auth-plugin` installed locally.
- Existing Cloud Run workflows were left in place; use `deploy-gke.yml` for GKE. Consider disabling overlapping workflows to avoid unintended deploys on `main`.
