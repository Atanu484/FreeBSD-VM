terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.97.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "atanu_rg" {
  name     = "atanu-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "atanu_vn" {
  name                = "atanu-network"
  resource_group_name = azurerm_resource_group.atanu_rg.name
  location            = azurerm_resource_group.atanu_rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "atanu_subnet" {
  name                 = "atanu-subnet"
  resource_group_name  = azurerm_resource_group.atanu_rg.name
  virtual_network_name = azurerm_virtual_network.atanu_vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "atanu_sg" {
  name                = "atanu-sg"
  location            = azurerm_resource_group.atanu_rg.location
  resource_group_name = azurerm_resource_group.atanu_rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "atanu_dev_rule" {
  name                        = "atanu-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.atanu_rg.name
  network_security_group_name = azurerm_network_security_group.atanu_sg.name
}

resource "azurerm_subnet_network_security_group_association" "atanu_sga" {
  subnet_id                 = azurerm_subnet.atanu_subnet.id
  network_security_group_id = azurerm_network_security_group.atanu_sg.id
}

resource "azurerm_public_ip" "atanu_ip" {
  name                = "atanu-ip"
  resource_group_name = azurerm_resource_group.atanu_rg.name
  location            = azurerm_resource_group.atanu_rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "atanu_nic" {
  name                = "atanu-nic"
  location            = azurerm_resource_group.atanu_rg.location
  resource_group_name = azurerm_resource_group.atanu_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.atanu_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.atanu_ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "atanu_vm" {
  name                  = "atanu-vm"
  resource_group_name   = azurerm_resource_group.atanu_rg.name
  location              = azurerm_resource_group.atanu_rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.atanu_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftOSTC"
    offer     = "FreeBSD"
    sku       = "12_1"  # Validate SKU based on the available image
    version   = "latest"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/atanuazurekey.pub")
  }

  tags = {
    environment = "dev"
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.atanu_ip.ip_address
}
