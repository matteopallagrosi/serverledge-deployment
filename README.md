# Serverledge Deployment

This repository contains the Terraform and Ansible configuration required to deploy the Serverledge infrastructure on Google Cloud Platform (GCP) and execute performance experiments involving distributed workflow execution and offloading policies.

The infrastructure consists of:
- **Edge nodes:** three nodes deployed in the Edge region.
- **Cloud nodes:** three nodes deployed in the Cloud region.
- **Global Registry:** a centralized node hosting etcd and Prometheus.
- **Load Balancer:** a node responsible for forwarding incoming requests.
- **Optimizer:** a node hosting the workflow optimization service.
- **Client:** a node running Locust for workload generation.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Building Serverledge](#building-serverledge)
- [Infrastructure Deployment](#infrastructure-deployment)
- [Workflow Registration](#workflow-registration)
- [Docker Image Preparation](#docker-image-preparation)
- [Manual Workflow Invocation](#manual-workflow-invocation)
- [Running Experiments](#running-experiments)
- [Results Analysis](#results-analysis)
- [Monitoring](#monitoring)
- [Destroying the Infrastructure](#destroying-the-infrastructure)

## Prerequisites

The deployment requires:
- A Google Cloud Platform account and an active GCP project.
- Terraform.
- Ansible.
- Git.
- Go (required to compile Serverledge).
- Python 3 and pip (required for results analysis).

The deployment scripts use Terraform to provision the infrastructure and Ansible to configure the virtual machines.

## Environment Setup

### 1. Prepare Google Cloud Shell

Open Google Cloud Shell and install Ansible:

```bash
sudo apt-get update
sudo apt-get install -y ansible
```

Install Terraform:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor \
    -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com \
$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install terraform
```

### 2. Upload the deployment repository

Upload the entire `serverledge-deployment` directory to Google Cloud Shell.

The following commands assume that the working directory is the root of this repository.

## Building Serverledge

Before deploying the infrastructure, Serverledge must be compiled locally. The resulting executables are transferred to the virtual machines by Ansible.

Clone the appropriate Serverledge branch:

```bash
git clone -b parallel-branches https://github.com/matteopallagrosi/serverledge.git
```

Compile the project:

```bash
cd serverledge
make
cd ..
```

Copy the generated executables into the directory used by Ansible:

```bash
mkdir -p ansible/serverledge-bin

cp -r ./serverledge/bin/* ansible/serverledge-bin/
```

The directory `ansible/serverledge-bin` must contain the executables required by the deployment, including:

- `serverledge`
- `serverledge-cli`
- `lb`

## Infrastructure Deployment

The infrastructure is provisioned using Terraform, while Ansible handles the configuration and startup of the different components.

From the repository root, make the deployment script executable:

```bash
chmod +x deploy.sh
```

Start the deployment:

```bash
./deploy.sh apply
```

The script automatically performs the following operations:

1. Initializes Terraform.
2. Creates the GCP infrastructure.
3. Generates the SSH private key.
4. Generates the Ansible inventory (`ansible/inventory.ini`).
5. Configures the virtual machines using Ansible.
6. Starts Serverledge nodes, the Load Balancer, etcd, Prometheus and the optimizer.

The deployment may take several minutes.

## Workflow Registration

After the infrastructure has been successfully deployed, register the functions and workflows on the first Edge node.

From the repository root:

```bash
cd ansible

ansible-playbook -i inventory.ini register_workflows.yml
```

This playbook registers the functions required by the following workflows:

- `sentiment-analysis`
- `detection`

The corresponding workflow definitions are stored in:

```text
ansible/files/sa-workflow.json
ansible/files/car-workflow.json
```

The registration process also creates the custom functions using their corresponding Docker images.

## Docker Image Preparation

Before executing experiments, it is possible to pre-pull the Docker images required by the workflows on all Edge and Cloud nodes.

From the `ansible` directory:

```bash
ansible-playbook -i inventory.ini pull_images.yml
```

This operation downloads the custom Docker images used by the Sentiment Analysis and Car Detection workflows.

Pre-pulling the images helps avoid image downloads during workflow execution.

## Manual Workflow Invocation

It is possible to manually invoke workflows through the Serverledge CLI installed on an Edge node.

First, connect to an Edge node using SSH:

```bash
ssh -i terraform/id_rsa_server ubuntu@<EDGE_PUBLIC_IP>
```

Then navigate to the Serverledge directory:

```bash
cd serverledge
```

### Sentiment Analysis

Invoke the Sentiment Analysis workflow:

```bash
./bin/serverledge-cli invoke-workflow -f sentiment-analysis \
    -p "data_url:https://matteonardelli.it/resources/amazon_review_polarity_csv2.tgz" \
    -p "subset:0.01" \
    -p "la_max_features:10" \
    -p "ha_max_features:100" > output.txt 2>&1
```

### Car Detection

Invoke the Car Detection workflow using the input parameters stored in `input.json`:

```bash
./bin/serverledge-cli invoke-workflow \
    -f detection \
    --params_file input.json
```

## Running Experiments

Experiments are executed through Ansible using Locust as the workload generator.

The `run_experiment.yml` playbook:
- Copies the Locust configuration files to the Client node.
- Removes previous experiment results from the Client.
- Starts Locust.
- Executes the workload against the first Edge node.
- Retrieves the generated results and stores them locally.

From the `ansible` directory, execute:

```bash
ansible-playbook -i inventory.ini run_experiment.yml
```

### Experiment Configuration

The default experiment parameters are defined in `ansible/run_experiment.yml`:

| Parameter | Default value |
|---|---:|
| Experiment duration | 600 seconds |
| Concurrent users | 5 |
| Spawn rate | 2 users/second |

The target endpoint is automatically configured using the public IP of the first Edge node:

```text
http://<EDGE_IP>:1323
```

The workload configuration is defined in:

```text
ansible/locust/locustfile.py
```

The default workload randomly selects between the two registered workflows:

- Sentiment Analysis: 30% probability.
- Car Detection: 70% probability.

Each Locust user generates requests with a constant throughput of one request per second.

### Experiment Results

At the end of each experiment, the results are downloaded to the local repository in a timestamped directory:

```text
results/
└── run-YYYYMMDDTHHMMSS/
    ├── locust-results_stats.csv
    ├── locust-results_stats_history.csv
    └── response_times.txt
```

The files contain:
- `locust-results_stats.csv`: aggregated Locust statistics.
- `locust-results_stats_history.csv`: time-series performance statistics.
- `response_times.txt`: individual workflow execution information, including response times, execution placement, execution nodes, warm/cold-start information and other timing measurements.

Each experiment generates a separate directory, allowing results from different configurations and offloading policies to be preserved.

## Results Analysis

The repository includes a Python script to analyze the experiment results and generate performance graphs.

### 1. Create a Python Virtual Environment

From the repository root, install the required packages:

```bash
sudo apt install python3-venv python3-pip -y
```

Create and activate a virtual environment:

```bash
python3 -m venv bench_env
source bench_env/bin/activate
```

Install the dependencies:

```bash
pip install --upgrade pip
pip install "numpy<2" pandas matplotlib numexpr bottleneck
```

### 2. Generate Graphs

From the repository root, execute:

```bash
python3 scripts/analyze.py results/run-YYYYMMDDTHHMMSS
```

Replace the directory with the identifier of the experiment you want to analyze.

The script generates the following graphs inside the experiment directory:

| File | Description |
|---|---|
| `throughput_vs_time.pdf` | Request throughput over time. |
| `goodput_vs_time.pdf` | Successful requests per second over time. |
| `failures_vs_time.pdf` | Failed requests per second over time. |
| `boxplot_response_times.pdf` | Workflow response-time distributions. |
| `edge_vs_cloud_percentage.pdf` | Percentage of tasks executed at the Edge and in the Cloud. |

Deactivate the virtual environment when finished:

```bash
deactivate
```

## Monitoring

The deployment includes Prometheus and Pushgateway on the Global Registry.

Their web interfaces are accessible through:

```text
http://<GLOBAL_REGISTRY_PUBLIC_IP>:9090
http://<GLOBAL_REGISTRY_PUBLIC_IP>:9091
```

The Ansible inventory contains the IP addresses of the deployed machines.

### Connecting to Virtual Machines

Use the SSH private key generated by Terraform:

```bash
ssh -i terraform/id_rsa_server ubuntu@<PUBLIC_IP>
```

### Checking Running Processes

Check Serverledge processes:

```bash
ps aux | grep serverledge
```

List active tmux sessions:

```bash
tmux ls
```

Attach to the Serverledge session to inspect its output:

```bash
tmux attach -t serverledge
```

Detach from a tmux session without terminating it using:

```text
Ctrl+B, then D
```

### Checking Docker Containers

List all containers:

```bash
docker ps -a
```

## Destroying the Infrastructure

When experiments are complete, destroy the provisioned infrastructure to avoid unnecessary GCP costs.

From the repository root:

```bash
./deploy.sh destroy
```

**Warning:** This operation permanently destroys the Terraform-managed infrastructure. Make sure that all experiment results have been downloaded before executing it.
