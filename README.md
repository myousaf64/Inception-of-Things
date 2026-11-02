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
