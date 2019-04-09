# PowerShell Script to list Azure Services as follows:
# Subscriptions > Virtual Networks > Sub-Networks > Virtual Machines (OS & Network Card) > Private & Public IPAddresses > Network Security Group (Ports)


$AzSub = Get-AzSubscription
cls 
foreach ($AzSub in $AzSub) 
    {
    Write-Host "Subsctiption                       :" $AzSub.Name
    $VNETs = Get-AzVirtualNetwork 
    foreach ($VNET in $VNETs)
        {
        Write-Host "   Virtual Network                 :" $VNET.Name 
        $SubNets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNET 
        foreach ($Subnet in $Subnets)
            {
            Write-Host "       Address Space               :" $Subnet.AddressPrefix
            $HostNet, [Int]$CIDR  = ($Subnet.AddressPrefix).Split('/')
       
            # Find SubnetMask - from Reddit
            $M='{0:D}.{1:D}.{2:D}.{3:D}'-f $('{0:X}'-f -bnot([Uint32][math]::Pow(2,(32-$CIDR))-1)-Split'(..)'|?{$_}|%{[byte]('0x'+$_)})
            
            Write-Host "       Subnet Name                 :" $Subnet.Name
            $VMs = Get-AzVM -ResourceGroupName $VNET.ResourceGroupName -Status
            foreach ($VM in $VMs)
                {
                $InternalNIC = Get-AzResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id | Get-AzNetworkInterface
                $VMNIC = Get-AzNetworkInterface | where {$_.Id -eq $VM.NetworkProfile.NetworkInterfaces[0].Id} 
                [Net.IPAddress] $IP1 = $VMNIC.IpConfigurations[0].PrivateIpAddress
                [Net.IPAddress] $IP2 = $HostNet
                [Net.IPAddress] $Mask = $M
                If (($IP1.address -band $Mask.address) -eq ($IP2.address -band $Mask.address)) 
                    {
                    Write-Host "           Virtual Machine         :" $VM.Name
                    Write-Host "               Status              :" $VM.PowerState
                    Write-Host "               Operating System    :" $VM.StorageProfile.OsDisk.OsType
                    Write-Host "               Network Card        :" $InternalNIC.Name
                    Write-Host "                   Private IP      :" $VMNIC.IpConfigurations[0].PrivateIpAddress
                    $NIC = $VM.NetworkProfile.NetworkInterfaces[0].Id.Split('/') | select -Last 1
                    $PIP =  (Get-AzNetworkInterface -ResourceGroupName $VM.ResourceGroupName -Name $NIC).IpConfigurations.PublicIpAddress.Id
                    If ([string]::IsNullOrWhiteSpace($PIP))
                        {
                        Write-Host "                   Public IP       : Not Assigned"
                        }
                        Else
                        { 
                        $PIPName = $PIP.Split('/') | select -Last 1
                        $PIPAddress = (Get-AzPublicIpAddress -ResourceGroupName $VM.ResourceGroupName -Name $PIPName).IpAddress
                        Write-Host "                   Public IP       :" $PIPAddress
                        If ($VM.PowerState -eq "VM running")
                            {
                            $NSGs = Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName $InternalNIC.Name -ResourceGroupName $InternalNIC.ResourceGroupName
                            $NumRules = $NSGs.EffectiveSecurityRules.Count
                            $RuleCount = 0
                            While ($RuleCount -lt $NumRules)
                                {
                                Write-Host "                       Priority    :" $NSGs.EffectiveSecurityRules[$RuleCount].Priority
                                Write-Host "                       NSG Name    :" $NSGs.EffectiveSecurityRules[$RuleCount].Name.Split('/')[-1]
                                Write-Host "                       Direction   :" $NSGs.EffectiveSecurityRules[$RuleCount].Direction
                                Write-Host "                       Source Addr :" $NSGs.EffectiveSecurityRules[$RuleCount].SourceAddressPrefix
                                Write-Host "                       Dest. Addr  :" $NSGs.EffectiveSecurityRules[$RuleCount].DestinationAddressPrefix
                                Write-Host "                       Source Port :" $NSGs.EffectiveSecurityRules[$RuleCount].SourcePortRange
                                Write-Host "                       Dest. Port  :" $NSGs.EffectiveSecurityRules[$RuleCount].DestinationPortRange
                                $RuleCount += 1
                                }
                            }
                        }
                    Write-Host " "
                    }   
                }
            Write-Host " " 
            }  
        Write-Host " "
        }
    }