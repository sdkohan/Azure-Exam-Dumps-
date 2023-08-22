# Title: Changing Hostname and IP Address of Windows Server
# Created By: Soroush Kohan
# Created Date: 22Aug2023



# List available network adapters
$adapters = Get-NetAdapter | Select-Object Name, Status, InterfaceIndex | Format-Table -AutoSize
Write-Host "Available network adapters:"
$adapters

# Prompt user to choose a network adapter by index
$selectedIndex = Read-Host "Enter the index number of the network adapter to configure"
$adapterToConfigure = Get-NetAdapter | Where-Object { $_.InterfaceIndex -eq $selectedIndex }

if ($adapterToConfigure -eq $null) {
    Write-Host "No network adapter found with the specified index."
}
else {
    Write-Host "Selected network adapter: $($adapterToConfigure.Name)"

    # Display existing hostname and IP addresses
    $existingHostName = (Get-WmiObject Win32_ComputerSystem).Name
    $existingIPAddresses = ($adapterToConfigure | Get-NetIPAddress).IPAddress

    Write-Host "Existing Host Name: $existingHostName"
    Write-Host "Existing IP Addresses: $($existingIPAddresses -join ', ')"

    # Prompt user for new host name or keep the default
    $newHostName = Read-Host "Your current host name is $existingHostName. Please provide the new host name or accept the default [$existingHostName]:"
    if ($newHostName -eq "") {
        $newHostName = $existingHostName
    }
    Rename-Computer -NewName $newHostName -Force

    # Prompt user for new IP address or keep the default
    $newIPAddress = Read-Host "Your current IP address is $($existingIPAddresses -join ', '). Please provide the new IP address or accept the default:"
    if ($newIPAddress -eq "") {
        $newIPAddress = $existingIPAddresses
    }

    # Prompt user for subnet mask or keep the default
    $newSubnetMask = Read-Host "Please provide the new subnet mask in CIDR format (e.g., 24 for /24) or accept the default:"
    if ($newSubnetMask -eq "") {
        $existingSubnetMask = ($adapterToConfigure | Get-NetIPAddress).PrefixLength
        $newSubnetMask = $existingSubnetMask
    }

    # Prompt user for default gateway or keep the default
    $existingDefaultGateway = ($adapterToConfigure | Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Manual" }).NextHop
    $newDefaultGateway = Read-Host "Please provide the new default gateway or accept the default [$existingDefaultGateway]:"
    if ($newDefaultGateway -eq "") {
        $newDefaultGateway = $existingDefaultGateway
    }

    # Prompt user for primary DNS or keep the default
    $existingPrimaryDNS = ($adapterToConfigure | Get-DnsClientServerAddress).ServerAddresses[0]
    $newPrimaryDNS = Read-Host "Your current primary DNS IP address is $existingPrimaryDNS. Please provide the new primary DNS IP address or accept the default:"
    if ($newPrimaryDNS -eq "") {
        $newPrimaryDNS = $existingPrimaryDNS
    }

    # Prompt user for secondary DNS or keep the default
    $existingSecondaryDNS = ($adapterToConfigure | Get-DnsClientServerAddress).ServerAddresses[1]
    $newSecondaryDNS = Read-Host "Your current secondary DNS IP address is $existingSecondaryDNS. Please provide the new secondary DNS IP address or accept the default:"
    if ($newSecondaryDNS -eq "") {
        $newSecondaryDNS = $existingSecondaryDNS
    }

    # Prompt user to disable IPv6 or keep the default
    $disableIPv6 = Read-Host "Do you want to disable IPv6? (Y/N) [N]"
    if ($disableIPv6 -eq "Y") {
        $adapterToConfigure | Disable-NetAdapterBinding -ComponentID ms_tcpip6
        Write-Host "IPv6 has been disabled."
    }

    # Apply the new IP configuration
    $adapterToConfigure | Remove-NetIPAddress -Confirm:$false
    $adapterToConfigure | New-NetIPAddress -IPAddress $newIPAddress -PrefixLength $newSubnetMask

    # Remove the existing default gateway
    $adapterToConfigure | Remove-NetRoute -Confirm:$false -NextHop $existingDefaultGateway

    # Add the new default gateway
    $adapterToConfigure | New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop $newDefaultGateway

    # Set the DNS servers
    $dnsServers = @($newPrimaryDNS, $newSecondaryDNS)
    $adapterToConfigure | Set-DnsClientServerAddress -ServerAddresses $dnsServers

    Write-Host "Network settings have been updated for $($adapterToConfigure.Name)."

    # Prompt user to reboot the host
    $reboot = Read-Host "Do you want to reboot the host now? (Y/N) [N]"
    if ($reboot -eq "Y") {
        Write-Host "Rebooting the host..."
        Restart-Computer -Force
    }
    else {
        Write-Host "Network configuration has been updated. You can choose to reboot the host later."
    }
}
