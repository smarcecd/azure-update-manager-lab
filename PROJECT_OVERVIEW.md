
## 🌐 Azure Update Manager Lab — Project Overview

Active Directory · Terraform · PowerShell · Azure Policy

https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white  
https://img.shields.io/badge/AzureRM_Provider-3.x-0078D4?logo=microsoftazure&logoColor=white  
https://img.shields.io/badge/PowerShell-7+-5391FE?logo=powershell&logoColor=white  
https://img.shields.io/badge/Windows_Server-2022-0078D4?logo=windows&logoColor=white  
https://img.shields.io/badge/Lab_Status-Completed-brightgreen

A production‑grade Azure Update Manager lab built with modular Terraform, Azure Policy, and PowerShell 7.
This environment deploys three Windows Server 2022 VMs, automatically enrolls them into Azure Update Manager, configures a weekly maintenance window, triggers on‑demand patch assessments, and exports a structured compliance report.

---

## 1. Project Purpose

This lab demonstrates how cloud operations teams manage patching at scale using Azure-native tools.
It provides a complete workflow for:

 🔹 Automated VM enrollment via Azure Policy

 🔹 Scheduled patching through Maintenance Configurations

 🔹 On-demand assessments for rapid CVE response

 🔹 Compliance validation using PowerShell

 🔹 JSON reporting for SIEM, dashboards, or audit workflows

 🔹 The project mirrors real enterprise practices for patch governance, security compliance, and operational consistency.

---

## 2. Learning Objectives

 🔹 By completing this lab, you will learn how to:

 🔹 Build modular Terraform infrastructure

 🔹 Configure Azure Update Manager for assessment and patching

 🔹 Use Azure Policy for automatic VM enrollment

 🔹 Implement maintenance windows with controlled reboot behavior

 🔹 Trigger manual patch assessments

 🔹 Validate compliance and export structured reports

 🔹 Tear down cloud environments safely and cleanly

---

## 3. Prerequisites

- Required PowerShell Modules

```powershell
Install-Module Az -Force
Install-Module Az.Maintenance -Force
Install-Module Az.Compute -Force
```

- Required Tools
Azure CLI (authenticated with az login)

- Terraform v1.5+

- PowerShell 7+

- Git for Windows

- Active Azure subscription

Terraform installation guide:
🔗 https://github.com/smarcecd/Terraform-Automation---Azure-Active-Directory-Domain-Controller/blob/main/Terraform%20Install%20and%20Azure%20connection.md

---

## 4. Architecture at a Glance

The lab deploys:
- 3 Windows Server 2022 VMs
- DC01 (Domain Controller)
- WS01 & WS02 (Member Servers)

Networking  
VNet, subnet, NSG, and subnet–NSG association

Key Vault  
RBAC-enabled vault storing the admin password

Azure Update Manager

Periodic assessment via Azure Policy

Weekly maintenance window

VM assignments for patching

PowerShell Validation  
Compliance reporting + JSON export

All resources are deployed into: **rg-aumlab**

---

## 5. Personas & What They Demonstrate

**Cloud Engineer**
- Builds modular Terraform infrastructure
- Manages remote state
- Deploys compute, networking, and Key Vault

**Security Engineer**
- Uses Azure Policy for compliance enforcement
- Validates patch posture
- Responds to CVEs with on-demand assessments

**Operations Engineer**
- Manages maintenance windows
- Oversees patching and reboot behavior
- Generates compliance reports for audit teams

---

## 6. Repository Structure

```powershell
azure-update-manager-lab/
├── backend.tf                         ← Remote state configuration
├── versions.tf                        ← Provider version requirements
├── variables.tf                       ← Input variables
├── main.tf                            ← Root module wiring all child modules
├── outputs.tf                         ← VM public IPs and Key Vault name
├── terraform.tfvars.example           ← Safe template (commit this)
├── terraform.tfvars                   ← Real values (never commit)
├── .gitignore                         ← Ignore state files, secrets, reports
│
├── modules/
│   ├── networking/                    ← VNet, subnet, NSG
│   ├── keyvault/                      ← Key Vault + admin password secret
│   ├── compute/                       ← 3 VMs + domain promotion/join
│   └── update-manager/                ← Policy + Maintenance Config + Assignments
│
└── scripts/
    └── validate-lab.ps1               ← Compliance validation + JSON export
```

---

## 7. Quick Start

- Clone the repository

```powershell
git clone https://github.com/smarcecd/azure-update-manager-lab.git
cd azure-update-manager-lab
```

- Create Terraform remote state storage

- Configure variables

- Deploy infrastructure

- Trigger patch assessment

- Validate compliance

---

## 8. Terraform Usage

```powershell
terraform init
terraform plan
terraform apply
```

Terraform deploys:
- Networking
- Key Vault
- Compute (DC01, WS01, WS02)
- Update Manager configuration
- Azure Policy assignment
- Maintenance window + VM assignments
- Deployment time: 15–20 minutes

---

## 9. Validation & Testing

= Trigger on-demand assessment
```powershell
foreach ($vm in @("DC01","WS01","WS02")) {
    az rest --method POST `
        --url "https://management.azure.com/subscriptions/$subId/resourceGroups/rg-aumlab/providers/Microsoft.Compute/virtualMachines/$vm/assessPatches?api-version=2022-03-01"
}
```

- Validate compliance
```powershell
pwsh ./scripts/validate-lab.ps1 -ResourceGroup "rg-aumlab" -SubscriptionId $subId
```

- Portal checks
Update Manager → Machines

Maintenance Configurations → Assignments

Azure Policy → Assignments

---

## 10. Key Concepts Reinforced

- Modular Terraform design
- Azure Policy-driven automation
- Separation of assessment vs patching
- Controlled maintenance windows
- JSON-based compliance reporting
- Infrastructure teardown discipline

---

## 11. Clean Up

Destroy the lab to avoid charges:

```powershell
terraform destroy -auto-approve
```

Verify deletion:
```powershell
az group show --name rg-aumlab 2>&1
# Expected: ResourceGroupNotFound
```
---

## 12. Contributing

Contributions are welcome!
Submit issues or pull requests to improve documentation, modules, or automation scripts.

---

## 13. References

- Azure Update Manager Documentation
- Azure Policy Documentation
- Terraform Registry — AzureRM Provider

PowerShell Az Modules

Microsoft Learn — Windows Server Administration
