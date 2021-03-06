---
title: Cloud Controller API Reference

language_tabs:
  - shell: curl

includes:
 # snippets have to be at the top to be used in other files
  - snippets/query_params
  - snippets/object_attributes
  - api_resources/app_features
  - api_resources/app_ssh_enabled
  - api_resources/apps
  - api_resources/builds
  - api_resources/buildpacks
  - api_resources/deployments
  - api_resources/droplets
  - api_resources/domains
  - api_resources/feature_flags
  - api_resources/isolation_segments
  - api_resources/jobs
  - api_resources/organizations
  - api_resources/packages
  - api_resources/processes
  - api_resources/resource_matches
  - api_resources/revisions
  - api_resources/route_mappings
  - api_resources/service_bindings
  - api_resources/service_instances
  - api_resources/sidecars
  - api_resources/spaces
  - api_resources/stacks
  - api_resources/tasks
  - introduction/introduction
  - concepts/concepts
  - workflows/workflows
  - resources/header
  - resources/apps/header
  - resources/apps/object
  - resources/apps/create
  - resources/apps/get
  - resources/apps/list
  - resources/apps/update
  - resources/apps/delete
  - resources/apps/get_current_droplet
  - resources/apps/get_current_droplet_relationship
  - resources/apps/env
  - resources/apps/environment_variables
  - resources/apps/current_droplet
  - resources/apps/start
  - resources/apps/stop
  - resources/apps/update_environment_variables
  - resources/builds/header
  - resources/builds/object
  - resources/builds/create
  - resources/builds/get
  - resources/builds/list
  - resources/builds/list_for_app
  - resources/builds/update
  - resources/droplets/header
  - resources/droplets/object
  - resources/droplets/get
  - resources/droplets/list
  - resources/droplets/list_for_package
  - resources/droplets/list_for_app
  - resources/droplets/update
  - resources/droplets/delete
  - resources/droplets/copy
  - resources/feature_flags/header
  - resources/feature_flags/object
  - resources/feature_flags/flags
  - resources/feature_flags/get
  - resources/feature_flags/list
  - resources/feature_flags/update
  - resources/isolation_segments/header
  - resources/isolation_segments/object
  - resources/isolation_segments/create
  - resources/isolation_segments/get
  - resources/isolation_segments/list
  - resources/isolation_segments/list_organizations
  - resources/isolation_segments/list_spaces
  - resources/isolation_segments/update
  - resources/isolation_segments/delete
  - resources/isolation_segments/assign
  - resources/isolation_segments/unassign
  - resources/jobs/header
  - resources/jobs/object
  - resources/jobs/get
  - resources/organizations/header
  - resources/organizations/object
  - resources/organizations/create
  - resources/organizations/get_an_organization
  - resources/organizations/list
  - resources/organizations/list_for_isolation_segment
  - resources/organizations/update
  - resources/organizations/assign_default_isolation_segment
  - resources/organizations/get_default_isolation_segment
  - resources/packages/header
  - resources/packages/object
  - resources/packages/create
  - resources/packages/get
  - resources/packages/list
  - resources/packages/list_for_app
  - resources/packages/update
  - resources/packages/delete
  - resources/packages/copy_bits
  - resources/packages/download_bits
  - resources/packages/stage
  - resources/packages/upload_bits
  - resources/processes/header
  - resources/processes/object
  - resources/processes/health_check_object
  - resources/processes/stats_object
  - resources/processes/get
  - resources/processes/stats
  - resources/processes/list
  - resources/processes/list_for_app
  - resources/processes/update
  - resources/processes/scale
  - resources/processes/terminate_instance
  - resources/service_instances/header
  - resources/service_instances/object
  - resources/service_instances/list
  - resources/service_instances/list_shared_spaces
  - resources/service_instances/update
  - resources/service_instances/share_to_space
  - resources/service_instances/unshare_from_space
  - resources/spaces/header
  - resources/spaces/object
  - resources/spaces/create
  - resources/spaces/get_a_space
  - resources/spaces/list
  - resources/spaces/update
  - resources/spaces/get_assigned_isolation_segment
  - resources/spaces/manage_isolation_segment
  - resources/stacks/header
  - resources/stacks/object
  - resources/stacks/create
  - resources/stacks/get
  - resources/stacks/list
  - resources/stacks/update
  - resources/stacks/delete
  - resources/tasks/header
  - resources/tasks/object
  - resources/tasks/create
  - resources/tasks/get
  - resources/tasks/list
  - resources/tasks/list_for_app
  - resources/tasks/update
  - resources/tasks/cancel
  - experimental_resources/header
  - experimental_resources/app_features/header
  - experimental_resources/app_features/object
  - experimental_resources/app_features/supported_features
  - experimental_resources/app_features/get
  - experimental_resources/app_features/list
  - experimental_resources/app_features/update
  - experimental_resources/app_manifest/header
  - experimental_resources/app_manifest/object
  - experimental_resources/app_manifest/get
  - experimental_resources/app_manifest/apply
  - experimental_resources/app_restart/header
  - experimental_resources/app_restart/create
  - experimental_resources/app_ssh_enabled/header
  - experimental_resources/app_ssh_enabled/get
  - experimental_resources/buildpacks/header
  - experimental_resources/buildpacks/object
  - experimental_resources/buildpacks/create  
  - experimental_resources/buildpacks/get
  - experimental_resources/buildpacks/list
  - experimental_resources/buildpacks/update
  - experimental_resources/buildpacks/delete
  - experimental_resources/buildpacks/upload_bits
  - experimental_resources/deployments/header
  - experimental_resources/deployments/object
  - experimental_resources/deployments/create
  - experimental_resources/deployments/get
  - experimental_resources/deployments/list
  - experimental_resources/deployments/update
  - experimental_resources/deployments/cancel
  - experimental_resources/domains/header
  - experimental_resources/domains/object
  - experimental_resources/domains/create
  - experimental_resources/domains/list
  - experimental_resources/resource_matches/header
  - experimental_resources/resource_matches/object
  - experimental_resources/resource_matches/create
  - experimental_resources/revisions/header
  - experimental_resources/revisions/object
  - experimental_resources/revisions/get
  - experimental_resources/revisions/list
  - experimental_resources/revisions/deployed_list
  - experimental_resources/revisions/update
  - experimental_resources/route_mappings/header
  - experimental_resources/route_mappings/object
  - experimental_resources/route_mappings/create
  - experimental_resources/route_mappings/get
  - experimental_resources/route_mappings/list
  - experimental_resources/route_mappings/list_for_app
  - experimental_resources/route_mappings/update
  - experimental_resources/route_mappings/delete
  - experimental_resources/service_bindings/header
  - experimental_resources/service_bindings/object
  - experimental_resources/service_bindings/create
  - experimental_resources/service_bindings/get
  - experimental_resources/service_bindings/list
  - experimental_resources/service_bindings/delete
  - experimental_resources/sidecars/header
  - experimental_resources/sidecars/object
  - experimental_resources/sidecars/get
  - experimental_resources/space_manifest/header
  - experimental_resources/space_manifest/object
  - experimental_resources/space_manifest/apply

search: true
---
