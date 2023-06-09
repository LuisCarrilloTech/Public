Function Update-VMAdvancedSetting {
<#
.SYNOPSIS
Enables Change Block Tracking (CBT) for the specified virtual machines in a vCenter environment.

.DESCRIPTION
This script enables Change Block Tracking (CBT) for the specified virtual machines in a vCenter environment. CBT tracks disk changes in VMs and is used by backup solutions to determine which disk blocks need to be backed up, improving backup speed and efficiency.

.EXAMPLE
Enable-CBT -VirtualMachines "vm1, vm2" -vCenter "vcenter.domain.com" -AdvancedSetting "changeTrackingEnabled" -Value $TRUE

This example sets the advanced setting "changeTrackingEnabled" to $TRUE on VMs "vm1" and "vm2" on vCenter server "vcenter.domain.com".

.EXAMPLE
Enable-CBT -VirtualMachines vm1, vm2, vm3 -vCenter "myvcenter.domain.com" -AdvancedSetting "changeTrackingEnabled" -Value $TRUE

This example enables CBT for VMs "vm1", "vm2", and "vm3" on vCenter server "myvcenter.domain.com".

.EXAMPLE
Enable-CBT -VirtualMachines vm1, vm2, vm3 -vCenter "myvcenter.domain.com" -AdvancedSetting "changeTrackingEnabled" -Value $TRUE -Disconnect

This example enables CBT for VMs "vm1", "vm2", and "vm3" on vCenter server "myvcenter.domain.com" and Disconnects from vCenter(s) by using the -Disconnect switch parameter.

.INPUTS
VirtualMachines:
The virtual machines to enable CBT for. This parameter accepts an array of virtual machine names.

vCenter:
The vCenter server to connect to.

AdvancedSetting:
The advanced setting to configure for the specified virtual machine. Example: "changeTrackingEnabled".

Value:
The value to set for the advanced setting as either True or False.

.OUTPUTS
None, it enables CBT for the specified virtual machines.

.NOTES
Author: Luis Carrillo
Github: https://github.com/LuisCarrilloTech

#>


    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [string[]]$VirtualMachines,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $false)]
        [string]$vCenters,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $false)]
        [string]$AdvancedSetting,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $false)]
        $Value,
        [switch]$Disconnect
    )

    # Check if VMWare PowerCLI module is installed:
    $moduleName = "VMware.VimAutomation.Core"
    if (!(Get-Module -Name $moduleName)) {
        Import-Module -Name $moduleName -Force
    } else {
        Write-Output "Loading module. Please wait..."
    }

    # Prompt user to input vCenter FQDN and connect to server:
    if (!($global:DefaultVIServers)) {

        [System.Management.Automation.PSCredential]$Credential = Get-Credential

        foreach ($vcenter in $vCenters) {
            # Connect to vCenter server:
            try {
                Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
                Write-Host "Connected to vCenter $($vCenter)"
            } catch [VMware.Vim.VimException] {
                Write-Error "Failed to connect to vCenter. Please verify your credentials and try again."
                break
            } catch {
                Write-Error "An error occurred. Please try again."
                break
            }
        }
    }

    # Enable CBT on each VM:
    foreach ($vm in $VirtualMachines) {
        try {
            # Check if VM exists and get view object:
            $vmview = Get-VM $vm -ErrorAction Stop | Get-View
            $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        } catch {
            Write-Error "Failed to find VM $($vm). Please verify the VM name and try again."
            continue
        }

        # Create snapshot before enabling CBT and set setting:
        try {
            New-Snapshot $vm -Name "Prior to enabling setting $($AdvancedSetting)" -ea Stop
        } catch {
            Write-Error "Failed to create snapshot for $($vm). Please verify try again."
            continue
        }

        # Enable CBT:
        $vmConfigSpec.($AdvancedSetting) = $Value
        $vmview.reconfigVM($vmConfigSpec)

        # Wait for task to complete:
        Start-Sleep 15

        # Verify settings has been configured, if so, delete pre-setting snapshot:
        if ((Get-VM $vm | Get-View).config.$AdvancedSetting -eq $value) {
            Write-Host "Setting $($AdvancedSetting) set to $($Value) on VM $($vm)."
            # Remove snapshot:
            try {
                Get-Snapshot -VM $vm -Name "Prior to enabling setting $($AdvancedSetting)" | Remove-Snapshot -Confirm:$false -ErrorAction Stop
                Write-Host "Snapshot removed."
            } catch {
                Write-Error "Failed to remove snapshot. Please check if the snapshot exists and try again."
                continue
            }
        }

    }

    # Disconnect from vCenter:
    if ($Disconnect) {
        $global:DefaultVIServers | Disconnect-VIServer -Force -Confirm:$false
        Write-Host "Disconnected from vCenter $($vCenter)."
    } else {
        Write-Error "Failed to disconnect from vCenter $($vCenter)."
    }
}