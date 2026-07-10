variable "node_name" {
  type    = string
  default = "pve"
}

variable "template_vm_id" {
  type    = number
  default = 9000
}

variable "vm_id" {
  type    = number
  default = 100
}

variable "name" {
  type    = string
  default = "mediacenter"
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory_mib" {
  type    = number
  default = 24576
}

variable "os_disk_size_gb" {
  type    = number
  default = 100
}

variable "media_disk_size_gb" {
  type    = number
  default = 4300
}

variable "appdata_disk_size_gb" {
  type    = number
  default = 850
}
