variable "project_id" {
  description = "The project to create test resources within."
  type        = string
  default     = "rteller-demo-host-aaaa"
}

variable "region" {
  description = "Region for cloud resources."
  type        = string
  default     = "us-central1"
}

variable "instances" {
  type = list(object({ Name = string, Zone = string }))
}

# Example structure for instances
# instances = [
#   {
#     Name = "us-east4-echo"
#     Zone = "us-east4-c"
#   },
#   {
#     Name = "bridged-vpc-edwu-usc1-panfw-01-b053"
#     Zone = "us-central1-a"
#   },
#   {
#     Name = "bridged-vpc-edwu-usc1-panfw-02-b053"
#     Zone = "us-central1-b"
#   },
#   {
#     Name = "bridged-vpc-edwm-usc1-panorama-4f3e",
#     Zone = "us-central1-a"
#   }
# ]