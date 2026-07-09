resource "tailscale_tailnet_key" "mediacenter" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags          = ["tag:mediacenter"]
  description   = "mediacenter VM cloud-init bootstrap"
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "${var.name}.cloud-config.yaml"
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname           = var.name
      tailscale_auth_key = tailscale_tailnet_key.mediacenter.key
    })
  }
}

resource "proxmox_virtual_environment_vm" "mediacenter" {
  name        = var.name
  description = "Jellyfin + arr stack"
  tags        = ["mediacenter"]

  node_name = var.node_name
  vm_id     = var.vm_id

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  stop_on_destroy = true
  on_boot         = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mib
  }

  efi_disk {
    datastore_id      = "fast-store"
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = "fast-store"
    interface    = "scsi0"
    size         = var.os_disk_size_gb
    file_format  = "raw"
    ssd          = true
  }

  disk {
    datastore_id = "bulk-store"
    interface    = "scsi1"
    size         = var.media_disk_size_gb
    file_format  = "raw"
  }

  hostpci {
    device  = "hostpci0"
    mapping = "intel-igpu"
    pcie    = true
  }

  network_device {}

  initialization {
    datastore_id      = "fast-store"
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
