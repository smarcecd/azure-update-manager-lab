# Azure Update Manager Lab — Terraform + PowerShell + Azure Policy

**Active Directory · Terraform · PowerShell**

![Terraform](https://img.shields.io/badge/Terraform-v1.5+-7B42BC?logo=terraform&logoColor=white)
![AzureRM](https://img.shields.io/badge/AzureRM_Provider-3.x-0078D4?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-Scripts-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows_Server-Lab_Environment-0078D4?logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Lab_Status-Completed-brightgreen)


A complete, production‑style Azure Update Manager lab built with modular Terraform, Azure Policy, and PowerShell 7. This lab deploys three Windows Server 2022 VMs, auto‑enrolls them into Update Manager, configures a weekly maintenance window, triggers on‑demand patch assessments, and exports a compliance report.

---

## 🔗 Lab Overview

This lab deploys a full patch‑management environment into Azure using:

- **Terraform (modular)** — networking, Key Vault, compute, and Update Manager modules

- **Azure Update Manager** — assessment + patch orchestration

- **Azure Policy** — automatic VM enrollment

- **Maintenance Configuration** — weekly patch window

- **PowerShell 7** — compliance validation + JSON export

The lab is **fully standalone** and deploys into its own resource group: rg-aumlab



---

## 🎯 Purpose of This Lab

This lab teaches how real cloud operations teams manage patching at scale:

- Automatically enroll VMs into Update Manager using Azure Policy

- Configure a controlled maintenance window for patching

- Trigger on‑demand assessments when a new CVE is released

- Validate compliance using PowerShell

- Export machine‑readable JSON reports for SIEM or dashboards

- Destroy the environment cleanly to avoid unnecessary Azure costs

It mirrors real enterprise workflows for patch governance, audit readiness, and operational consistency.


---

## 📘 Prerequisites

Install the Azure Update Manager cmdlets:

```powershell
Install-Module Az -Force
Install-Module Az.Maintenance -Force
Install-Module Az.Compute -Force
```

Ensure the following are ready:

[ ] Azure CLI installed and authenticated (az login)

[ ] Terraform v1.5+

[ ] PowerShell 7+ (required for Update Manager cmdlets)

[ ] Active Azure subscription

[ ] Git for Windows

[ ] A local directory for Terraform files


Terraform installation guide:
🔗 https://github.com/smarcecd/Terraform-Automation---Azure-Active-Directory-Domain-Controller/blob/main/Terraform%20Install%20and%20Azure%20connection.md

---

## 📂 Project Structure


This lab uses a modular Terraform layout, where networking, compute, Key Vault, and Update Manager are organized into separate modules. The root directory holds the main Terraform configuration, while all reusable components live under modules/. Automation and validation scripts are stored in scripts/. This structure keeps the project organized, scalable, and easy to maintain.

```powershell
azure-update-manager-lab/
├── backend.tf                         ← Remote state configuration (Azure Storage)
├── versions.tf                        ← Provider version requirements (azurerm + random)
├── variables.tf                       ← All input variables for the lab
├── main.tf                            ← Root module wiring all 4 child modules
├── outputs.tf                         ← VM public IPs and Key Vault name
├── terraform.tfvars.example           ← Safe template for variables (commit this)
├── terraform.tfvars                   ← Your real values (never commit this)
├── .gitignore                         ← Ignore state files, secrets, and reports
│
├── modules/
│   ├── networking/
│   │   └── main.tf                    ← VNet, subnet, NSG, subnet–NSG association
│   │
│   ├── keyvault/
│   │   └── main.tf                    ← Key Vault (RBAC model) + admin password secret
│   │
│   ├── compute/
│   │   └── main.tf                    ← 3 VMs, domain promotion, domain join extensions
│   │
│   └── update-manager/
│       └── main.tf                    ← Azure Policy + Maintenance Config + 3 VM assignments
│
└── scripts/
    └── validate-lab.ps1               ← Compliance validation + JSON report export
```

---


## 🚀 Deployment Guide

### 📥 Step 1 — Clone This Repository to Your Project Folder

```powershell
git clone https://github.com/smarcecd/azure-update-manager-lab.git

```

This folder contains:
 - Root Terraform files
 - Four Terraform modules
 - PowerShell validation script

This will create a folder named: **azure-update-manager-lab** . Then navigate into it:

```powershell
cd azure-update-manager-lab
```
You now have the full project locally and can begin exploring or deploying the Terraform lab.


---

## ☁️ Step 2 — Create Root Terraform State Storage

On Powersherll or Visual Studio Code, create the storage account.
Please remember the storage account name must be unique, then change the name "aumlabYOURNAME" to your unique name.

```powershell
az login
```

```powershell
az group create --name RG-TerraformState --location "East US"
```

```powershell
az storage account create --name aumlabYOURNAME --resource-group RG-TerraformState --sku Standard_LRS --encryption-services blob
```

```powershell
az storage container create --name tfstate --account-name aumlabYOURNAME
```


---

## ⚙️ Step 3 — Configure Variables

 🔹Set the Public IP on **terraform.tfvars.example**:

Retrieve your public IP address from **whatismyip.com** and update the rdp_source value in **terraform.tfvars** using the CIDR format (e.g., 1.2.3.4/32).
Make sure the description for rdp_source in **variables.tf** reflects the same format, and update **terraform.tfvars.example** as well so future runs or references stay consistent.

 🔹Update **backend.tf** and replace REPLACE_WITH_YOUR_STORAGE_ACCOUNT_NAME with your actual storage account name set up on step 2.

 🔹Edit modules/update-manager/main.tf:
It is set up for **"2026-08-15 02:00"**, if you are doing this lab after that date, please update it. 
Update the **start_date_time** to any future date. If this date is in the past, terraform plan fails

 🔹Copy example variables:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

 🔹Set admin password securely:

```powershell
$env:TF_VAR_admin_password = "YourStrongPassword!"
```

---

## 🏗️ Step 4 — Deploy Infrastructure

On Powersherll or Visual Studio Code, on the \azure-update-manager-lab path, type:

```powershell
az login
```

```powershell
terraform init
```

```powershell
terraform plan
```

```powershell
terraform apply
```

Deployment takes ~15–20 minutes.

---

## 🛠️ Step 6 — Trigger Patch Assessment & Validate Compliance

Azure Policy performs assessments automatically, but manual assessment gives immediate compliance data.

 🔹 Trigger an on‑demand assessment

```powershell
$subId = az account show --query id -o tsv

# Manually trigger a patch assessment on each VM.
# This is the same operation performed when selecting "Assess Now" in the Azure portal.
foreach ($vm in @("DC01","WS01","WS02")) {
    az rest --method POST `
        --url "https://management.azure.com/subscriptions/$subId/resourceGroups/rg-aumlab/providers/Microsoft.Compute/virtualMachines/$vm/assessPatches?api-version=2022-03-01"
    Write-Host "Assessment triggered: $vm"
}
```

Assessment takes 5–10 minutes per VM.


 🔹 Validate assessment results

```powershell
pwsh ./scripts/validate-lab.ps1 -ResourceGroup "rg-aumlab" -SubscriptionId $subId
```

 🔹 Expected behavior

If the script shows:

```powershell
FAIL — Critical missing > 0
```

This is **normal** for new VMs.
Apply patches via the maintenance window, then re‑run validation.


---

## 🔍 Azure Portal Verification Checklist

 🔹 Azure Update Manager → Machines  

1. Search for “Azure Update Manager” and open it.

2. In the Update Manager navigation pane, select Machines

3. You will see a list of all VMs onboarded to Update Manager

4. Each VM will show a status such as:
  - Assessed
  - Not Assessed
  - Needs attention
  - Compliant / Non‑compliant

Your three VMs (DC01, WS01, WS02) should appear here once assessments have run.


 🔹 Maintenance Configurations → aum-weekly-patches  

1. Go to Resource groups and open **rg‑aumlab**

2. In the list of resources, click:
    - aum-ws-inguest-patching  
    - or your host config: aum-dc-host-patching

3.Inside the Maintenance Configuration blade, select: **Assignments**  

4. You will see a table listing all VMs linked to that maintenance configuration.


 🔹 Azure Policy → Assignments → The periodic assessment policy shows Applied on rg-aumlab

1. Search for “Policy”

2. In the Policy blade, select Assignments

3. Click Policy (Microsoft Azure Policy service)

4. Find:  “[Preview] Configure periodic patch assessment for machines”

5. In the assignment details, check:
     Scope: /subscriptions/<subId>/resourceGroups/rg-aumlab
     Compliance state: Applied or Non-compliant
     Last evaluation: timestamp
     Resources evaluated: count of VMs in the RG

This is the exact place Microsoft expects you to verify that your periodic assessment policy is active and targeting your lab resource group.




---

## 🧹 Step 7 — Teardown

Destroy the lab to avoid charges:


```powershell
terraform destroy -auto-approve
```

After the destroy completes, verify the resource group is gone:
```powershell
az group show --name rg-aumlab 2>&1
# Expected output: ResourceGroupNotFound

```

