# Bicep template change summary

## Comparison basis

This document compares:

- **Previous template:** [`main-v1.bicep`](../agentic-iac-lab-files/lab-files/templates/main-v1.bicep)
- **Current template:** [`main.bicep`](../agentic-iac-lab-files/lab-files/templates/main.bicep)

The templates represent substantially different architectures rather than a small in-place revision. The previous template deploys a hub-and-spoke network with Azure Firewall. The current template deploys a simpler virtual network and an Ubuntu virtual machine through separate modules.

## Change summary

| What changed | Why it likely changed | Potential impact on existing deployments |
|---|---|---|
| **Deployment scope changed from resource group to subscription.** The current template declares `targetScope = 'subscription'` and creates its own resource group. | To make the deployment self-contained and allow it to create the resource group before deploying resources into it. | Existing automation must deploy at subscription scope and supply permission to create resource groups. Commands, service connections, and policy checks designed for resource-group deployments may need updating. |
| **The architecture changed from hub-and-spoke to a single virtual network.** The previous hub VNet, spoke VNet, and bidirectional peerings are replaced by one VNet. | Likely to simplify the environment for a smaller application or training scenario. | Existing hub/spoke routing and network segmentation are not reproduced. In a standard incremental deployment, previously deployed hub-and-spoke resources are not automatically deleted; the new resources may exist alongside them. |
| **Azure Firewall and its public IP were removed.** | Likely to reduce cost and complexity for a basic workload. This is not an added-security change. | Central traffic inspection, filtering, and the firewall's stable public IP are lost in the new design. Applications relying on firewall routing or allowlists may stop working if migrated to the new network. Old firewall resources can continue generating charges if left deployed. |
| **The application network security group was removed.** The previous template explicitly denied internet-originated SSH and RDP traffic. | The new VM has no public IP and uses key-based authentication, which reduces direct exposure, but the template also appears intentionally minimal. | The explicit deny rules no longer exist. The VM cannot be reached directly from the internet as deployed, but future connectivity changes could expose it unless network security controls are added. |
| **An Ubuntu virtual machine was added.** The current template deploys Ubuntu 22.04 LTS on a `Standard_B2s` VM with a Standard locally redundant OS disk. | To add an actual compute workload instead of deploying network infrastructure only. | Introduces compute and disk charges, operating-system maintenance, patching, backup, and availability responsibilities. Deployment now requires a valid SSH public key. |
| **VM authentication is key-based only.** Password authentication is disabled. | To improve administrator access security and avoid password-based sign-in. | Existing password-based access procedures will not work. Operators must securely manage the matching SSH private key and provide a network path to the private VM. |
| **Subnet design and address ranges changed.** The previous `10.0.0.0/16` hub and `10.1.0.0/16` spoke become one `10.10.0.0/16` VNet with `10.10.1.0/24` application and `10.10.2.0/24` data subnets. | To provide a straightforward application/data layout and avoid the previous firewall subnet sizing issue. | Existing IP-based rules, routes, DNS configuration, peerings, and allowlists will require changes. The data subnet is currently empty. The old `/27` Azure Firewall subnet deployment blocker disappears because Azure Firewall itself is no longer deployed. |
| **A private network interface was added for the VM.** It receives a dynamically allocated private IP in the application subnet. | Required to connect the new VM to the virtual network without exposing it directly through a public IP. | The private IP can change when the interface is reconfigured. Systems should not assume a fixed address unless allocation is changed to static or private DNS is introduced. |
| **Parameters were completely redesigned.** `environment` and `owner` are replaced by explicit resource names, address ranges, VM image settings, VM size, administrator name, SSH key, and a general tags object. | To make the simpler environment and VM independently configurable. | Existing parameter files and pipeline arguments are incompatible and must be rewritten. The former environment allowlist (`training`, `staging`, `production`) no longer governs naming. |
| **Resource naming changed.** Environment-derived names such as `vnet-hub-training` are replaced by direct defaults such as `vnet-agentic-iaclab` and `vm-iaclab`. | To make names easier to override and remove dependence on a fixed environment parameter. | Monitoring, policy assignments, scripts, dashboards, or support procedures that locate resources by the old names must be updated. Default names may collide if multiple copies are deployed into the same resource group. |
| **Tag handling was centralized.** The current template passes one tags object to all tag-capable resources. | To improve consistency and make tags customizable from one parameter. | Tag coverage is more consistent, but the default values are fixed to `Environment: Training` and `Owner: agentic-iaclab`. Existing reporting that expects lowercase environment values or a supplied owner alias may need adjustment. |
| **Network and compute API versions were updated.** Network resources move from `2022-07-01` to `2024-05-01`; the VM uses `2024-07-01`, and the resource group uses `2024-03-01`. | To use newer Azure resource schemas and supported platform behavior. | Usually low impact, but validation behavior and defaults can differ. Deployment pipelines should compile and validate the template with a current Bicep CLI. |
| **The template was split into modules.** Networking and virtual-machine definitions now live in separate Bicep files. | To improve maintainability, reuse, and separation of responsibilities. | Deployment tooling must include the `modules` directory. Publishing or copying only `main.bicep` will cause compilation or deployment failure. |
| **Outputs changed.** Hub/spoke IDs and firewall addresses are replaced by resource-group, VNet, network-interface, VM, and VM provisioning-state outputs. | To expose identifiers and status relevant to the new architecture. | Pipelines or scripts consuming the old firewall and peering-related outputs will break and must be updated to use the new output names. |

## Migration and deployment considerations

1. **Treat this as a replacement architecture, not an in-place upgrade.** Resource names, scope, parameters, resources, and outputs are materially different.
2. **Rewrite deployment commands and parameter files.** The current template requires subscription-scope deployment and a secure `sshPublicKey` value.
3. **Plan connectivity before migration.** The VM has no public IP, Bastion host, VPN gateway, or other administrative access path in this template.
4. **Review deletion separately.** Azure deployments normally use incremental behavior, so removing a resource declaration does not necessarily delete the old firewall, public IP, peerings, or VNets. Confirm the deployment mode and remove obsolete resources deliberately.
5. **Update dependent systems.** Revise pipelines, output consumers, IP allowlists, resource-name lookups, monitoring, and operational documentation.
6. **Validate governance requirements.** The default tags still do not include `CostCenter`; deployment may fail if organizational policy requires it.

## Features still absent

The header comments in `main-v1.bicep` describe Azure Bastion, Log Analytics, firewall diagnostics, a user-assigned managed identity, and a required `CostCenter` parameter as expected improvements in a later version. None of those features is present in the supplied `main.bicep`. Observability has therefore not been added, and the stated `CostCenter` policy issue remains unresolved.
