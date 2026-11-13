output "ip_client_locust" {
  value       = google_compute_instance.client.network_interface[0].access_config[0].nat_ip
  description = "IP pubblico del Client (Locust)"
}

output "ip_optimizer_heftless" {
  value       = google_compute_instance.optimizer.network_interface[0].access_config[0].nat_ip
  description = "IP pubblico dell'ottimizzatore"
}

output "ip_edge_nodes" {
  value       = google_compute_instance.edge_nodes[*].network_interface[0].access_config[0].nat_ip
  description = "Lista IP pubblici dei 3 nodi Edge"
}

output "ip_global_registry" {
  value       = google_compute_instance.registry.network_interface[0].access_config[0].nat_ip
  description = "IP pubblico del Global Registry (etcd)"
}

output "ip_load_balancer" {
  value       = google_compute_instance.load_balancer.network_interface[0].access_config[0].nat_ip
  description = "IP pubblico del Load Balancer"
}

output "ip_cloud_nodes" {
  value       = google_compute_instance.cloud_nodes[*].network_interface[0].access_config[0].nat_ip
  description = "Lista IP pubblici dei 3 nodi Cloud"
}

output "private_key_path" {
  value       = local_file.private_key.filename
  sensitive   = true
}