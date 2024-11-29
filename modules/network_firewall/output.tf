output "firewall_endpoint_ids" {
  value = {
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}