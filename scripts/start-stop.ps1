param(
    [string]$action,
    [string[]]$vmnames,
    [string[]]$resourcegroups,
    [Parameter(Mandatory = $true)]
    [string]$AccountId
)

# Function to write structured output
function Write-JobOutput {
    param(
        [string]$Status,
        [string]$Message,
        [string]$VMName,
        [string]$ResourceGroup,
        [object]$ErrorDetails = $null
    )
    
    $output = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status = $Status
        Message = $Message
        VMName = $VMName
        ResourceGroup = $ResourceGroup
        ErrorDetails = $ErrorDetails
    }
    
    Write-Output ($output | ConvertTo-Json)
}

# Initialize job status
Write-JobOutput -Status "Started" -Message "Starting VM management job" -VMName "N/A" -ResourceGroup "N/A"

try {
    Write-JobOutput -Status "Authenticating" -Message "Connecting to Azure using managed identity" -VMName "N/A" -ResourceGroup "N/A"
    
    # Ensures you do not inherit an AzContext in your runbook
    Write-JobOutput -Status "Info" -Message "Clearing Azure context" -VMName "N/A" -ResourceGroup "N/A"
    Disable-AzContextAutosave -Scope Process | Out-Null
    Clear-AzContext -Force | Out-Null

    # Connect to Azure with user-assigned managed identity
    Write-JobOutput -Status "Info" -Message "Attempting to connect with managed identity" -VMName "N/A" -ResourceGroup "N/A"
    try {
        $null = Connect-AzAccount -Identity -AccountId $AccountId
        
        # Get and select the subscription
        $subscription = Get-AzSubscription | Select-Object -First 1
        if ($subscription) {
            $null = Set-AzContext -Subscription $subscription.Id
            Write-JobOutput -Status "Success" -Message "Successfully authenticated to Azure and selected subscription $($subscription.Name)" -VMName "N/A" -ResourceGroup "N/A"
        } else {
            throw "No subscription found for the managed identity"
        }
    }
    catch {
        throw "Failed to connect with managed identity: $($_.Exception.Message)"
    }

    $hasErrors = $false
    $processedVMs = 0
    $totalVMs = $vmnames.Length
    
    Write-JobOutput -Status "Info" -Message "Starting to process $totalVMs VMs" -VMName "N/A" -ResourceGroup "N/A"

    for ($i = 0; $i -lt $vmnames.Length; $i++) {
        $vmName = $vmnames[$i]
        $resourceGroup = $resourcegroups[$i]
        $processedVMs++
        
        Write-JobOutput -Status "Processing" -Message "Processing VM $processedVMs of $totalVMs" -VMName $vmName -ResourceGroup $resourceGroup
        
        try {
            # Verify VM exists
            Write-JobOutput -Status "Checking" -Message "Verifying VM exists" -VMName $vmName -ResourceGroup $resourceGroup
            Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction Stop
            
            if ($action -eq "start") {
                Write-JobOutput -Status "Starting" -Message "Initiating VM start operation" -VMName $vmName -ResourceGroup $resourceGroup
                $result = Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction Stop
                
                if ($result.Status -eq "Succeeded") {
                    Write-JobOutput -Status "Success" -Message "Successfully started VM" -VMName $vmName -ResourceGroup $resourceGroup
                } else {
                    throw "VM start operation returned status: $($result.Status)"
                }
            }
            elseif ($action -eq "stop") {
                Write-JobOutput -Status "Stopping" -Message "Initiating VM stop operation" -VMName $vmName -ResourceGroup $resourceGroup
                $result = Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force -ErrorAction Stop
                
                if ($result.Status -eq "Succeeded") {
                    Write-JobOutput -Status "Success" -Message "Successfully stopped VM" -VMName $vmName -ResourceGroup $resourceGroup
                } else {
                    throw "VM stop operation returned status: $($result.Status)"
                }
            }
        }
        catch {
            $hasErrors = $true
            $errorDetails = @{
                Message = $_.Exception.Message
                Category = $_.CategoryInfo.Category
                ErrorId = $_.FullyQualifiedErrorId
                ScriptStackTrace = $_.ScriptStackTrace
            }
            Write-JobOutput -Status "Error" -Message "Failed to $action VM" -VMName $vmName -ResourceGroup $resourceGroup -ErrorDetails $errorDetails
            continue
        }
    }
}
catch {
    $errorDetails = @{
        Message = $_.Exception.Message
        Category = $_.CategoryInfo.Category
        ErrorId = $_.FullyQualifiedErrorId
        ScriptStackTrace = $_.ScriptStackTrace
    }
    Write-JobOutput -Status "Error" -Message "Authentication failed: $($_.Exception.Message)" -VMName "N/A" -ResourceGroup "N/A" -ErrorDetails $errorDetails
    throw "Authentication failed. Unable to connect to Azure using managed identity: $($_.Exception.Message)"
}

# Final job status
if ($hasErrors) {
    Write-JobOutput -Status "Failed" -Message "Job completed with errors. Some VM operations failed." -VMName "N/A" -ResourceGroup "N/A"
    throw "Job Failed. An unhandled exception occurred."
} else {
    Write-JobOutput -Status "Completed" -Message "Job completed successfully. All VM operations succeeded." -VMName "N/A" -ResourceGroup "N/A"
}