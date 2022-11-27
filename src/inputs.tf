variable CONFIG_GIT_HOST {
  type        = string
}

variable CONFIG_GIT_REPOSITORY_URL {
  type        = string
  description = "URL of the source repository where the centrally-managed Salt configuration residess."
}

variable DEFAULT_GATEWAY {
  type        = string
  description = "Default network gateway used to configure static IP address."
}

variable ENABLE_CW_LOGGING {
  type        = bool
  default     = false
  description = "Determines whether or not logs are written to AWS CloudWatch. This becomes expensive so enable with care."
}

variable FS_SPEC {
  type        = string
  description = "Shared network file server where salt master keys are maintained."
}


variable GIT_REPOSITORY {
  type        = string
  description = "Unique identifier for the current code repository."
}

variable GIT_SHORT_SHA {
  type        = string
  description = "Unique identifier for the current code code revision within the current code repository."
}

variable IP_ADDRESS {
  type        = string
  description = "Static IP address to be assigned to salt master."
}

variable NETMASK {
  type        = string
  description = "Netmask used to configure static IP address."
}

variable PRIVATE_GPG_KEY {
  type        = string
  description = "Private GPG key used to enable Salt to handle encrypted Pillar data."
}

variable PRIVATE_KEY {
  type        = string
  description = "Private SSH key used to connect to the Git-hosted Salt state tree."
}

variable PUBLIC_GPG_KEY {
  type        = string
  description = "Public GPG key used to enable Salt to handle encrypted Pillar data."
}

variable PUBLIC_KEY {
  type        = string
  description = "Public SSH key used to connect to the Git-hosted Salt state tree."
}

variable PVE_HOST {
  type        = string
  description = "description"
}

variable PVE_NODE {
  type        = string
  description = "The name of the Proxmox Node on which to place the VM."
}

variable PVE_PASSWORD {
  type        = string
  description = "Password used to authenticate to the Proxmox hypervisor."
}

variable PVE_POOL {
  type        = string
  description = "The resource pool to which the VM will be added."
}

variable PVE_USER {
  type        = string
  description = "description"
}
