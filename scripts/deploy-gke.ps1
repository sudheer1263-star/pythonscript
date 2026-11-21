param(
  [Parameter(Mandatory = $true)][string]$ProjectId,
  [Parameter(Mandatory = $true)][string]$Cluster,
  [Parameter(Mandatory = $true)][string]$Region,
  [string]$Repository = "python-repo",
  [string]$ImageName = "python-app",
  [string]$Tag = (git rev-parse --short HEAD),
  [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

$Image = "$Region-docker.pkg.dev/$ProjectId/$Repository/$ImageName`:$Tag"

Write-Host "Building image: $Image"
docker build -t $Image .

Write-Host "Pushing image to Artifact Registry"
docker push $Image

Write-Host "Configuring kubectl for cluster $Cluster"
gcloud container clusters get-credentials $Cluster --region $Region --project $ProjectId

Write-Host "Deploying to GKE namespace $Namespace"
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
kubectl -n $Namespace apply -k k8s
kubectl -n $Namespace set image deployment/python-app python-app=$Image
kubectl -n $Namespace rollout status deployment/python-app

Write-Host "Service status:"
kubectl -n $Namespace get svc python-app
