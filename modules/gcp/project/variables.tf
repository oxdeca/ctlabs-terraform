# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/variables.tf
# Description : project module variables
#               defaults are given in  main.tf as locals
# -----------------------------------------------------------------------------

#
# required:
#   - project.name
#   - project.billing
#   - either project.oid or project.fid
#   - if project.vpc_type == 'shared': project.shared_vpc 
# 
# defaults given:
#   - project.vpc_type
#   - project.sa_delete
#
# optional:
#   - project.id (defaults to project.name if not given)
#   - project.labels
#   - prroject.delete_policy
#   - project.create_network

variable project { type = any }
