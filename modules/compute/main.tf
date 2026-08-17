variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type = string
}

variable "domain_netbios" {
  type = string
}

# ============================================================
# PUBLIC IP ADDRESSES
# ============================================================

resource "azurerm_public_ip" "dc01" {
  name                = "pip-dc01"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "ws01" {
  name                = "pip-ws01"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "ws02" {
  name                = "pip-ws02"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ============================================================
# NETWORK INTERFACES
# ============================================================

# DC01 gets a STATIC private IP because it will provide DNS
# and Active Directory Domain Services.
resource "azurerm_network_interface" "dc01" {
  name                = "nic-dc01"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.dc01.id
  }
}

# WS01 gets a dynamic private IP.
resource "azurerm_network_interface" "ws01" {
  name                = "nic-ws01"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ws01.id
  }
}

# WS02 gets a dynamic private IP.
resource "azurerm_network_interface" "ws02" {
  name                = "nic-ws02"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ws02.id
  }
}

# ============================================================
# WINDOWS SERVER IMAGE
# ============================================================

locals {
  img = {
    pub   = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku   = "2022-Datacenter"
    ver   = "latest"
  }
}

# ============================================================
# DOMAIN CONTROLLER - DC01
# ============================================================

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "DC01"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username
  admin_password = var.admin_password

  # Required for Azure Update Manager scheduled patching.
  patch_mode = "AutomaticByPlatform"

  # Allows the Update Manager user schedule to override
  # platform safety checks.
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  # Reboot the VM when a patch requires it.
  reboot_setting = "IfRequired"

  network_interface_ids = [
    azurerm_network_interface.dc01.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.img.pub
    offer     = local.img.offer
    sku       = local.img.sku
    version   = local.img.ver
  }
}

# ============================================================
# WINDOWS SERVER - WS01
# ============================================================

resource "azurerm_windows_virtual_machine" "ws01" {
  name                = "WS01"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username
  admin_password = var.admin_password

  # Required for Azure Update Manager scheduled patching.
  patch_mode = "AutomaticByPlatform"

  # Allows the Update Manager user schedule to override
  # platform safety checks.
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  # Reboot the VM when a patch requires it.
  reboot_setting = "IfRequired"

  network_interface_ids = [
    azurerm_network_interface.ws01.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.img.pub
    offer     = local.img.offer
    sku       = local.img.sku
    version   = local.img.ver
  }
}

# ============================================================
# WINDOWS SERVER - WS02
# ============================================================

resource "azurerm_windows_virtual_machine" "ws02" {
  name                = "WS02"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username
  admin_password = var.admin_password

  # Required for Azure Update Manager scheduled patching.
  patch_mode = "AutomaticByPlatform"

  # Allows the Update Manager user schedule to override
  # platform safety checks.
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  # Reboot the VM when a patch requires it.
  reboot_setting = "IfRequired"

  network_interface_ids = [
    azurerm_network_interface.ws02.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.img.pub
    offer     = local.img.offer
    sku       = local.img.sku
    version   = local.img.ver
  }
}

# ============================================================
# ACTIVE DIRECTORY DOMAIN CONTROLLER SETUP
# ============================================================

resource "azurerm_virtual_machine_extension" "setup_dc" {
  name                 = "SetupDC"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = <<-EOT
      powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools; Import-Module ADDSDeployment; Install-ADDSForest -DomainName '${var.domain_name}' -DomainNetBiosName '${var.domain_netbios}' -SafeModeAdministratorPassword (ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force) -InstallDns -Force"
    EOT
  })
}

# ============================================================
# DOMAIN JOIN COMMAND
# ============================================================

locals {
  join_cmd = <<-EOT
    powershell -ExecutionPolicy Unrestricted -Command "
    \$a = Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | Select-Object -First 1;

    Set-DnsClientServerAddress -InterfaceIndex \$a.InterfaceIndex -ServerAddresses '10.0.1.10';

    Write-Host 'Waiting for DNS to resolve the domain...';
    do {
        Start-Sleep -Seconds 20
    } until (Resolve-DnsName '${var.domain_name}' -ErrorAction SilentlyContinue);

    Write-Host 'Waiting for domain controller to respond...';
    do {
        Start-Sleep -Seconds 20
    } until (Test-Connection -ComputerName '${var.domain_name}' -Count 1 -Quiet);

    Write-Host 'Attempting domain join...';

    Add-Computer -DomainName '${var.domain_name}' -Credential (New-Object System.Management.Automation.PSCredential('${var.domain_netbios}\\${var.admin_username}', (ConvertTo-SecureString '${var.admin_password}' -AsPlainText -Force))) -Restart -Force
    "
  EOT
}

# ============================================================
# JOIN WS01 TO DOMAIN
# ============================================================

resource "azurerm_virtual_machine_extension" "join_ws01" {
  name                 = "JoinDomain"
  virtual_machine_id   = azurerm_windows_virtual_machine.ws01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = local.join_cmd
  })

  depends_on = [
    azurerm_virtual_machine_extension.setup_dc
  ]
}

# ============================================================
# JOIN WS02 TO DOMAIN
# ============================================================

resource "azurerm_virtual_machine_extension" "join_ws02" {
  name                 = "JoinDomain"
  virtual_machine_id   = azurerm_windows_virtual_machine.ws02.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = local.join_cmd
  })

  depends_on = [
    azurerm_virtual_machine_extension.setup_dc
  ]
}

# ============================================================
# OUTPUTS
# ============================================================

output "dc01_id" {
  value = azurerm_windows_virtual_machine.dc01.id
}

output "ws01_id" {
  value = azurerm_windows_virtual_machine.ws01.id
}

output "ws02_id" {
  value = azurerm_windows_virtual_machine.ws02.id
}

output "dc01_public_ip" {
  value = azurerm_public_ip.dc01.ip_address
}

output "ws01_public_ip" {
  value = azurerm_public_ip.ws01.ip_address
}

output "ws02_public_ip" {
  value = azurerm_public_ip.ws02.ip_address
}