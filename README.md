# INFO8985-Inclass-task-4
signoz in docker and k8s-infra on kubernetes

TLDR;

```bash
pip install ansible kubernetes
git submodule update --init --recursive
patch  signoz/signoz/deploy/docker/docker-compose.yaml  < signoz/patch.diff
ansible-playbook up.yml
```
