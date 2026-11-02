# Inception-of-Things

A minimal introduction to Kubernetes with K3s, K3d, Vagrant and Argo CD.

| Part | Folder | What it runs |
|---|---|---|
| 1 | `p1/` | Two Rocky Linux 10 VMs (Vagrant + VirtualBox): K3s server `shamzaouS`, K3s agent `shamzaouSW` |
| 2 | `p2/` | One VM `shamzaouS`: K3s with three apps behind the Traefik Ingress |
| 3 | `p3/` | K3d on the host VM, with Argo CD deploying an app from GitHub |

## Host prerequisites (p1, p2)

- x86_64 Linux host (target: Ubuntu 24.04) with VirtualBox 7.x and Vagrant 2.4.x.
- If the host is itself a VM, enable nested virtualization (VT-x / AMD-V) for it.
- Internet access. The first `vagrant up` downloads the box from Rocky Linux's own
  mirror (`config.vm.box_url` → `dl.rockylinux.org`), not from the HashiCorp registry.

## Part 1: K3s and Vagrant

```sh
cd p1
vagrant up
```

- `shamzaouS` (192.168.56.110) installs K3s in server (controller) mode.
- `shamzaouSW` (192.168.56.111) installs K3s in agent mode and joins the server.
- Both run `scripts/install-k3s.sh`. The join token is generated once by the
  Vagrantfile and kept in `p1/.vagrant/k3s-token` (git-ignored).
- `kubectl` comes with K3s; on the server it works without `sudo`, and `k` is an alias for it.

Verify:

```sh
vagrant ssh shamzaouS  -c "kubectl get nodes -o wide"     # 2 nodes Ready, INTERNAL-IP .110 and .111
vagrant ssh shamzaouS  -c "ip -4 a show to 192.168.56.110" # dedicated interface carrying the IP
vagrant ssh shamzaouSW -c "ip -4 a show to 192.168.56.111"
```

Clean up with `vagrant destroy -f`.

## Part 2: K3s and three simple applications

```sh
cd p2
vagrant up
```

One VM, `shamzaouS` (192.168.56.110), runs K3s in server mode. `scripts/setup.sh`
installs K3s and applies `confs/`:

- three apps (`app-one`, `app-two` with 3 replicas, `app-three`), each a `traefik/whoami`
  server that answers with its app name and pod hostname;
- one Ingress (`confs/ingress.yaml`, Traefik): `app1.com` → app1, `app2.com` → app2,
  any other host → app3.

Verify:

```sh
curl -H "Host: app1.com" 192.168.56.110   # Name: app1
curl -H "Host: app2.com" 192.168.56.110   # Name: app2 (Hostname changes across the 3 replicas)
curl 192.168.56.110                       # Name: app3
vagrant ssh shamzaouS -c "kubectl get all"
vagrant ssh shamzaouS -c "kubectl describe ingress apps"
```

## Part 3: K3d and Argo CD

Run on the host VM (no Vagrant):

```sh
p3/scripts/install.sh   # Docker Engine, kubectl, k3d (log out/in afterwards for the docker group)
p3/scripts/setup.sh     # k3d cluster "iot", namespaces argocd + dev, Argo CD, the app
```

Argo CD watches the public repo
[shamzaou/shamzaou-iot](https://github.com/shamzaou/shamzaou-iot) (`manifests/`) and
deploys it to namespace `dev`: `wil42/playground` on port 8888.

Verify:

```sh
kubectl get ns                        # argocd and dev
kubectl get pods -n dev               # wil-playground-... Running
curl http://localhost:8888/           # {"status":"ok", "message": "v1"}
kubectl port-forward -n argocd svc/argocd-server 8080:443   # UI: https://localhost:8080, user admin
```

The admin password is printed by `setup.sh`; it is also stored in the
`argocd-initial-admin-secret` secret.

Switch versions from GitHub:

```sh
git clone https://github.com/shamzaou/shamzaou-iot.git && cd shamzaou-iot
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git commit -am "v2" && git push
# Argo CD syncs within ~3 minutes (or click Refresh in the UI), then:
curl http://localhost:8888/           # {"status":"ok", "message": "v2"}
```
