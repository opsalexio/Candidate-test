# Configure the Azure provider
provider "azurerm" {
  version = "~> 4.35"
  skip_provider_registration = "true"
  subscription_id      = "045d1194-578b-4c69-ae44-73b753f29f2e"                

  features {}
}

# Generate SSH key pair
resource "tls_private_key" "keycloak_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.keycloak_ssh.private_key_openssh
  filename        = "${path.module}/keycloak_ssh_key.pem"
  file_permission = "0600"
}

# Save public key to file
resource "local_file" "public_key" {
  content         = tls_private_key.keycloak_ssh.public_key_openssh
  filename        = "${path.module}/keycloak_ssh_key.pub"
  file_permission = "0644"
}

# Create a resource group
resource "azurerm_resource_group" "keycloak_rg" {
  name     = "keycloak-resources"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "keycloak_vnet" {
  name                = "keycloak-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.keycloak_rg.location
  resource_group_name = azurerm_resource_group.keycloak_rg.name
}

# Create a subnet
resource "azurerm_subnet" "keycloak_subnet" {
  name                 = "keycloak-subnet"
  resource_group_name  = azurerm_resource_group.keycloak_rg.name
  virtual_network_name = azurerm_virtual_network.keycloak_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP
resource "azurerm_public_ip" "keycloak_public_ip" {
  name                = "keycloak-public-ip"
  location            = azurerm_resource_group.keycloak_rg.location
  resource_group_name = azurerm_resource_group.keycloak_rg.name
  allocation_method   = "Dynamic"
}

# Create network security group with rules
resource "azurerm_network_security_group" "keycloak_nsg" {
  name                = "keycloak-nsg"
  location            = azurerm_resource_group.keycloak_rg.location
  resource_group_name = azurerm_resource_group.keycloak_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Keycloak"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "keycloak_nic" {
  name                = "keycloak-nic"
  location            = azurerm_resource_group.keycloak_rg.location
  resource_group_name = azurerm_resource_group.keycloak_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.keycloak_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.keycloak_public_ip.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "keycloak_nic_nsg" {
  network_interface_id      = azurerm_network_interface.keycloak_nic.id
  network_security_group_id = azurerm_network_security_group.keycloak_nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "keycloak_vm" {
  name                = "keycloak-vm"
  resource_group_name = azurerm_resource_group.keycloak_rg.name
  location            = azurerm_resource_group.keycloak_rg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.keycloak_nic.id,
  ]

admin_ssh_key {
  username   = "adminuser"
  public_key = tls_private_key.keycloak_ssh.public_key_openssh
}

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Provisioner to copy Ansible files
  provisioner "file" {
    source      = "./ansible"
    destination = "/home/adminuser"
    
    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = tls_private_key.keycloak_ssh.private_key_openssh
      host        = azurerm_public_ip.keycloak_public_ip.ip_address
    }
  }

  # Provisioner to execute remote commands
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3-pip",
      "sudo pip3 install ansible",
      "cd /home/adminuser/ansible && ansible-playbook -i inventory.ini playbook.yml"
    ]
    
    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = tls_private_key.keycloak_ssh.private_key_openssh
      host        = azurerm_public_ip.keycloak_public_ip.ip_address
    }
  }
}