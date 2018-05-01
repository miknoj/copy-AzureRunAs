<#
    .DESCRIPTION
        Copies the RunAs account information (Certificate and Connection) to another Azure Automation account.

    .NOTES
        AUTHOR: Jason Wages
        LASTEDIT: Nov 5, 2017
#>

### User Variables
	$targetResourceGroup = "myTargetAutomationAccountResourceGroup"
	$targetAutomationAccount = "myTargetAutomationAccountName"

### System Variables - don't change unless you know what/why
	$connectionName = "AzureRunAsConnection"
	$certFile =  "AzureRunAsCert.pfx"
	$certPassword = "azureRunAs!tempPassword123"
	$certName = "AzureRunAsCertificate"
	$connName = "AzureRunAsConnection"
	$connType = "AzureServicePrincipal"

### Login to Azure using the local RunAs connection
	try {
		$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

		"Logging in to Azure..."
		Add-AzureRmAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
	}
	catch {
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		} else{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}

### Loading local certificate	
	Write-Output "Getting Local Certificate..."
		$thumbprint = $servicePrincipalConnection.CertificateThumbprint
		$cert = Get-ChildItem -Path Cert:\CurrentUser\My | where {$_.Thumbprint -match $thumbprint}
		Write-Output $cert

### Exporting local certificate		
	$certFile =  ($env:TEMP) + $certFile
	Write-Output "Exporting Certificate to File: $certFile"
	$certPassword = ConvertTo-SecureString -String $certPassword -Force -AsPlainText
	[system.IO.file]::WriteAllBytes($certFile, ($cert.Export('PFX', $certPassword)))
	
### Copying local certificate to target automation account
	if(Test-Path $certFile){
		Write-Output "Certificate Successfully Exported"
		Write-Output "Importing Certificate..."
		New-AzureRmAutomationCertificate -ResourceGroupName $targetResourceGroup -AutomationAccountName $targetAutomationAccount -Name $certName -Path $certFile -Exportable -Password $certPassword
		Write-Output "Import Complete"
		Write-Output "Creating Connection..."
		$subId = $servicePrincipalConnection.SubscriptionId
		$connectionFieldValues = @{"ApplicationId" = $servicePrincipalConnection.ApplicationId; "TenantId" = $servicePrincipalConnection.TenantId; "CertificateThumbprint" = $thumbprint; "SubscriptionId" = $subId}
		New-AzureRmAutomationConnection -ResourceGroupName $targetResourceGroup -AutomationAccountName $targetAutomationAccount -Name $connName -ConnectionTypeName $connType -ConnectionFieldValues $connectionFieldValues
		Write-Output "Connection Created"
	} else {
		Write-Output "Certificate Export Failed"
	}

Write-Output "DONE"
