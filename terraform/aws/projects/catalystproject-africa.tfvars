region = "af-south-1"

cluster_name = "catalystproject-africa"

cluster_nodes_location = "af-south-1a"

user_buckets = {
  "scratch-staging" : {
    "delete_after" : 7
  },
  "scratch" : {
    "delete_after" : 7
  },
}


hub_cloud_permissions = {
  "staging" : {
    bucket_admin_access : ["scratch-staging"],
    extra_iam_policy : ""
  },
  "prod" : {
    bucket_admin_access : ["scratch"],
    extra_iam_policy : ""
  },
}