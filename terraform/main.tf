terraform {
    required_providers {
        google = { source = "hashicorp/google", version = "~> 5.0" }
        tls    = { source = "hashicorp/tls", version = "~> 4.0" }
        local  = { source = "hashicorp/local", version = "~> 2.0" }
    }
}

provider "google" {
    project = var.project
}

# SSH key
resource "tls_private_key" "ssh_key" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "local_file" "private_key" {
    content         = tls_private_key.ssh_key.private_key_pem
    filename        = "${path.module}/id_rsa_server"
    file_permission = "0600"
}

# Firewall
resource "google_compute_firewall" "rules" {
    name    = "allow-serverledge-ports"
    network = "default"
    allow {
        protocol = "tcp"
        ports = ["22", "1322", "1323", "2379", "8080", "8089", "9090", "9091"] # SSH, LB, Nodi, ETCD, Locust, Prometheus
    }
    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["serverledge-node"]
}


# Zona Edge (Regione A)
resource "google_compute_instance" "client" {
    name         = "client-locust"
    machine_type = var.machine_type_medium
    zone         = var.zone_edge
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params { 
            image = var.image_x86 
        } 
    }
    network_interface { 
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }

    scheduling {
        preemptible                 = true
        automatic_restart           = false
        provisioning_model          = "SPOT"
        instance_termination_action = "STOP"
    }
}

resource "google_compute_instance" "optimizer" {
    name         = "optimizer-heftless"
    machine_type = var.machine_type_medium
    zone         = var.zone_edge
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params { 
            image = var.image_x86 
        } 
    }
    network_interface { 
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }

    scheduling {
        preemptible                 = true
        automatic_restart           = false
        provisioning_model          = "SPOT"
        instance_termination_action = "STOP"
    }
}

resource "google_compute_instance" "edge_nodes" {
    count        = 3
    name         = "edge-node-${count.index + 1}"
    machine_type = var.machine_type_edge
    zone         = var.zone_edge
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params { 
            image = var.image_x86 
        } 
    }
    network_interface { 
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }

    scheduling {
        preemptible                 = true
        automatic_restart           = false
        provisioning_model          = "SPOT"
        instance_termination_action = "STOP"
    }
}


# Zona Cloud (Regione B)
resource "google_compute_instance" "registry" {
    name         = "global-registry"
    machine_type = var.machine_type_medium
    zone         = var.zone_cloud
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params { 
            image = var.image_x86 
        } 
    }
    network_interface { 
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }
}

resource "google_compute_instance" "load_balancer" {
    name         = "load-balancer"
    machine_type = var.machine_type_medium
    zone         = var.zone_cloud
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params { 
            image = var.image_x86 
        } 
    }
    network_interface {
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }
}

resource "google_compute_instance" "cloud_nodes" {
    count        = 3
    name         = "cloud-node-${count.index + 1}"
    machine_type = var.machine_type_cloud
    zone         = var.zone_cloud
    tags         = ["serverledge-node"]
    boot_disk { 
        initialize_params {
            image = var.image_x86
        } 
    }
    network_interface {
        network = "default"
        access_config {} 
    }
    metadata = { ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}" }
}

# Generazione inventario per Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOF
    [client]
    ${google_compute_instance.client.network_interface[0].access_config[0].nat_ip}
    [optimizer]
    ${google_compute_instance.optimizer.network_interface[0].network_ip} ansible_host=${google_compute_instance.optimizer.network_interface[0].access_config[0].nat_ip}
    [edge_nodes]
    %{ for node in google_compute_instance.edge_nodes ~}
    ${node.network_interface[0].network_ip} ansible_host=${node.network_interface[0].access_config[0].nat_ip}
    %{ endfor ~}
    [registry]
    ${google_compute_instance.registry.network_interface[0].network_ip} ansible_host=${google_compute_instance.registry.network_interface[0].access_config[0].nat_ip}
    [load_balancer]
    ${google_compute_instance.load_balancer.network_interface[0].network_ip} ansible_host=${google_compute_instance.load_balancer.network_interface[0].access_config[0].nat_ip}
    [cloud_nodes]
    %{ for node in google_compute_instance.cloud_nodes ~}
    ${node.network_interface[0].network_ip} ansible_host=${node.network_interface[0].access_config[0].nat_ip}
    %{ endfor ~}

    [serverledge_nodes:children]
    edge_nodes
    cloud_nodes
    optimizer
    load_balancer

    [all:vars]
    ansible_user=${var.ssh_user}
    ansible_ssh_private_key_file=../terraform/id_rsa_server
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
    registry_ip=${google_compute_instance.registry.network_interface[0].network_ip}
    optimizer_ip=${google_compute_instance.optimizer.network_interface[0].network_ip}
  EOF
}
