# PowerShell Script to list Azure resources associated with a Private IP Address

cls
$InputIP = Read-Host -Prompt 'Enter a Private IP Address to search'
$IPValid = (($InputIP -As [IPAddress]) -As [Bool])
If($IPValid)
    {
    [Net.IPAddress] $IPAddress = $InputIP
    $MultiVNETs = 0
    Write-Host " "
    $VNETs = Get-AzVirtualNetwork 
    foreach ($VNET in $VNETs)
        {
        $SubNets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNET 
        foreach ($Subnet in $Subnets)
            {
            $HostNet, [Int]$CIDR  = ($Subnet.AddressPrefix).Split('/')
       
            # Find SubnetMask - from Reddit
            $M='{0:D}.{1:D}.{2:D}.{3:D}'-f $('{0:X}'-f -bnot([Uint32][math]::Pow(2,(32-$CIDR))-1)-Split'(..)'|?{$_}|%{[byte]('0x'+$_)})
            [Net.IPAddress] $IP2 = $HostNet
            [Net.IPAddress] $Mask = $M
            
            If (($IPAddress.address -band $Mask.address) -eq ($IP2.address -band $Mask.address))
                {
                $AvailableIp = Test-AzPrivateIPAddressAvailability -IPAddress $IPAddress -VirtualNetworkName $VNET.Name -ResourceGroupName $VNET.ResourceGroupName
                If ($AvailableIp.Available –eq $True) 
                    {
                    Write-Host "The IP Address $IPAddress is currently available" -ForegroundColor Green
                    Write-Host "as part of" $VNET.Name "Virtual Network's Address space" -ForegroundColor Green
                    Write-Host " "
                    $MultiVNETs += 1
                    }
                    Else
                    {
                    Write-Host "The $IPAddress IP Address is not available" -ForegroundColor Red
                    Write-Host "as part of" $VNET.Name "Virtual Network's Address space" -ForegroundColor Red
                    $NIC = Get-AzNetworkInterface | Where {$_.IpConfigurations.PrivateIpAddress -eq $IPAddress -and $_.ResourceGroupName -eq $VNET.ResourceGroupName}
                    If ($NIC -eq $null)
                        {
                        $NLB = Get-AzLoadBalancer | Where {$_.FrontendIpConfigurations.PrivateIpAddress -eq $IPAddress}
                        Write-Host "currently associated with the" $NLB.Name "Network Load Balancer" -ForegroundColor Red
                        Write-Host " "
                        $MultiVNETs += 1
                        }
                        Else
                        {
                        Write-Host "currently associated with the" $NIC.Name "Network Card" -ForegroundColor Red
                        If ($NIC.VirtualMachine.Id -eq $null)
                            {
                            Write-Host "but not currently attached to any Virtual Machine" -ForegroundColor Red
                            Write-Host " "
                            $MultiVNETs += 1
                            }
                            Else
                            { 
                            Write-Host "and attached to the" ($NIC.VirtualMachine.Id.Split('/') | Select -Last 1) "Virtual Machine" -ForegroundColor Red
                            Write-Host " "
                            $MultiVNETs += 1
                            }
                        }
                    }
                }
            }
        }
    If ($MultiVNETs -eq 0)
        {
        Write-Host "There are no Virtual Networks using an address space that includes the provided IP Address" -ForegroundColor Yellow
        }
        Else
        {
        If ($MultiVNETs -gt 1)
            {
            Write-Host "More than one Virtual Network share the same address space" -ForegroundColor Yellow
            }
        }
    }
    Else
    {
    Write-Host "Invalid IP Address"
    }