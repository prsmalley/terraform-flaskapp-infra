# terraform-flaskapp-infra

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Status:** EC2 currently provisioned and serving as the k3s host for the flaskapp deployment (last `terraform apply` 2026-05-20). Inbound is restricted to operator IP via the security group.

This repo owns the AWS infrastructure: a single EC2 instance, SSH key pair, and security group. It's one of three repos that together build, provision, and deploy a Flask app to a k3s cluster on AWS EC2:

- **[flaskapp-docker-practice](https://github.com/prsmalley/flaskapp-docker-practice)** — builds and publishes the container image to GHCR.
- **terraform-flaskapp-infra** — provisions the EC2 host.
- **[ansible-playground](https://github.com/prsmalley/ansible-playground)** — bootstraps k3s and deploys the app via ephemeral self-hosted runners (ARC) running inside the cluster.

See [ARCHITECTURE.md](https://github.com/prsmalley/ansible-playground/blob/main/ARCHITECTURE.md) for the full design.

```mermaid
flowchart LR
    A[flaskapp-docker-practice] -->|CI + release| GHCR[(GHCR)]
    B[terraform-flaskapp-infra] -.provisions.-> EC2
    C[ansible-playground] -.bootstraps.-> k3s
    C --> Runner
    subgraph EC2[AWS EC2]
        subgraph k3s[k3s cluster]
            Runner[ARC runner pod] -->|kubectl apply| APP[flaskapp pods]
        end
    end
    GHCR -.image pull.-> APP
```

## Repo layout

```
.
├── main.tf                    # Provider, AMI lookup, key pair, security group, EC2 instance
├── variables.tf               # Input variables (region, instance type, SSH key, IP)
├── outputs.tf                 # Public IP, DNS, instance ID, SSH command
├── terraform.tfvars.example   # Copy to terraform.tfvars and fill in
├── .terraform.lock.hcl        # Pinned provider versions (committed)
└── .gitignore                 # Excludes *.tfstate, *.tfvars, .terraform/
```

## What it builds

- A `t3.small` Ubuntu 22.04 EC2 instance (enough RAM for k3s + ARC).
- An SSH key pair from your local public key.
- A security group with three inbound rules, all restricted to your IP:
  - `22/tcp` — SSH
  - `80/tcp` — HTTP (for the deployed app)
  - `6443/tcp` — Kubernetes API (for remote `kubectl`)
- No `user_data` — Ansible handles the host bootstrap (see ansible-playground).
- Outputs the public IP, public DNS, instance ID, and a ready-to-paste SSH command.

## Prerequisites

- AWS account with an IAM user that has EC2 + IAM write permissions.
- AWS CLI configured (`aws configure`) on your machine.
- Terraform 1.5+ (`brew install terraform`).
- A local SSH public key (e.g. `~/.ssh/id_ed25519.pub`).

## Run it

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set ssh_public_key_path and my_ip
# Find your IP with: curl -s https://api.ipify.org

terraform init    # downloads the AWS provider
terraform plan    # dry run — preview the changes
terraform apply   # type "yes" to confirm
```

Outputs include the public IP and an SSH command:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform output -raw public_ip)
```

When done, save costs:

```bash
terraform destroy
```

## After `terraform apply`: bootstrap the host

The instance comes up as bare Ubuntu. Run Ansible from
[ansible-playground](https://github.com/prsmalley/ansible-playground) to
install k3s:

```bash
# In ansible-playground/, with the EC2 IP added to inventory.ini under [appservers]
ansible-playbook bootstrap-k3s.yml
```

After bootstrap, ARC + workflow setup happens via `helm install` on the
cluster. See ansible-playground's ARCHITECTURE.md for the full flow.

## Notes on production gaps

This is a learning-grade setup. Real production would add:

- **Remote state** in S3 with DynamoDB locking. Local `terraform.tfstate`
  doesn't survive lost laptops and breaks team workflows.
- **Custom VPC** with private subnets for app servers and an ALB in a
  public subnet. The default VPC keeps everything in public subnets.
- **IAM Role attached to the instance** instead of using static AWS
  credentials. The instance assumes the role via the metadata service.
- **ALB + ACM cert + Route 53** for HTTPS on a real domain. The app is
  currently reachable as `http://<EC2-IP>` only.
- **Auto Scaling Group + multi-AZ** for high availability.
- **Bastion + Session Manager** instead of inbound SSH. No public port 22
  exposure; ops access via AWS-authenticated channels.
- **Packer-baked AMI** with k3s pre-installed, eliminating the manual
  Ansible bootstrap step.
- **CI for the Terraform code itself** — `terraform fmt -check`,
  `terraform validate`, `tflint`, and `tfsec` on every PR. Currently
  checked locally only.

## License

MIT — see [LICENSE](LICENSE).
