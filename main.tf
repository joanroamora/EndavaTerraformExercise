terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    
    tls = {
      source = "hashicorp/tls"
      version = "=4.0.3"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "endava-rg" {
  name     = "endava-homework"
  location = "brazilsouth"
  tags = {
    "owner" = "joanroamora"
    "email" = "joanroamora@gmail.com"
  }
}

resource "azurerm_network_security_group" "endava-sg" {
  name                = "endava-security-group"
  location            = azurerm_resource_group.endava-rg.location
  resource_group_name = azurerm_resource_group.endava-rg.name

  security_rule {
    name                       = "ssh22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http80"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    "owner" = "joanroamora"
    "email" = "joanroamora@gmail.com"
  }
}

resource "azurerm_virtual_network" "endava-vn" {
  name                = "endava-vn"
  location            = azurerm_resource_group.endava-rg.location
  resource_group_name = azurerm_resource_group.endava-rg.name
  address_space       = ["10.0.0.0/27"]

  tags = {
    "owner" = "joanroamora"
    "email" = "joanroamora@gmail.com"
  }
}

resource "azurerm_subnet" "endava-subnet" {
  name                 = "endava-subnet1"
  resource_group_name  = azurerm_resource_group.endava-rg.name
  virtual_network_name = azurerm_virtual_network.endava-vn.name
  address_prefixes     = ["10.0.0.0/28"]
}


resource "azurerm_public_ip" "endava-pub-ip" {
  name                = "endava-publicip"
  resource_group_name = azurerm_resource_group.endava-rg.name
  location            = azurerm_resource_group.endava-rg.location
  allocation_method   = "Dynamic"

  tags = {
    "owner" = "joanroamora"
    "email" = "joanroamora@gmail.com"
  }
}

resource "azurerm_network_interface" "endava-ni" {
  name                = "endava-nic"
  location            = azurerm_resource_group.endava-rg.location
  resource_group_name = azurerm_resource_group.endava-rg.name

  ip_configuration {
    name                          = "endava-iptest"
    subnet_id                     = azurerm_subnet.endava-subnet.id
    private_ip_address_allocation  = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.endava-pub-ip.id
  }

  tags = {
    "owner" = "joanroamora"
    "email" = "joanroamora@gmail.com"
  }
  
}

resource "azurerm_network_interface_security_group_association" "endava-nisga" {
  network_interface_id      = azurerm_network_interface.endava-ni.id
  network_security_group_id = azurerm_network_security_group.endava-sg.id
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_ssh_public_key" "endava_sshKey" {
  name                = "endava-sshKey"
  resource_group_name = azurerm_resource_group.endava-rg.name
  location            = azurerm_resource_group.endava-rg.location
  public_key          = file("/home/augustus/.ssh/id_rsa.pub")
  
}

resource "azurerm_linux_virtual_machine" "endava_vm" {
  name                  = "ENDAVA-VM"
  location              = azurerm_resource_group.endava-rg.location
  resource_group_name   = azurerm_resource_group.endava-rg.name
  network_interface_ids = [azurerm_network_interface.endava-ni.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
}

data "template_file" "endava-script" {
  template = file("script.sh")
}