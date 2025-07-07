# Output the public IP address
output "public_ip_address" {
  value = azurerm_public_ip.keycloak_public_ip.ip_address
}

output "ssh_command" {
  value = "ssh -i keycloak_ssh_key.pem adminuser@${azurerm_public_ip.keycloak_public_ip.ip_address}"
}