# Voting Application AKS Helm Deployment Script (PowerShell)
# This script automates the Helm deployment process for Windows

param(
    [string]$ResourceGroup = "voting-app-rg",
    [string]$Location = "eastus",
    [string]$AksClusterName = "voting-app-aks",
    [string]$AcrName = "",
    [int]$NodeCount = 3,
    [string]$NodeVmSize = "Standard_B2s",
    [switch]$SkipAzureResources,
    [switch]$SkipBuildImages,
    [switch]$SkipDeploy
)

# Function to print colored output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI is not installed. Please install it first."
        exit 1
    }
    
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Error "kubectl is not installed. Please install it first."
        exit 1
    }
    
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        Write-Error "Helm is not installed. Please install it first."
        exit 1
    }
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed. Please install it first."
        exit 1
    }
    
    Write-Info "All prerequisites are installed."
}

# Create Azure resources
function New-AzureResources {
    param(
        [string]$ResourceGroup,
        [string]$Location,
        [string]$AksClusterName,
        [string]$AcrName,
        [int]$NodeCount,
        [string]$NodeVmSize
    )
    
    Write-Info "Creating Azure resources..."
    
    # Create resource group
    Write-Info "Creating resource group..."
    az group create --name $ResourceGroup --location $Location | Out-Null
    
    # Generate ACR name if not provided
    if ([string]::IsNullOrEmpty($AcrName)) {
        $randomSuffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
        $AcrName = "votingapp$randomSuffix"
        Write-Info "Generated ACR name: $AcrName"
    }
    
    # Create ACR
    Write-Info "Creating Azure Container Registry..."
    az acr create `
        --resource-group $ResourceGroup `
        --name $AcrName `
        --sku Basic `
        --admin-enabled true | Out-Null
    
    # Create AKS cluster
    Write-Info "Creating AKS cluster (this may take 10-15 minutes)..."
    az aks create `
        --resource-group $ResourceGroup `
        --name $AksClusterName `
        --node-count $NodeCount `
        --node-vm-size $NodeVmSize `
        --enable-managed-identity `
        --attach-acr $AcrName `
        --generate-ssh-keys | Out-Null
    
    # Get AKS credentials
    Write-Info "Getting AKS credentials..."
    az aks get-credentials `
        --resource-group $ResourceGroup `
        --name $AksClusterName `
        --overwrite-existing | Out-Null
    
    Write-Info "Azure resources created successfully."
    return $AcrName
}

# Build and push images
function Build-AndPushImages {
    param(
        [string]$AcrName,
        [string]$ResourceGroup
    )
    
    Write-Info "Building and pushing Docker images..."
    
    $AcrLoginServer = az acr show --name $AcrName --resource-group $ResourceGroup --query loginServer --output tsv
    
    Write-Info "ACR Login Server: $AcrLoginServer"
    
    # Login to ACR
    az acr login --name $AcrName | Out-Null
    
    # Build and push Vote service
    Write-Info "Building Vote service..."
    Set-Location ..\..\vote
    docker build -t "$AcrLoginServer/vote:v2" .
    docker push "$AcrLoginServer/vote:v2"
    
    # Build and push Result service
    Write-Info "Building Result service..."
    Set-Location ..\result
    docker build -t "$AcrLoginServer/result:v2" .
    docker push "$AcrLoginServer/result:v2"
    
    # Build and push Worker service
    Write-Info "Building Worker service..."
    Set-Location ..\worker
    docker build -t "$AcrLoginServer/worker:v2" .
    docker push "$AcrLoginServer/worker:v2"
    
    Set-Location ..\..\helm\voting-app
    Write-Info "Images built and pushed successfully."
}

# Update Helm values file
function Update-HelmValues {
    param(
        [string]$AcrName,
        [string]$ResourceGroup
    )
    
    Write-Info "Updating Helm values file with ACR name..."
    
    $AcrLoginServer = az acr show --name $AcrName --resource-group $ResourceGroup --query loginServer --output tsv
    
    # Update values-aks.yaml
    (Get-Content values-aks.yaml) -replace '<ACR_NAME>', $AcrLoginServer | Set-Content values-aks.yaml
    
    Write-Info "Helm values file updated."
}

# Deploy with Helm
function Deploy-WithHelm {
    Write-Info "Deploying with Helm..."
    
    # Check if release already exists
    $existingRelease = helm list -n voting-app --output json | ConvertFrom-Json | Where-Object { $_.name -eq "voting-app" }
    
    if ($existingRelease) {
        Write-Warn "Helm release 'voting-app' already exists. Upgrading..."
        helm upgrade voting-app . `
            --namespace voting-app `
            --values values-aks.yaml | Out-Null
    } else {
        Write-Info "Installing Helm chart..."
        helm install voting-app . `
            --namespace voting-app `
            --create-namespace `
            --values values-aks.yaml | Out-Null
    }
    
    Write-Info "Helm deployment completed."
}

# Verify deployment
function Test-Deployment {
    Write-Info "Verifying deployment..."
    
    Write-Host ""
    Write-Info "Helm Release Status:"
    helm list -n voting-app
    
    Write-Host ""
    Write-Info "Pod Status:"
    kubectl get pods -n voting-app
    
    Write-Host ""
    Write-Info "Service Status:"
    kubectl get services -n voting-app
    
    Write-Host ""
    Write-Info "Deployment Status:"
    kubectl get deployments -n voting-app
}

# Main execution
function Main {
    Write-Info "Starting Voting Application AKS Helm Deployment..."
    
    Test-Prerequisites
    
    if (-not $SkipAzureResources) {
        $script:AcrName = New-AzureResources -ResourceGroup $ResourceGroup -Location $Location -AksClusterName $AksClusterName -AcrName $AcrName -NodeCount $NodeCount -NodeVmSize $NodeVmSize
    } else {
        if ([string]::IsNullOrEmpty($AcrName)) {
            Write-Error "ACR name must be provided when skipping Azure resource creation."
            exit 1
        }
        $script:AcrName = $AcrName
    }
    
    if (-not $SkipBuildImages) {
        Build-AndPushImages -AcrName $script:AcrName -ResourceGroup $ResourceGroup
        Update-HelmValues -AcrName $script:AcrName -ResourceGroup $ResourceGroup
    } else {
        # Still update values if ACR name is known
        Update-HelmValues -AcrName $script:AcrName -ResourceGroup $ResourceGroup
    }
    
    if (-not $SkipDeploy) {
        Deploy-WithHelm
        Test-Deployment
    }
    
    Write-Info "Deployment script completed!"
    Write-Info "Use 'helm list -n voting-app' to check Helm releases"
    Write-Info "Use 'kubectl get pods -n voting-app' to check pod status"
    Write-Info "Use 'helm status voting-app -n voting-app' for detailed status"
}

# Run main function
Main

