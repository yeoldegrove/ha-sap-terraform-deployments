# Automated SAP/HA Deployments in Public and Private Clouds with Terraform

[![Build Status](https://github.com/SUSE/ha-sap-terraform-deployments/workflows/CI%20tests/badge.svg)](https://github.com/SUSE/ha-sap-terraform-deployments/actions)

**Supported terraform version  `1.1.X`**

* [About](#about)
* [Components and Feature Overview](#components-and-feature-overview)
* [Project Structure](#project-structure)
* [Getting started](#getting-started)
   * [Templates](#templates)
   * [Links](#links)
* [Troubleshooting](#troubleshooting)

___

# About

This Project provides a high configurable way to deploy **SAP HANA**
database and **SAP S/4HANA** or rather **SAP NetWeaver** on various
cloud platforms. Both public cloud and private cloud scenarios are
considerable. The major big cloud providers _Google Cloud Platform_
(GCP), _Microsoft Azure_, and _Amazon Web Services_ (AWS) are
supported.  Furthermore _OpenStack_ and _libvirt/KVM_ can be used.


# Components and Feature Overview

![SAP architecture building blocks](doc/sap-architecture-building-blocks.png)

The diagram above shows components for an example setup. Several
features can be enabled or disabled through configuration options to
control the behavior of the HA Cluster, the SAP HANA and SAP S/4HANA
or SAP NetWeaver.

Some configurable major features are:

 - _SAP HANA environment_: The SAP HANA deployment is configurable. It
   might be deployed as a single SAP HANA database, a dual
   configuration with system replication. In addition a HA cluster can
   be set in top of that. Also see [Preparing SAP software](doc/sap_software.md)

 - _ISCSI server_: provides a network based storage mostly used by
   _sbd fencing_ mechanism.  Also see [Fencing mechanism](doc/fencing.md)

 - _Monitoring services server_: The monitoring solution is based in
   [prometheus🔗](https://prometheus.io) and
   [grafana🔗](https://grafana.com/) and provides informative and
   customizable dashboards to users and administrators. For
   more information see [Monitoring of cluster](doc/monitoring.md).

 - _DRBD cluster_: is used to mount a HA NFS server on top of it. It
   will be used to mount SAP NetWeaver shared files. For more
   information see [DRBD](doc/drbd.md).

 - _SAP NetWeaver_ environment: with ASCS, ERS, PAS and AAS instances
   can be deployed using SAP HANA database as storage. For more
   information see [S/4HANA and NetWeaver](doc/netweaver.md).

For more on various topics have a look on the following documentation:

   - [SUSE saptune](doc/saptune.md)
   - [IP addresses auto generation](doc/ip_autogeneration.md)


# Project Structure

This project heavily uses [terraform🔗](https://www.terraform.io/) and
[salt🔗](https://www.saltstack.com/) for configuration and deployment.

**Terraform** is used to create the required infrastructure in the
specified provider. The code is divided in different terraform modules
to make the code modular and more maintainable.

**Salt** configures all the by terraform created machines based in the
provided pillar files that give the option to customize the deployment.

![SUSE/SAP HA automation project](doc/suse-sap-ha-automation-project.png)

This repository is intended to be configured and run from a local
computer. Terraform will then build up the infrastructure and
machines. The SAP software media will be installed from a storage and
configured after.

This project is organized in subfolders per public or private cloud
provider containing the terraform modules and salt configuration files

```
./ha-sap-terraform-deployments
├── aws
│    └── modules
├── azure
│    └── modules
├── gcp
│    └── modules
├── libvirt
│    └── modules
├── openstack
│    └── modules
…
```

Each provider folder has it own provider relevant documentation,
modules and example configuration.


# Getting started 

First make sure to have terraform and salt installed. Clone this
repository and follow the quickstart guides of the favored provider.
They can be found in `./<provider/README.md>` or linked below:

  - [Microsoft Azure](azure/README.md#quickstart)
  - [Google Cloud Platform (GCP)](gcpazure/README.md#quickstart)
  - [Amamazon Web Services (AWS)](aws/README.md#quickstart)
  - [OpenStack](openstackaws/README.md#quickstart)
  - [libvirt/KVM](libvirtaws/README.md#quickstart)

Each provider folder contains a minimal working configuration example
`terraform.tfvars.example`.


## Templates

For setting up the terraform variables in order to get started with the project.
For fine tuning refer to variable specification, see [templates](doc/deployment-templates.md).

**Please be careful which instance type you will use! Because default
selection value chooses systems certified by SAP.  This could lead to
expensive costs if you leave the value untouched.**


## Links

Find certified systems for each provider at 

 - [SAP Certified IaaS Platforms for AWS🔗](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/iaas.html#categories=Amazon%20Web%20Services)

 - [SAP Certified IaaS Platforms for GCP🔗](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/iaas.html#categories=Google%20Cloud%20Platform)

 - [SAP Certified IaaS Platforms for Azure🔗](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/iaas.html#categories=Microsoft%20Azure) (Be carreful with Azure, **clustering** means scale-out scenario)


# Troubleshooting

In case you have some issue, take a look at this [troubleshooting guide](doc/troubleshooting.md).

