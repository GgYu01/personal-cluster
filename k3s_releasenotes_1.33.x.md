Release Notesv1.33.X
v1.33.X
Upgrade Notice
Before upgrading from earlier releases, be sure to read the Kubernetes Urgent Upgrade Notes.

Version	Release date	Kubernetes	Kine	SQLite	Etcd	Containerd	Runc	Flannel	Metrics-server	Traefik	CoreDNS	Helm-controller	Local-path-provisioner
v1.33.3+k3s1	Jul 26 2025	v1.33.3	v0.13.17	3.49.1	v3.5.21-k3s1	v2.0.5-k3s2	v1.2.6	v0.27.0	v0.7.2	v3.3.6	v1.12.1	v0.16.13	v0.0.31
v1.33.2+k3s1	Jun 30 2025	v1.33.2	v0.13.15	3.49.1	v3.5.21-k3s1	v2.0.5-k3s1	v1.2.6	v0.27.0	v0.7.2	v3.3.6	v1.12.1	v0.16.11	v0.0.31
v1.33.1+k3s1	May 23 2025	v1.33.1	v0.13.15	3.49.1	v3.5.21-k3s1	v2.0.5-k3s1	v1.2.6	v0.26.7	v0.7.2	v3.3.6	v1.12.1	v0.16.10	v0.0.31
v1.33.0+k3s1	May 08 2025	v1.33.0	v0.13.14	v3.46.1	v3.5.21-k3s1	v2.0.4-k3s4	v1.2.5	v0.26.7	v0.7.2	v3.3.6	v1.12.1	v0.16.10	v0.0.31

Release v1.33.3+k3s1
This release updates Kubernetes to v1.33.3, and fixes a number of issues.

For more details on what's new, see the Kubernetes release notes.

Changes since v1.33.2+k3s1:
Add usage description for etcd-snapshot (#12573)
Refac shell completion to a better command structure (#12605)
K3s completion shell command will now be separate to specific subcommands for bash and zsh
GHA + Testing Backports (#12608)
Backports for 2025-07 (#12631)
Update to v1.33.3-k3s1 (#12652)
Release v1.33.2+k3s1
This release updates Kubernetes to v1.33.2, and fixes a number of issues.

For more details on what's new, see the Kubernetes release notes.

Changes since v1.33.1+k3s1:
GHCR image release (#12462)
Backports for 2025-06 (#12492)
Bump helm-controller (#12518)
Update network components (#12512)
Update to v1.33.2-k3s1 and Go 1.24.4 (#12529)
Release v1.33.1+k3s1
This release updates Kubernetes to v1.33.1, and fixes a number of issues.

For more details on what's new, see the Kubernetes release notes.

Changes since v1.33.0+k3s1:
Backports for May (#12319)
Backports for 2025-05 (#12325)
Fix authorization-config/authentication-config handling (#12344)
Fix secretsencrypt race conditions (#12355)
Update to v1.33.1-k3s1 (#12360)
Fix startup e2e test (#12370)
Release v1.33.0+k3s1
This release updates Kubernetes to v1.33.0, and fixes a number of issues.

For more details on what's new, see the Kubernetes release notes.

Changes since v1.32.4+k3s1
Build k3s overhaul (#12200)
Fix sonobuoy conformance testing (#12214)
Update k8s version to 1.33 (#12221)
Remove ghcr from drone (#12229)
