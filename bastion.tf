provider "azurerm" {
  
  features {}
}


resource "azurerm_resource_group" "default" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"

  tags = {
    environment = "dev"
  }
}


module  "demo-network" {
  #source              = "./terraform-azurerm-network-master"
  source               = "app.terraform.io/Demo-Mahil/network/azurerm" 
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  subnet_prefixes     = "${var.subnet_prefixes}"
  subnet_names        = "${var.subnet_names}"
  vnet_name           = "mahil-vnet"
  sg_name             = "${var.sg_name}"
}

resource "azurerm_public_ip" "jumpbox" {
  name                         = "jumpbox-public-ip"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.default.name
  domain_name_label            = join("-",[var.resource_group_name,"ssh"])
  allocation_method   = "Static"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "jumpbox-ssh-access"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_network_security_rule" "ssh_access" {
  name                        = "ssh-access-rule-test"
  network_security_group_name = azurerm_network_security_group.jumpbox.name
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 200
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = azurerm_network_interface.jumpbox.private_ip_address
  destination_port_range      = "22"
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.default.name
}

resource "azurerm_network_interface" "jumpbox" {
  name                      = "jumpbox-nic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.default.name
  #network_security_group_id = azurerm_network_security_group.jumpbox.id

 ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = module.demo-network.vnet_subnets[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
    primary                                = true
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_machine" "jumpbox" {
  name                          = "jumpbox"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.default.name
  network_interface_ids         = [azurerm_network_interface.jumpbox.id]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "jumpbox-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "jumpbox"
    admin_username = "azureuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = var.ssh_key_public
    }
  }

  tags = {
    environment = "dev"
  }
}