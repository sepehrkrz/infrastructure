(howto:cost-attribution:enable-aws)=
# Enable AWS cost attribution system

```{important}
Until the [epic to roll out a cost attribution system in all AWS
clusters](https://github.com/2i2c-org/infrastructure/issues/4872) is finalized,
this documentation is subject to active change.
```

The AWS cost attribution system, referenced as the system in this document,
consists of the `aws-ce-grafana-backend` Helm chart and a Grafana dashboard
using the backend as a data source.

## Practical steps

### 1. Tag cloud infra

The system relies on _at least one of these tags_ to be on any cloud infra to
attribute cost to.

- `2i2c.org/cluster-name`
- `alpha.eksctl.io/cluster-name`
- `kubernetes.io/cluster/<cluster name>`

The system also relies on the tag `2i2c:hub-name` to be specified in addition to
the tags above for any cloud infra tied to specific hubs.

We only need to ensure the `2i2c.org/cluster-name` and `2i2c:hub-name` tags are
declared, the others are applied by `eksctl` and Kubernetes controllers that can
create cloud resources to represent k8s resources (block storage volumes for k8s
PV resources referencing certain storage classes, and load balancers for k8s
Service's of type LoadBalancer).

1. _Configure `2i2c.org/cluster-name` tags_

   No configuration is needed.

   ```{note}
   Terraform managed resources already have the tag configured via the
   `default_tags` variable, and eksctl managed resources already have the tag
   configured for node groups via `nodegroup.libsonnet`.

   New clusters have _all_ eksctl managed resources configured to be tagged, not
   just the node groups. This isn't important to ensure for existing clusters'
   cost attribution though.
   ```

2. _Configure `2i2c:hub-name` tags_

   For any resource _specific to a hub_, declare an additional tag
   `2i2c:hub-name=<hub name>`. If this isn't done, they will be listed under a
   `shared` instead.

   The following resources are known to be hub specific in some cases and known
   to incur costs.

   - S3 buckets in terraform
   - EFS storage in terraform
   - EBS volumes in terraform
   - Node groups in eksctl

   Search and mimic configuration of other clusters to understand how to
   configure the `2i2c:hub-name` tags for specific cloud infra types.

3. _Apply changes_

   1. If you changed anything in terraform, apply those changes.
   2. If you changed anything in eksctl, apply those changed by re-creating
      those resources.
   3. If the eksctl cluster is listed and unchecked in this [github reference
      issue], and versioned older than k8s 1.29 or older, it needs to have its
      node groups re-created to get the implicitly configured
      `2i2c.org/cluster-name` tag unless you've not already just done this to
      apply a `2i2c:hub-name` tag.

      Reference our [documentation on doing node group
      upgrades](upgrade-cluster:aws:node-groups) for details.
   4. Update the [github reference issue] and ensure the checkbox is ticked for
      this cluster.

   [github reference issue]: https://github.com/2i2c-org/infrastructure/issues/4885

### 2. Enable cost allocation tags

Use terraform to enable relevant tags to function as a cost allocation tag as
well.

Configure the following terraform variable like below and apply the changes.

```
active_cost_allocation_tags = [
  "2i2c:hub-name",
  "2i2c.org/cluster-name",
  "alpha.eksctl.io/cluster-name",
  "kubernetes.io/cluster/{var_cluster_name}",
  "kubernetes.io/created-for/pvc/namespace",
]
```

Doing this will fail if the AWS billing system hasn't detected the tags recently
enough, then you'll see a error message about the tags not being found. If this
happens, wait a few hours and try again.

```{note}
The `kubernetes.io/created-for/pvc/namespace` is enabled even if its currently
not used by `aws-ce-grafana-backend`, as it could help us attribute cost for
storage disks dynamically provisioned in case that's relevant in the future.
```

### 3. (optional) Backfill billing data

You can optionally backfill billing data to tags having been around for a while
but not enabled as cost allocation tags.

You can do request this to be done once a day, and it takes a several hours to
process the request. Make a request through the AWS web console by navigating to
"Cost allocation tags" under "Billing and Cost Management", then from there
click the "Backfill tags" button.

### 4. Install `aws-ce-grafana-backend`

In the cluster's terraform variables, declare and apply the following:

```
enable_aws_ce_grafana_backend_iam = true
```

Look at the terraform output named `aws_ce_grafana_backend_k8s_sa_annotation`:

```
terraform output -raw aws_ce_grafana_backend_k8s_sa_annotation
```

Open the cluster's support.values.yaml file and update add a section like below,
updating `clusterName` and add the annotation (key and value) from the terraform
output.

```yaml
aws-ce-grafana-backend:
  enabled: true
  envBasedConfig:
    clusterName: <declare cluster name to the value of cluster_name in the cluster's .tfvars file>
  serviceAccount:
    annotations:
      <declare annotation key and value here>
```

Finally deploy the support chart:

```bash
deployer deploy-support $CLUSTER_NAME
```

### 5. Deploy a Grafana dashboard

```{important}
We doesn't yet have no automation for this, and the dashboard definition will be
duplicated every time we deploy because its not centralized. With that in mind,
please treat the Grafana dashboard in https://grafana.openscapes.2i2c.cloud as
the source of truth for now, and act as changes to dashboards in other cluster
will get discarded.
```

To manually deploy the dashboard we currently have:

1. Login to https://grafana.openscapes.2i2c.cloud as the admin user
2. Visit [openscapes's dashboard settings] and save the JSON blob to a text
   editor
3. Login to Grafana instance of the cluster you're working with now as the admin
   user
4. Navigate to the `plugins/yesoreyeram-infinity-datasource` path (Plugins -> Search for infinity)
5. First press the "Install" button, and then press the "Add new datasource"
   button
6. You'll arrive at a page with a path like
   `connections/datasources/edit/ddyyd0z19aznke`, where the last part is an ID
   of the datasource you just added. Copy that id, which in this example is
   `ddyyd0z19aznke`.
7. In the text editor with the JSON blob from openscapes dashboard definition,
   find all references to the old infinity datasource ID listed under `uid`, and
   replace all those with the ID you copied just before.
8. Navigate to the `/dashboard/import` path (Dashboards -> New dashboard ->
   Import dashboard)
9. Paste the JSON blob you updated in the text editor and create a new dashboard

The same dashboard definition is besides updating the datasource ID expected to
work out of the box, because there is nothing hardcoded to the openscapes
cluster within it. It simply reads data from
`aws-ce-grafana-backend.support.svc.cluster.local`, which is a k8s cluster local
address to the k8s Service `aws-ce-grafana-backend` in the `support` namespace.

[openscapes's dashboard settings]: https://grafana.openscapes.2i2c.cloud/d/edw06h7udjwg0b/cloud-cost-attribution?orgId=1&editview=dashboard_json

## Troubleshooting

If you don't see data in the cost attribution dashboard, you may want to look to
ensure the `aws-ce-grafana-backend` deployment's pod is running in the support
namespace, or if it reports errors in its logs.
