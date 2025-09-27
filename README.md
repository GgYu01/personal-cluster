tree  >  /root/log.log  2>&1
tail -n +1 kubernetes/apps/* kubernetes/bootstrap/*  kubernetes/manifests/argocd-ingress/* kubernetes/manifests/authentik-ingress/*  kubernetes/manifests/cluster-issuer/* kubernetes/manifests/frps/* kubernetes/manifests/n8n/* kubernetes/manifests/provisioner/*  ./deploy.sh   >>  /root/log.log  2>&1


由于你你现在数据库严重滞后，请不要直接回答，而是告诉我如何提供给你你现在有可能用到所有部分的官方文档信息或者日志,最好提供具体的网页及如何详细步骤点击什么页面找到目录中哪部分，有详细引导过程、debug、错误信息，并且告诉我如何找到对应文档或者本地存储的信息、辅助调试的信息，请务必保证代码和方案与设计的质量，不要直接尝试解决问题，也不要给出任何解决的方案，一定要等我把文档和本地调试、日志、抓取的信息发给你后才可以开始做设计或者是代码编写。不要盲目信任你的记忆信息，而是任何时候以我提供给你的官方最新文档为准。


请深度全面思考，我是全栈工程师，请深度严谨全面思考你的方案步骤的逻辑和合理性，绝对不要浅思考，你应该反复推理验证逻辑关系是否正确。你的日志、输出、注释可以用专业的英文，但是对我说明的内容必须使用简体中文。
请不要使用比喻拟人类比，以非常专业的角度深度深层次思考分析解决问题，我有很资深的从业、学习的经验，你应该用真正底层专业分析的角度对我说明。
你输出的必须是标准markdown格式正文说明，正文说明请使用简体中文，代码和命令必须用代码块包裹起来，注释保持简要的英文。你只需要提供需要修改代码文件中需要修改内容的部分及排版缩进正确情况下，足以清晰准确定位需要修改位置的上下文、代码的基本结构和排版、简要的分析和修改说明、调试说明，禁止使用diff，不需要修改的不需要发送。

我希望使用不安全的环境，除了域名证书和HTTPS以外不要有任何加密，所有密钥密码都硬编码且用简单的密码。
我希望直接使用通配符域名记录DNS的A解析，不需要单独指定某个域名对应的A解析。
如果有要设置的用户名密码，请保持不安全、统一、简单、常见、低安全性的，这样以后我不会忘。我喜欢不安全的密码，只要服务没有最低限制，admin 和 password我觉得很好。而且我希望所有服务尽可能都允许被反向代理后通过公网的443端口HTTPS访问，而不是HTTP。还有一点就是我了解到我之前debug实验部署过很多次，不知道这是否对我现在的错误造成了影响。
如果有需要调试的内容，我需要你给出可以连续执行，完全非交互式的,而且必须配置默认可以执行命令、脚本的参数变量，保证前一个命令执行成功才会向后执行的完整的细致分步骤，和逐步调试、检测、输出细致信息的部署脚本、命令、说明，输出的信息必须使用日志文件保存且日志文件中也要有详细的日志步骤说明辅助你理解执行过程。如果在错误修复过程中反复认真多角度评估有必要，可用进行重构。

https://github.com/GgYu01/personal-cluster.git 是我的terraform、argocd 配置文件储存的仓库。
cloudflare api token 是 "vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
acme_email 是 "1405630484@qq.com"
部署逻辑应该由外部世界的实际状态，例如DNS记录是否正确驱动，而不是由一个本地状态文件terraform.tfstate驱动，例如检测DNS解析正确后不应该再执行设置DNS解析IP的步骤。
数据库不使用K3S 嵌入式ETCD，而是用独立部署的ETCD。Tarefik用K3S自带的Tarefik。不用自签名证书，用Lets encrypt 下发的证书，但是目前是验证阶段，正式的证书可能有获取次数限制，你需要考虑到这个可能需要获取临时证书。
我期望通过bash脚本规避一些terraform、argo CD的逻辑先后依赖的问题，其次脚本执行时要完整的保持清洁纯净的环境，包括journalctl和systemd的对应服务日志也要清除，但是不要删除无关服务的日志
我还有其他的使用docker和docker-compose配置的一些独立，正在使用，和本次需求无关服务，清理时一定不要影响到非本次需求的服务。关于kubeconfig我希望最好简单粗暴执行成功率高的输出在kubectl的默认配置路径下。
脚本中禁止重启主机系统，如有必要应该在步骤中对用户说明。
如果系统逻辑架构有前后依赖关系，尽量保证前一个服务反复确认一定可用、正常的情况下再部署后续内容，串行多步骤部署。酌情可以考虑部署多个有相互依赖关系，严格检查部署和健康状态的子项目，一切以保证部署成功为唯一前提。

由于你现在数据库严重滞后，不要盲目信任你的记忆信息，而是任何时候以我提供给你的最新信息为准。
我从k3s官网查询到最新稳定版本是 v1.33.3+k3s1
cert-manager 是 v1.18.2
traefik 是 37.0.0
metallb 是 0.15.2
argo cd chart 是 8.2.7
如果你认知和我版本不同，一定是你记忆错误，因为我是前半小时刚刚从官网查询最新稳定版本的。
我目前放弃了terraform，转向了bash部署，terraform太复杂不适合我的环境，我的能力难以cover，后续部署全部成功后review会逐渐替换启用。
从项目部署初期实验来说，我期望 使用 串行化、可验证的引导流程。脚本将逐个部署核心应用，并在部署下一个应用前，执行深入的、有针对性的健康检查，确保其底层资源真实可用。
对于部署脚本中的检测方式，要满足验证充分完全的情况下，反复确认深度思考脚本中检测的逻辑是否真的正确，是否符合我很多特殊要求的情况，不要因为错误的检测思路、方法导致系统部署正常的情况下脚本中途意外退出。
关于脚本中的日志，要保证能全方位多角度获取尽可能全面的日志内容，多方面辅助debug检查流程。但是要想办法，比如禁止restart或者其他方案，防止因为反复重启输出大量无效日志，日志不要有过多重复。我认为脚本中应该针对错误的内容和步骤，在不重复输出、获取过多错误日志且保证可以获取更多诊断辅助判断的信息的情况下，打印尽可能全面的信息辅助判断流程到底发生了什么，哪里卡住了，最好能通过多方面的信息、诊断、调试信息，直接通过逻辑判断错误点，而不是事后找。



我刚刚偶然发现通过公网WebUI，主机地址和端口使用局域网对应的IP / 端口时，当访问所在的客户端主机可以联通服务器所在局域网时是可以访问通的。 我由此得出了一个结论：WebUI / 数据很可能是相当独立分离的。 我现在还是缺乏完整的debug路径，我想要搞清楚这个webUI显示地图到底是数据怎么链路实现的，为什么输入的这个主机 、 ip 端口好像需要客户端访问通才行？ 我发现局域网设备不存在WebUI页面雷达地图延迟的问题 ，由此，我希望优化一下路径，我希望数据还是传输在服务端本机 / 局域网以获取最低的延迟 ， 而不是客户端真的直接访问到data数据端。预期是服务端拿到数据后经过某种合成最后呈现页面出来，酌情可以考虑加入其他服务来实现。我所有的用户以及未来预期的用户100%没有公网IP，都在NAT之后，且无法做端口映射。

我不太接受直连的方案，在不修改后端代码，只有config，没有源码，闭源的情况下，我需要让客户端访问到的是在服务端处理好的数据，这很重要。 请注意，我说的服务端是值得Windows 辅助程序的server frpclient所在的副机，而不是Linux docker compose那台运行frpserver的机器。

我现在已经实现了初步的方案，现在我需要进阶，我现在需要使用一个Linux公网服务器提供服务的情况下，结合域名和Lets encrypt免费证书，做一套很专业的服务架构出来，为每一个使用地图雷达的客户最好可以直接用443或者80端口和域名，我完全不需要除了域名以外的安全性，尽量省事，保证连通、延迟低即可，可以随意无限制浪费一些其他的资源保证稳定和低延迟。

我希望在不会影响其他人连续正常使用的情况下，可以为每个用户提供一个子域名，我希望类似使用卡密或者某一串字符，作为域名的前缀整体服务来说我希望是解耦的，每个人只需要关注自己的特殊序列号+域名即可，可能后期还要引入过期机制。高度灵活可自由配置，尽量管控都放在Linux服务端，客户Windows仅提供一些数据。

架构我感觉可以引入更多专业时尚新潮的组件服务，甚至类似token / 序列号可以和用户名密码关联，可以web查询过期日期等。有必要的话可以引入K3S，时尚新潮最重要，尤其是用户名密码 序列号这个，最好有自动一些方便实现的方案，还要有过期时间，用户名密码不过期但是 序列号、token等可以定期过期。我其实也不是刚需token，token序列号一定是可以不需要的，只要有某种通过用户名+密码，且可以设置租期，并且能延长租期的手段即可。而且最好还有方便查询的手段，如果有WebUI更好，我之前只是想偷懒用用户名+密码+用户名关联的多个可过期的token或者key。如果有很多新潮的类似方案请你尽可能多的向我推荐，你选用的服务和架构可以尽可能新、时尚、社区，对专业性要求低，最好有现成的美观的页面，谢谢。我不知道怎么做这样的页面或者服务架构。除了域名证书和用户密码以外其他安全性尽可能去掉，保证整体架构连通、部署简便。

我期望本身架构是专业化的，加入更多云原生的思想架构，可持续部署灵活弹性等，但是架构下选择的服务可以是新潮稳定性专业性没那么强的。比如可以酌情引入argoCD还有其他的服务。

还有，因为这是一个Web服务，如果你有更好的建议，比如如何让用户很简单的认证访问和分享给朋友网页，不需要做很复杂的操作。真正提供数据的网络服务后端我改不了，http://115.120.240.160:19002/?address=115.120.240.160&port=19002&roomId=123456 看起来这个是能避免webUI登录的，我认为可以利用某种方法自动生成链接或者除了roomid以外全部都可以用一个域名代替。

我目前自己的方案如下，优先保证通，不考虑安全性。

我现在需要部署自动给用户增加24小时，168小时，744小时，2232小时，8784小时几种，用户登陆方式我没想好，用户如何访问网址我也没想好，尽可能降低用户的负担，越简单无感越好，然后我预期也要写一个程序或者初期先用脚本在用户Windows本地后台启动对应nginx和frpc，Windows启动这两个进程一般是hang住，我没想好检测联通的标志，这需要你帮我想这些要实现的功能如何对用户尽可能无感的实现。

我现在需要你帮我设计这个复杂体系的架构，请你开始设计，谢谢。禁止提供任何的具体命令、代码，我们现在仅作方案和架构设计的讨论。

我目前服务端部署失败，需要你帮我综合思考解决问题：
--> INFO: Deployment Bootstrapper (v23.1) initiated. Full log: /root/personal-cluster/deployment-bootstrap-20250926-001243.log


[1;34m# ============================================================================== #[0m
[1;34m# STEP 0: Ensure Cloudflare wildcard DNS (Timestamp: 2025-09-26T04:12:43+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Resolving Cloudflare Zone ID for gglohh.top ...
[1;32m✅ SUCCESS:[0m Cloudflare Zone ID acquired: 72377620fc4ce2aef5ba6bfd9c0c4c35
--> INFO: Checking existing DNS record for *.core01.prod.gglohh.top (type A) ...
[1;32m✅ SUCCESS:[0m Wildcard A already correct: *.core01.prod.gglohh.top -> 172.245.187.113 (no action).
--> INFO: Verifying public resolution via 1.1.1.1 ...
[1;32m✅ SUCCESS:[0m Public DNS resolution OK for wildcard subdomain.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 1: System Cleanup (Timestamp: 2025-09-26T04:12:45+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: This step will eradicate all traces of previous K3s and this project's ETCD.
--> INFO: Stopping k3s, docker, and containerd services...
--> INFO: Forcefully removing project's ETCD container and network...
--> INFO: Running K3s uninstaller and cleaning up filesystem...
--> INFO: Reloading systemd and cleaning journals for k3s and docker...
--> INFO: Rotating systemd journal only (no global vacuum; keep unrelated services' logs)...
[1;32m✅ SUCCESS:[0m System cleanup complete.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 2: Deploy and Verify External ETCD (Timestamp: 2025-09-26T04:13:16+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Preparing ETCD data directory with correct permissions for UID 1001...
--> INFO: Deploying ETCD via Docker...
[1;32m✅ SUCCESS:[0m ETCD container started.
--> INFO: Verifying: ETCD to be healthy (Timeout: 60s)
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: ETCD to be healthy.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 3: Install and Verify K3S (Timestamp: 2025-09-26T04:13:22+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Preparing K3s manifest and configuration directories...
--> INFO: Creating Traefik HelmChartConfig with CRD provider and frps (7000/TCP) entryPoint...
[1;32m✅ SUCCESS:[0m K3s customization manifests created.
--> INFO: Installing K3s v1.33.3+k3s1...
[INFO]  Using v1.33.3+k3s1 as release
[INFO]  Downloading hash https://github.com/k3s-io/k3s/releases/download/v1.33.3+k3s1/sha256sum-amd64.txt
[INFO]  Downloading binary https://github.com/k3s-io/k3s/releases/download/v1.33.3+k3s1/k3s
[INFO]  Verifying binary download
[INFO]  Installing k3s to /usr/local/bin/k3s
[INFO]  Skipping installation of SELinux RPM
[INFO]  Skipping /usr/local/bin/kubectl symlink to k3s, already exists
[INFO]  Creating /usr/local/bin/crictl symlink to k3s
[INFO]  Skipping /usr/local/bin/ctr symlink to k3s, command exists in PATH at /usr/bin/ctr
[INFO]  Creating killall script /usr/local/bin/k3s-killall.sh
[INFO]  Creating uninstall script /usr/local/bin/k3s-uninstall.sh
[INFO]  env: Creating environment file /etc/systemd/system/k3s.service.env
[INFO]  systemd: Creating service file /etc/systemd/system/k3s.service
[INFO]  systemd: Enabling k3s unit
Created symlink /etc/systemd/system/multi-user.target.wants/k3s.service → /etc/systemd/system/k3s.service.
[INFO]  systemd: Starting k3s
[1;32m✅ SUCCESS:[0m K3s installation script finished.
--> INFO: Setting up kubeconfig for user...
--> INFO: Verifying: K3s node to be Ready (Timeout: 180s)
Error from server (NotFound): nodes "racknerd-f770a87" not found
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: K3s node to be Ready.
--> INFO: Waiting for HelmChart 'traefik' to appear...
--> INFO: Verifying: HelmChart/traefik exists (Timeout: 240s)
[1;32m✅ SUCCESS:[0m Verified: HelmChart/traefik exists.
[1;32m✅ SUCCESS:[0m HelmChart/traefik detected.
--> INFO: Waiting for job/helm-install-traefik-crd to succeed...
--> INFO: Waiting Job kube-system/helm-install-traefik-crd to succeed...
[1;32m✅ SUCCESS:[0m Job kube-system/helm-install-traefik-crd succeeded.
--> INFO: Waiting for Traefik CRDs to be established in API...
--> INFO: Verifying: CRD ingressroutes.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD ingressroutes.traefik.io present.
--> INFO: Verifying: CRD ingressroutetcps.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD ingressroutetcps.traefik.io present.
--> INFO: Verifying: CRD ingressrouteudps.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD ingressrouteudps.traefik.io present.
--> INFO: Verifying: CRD middlewares.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD middlewares.traefik.io present.
--> INFO: Verifying: CRD traefikservices.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD traefikservices.traefik.io present.
--> INFO: Verifying: CRD tlsoptions.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD tlsoptions.traefik.io present.
--> INFO: Verifying: CRD serverstransports.traefik.io present (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: CRD serverstransports.traefik.io present.
[1;32m✅ SUCCESS:[0m All Traefik CRDs are present.
--> INFO: Waiting for job/helm-install-traefik to succeed...
--> INFO: Waiting Job kube-system/helm-install-traefik to succeed...
[1;32m✅ SUCCESS:[0m Job kube-system/helm-install-traefik succeeded.
--> INFO: Waiting for Traefik Deployment to be created...
--> INFO: Verifying: Deployment/traefik exists (Timeout: 240s)
[1;32m✅ SUCCESS:[0m Verified: Deployment/traefik exists.
--> INFO: Waiting for Traefik Deployment rollout...
--> INFO: Verifying: Traefik Deployment rollout (Timeout: 480s)
[1;32m✅ SUCCESS:[0m Verified: Traefik Deployment rollout.
[1;32m✅ SUCCESS:[0m Traefik Deployment is Ready.
--> INFO: Checking Service/traefik exposes required ports (80, 443, 7000)...
--> INFO: Verifying: Service/traefik to expose 80,443,7000 (Timeout: 300s)
[1;32m✅ SUCCESS:[0m Verified: Service/traefik to expose 80,443,7000.
[1;32m✅ SUCCESS:[0m Traefik Service exposes 80/443/7000.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 4: Bootstrap GitOps Engine (Argo CD) (Timestamp: 2025-09-26T04:14:41+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Bootstrapping Argo CD via Helm...
--> INFO: This initial install will create CRDs and components with static credentials.
Release "argocd" does not exist. Installing it now.
NAME: argocd
LAST DEPLOYED: Fri Sep 26 00:14:43 2025
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
In order to access the server UI you have the following options:

1. kubectl port-forward service/argocd-server -n argocd 8080:443

    and then open the browser on http://localhost:8080 and accept the certificate

2. enable ingress in the values file `server.ingress.enabled` and either
      - Add the annotation for ssl passthrough: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough
      - Set the `configs.params."server.insecure"` in the values file and terminate SSL at your ingress: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts


After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)
[1;32m✅ SUCCESS:[0m Argo CD components and CRDs installed via Helm with static password.
--> INFO: Applying Argo CD application manifests to enable GitOps self-management...
Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name including a path (/) to avoid accidental conflicts with other finalizer writers
application.argoproj.io/argocd created
--> INFO: Waiting for Argo CD to sync its own application resource...
--> INFO: Verifying: Argo CD to become Healthy and self-managed (Timeout: 300s)
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: Argo CD to become Healthy and self-managed.
[1;32m✅ SUCCESS:[0m Argo CD has been bootstrapped and is now self-managing via GitOps.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 5: Deploy Core Applications via GitOps (Timestamp: 2025-09-26T04:15:57+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Applying cert-manager Application (only)...
application.argoproj.io/cert-manager created
--> INFO: Checking Kubernetes apiserver readiness (/readyz) with timeout 300s...
[1;32m✅ SUCCESS:[0m Kubernetes apiserver reports Ready.
--> INFO: Waiting for cert-manager Deployments to become Available...
    ...waiting for cert-manager deployments to appear
    ...waiting for cert-manager deployments to appear
    ...waiting for cert-manager deployments to appear
    ...waiting for cert-manager deployments to appear
    ...waiting for cert-manager deployments to appear
Waiting for deployment "cert-manager" rollout to finish: 0 of 1 updated replicas are available...
deployment "cert-manager" successfully rolled out
deployment "cert-manager-webhook" successfully rolled out
[1;32m✅ SUCCESS:[0m cert-manager core Deployments are Available.
--> INFO: Checking Kubernetes apiserver readiness (/readyz) with timeout 300s...
[1;32m✅ SUCCESS:[0m Kubernetes apiserver reports Ready.
--> INFO: Waiting for Cert-Manager application to become Healthy in Argo CD...
--> INFO: Verifying: Cert-Manager Argo CD App to be Healthy (Timeout: 100s)
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: Cert-Manager Argo CD App to be Healthy.
[1;32m✅ SUCCESS:[0m Cert-Manager application is Healthy in Argo CD.
--> INFO: Applying remaining Applications (excluding n8n)...
application.argoproj.io/frps created
application.argoproj.io/core-manifests created
application.argoproj.io/argocd-ingress created
application.argoproj.io/provisioner created
application.argoproj.io/authentik-ingress-static created
--> INFO: Waiting for core-manifests application to become Healthy...
--> INFO: Verifying: core-manifests Argo CD App to be Healthy (Timeout: 600s)
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: core-manifests Argo CD App to be Healthy.
--> INFO: Waiting for argocd-ingress application to become Healthy...
--> INFO: Verifying: argocd-ingress Argo CD App to be Healthy (Timeout: 600s)
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: argocd-ingress Argo CD App to be Healthy.
--> INFO: Waiting for provisioner application to become Healthy...
--> INFO: Verifying: provisioner Argo CD App to be Healthy (Timeout: 600s)
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: provisioner Argo CD App to be Healthy.
[1;32m✅ SUCCESS:[0m provisioner application is Healthy.
--> INFO: Waiting for authentik-ingress-static application to become Healthy...
--> INFO: Verifying: authentik-ingress-static Argo CD App to be Healthy (Timeout: 600s)
    ...waiting...
[1;32m✅ SUCCESS:[0m Verified: authentik-ingress-static Argo CD App to be Healthy.
[1;32m✅ SUCCESS:[0m Remaining applications submitted and Healthy.


[1;34m# ============================================================================== #[0m
[1;34m# STEP 6: Final End-to-End Verification (Timestamp: 2025-09-26T04:19:40+00:00)[0m
[1;34m# ============================================================================== #[0m

--> INFO: Checking Kubernetes apiserver readiness (/readyz) with timeout 180s...
[1;32m✅ SUCCESS:[0m Kubernetes apiserver reports Ready.
--> INFO: Verifying ClusterIssuer 'cloudflare-staging' is ready...
--> INFO: Verifying: ClusterIssuer to be Ready (Timeout: 120s)
[1;32m✅ SUCCESS:[0m Verified: ClusterIssuer to be Ready.
--> INFO: Verifying ArgoCD IngressRoute certificate has been issued...
--> INFO: Verifying: Certificate to be Ready (Timeout: 300s)
[1;32m✅ SUCCESS:[0m Verified: Certificate to be Ready.
--> INFO: Performing final reachability check on ArgoCD URL: https://argocd.core01.prod.gglohh.top
--> INFO: Verifying: ArgoCD UI to be reachable (HTTP 200 OK) (Timeout: 120s)
[1;32m✅ SUCCESS:[0m Verified: ArgoCD UI to be reachable (HTTP 200 OK).
--> INFO: Verifying Provisioner portal Certificate has been issued...
--> INFO: Verifying: Portal Certificate to be Ready (Timeout: 300s)
[1;32m✅ SUCCESS:[0m Verified: Portal Certificate to be Ready.
--> INFO: Waiting for provisioner-gateway Deployment rollout...
--> INFO: Verifying: provisioner-gateway rollout to complete (Timeout: 240s)
[1;32m✅ SUCCESS:[0m Verified: provisioner-gateway rollout to complete.
--> INFO: Waiting for Service/provisioner-gateway endpoints to be populated...
--> INFO: Verifying: provisioner-gateway Endpoints to be Ready (Timeout: 240s)
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
[1;32m✅ SUCCESS:[0m Verified: provisioner-gateway Endpoints to be Ready.
--> INFO: Verifying TLS Secret 'portal-tls-staging' exists for Traefik...
--> INFO: Verifying: Secret portal-tls-staging available (Timeout: 180s)
[1;32m✅ SUCCESS:[0m Verified: Secret portal-tls-staging available.
--> INFO: Allowing Traefik to resync TLS assets...
--> INFO: Performing reachability check on Portal URL: https://portal.core01.prod.gglohh.top
--> INFO: Verifying: Provisioner portal to be reachable (HTTP 200/30x) (Timeout: 180s)
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
    ...waiting...
[1;33m⚠️  WARN: Condition 'Provisioner portal to be reachable (HTTP 200/30x)' was NOT met within the timeout period.[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mTraefik version 3.3.6 built on 2025-04-18T09:18:47Z[0m [36mversion=[0m3.3.6
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStats collection is enabled.[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mMany thanks for contributing to Traefik's improvement by allowing us to receive anonymous information from your configuration.[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mHelp us improve Traefik by leaving this feature on :)[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mMore details on: https://doc.traefik.io/traefik/contributing/data-collection/[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStarting provider aggregator *aggregator.ProviderAggregator[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStarting provider *acme.ChallengeTLSALPN[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStarting provider *crd.Provider[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStarting provider *traefik.Provider[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mlabel selector is: ""[0m [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mCreating in-cluster Provider client[0m [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mStarting provider *ingress.Provider[0m
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mingress label selector is: ""[0m [36mproviderName=[0mkubernetes
[90m2025-09-26T04:14:39Z[0m [32mINF[0m [1mCreating in-cluster Provider client[0m [36mproviderName=[0mkubernetes
[90m2025-09-26T04:17:33Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:35Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:35Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:35Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:35Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:35Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:36Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:36Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:36Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:40Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:40Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:40Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:41Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:49Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:49Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:49Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:50Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:50Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:50Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:51Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:51Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:51Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:52Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:52Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:52Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:56Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:56Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:17:56Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:08Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:09Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:09Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:09Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:26Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret argocd/argocd-server-tls-staging does not exist"[0m[0m [36mingress=[0margocd-server-https [36mnamespace=[0margocd [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:26Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:18:26Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:11Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:11Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:11Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:11Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:24Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:24Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:24Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:24Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:25Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:25Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:26Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:26Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:26Z[0m [31mERR[0m [1mError configuring TLS[0m [36merror=[0m[31m[1m"secret authentik/authentik-tls-staging does not exist"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:26Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:34Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
[90m2025-09-26T04:19:34Z[0m [31mERR[0m [36merror=[0m[31m[1m"kubernetes service not found: authentik/authentik-server"[0m[0m [36mingress=[0mauthentik-https [36mnamespace=[0mauthentik [36mproviderName=[0mkubernetescrd
Listening on port 80.
{"name":"echo-server","hostname":"provisioner-gateway-fcbff6984-wc795","pid":1,"level":30,"host":{"hostname":"10.42.0.22","ip":"::ffff:10.42.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{},"query":{},"cookies":{},"body":{},"headers":{"host":"10.42.0.22:80","user-agent":"kube-probe/1.33","accept":"*/*","connection":"close"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"provisioner-gateway-fcbff6984-wc795","NODE_VERSION":"20.11.0","YARN_VERSION":"1.22.19","KUBERNETES_SERVICE_PORT":"443","PROVISIONER_GATEWAY_PORT_80_TCP_PORT":"80","PROVISIONER_GATEWAY_PORT_80_TCP_ADDR":"10.43.127.120","KUBERNETES_SERVICE_PORT_HTTPS":"443","KUBERNETES_PORT":"tcp://10.43.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.43.0.1:443","PROVISIONER_GATEWAY_PORT_80_TCP_PROTO":"tcp","PROVISIONER_GATEWAY_SERVICE_HOST":"10.43.127.120","PROVISIONER_GATEWAY_PORT":"tcp://10.43.127.120:80","KUBERNETES_SERVICE_HOST":"10.43.0.1","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_ADDR":"10.43.0.1","PROVISIONER_GATEWAY_SERVICE_PORT":"80","PROVISIONER_GATEWAY_SERVICE_PORT_HTTP":"80","PROVISIONER_GATEWAY_PORT_80_TCP":"tcp://10.43.127.120:80","HOME":"/root"},"msg":"Fri, 26 Sep 2025 04:18:08 GMT | [GET] - http://10.42.0.22:80/","time":"2025-09-26T04:18:08.698Z","v":0}
{"name":"echo-server","hostname":"provisioner-gateway-fcbff6984-wc795","pid":1,"level":30,"host":{"hostname":"10.42.0.22","ip":"::ffff:10.42.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{},"query":{},"cookies":{},"body":{},"headers":{"host":"10.42.0.22:80","user-agent":"kube-probe/1.33","accept":"*/*","connection":"close"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"provisioner-gateway-fcbff6984-wc795","NODE_VERSION":"20.11.0","YARN_VERSION":"1.22.19","KUBERNETES_SERVICE_PORT":"443","PROVISIONER_GATEWAY_PORT_80_TCP_PORT":"80","PROVISIONER_GATEWAY_PORT_80_TCP_ADDR":"10.43.127.120","KUBERNETES_SERVICE_PORT_HTTPS":"443","KUBERNETES_PORT":"tcp://10.43.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.43.0.1:443","PROVISIONER_GATEWAY_PORT_80_TCP_PROTO":"tcp","PROVISIONER_GATEWAY_SERVICE_HOST":"10.43.127.120","PROVISIONER_GATEWAY_PORT":"tcp://10.43.127.120:80","KUBERNETES_SERVICE_HOST":"10.43.0.1","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_ADDR":"10.43.0.1","PROVISIONER_GATEWAY_SERVICE_PORT":"80","PROVISIONER_GATEWAY_SERVICE_PORT_HTTP":"80","PROVISIONER_GATEWAY_PORT_80_TCP":"tcp://10.43.127.120:80","HOME":"/root"},"msg":"Fri, 26 Sep 2025 04:18:13 GMT | [GET] - http://10.42.0.22:80/","time":"2025-09-26T04:18:13.664Z","v":0}
{"name":"echo-server","hostname":"provisioner-gateway-fcbff6984-wc795","pid":1,"level":30,"host":{"hostname":"10.42.0.22","ip":"::ffff:10.42.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{},"query":{},"cookies":{},"body":{},"headers":{"host":"10.42.0.22:80","user-agent":"kube-probe/1.33","accept":"*/*","connection":"close"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"provisioner-gateway-fcbff6984-wc795","NODE_VERSION":"20.11.0","YARN_VERSION":"1.22.19","KUBERNETES_SERVICE_PORT":"443","PROVISIONER_GATEWAY_PORT_80_TCP_PORT":"80","PROVISIONER_GATEWAY_PORT_80_TCP_ADDR":"10.43.127.120","KUBERNETES_SERVICE_PORT_HTTPS":"443","KUBERNETES_PORT":"tcp://10.43.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.43.0.1:443","PROVISIONER_GATEWAY_PORT_80_TCP_PROTO":"tcp","PROVISIONER_GATEWAY_SERVICE_HOST":"10.43.127.120","PROVISIONER_GATEWAY_PORT":"tcp://10.43.127.120:80","KUBERNETES_SERVICE_HOST":"10.43.0.1","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_ADDR":"10.43.0.1","PROVISIONER_GATEWAY_SERVICE_PORT":"80","PROVISIONER_GATEWAY_SERVICE_PORT_HTTP":"80","PROVISIONER_GATEWAY_PORT_80_TCP":"tcp://10.43.127.120:80","HOME":"/root"},"msg":"Fri, 26 Sep 2025 04:22:43 GMT | [GET] - http://10.42.0.22:80/","time":"2025-09-26T04:22:43.659Z","v":0}
{"name":"echo-server","hostname":"provisioner-gateway-fcbff6984-wc795","pid":1,"level":30,"host":{"hostname":"10.42.0.22","ip":"::ffff:10.42.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{},"query":{},"cookies":{},"body":{},"headers":{"host":"10.42.0.22:80","user-agent":"kube-probe/1.33","accept":"*/*","connection":"close"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"provisioner-gateway-fcbff6984-wc795","NODE_VERSION":"20.11.0","YARN_VERSION":"1.22.19","KUBERNETES_SERVICE_PORT":"443","PROVISIONER_GATEWAY_PORT_80_TCP_PORT":"80","PROVISIONER_GATEWAY_PORT_80_TCP_ADDR":"10.43.127.120","KUBERNETES_SERVICE_PORT_HTTPS":"443","KUBERNETES_PORT":"tcp://10.43.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.43.0.1:443","PROVISIONER_GATEWAY_PORT_80_TCP_PROTO":"tcp","PROVISIONER_GATEWAY_SERVICE_HOST":"10.43.127.120","PROVISIONER_GATEWAY_PORT":"tcp://10.43.127.120:80","KUBERNETES_SERVICE_HOST":"10.43.0.1","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_ADDR":"10.43.0.1","PROVISIONER_GATEWAY_SERVICE_PORT":"80","PROVISIONER_GATEWAY_SERVICE_PORT_HTTP":"80","PROVISIONER_GATEWAY_PORT_80_TCP":"tcp://10.43.127.120:80","HOME":"/root"},"msg":"Fri, 26 Sep 2025 04:22:48 GMT | [GET] - http://10.42.0.22:80/","time":"2025-09-26T04:22:48.656Z","v":0}

[1;31m❌ FATAL ERROR:[0m Portal end-to-end verification failed.
[1;31mDeployment failed. See /root/personal-cluster/deployment-bootstrap-20250926-001243.log for full details.[0m














































































我当前所有源码如下：


.
├── 01-infra
│   ├── c2-vps-setup.tf
│   ├── c3-k3s-cluster.tf
│   ├── locals.tf
│   ├── providers.tf
│   └── variables.tf
├── argocd_values.md
├── cert_manager_Concepts_ACME_Orders_and_Challenges.md
├── cert_manager_Configuring_Issuers_ACME_DNS01_Cloudflare.md
├── cert_manager_helmcharts_values.md
├── cert_manager_Troubleshooting_ACME_lets_encrypt.md
├── collect_enhanced_diagnostics.sh
├── deployment-bootstrap-20250926-001243.log
├── deploy.sh
├── docker_compose_down.md
├── docker_network_inspect.md
├── docker_network_rm.md
├── k3s_Advanced_Options_Configuration.md
├── k3s_datastore_High_Availability_External_DB.md
├── k3s_installation_Configuration_Options.md
├── k3s_Networking_Basic_Network_Options.md
├── k3s_Networking_Networking_Services.md
├── k3s_releasenotes_1.33.x.md
├── kubernetes
│   ├── apps
│   │   ├── argocd-ingress-app.yaml
│   │   ├── authentik-app.yaml
│   │   ├── authentik-ingress-static-app.yaml
│   │   ├── cert-manager-app.yaml
│   │   ├── core-manifests-app.yaml
│   │   ├── frps-app.yaml
│   │   ├── n8n-app.yaml
│   │   └── provisioner-app.yaml
│   ├── bootstrap
│   │   └── argocd-app.yaml
│   └── manifests
│       ├── argocd-ingress
│       │   ├── certificate.yaml
│       │   └── ingress.yaml
│       ├── authentik-ingress
│       │   ├── certificate.yaml
│       │   ├── ingress.yaml
│       │   └── namespace.yaml
│       ├── cluster-issuer
│       │   ├── issuer.yaml
│       │   └── secret.yaml
│       ├── frps
│       │   ├── config.yaml
│       │   ├── deployment.yaml
│       │   ├── namespace.yaml
│       │   ├── service-and-routes.yaml
│       │   └── wildcard-certificate.yaml
│       ├── n8n
│       │   └── certificate.yaml
│       └── provisioner
│           ├── certificate.yaml
│           ├── deployment.yaml
│           ├── ingress.yaml
│           ├── namespace.yaml
│           └── service.yaml
├── README.md
├── temp.sh
├── traefik_Reference_Configuration_Discovery_Kubernetes_CRD_HTTP_IngressRoute.md
└── traefik_User_Guides_Kubernetes_and_cert-manager.md

12 directories, 53 files
==> kubernetes/apps/argocd-ingress-app.yaml <==
# apps/argocd-ingress-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # 可选
spec:
  project: default
  source:
    repoURL: https://github.com/GgYu01/personal-cluster.git
    targetRevision: HEAD
    path: kubernetes/manifests/argocd-ingress
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/authentik-app.yaml <==
# kubernetes/apps/authentik-app.yaml
# Code Analysis: Deploys Authentik using its official Helm chart, following the same
# pattern as your existing n8n-app.yaml. A sync-wave of "10" ensures it deploys
# after frps and other core services.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: default
  source:
    repoURL: https://charts.goauthentik.io
    chart: authentik
    targetRevision: 2024.6.1 # Pin chart version for stability
    helm:
      releaseName: authentik
      values: |
        # IMPORTANT: Replace with a long random string
        authentik:
          secret_key: "a_very_long_and_random_secret_key_change_me"

        # For simplicity, enable the bundled PostgreSQL and Redis
        postgresql:
          enabled: true
          auth:
            # IMPORTANT: Replace with a strong password
            password: "a_strong_database_password_change_me"

        redis:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: authentik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/authentik-ingress-static-app.yaml <==
# apps/authentik-ingress-static-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik-ingress-static
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "20"   # 可选
spec:
  project: default
  source:
    repoURL: https://github.com/GgYu01/personal-cluster.git
    targetRevision: HEAD
    path: kubernetes/manifests/authentik-ingress
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/cert-manager-app.yaml <==
# kubernetes/applications/cert-manager.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.18.2 # This is the application version. The chart version will be resolved by Helm.
    helm:
      releaseName: cert-manager
      values: |
        # --- [START OF CORRECTION] ---
        # According to the provided official Helm chart documentation, 'installCRDs' is deprecated.
        # The modern and correct way to ensure CRDs are managed by the Helm chart is using 'crds.enabled'.
        crds:
          enabled: true
        # --- [END OF CORRECTION] ---
        
        startupapicheck:
          enabled: true
          # Give it ample time to succeed, especially on slower networks or busy nodes.
          timeout: 5m
        prometheus:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/core-manifests-app.yaml <==
# kubernetes/applications/manifests.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-manifests
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/GgYu01/personal-cluster.git
    targetRevision: HEAD
    path: kubernetes/manifests/cluster-issuer
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/frps-app.yaml <==
# kubernetes/apps/frps-app.yaml
# Code Analysis: Defines the frps application for Argo CD.
# This application definition tells Argo CD to manage the resources located
# in the 'kubernetes/manifests/frps' directory. This keeps all raw manifests
# centralized, following your existing pattern. A sync-wave of "5" ensures
# it is deployed after core infrastructure like cert-manager.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frps
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  source:
    repoURL: https://github.com/GgYu01/personal-cluster.git # Using your existing repo URL
    targetRevision: HEAD
    path: kubernetes/manifests/frps # Manages all manifests within this specific path
  destination:
    server: https://kubernetes.default.svc
    namespace: frp-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/n8n-app.yaml <==
# kubernetes/apps/n8n-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: n8n
  namespace: argocd
  annotations:
    # 托管顺序可保留
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: default
  source:
    repoURL: https://community-charts.github.io/helm-charts
    chart: n8n
    targetRevision: 1.15.4
    helm:
      releaseName: n8n
      values: |
        # ======================================================================
        # n8n Core Configuration
        # ======================================================================
        encryptionKey: "a-very-insecure-but-static-encryption-key-for-n8n"
        timezone: "Asia/Shanghai"

        # 主容器设置（注意：此 chart 版本不支持 startupProbe/extraEnv）
        main:
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 500m
              memory: 512Mi

          livenessProbe:
            enabled: true
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 12

          readinessProbe:
            enabled: true
            httpGet:
              path: /healthz/readiness
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 12

          # 关键修复：使用 map 形式的 extraEnvVars（而不是数组）
          extraEnvVars:
            N8N_HOST: n8n.core01.prod.gglohh.top
            N8N_SECURE_COOKIE: "false"      # 你要求的禁用安全 Cookie 配置
            N8N_PROTOCOL: https
            N8N_PORT: "5678"
            WEBHOOK_URL: https://n8n.core01.prod.gglohh.top/

        # 二进制数据本地持久化
        binaryData:
          mode: "filesystem"

        # 执行模式：队列 + 1 个 worker
        worker:
          mode: queue
          count: 1

        # 数据库：PostgreSQL 子图表
        db:
          type: postgresdb

        postgresql:
          enabled: true
          architecture: standalone
          auth:
            database: "n8n"
            username: "admin"
            password: "password"
          primary:
            persistence:
              enabled: true
              storageClass: "local-path"
              size: 8Gi

        # 队列：Redis 子图表
        redis:
          enabled: true
          architecture: standalone
          auth:
            enabled: true
            password: "password"
          master:
            persistence:
              enabled: true
              storageClass: "local-path"
              size: 2Gi

        # Ingress（Traefik）
        ingress:
          enabled: true
          className: "traefik"
          hosts:
            - host: n8n.core01.prod.gglohh.top
              paths:
                - path: /
                  pathType: Prefix
          tls:
            - secretName: n8n-tls-staging
              hosts:
                - n8n.core01.prod.gglohh.top

  destination:
    server: https://kubernetes.default.svc
    namespace: n8n
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/apps/provisioner-app.yaml <==
# [ADD START] 新增：Provisioner 网关（控制面），用于令牌校验与发放 Ephemeral Host
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: provisioner
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "8"  # 在 frps(5) 之后、authentik(10) 之前
spec:
  project: default
  source:
    repoURL: https://github.com/GgYu01/personal-cluster.git
    targetRevision: HEAD
    path: kubernetes/manifests/provisioner
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: provisioner
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
# [ADD END]
==> kubernetes/bootstrap/argocd-app.yaml <==
# kubernetes/bootstrap/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-options: "Replace=true"
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 8.2.7
    helm:
      releaseName: argocd
      values: |
        # ======================================================================
        # CORE CONFIGURATION
        # ======================================================================
        configs:
          # --- RBAC（关键修复）---
          # 注意：helm chart 的键是 policy 和 policyDefault（不是 policy.csv）
          rbac:
            create: true
            policy: |
              p, role:readonly, applications, get, */*, allow
              p, role:readonly, applications, subscribe, */*, allow
              p, role:readonly, certificates, get, *, allow
              p, role:readonly, clusters, get, *, allow
              p, role:readonly, repositories, get, *, allow
              p, role:readonly, projects, get, *, allow
              p, role:readonly, accounts, get, *, allow
              p, role:readonly, gpgkeys, get, *, allow

              p, role:admin, applications, *, */*, allow
              p, role:admin, applicationsets, *, */*, allow
              p, role:admin, certificates, *, *, allow
              p, role:admin, clusters, *, *, allow
              p, role:admin, repositories, *, *, allow
              p, role:admin, projects, *, *, allow
              p, role:admin, accounts, *, *, allow
              p, role:admin, gpgkeys, *, *, allow
              p, role:admin, exec, *, *, allow

              g, admin, role:admin
            policyDefault: ""
            scopes: '[email, groups]'
          # -----------------------

          secret:
            createSecret: true
            # admin 密码：password
            argocdServerAdminPassword: "$2a$10$Xx3c/ILSzwZfp2wHhoPxFOwH4yFp3MepBtoZpR2JgTsPaG6dz1EYS"
            argocdServerAdminPasswordMtime: "2024-01-01T00:00:00Z"

        # ======================================================================
        # ARGO CD SERVER CONFIGURATION
        # ======================================================================
        server:
          extraArgs:
            - --insecure
          service:
            type: ClusterIP

        # ======================================================================
        # COMPONENT-SPECIFIC SETTINGS
        # ======================================================================
        ha:
          enabled: false
        applicationSet:
          enabled: false
        notifications:
          enabled: false
        redis:
          enabled: true
        redis-ha:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
==> kubernetes/manifests/argocd-ingress/certificate.yaml <==
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-server-tls-staging
  namespace: argocd
spec:
  secretName: argocd-server-tls-staging
  issuerRef:
    name: cloudflare-staging
    kind: ClusterIssuer
  dnsNames:
  - argocd.core01.prod.gglohh.top

==> kubernetes/manifests/argocd-ingress/ingress.yaml <==
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server-https
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argocd.core01.prod.gglohh.top`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
  tls:
    secretName: argocd-server-tls-staging

==> kubernetes/manifests/authentik-ingress/certificate.yaml <==
# Code Analysis: Manages the TLS certificate for Authentik using your existing ClusterIssuer.
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: authentik-tls-staging
  namespace: authentik
spec:
  secretName: authentik-tls-staging
  issuerRef:
    name: cloudflare-staging # Uses your existing issuer
    kind: ClusterIssuer
  dnsNames:
  - auth.core01.prod.gglohh.top
==> kubernetes/manifests/authentik-ingress/ingress.yaml <==
# Code Analysis: Exposes the Authentik service via Traefik, following your existing pattern.
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: authentik-https
  namespace: authentik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`auth.core01.prod.gglohh.top`)
      kind: Rule
      services:
        # The Authentik helm chart creates a service named 'authentik-server'
        - name: authentik-server
          port: http
  tls:
    secretName: authentik-tls-staging
==> kubernetes/manifests/authentik-ingress/namespace.yaml <==
# [ADD START] 明确创建 authentik 命名空间，避免资源引用失败
apiVersion: v1
kind: Namespace
metadata:
  name: authentik
# [ADD END]
==> kubernetes/manifests/cluster-issuer/issuer.yaml <==
# kubernetes/manifests/cluster-issuer/issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-staging
spec:
  acme:
    email: 1405630484@qq.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    solvers:
    - dns01:
        cloudflare:
          # email removed when using apiTokenSecretRef (token mode)
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
==> kubernetes/manifests/cluster-issuer/secret.yaml <==
# kubernetes/manifests/cluster-issuer/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
==> kubernetes/manifests/frps/config.yaml <==
# kubernetes/manifests/frps/config.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: frps-config
  namespace: frp-system
data:
  frps.toml: |
    # --- Core bind ---
    bindPort = 7000

    # --- Auth (insecure by design) ---
    [auth]
    method = "token"
    token = "password"  # as requested: simple, low-security

    # --- Subdomain host for HTTP vhosts ---
    subdomainHost = "core01.prod.gglohh.top"

    # --- HTTP vhost for browser side (Traefik terminates TLS at 443) ---
    vhostHTTPPort = 8080
    # vhostHTTPSPort is not needed because TLS is terminated by Traefik

    # --- Web dashboard (insecure by design) ---
    [webServer]
    addr = "0.0.0.0"
    port = 7500
    user = "admin"
    password = "password"
==> kubernetes/manifests/frps/deployment.yaml <==
# kubernetes/manifests/frps/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frps-server
  namespace: frp-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frps
  template:
    metadata:
      labels:
        app: frps
    spec:
      containers:
      - name: frps
        image: snowdreamtech/frps:0.58.1
        args: ["-c", "/etc/frp/frps.toml"]
        ports:
        - containerPort: 7000
          name: frps-bind
        - containerPort: 8080
          name: vhost-http
        - containerPort: 7500
          name: dashboard
        # envFrom removed (no longer needed)
        volumeMounts:
        - name: config-volume
          mountPath: /etc/frp
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: frps-config
==> kubernetes/manifests/frps/namespace.yaml <==
# Code Analysis: Creates a dedicated namespace for frps to keep resources isolated.
apiVersion: v1
kind: Namespace
metadata:
  name: frp-system
==> kubernetes/manifests/frps/service-and-routes.yaml <==
# kubernetes/manifests/frps/service-and-routes.yaml
apiVersion: v1
kind: Service
metadata:
  name: frps-service
  namespace: frp-system
spec:
  selector:
    app: frps
  ports:
  - name: frps-bind
    port: 7000
  - name: vhost-http
    port: 8080
  - name: dashboard
    port: 7500
---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: frps-tcp-ingress
  namespace: frp-system
spec:
  entryPoints:
    - frps  # must exist in Traefik static config; deploy.sh will ensure it
  routes:
  - match: HostSNI(`*`)
    services:
    - name: frps-service
      port: 7000
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: 
  name: frps-http-ingress
  namespace: frp-system
  annotations:
    # [ADD START]
    argocd.argoproj.io/sync-wave: "1"
    # [ADD END]
spec:
  entryPoints: 
    - websecure
  routes: 
  - kind: Rule
    match: HostRegexp(`e-{subdomain:[a-z0-9-]+}\.core01\.prod\.gglohh\.top`)
    services: 
    - name: frps-service
      port: 8080
  tls: 
    secretName: wildcard-core01-prod-gglohh-top-tls

==> kubernetes/manifests/frps/wildcard-certificate.yaml <==
# 修改范围：增加同步波次注解，确保证书先于 IngressRoute
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-core01-prod-gglohh-top
  namespace: frp-system
  annotations:
    # [ADD START]
    argocd.argoproj.io/sync-wave: "0"
    # [ADD END]
spec:
  secretName: wildcard-core01-prod-gglohh-top-tls
  issuerRef:
    name: cloudflare-staging
    kind: ClusterIssuer
  dnsNames:
  - "*.core01.prod.gglohh.top"
==> kubernetes/manifests/n8n/certificate.yaml <==
# kubernetes/manifests/n8n/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: n8n-tls-staging
  namespace: n8n # MUST be in the same namespace as the Ingress
spec:
  secretName: n8n-tls-staging # This name is referenced by the Ingress created by the Helm chart
  issuerRef:
    name: cloudflare-staging
    kind: ClusterIssuer
  dnsNames:
  - n8n.core01.prod.gglohh.top
==> kubernetes/manifests/provisioner/certificate.yaml <==
# 修改范围：在 metadata 增加 Argo CD 同步波次注解（证书先于 IngressRoute）
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: portal-tls-staging
  namespace: provisioner
  annotations:
    # [ADD START] ensure cert before ingress
    argocd.argoproj.io/sync-wave: "0"
    # [ADD END]
spec:
  secretName: portal-tls-staging
  issuerRef:
    name: cloudflare-staging
    kind: ClusterIssuer
  dnsNames:
  - portal.core01.prod.gglohh.top
==> kubernetes/manifests/provisioner/deployment.yaml <==
# 修改范围：整段 container 配置（替换镜像为可公开拉取的 echo-server）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: provisioner-gateway
  namespace: provisioner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: provisioner-gateway
  template:
    metadata:
      labels:
        app: provisioner-gateway
    spec:
      containers:
      - name: gateway
        image: ealen/echo-server:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 3
==> kubernetes/manifests/provisioner/ingress.yaml <==
# 修改范围：在 metadata 增加 Argo CD 同步波次注解（IngressRoute 晚于证书）
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: provisioner-https
  namespace: provisioner
  annotations:
    # [ADD START] ensure ingress after cert
    argocd.argoproj.io/sync-wave: "1"
    # [ADD END]
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`portal.core01.prod.gglohh.top`) && PathPrefix(`/`)
    kind: Rule
    services:
    - name: provisioner-gateway
      port: 80
  tls:
    secretName: portal-tls-staging
==> kubernetes/manifests/provisioner/namespace.yaml <==
# [ADD START]
apiVersion: v1
kind: Namespace
metadata:
  name: provisioner
# [ADD END]
==> kubernetes/manifests/provisioner/service.yaml <==
# [ADD START]
apiVersion: v1
kind: Service
metadata:
  name: provisioner-gateway
  namespace: provisioner
spec:
  selector:
    app: provisioner-gateway
  ports:
  - name: http
    port: 80
    targetPort: 8080
# [ADD END]
==> ./deploy.sh <==
#!/usr/bin/env bash

# ==============================================================================
#
#       PERSONAL CLUSTER DEPLOYMENT BOOTSTRAPPER (v23.1 - Static Password)
#
# ==============================================================================
#
#   VERSION 23.1 CHANGE LOG:
#   - PASSWORD MANAGEMENT: Implemented static password for Argo CD 'admin' user
#     based on official Helm chart v8.2.7 documentation. The password is now
#     consistently 'password'.
#   - BOOTSTRAP PROCESS: Modified both the initial 'helm install' command and the
#     GitOps Application manifest (`argocd-app.yaml`) to include the bcrypt-hashed
#     password. This ensures correctness at creation and prevents configuration
#     drift during self-healing.
#   - VERIFICATION: Removed logic for retrieving a random password. The final
#     output now displays the static credentials.
#
# ==============================================================================

set -eo pipefail

# --- [SECTION 1: CONFIGURATION VARIABLES] ---
readonly VPS_IP="172.245.187.113"
readonly DOMAIN_NAME="gglohh.top"
readonly SITE_CODE="core01"
readonly ENVIRONMENT="prod"
readonly K3S_CLUSTER_TOKEN="admin" # Simple, as requested
readonly ARGOCD_ADMIN_PASSWORD="password"

# --- ACME & DNS (Cloudflare) ---
# NOTE: Hard-coded, insecure by design, as requested
readonly ACME_EMAIL="1405630484@qq.com"
readonly CF_API_TOKEN="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
readonly WILDCARD_FQDN="*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"   # *.core01.prod.gglohh.top
readonly CF_PROXIED="false"

# --- Software Versions ---
readonly K3S_VERSION="v1.33.3+k3s1"

# --- Internal Settings ---
readonly ETCD_PROJECT_NAME="personal-cluster-etcd"
readonly ETCD_CONTAINER_NAME="core-etcd"
readonly ETCD_DATA_DIR="/opt/etcd/data"
readonly ETCD_CONTAINER_USER_ID=1001
readonly ETCD_NETWORK_NAME="${ETCD_PROJECT_NAME}_default"
readonly KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
readonly USER_KUBECONFIG_PATH="${HOME}/.kube/config"
readonly TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
readonly LOG_FILE_NAME="deployment-bootstrap-${TIMESTAMP}.log"
readonly LOG_FILE="$(pwd)/${LOG_FILE_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly PORTAL_FQDN="portal.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"  # portal.core01.prod.gglohh.top
readonly KUBELET_CONFIG_PATH="/etc/rancher/k3s/kubelet.config"

# --- [START OF PASSWORD FIX] ---
# Statically define the bcrypt hash for the password 'password'.
# This avoids re-calculating it on every run and makes the script's intent clearer.
readonly ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$Xx3c/ILSzwZfp2wHhoPxFOwH4yFp3MepBtoZpR2JgTsPaG6dz1EYS'
# --- [END OF PASSWORD FIX] ---

# --- [NEW - SECTION 2.1: Cloudflare DNS Helpers] ---
# Purpose: Manage wildcard A record state-driven via CF API (idempotent, non-interactive).
cf_api() {
  # $1: method, $2: path, $3: data (optional)
  local method="$1"; local path="$2"; local data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sS -X "${method}" "https://api.cloudflare.com/client/v4${path}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data-raw "${data}"
  else
    curl -sS -X "${method}" "https://api.cloudflare.com/client/v4${path}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json"
  fi
}

wait_apiserver_ready() {
  # $1 timeout seconds (default 180), $2 interval seconds (default 5)
  local timeout_s="${1:-180}"
  local interval_s="${2:-5}"
  log_info "Checking Kubernetes apiserver readiness (/readyz) with timeout ${timeout_s}s..."
  if ! timeout "${timeout_s}s" bash -lc \
    'until kubectl --request-timeout=10s get --raw=/readyz >/dev/null 2>&1; do echo "    ...apiserver not ready yet"; sleep '"${interval_s}"'; done'; then
    log_error_and_exit "Kubernetes apiserver is not ready within ${timeout_s}s."
  fi
  log_success "Kubernetes apiserver reports Ready."
}

ensure_cloudflare_wildcard_a() {
  # Non-interactive, state-driven; creates or updates wildcard A only when needed.
  log_step 0 "Ensure Cloudflare wildcard DNS"
  local zone_name="${DOMAIN_NAME}"
  local sub_wildcard="*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"

  log_info "Resolving Cloudflare Zone ID for ${zone_name} ..."
  local zone_resp; zone_resp=$(cf_api GET "/zones?name=${zone_name}")
  local zone_id; zone_id=$(echo "${zone_resp}" | jq -r '.result[0].id')
  if [[ -z "${zone_id}" || "${zone_id}" == "null" ]]; then
    log_error_and_exit "Cloudflare zone '${zone_name}' not found."
  fi
  log_success "Cloudflare Zone ID acquired: ${zone_id}"

  log_info "Checking existing DNS record for ${sub_wildcard} (type A) ..."
  # URL-encode "*." as %2A.
  local qname; qname="%2A.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
  local rec_resp; rec_resp=$(cf_api GET "/zones/${zone_id}/dns_records?type=A&name=${qname}")
  local rec_id; rec_id=$(echo "${rec_resp}" | jq -r '.result[0].id // empty')
  local rec_ip; rec_ip=$(echo "${rec_resp}" | jq -r '.result[0].content // empty')

  if [[ -n "${rec_id}" ]]; then
    if [[ "${rec_ip}" == "${VPS_IP}" ]]; then
      log_success "Wildcard A already correct: ${sub_wildcard} -> ${VPS_IP} (no action)."
    else
      log_info "Updating wildcard A to ${VPS_IP} ..."
      local payload; payload=$(jq -nc --arg name "${sub_wildcard}" --arg ip "${VPS_IP}" --argjson proxied ${CF_PROXIED} \
        '{type:"A", name:$name, content:$ip, ttl:1, proxied:$proxied}')
      local up_resp; up_resp=$(cf_api PUT "/zones/${zone_id}/dns_records/${rec_id}" "${payload}")
      if [[ "$(echo "${up_resp}" | jq -r '.success')" != "true" ]]; then
        echo "${up_resp}" | sed 's/^/CF-ERR: /g'
        log_error_and_exit "Failed to update wildcard A record."
      fi
      log_success "Wildcard A updated: ${sub_wildcard} -> ${VPS_IP}"
    fi
  else
    log_info "Creating wildcard A ${sub_wildcard} -> ${VPS_IP} ..."
    local payload; payload=$(jq -nc --arg name "${sub_wildcard}" --arg ip "${VPS_IP}" --argjson proxied ${CF_PROXIED} \
      '{type:"A", name:$name, content:$ip, ttl:1, proxied:$proxied}')
    local cr_resp; cr_resp=$(cf_api POST "/zones/${zone_id}/dns_records" "${payload}")
    if [[ "$(echo "${cr_resp}" | jq -r '.success')" != "true" ]]; then
      echo "${cr_resp}" | sed 's/^/CF-ERR: /g'
      log_error_and_exit "Failed to create wildcard A record."
    fi
    log_success "Wildcard A created: ${sub_wildcard} -> ${VPS_IP}"
  fi

  log_info "Verifying public resolution via 1.1.1.1 ..."
  local probe_fqdn="test.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
  if ! timeout 60 bash -lc "until dig +short @1.1.1.1 ${probe_fqdn} A | grep -q '^${VPS_IP}\$'; do echo '    ...waiting DNS...'; sleep 5; done"; then
    log_warn "Public resolution for ${probe_fqdn} did not return ${VPS_IP} within timeout."
  else
    log_success "Public DNS resolution OK for wildcard subdomain."
  fi
}

# --- [SECTION 2: LOGGING & DIAGNOSTICS] ---
log_step() { printf "\n\n\033[1;34m# ============================================================================== #\033[0m\n"; printf "\033[1;34m# STEP %s: %s (Timestamp: %s)\033[0m\n" "$1" "$2" "$(date -u --iso-8601=seconds)"; printf "\033[1;34m# ============================================================================== #\033[0m\n\n"; }
log_info() { echo "--> INFO: $1"; }
log_warn() { echo -e "\033[1;33m⚠️  WARN: $1\033[0m"; }
log_success() { echo -e "\033[1;32m✅ SUCCESS:\033[0m $1"; }
log_error_and_exit() { echo -e "\n\033[1;31m❌ FATAL ERROR:\033[0m $1" >&2; echo -e "\033[1;31mDeployment failed. See ${LOG_FILE} for full details.\033[0m" >&2; exit 1; }

run_with_retry() {
    local cmd="$1"
    local description="$2"
    local timeout_seconds="$3"
    local interval_seconds="${4:-10}"
    
    log_info "Verifying: ${description} (Timeout: ${timeout_seconds}s)"
    if ! timeout "${timeout_seconds}s" bash -c -- "until ${cmd} &>/dev/null; do printf '    ...waiting...\\n'; sleep ${interval_seconds}; done"; then
        log_warn "Condition '${description}' was NOT met within the timeout period."
        return 1
    fi
    log_success "Verified: ${description}."
    return 0
}

# Single-shot job logs collector for helm jobs
print_job_pod_logs() {
    # $1: namespace, $2: job name
    local ns="$1"; local job="$2"
    echo "==== [DIAG] Logs for Job ${ns}/${job} ===="
    local pods
    pods=$(kubectl -n "${ns}" get pods --selector=job-name="${job}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    if [[ -z "${pods}" ]]; then
        echo "(no pods found for job ${job})"
        return 0
    fi
    for p in ${pods}; do
        echo "--- Pod: ${p} (containers) ---"
        kubectl -n "${ns}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true
        echo
        for c in $(kubectl -n "${ns}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null); do
            echo "----- Container: ${c} -----"
            kubectl -n "${ns}" logs "${p}" -c "${c}" --tail=500 2>/dev/null || true
        done
    done
}

# Wait helm install job to succeed; no early-exit on BackOff (controller may retry)
wait_helm_job_success() {
    # $1: namespace, $2: job name, $3: timeout seconds
    local ns="$1"; local job="$2"; local timeout_s="$3"
    log_info "Waiting Job ${ns}/${job} to succeed..."
    if ! timeout "${timeout_s}s" bash -lc "until [[ \$(kubectl -n ${ns} get job ${job} -o jsonpath='{.status.succeeded}' 2>/dev/null) == 1 ]]; do sleep 5; done"; then
        log_warn "Timeout waiting Job ${ns}/${job} to succeed."
        print_job_pod_logs "${ns}" "${job}"
        return 1
    fi
    log_success "Job ${ns}/${job} succeeded."
    return 0
}

# Wait all required Traefik CRDs available after traefik-crd job
wait_for_traefik_crds() {
    log_info "Waiting for Traefik CRDs to be established in API..."
    local crds=(
        ingressroutes.traefik.io
        ingressroutetcps.traefik.io
        ingressrouteudps.traefik.io
        middlewares.traefik.io
        traefikservices.traefik.io
        tlsoptions.traefik.io
        serverstransports.traefik.io
    )
    for c in "${crds[@]}"; do
        if ! run_with_retry "kubectl get crd ${c} >/dev/null 2>&1" "CRD ${c} present" 180 5; then
            log_error_and_exit "Required CRD ${c} not found after traefik-crd installation."
        fi
    done
    log_success "All Traefik CRDs are present."
}

# [New] Dump HelmChart & HelmChartConfig valuesContent once for high-value diagnostics
diagnose_traefik_values_merge() {
    echo "==== [DIAG] HelmChart kube-system/traefik (spec.valuesContent) ===="
    kubectl -n kube-system get helmchart traefik -o jsonpath='{.spec.valuesContent}' 2>/dev/null || true
    echo
    echo "==== [DIAG] HelmChartConfig kube-system/traefik (spec.valuesContent) ===="
    kubectl -n kube-system get helmchartconfig traefik -o jsonpath='{.spec.valuesContent}' 2>/dev/null || true
    echo
    echo "==== [DIAG] Traefik Service (full manifest) ===="
    kubectl -n kube-system get svc traefik -o yaml 2>/dev/null || true
}

# --- New: compact diagnostic for Traefik installation ---
diagnose_traefik_install() {
    # Single-shot diagnostics, no loops. Minimal but high-value.
    echo "==== [DIAG] kube-system basic resources ===="
    kubectl -n kube-system get deploy,po,svc,helmchart 2>/dev/null || true

    echo "==== [DIAG] helm-controller status ===="
    kubectl -n kube-system get deploy/helm-controller -o yaml 2>/dev/null || true
    kubectl -n kube-system logs deploy/helm-controller --tail=100 2>/dev/null || true

    echo "==== [DIAG] HelmChart traefik (if any) ===="
    kubectl -n kube-system get helmchart traefik -o yaml 2>/dev/null || true

    echo "==== [DIAG] Traefik deployment (if any) ===="
    kubectl -n kube-system get deploy/traefik -o yaml 2>/dev/null || true
    kubectl -n kube-system logs deploy/traefik --tail=200 2>/dev/null || true

    echo "==== [DIAG] Traefik service (if any) ===="
    kubectl -n kube-system get svc/traefik -o yaml 2>/dev/null || true

    echo "==== [DIAG] Recent kube-system events ===="
    kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -n 50 2>/dev/null || true
}

# --- [SECTION 3: DEPLOYMENT FUNCTIONS] ---

function perform_system_cleanup() {
    log_step 1 "System Cleanup"
    log_info "This step will eradicate all traces of previous K3s and this project's ETCD."
    
    log_info "Stopping k3s, docker, and containerd services..."
    systemctl stop k3s.service &>/dev/null || true
    systemctl disable k3s.service &>/dev/null || true
    
    if command -v docker &>/dev/null && systemctl is-active --quiet docker.service; then
        log_info "Forcefully removing project's ETCD container and network..."
        docker rm -f "${ETCD_CONTAINER_NAME}" &>/dev/null || true
        docker network rm "${ETCD_NETWORK_NAME}" &>/dev/null || true
    else
        log_warn "Docker not running or not installed. Skipping Docker resource cleanup."
    fi
    
    log_info "Running K3s uninstaller and cleaning up filesystem..."
    if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
        /usr/local/bin/k3s-uninstall.sh &>/dev/null
    fi
    rm -rf /var/lib/rancher/k3s /etc/rancher /var/lib/kubelet /run/flannel /run/containerd /var/lib/containerd /tmp/k3s-*
    rm -rf "${ETCD_DATA_DIR}"
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env "${KUBELET_CONFIG_PATH}" "${KUBECONFIG_PATH}"
    rm -rf "${HOME}/.kube"

    log_info "Reloading systemd and cleaning journals for k3s and docker..."
    systemctl daemon-reload
    # --- [MODIFY START] targeted journal handling (do not vacuum unrelated logs) ---
    log_info "Rotating systemd journal only (no global vacuum; keep unrelated services' logs)..."
    journalctl --rotate || true
    # --- [MODIFY END] ---
    
    log_success "System cleanup complete."
}

function deploy_etcd() {
    log_step 2 "Deploy and Verify External ETCD"
    
    log_info "Preparing ETCD data directory with correct permissions for UID ${ETCD_CONTAINER_USER_ID}..."
    mkdir -p "${ETCD_DATA_DIR}"
    chown -R "${ETCD_CONTAINER_USER_ID}:${ETCD_CONTAINER_USER_ID}" "${ETCD_DATA_DIR}"
    
    log_info "Deploying ETCD via Docker..."
    docker run -d --restart unless-stopped \
      -p 127.0.0.1:2379:2379 \
      -v "${ETCD_DATA_DIR}":/bitnami/etcd/data \
      --name "${ETCD_CONTAINER_NAME}" \
      -e ALLOW_NONE_AUTHENTICATION=yes \
      bitnami/etcd:latest >/dev/null
      
    log_success "ETCD container started."

    if ! run_with_retry "curl --fail --silent http://127.0.0.1:2379/health" "ETCD to be healthy" 60 5; then
        log_info "ETCD health check failed. Dumping container logs for diagnosis:"
        docker logs "${ETCD_CONTAINER_NAME}"
        log_error_and_exit "ETCD deployment failed."
    fi
}

function install_k3s() {
    log_step 3 "Install and Verify K3S"

    log_info "Preparing K3s manifest and configuration directories..."
    mkdir -p /var/lib/rancher/k3s/server/manifests
    mkdir -p "$(dirname "${KUBELET_CONFIG_PATH}")"

  log_info "Creating Traefik HelmChartConfig with CRD provider and frps (7000/TCP) entryPoint..."
  cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml << 'EOF'
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    # 启用 CRD/Ingress 两类 provider，并让 Ingress 使用已发布的服务做状态回填
    providers:
      kubernetesCRD:
        enabled: true
      kubernetesIngress:
        publishedService:
          enabled: true

    # 正确的入口点定义（每个入口点内使用 expose.default）
    ports:
      web:
        port: 8000
        exposedPort: 80
        expose:
          default: true
      websecure:
        port: 8443
        exposedPort: 443
        expose:
          default: true
      frps:
        port: 7000
        exposedPort: 7000
        protocol: TCP
        expose:
          default: true

    # 为 websecure 显式启用 TLS（由 IngressRoute/Certificate 控制证书）
    additionalArguments:
      - "--entrypoints.websecure.http.tls=true"
EOF

    cat > "${KUBELET_CONFIG_PATH}" << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF
    log_success "K3s customization manifests created."

    log_info "Installing K3s ${K3S_VERSION}..."
    local install_cmd=(
        "curl -sfL https://get.k3s.io |"
        "INSTALL_K3S_VERSION='${K3S_VERSION}'"
        "K3S_TOKEN='${K3S_CLUSTER_TOKEN}'"
        "sh -s - server"
        "--cluster-init"
        "--datastore-endpoint='http://127.0.0.1:2379'"
        "--tls-san='${VPS_IP}'"
        "--flannel-backend=host-gw"
        "--kubelet-arg='config=${KUBELET_CONFIG_PATH}'"
    )
    eval "${install_cmd[*]}"
    log_success "K3s installation script finished."

    log_info "Setting up kubeconfig for user..."
    mkdir -p "$(dirname "${USER_KUBECONFIG_PATH}")"
    cp "${KUBECONFIG_PATH}" "${USER_KUBECONFIG_PATH}"
    chown "$(id -u):$(id -g)" "${USER_KUBECONFIG_PATH}"
    export KUBECONFIG="${USER_KUBECONFIG_PATH}"

    if ! run_with_retry "kubectl get node $(hostname | tr '[:upper:]' '[:lower:]') --no-headers | awk '{print \$2}' | grep -q 'Ready'" "K3s node to be Ready" 180; then
        log_info "K3s node did not become ready. Dumping K3s service logs:"
        journalctl -u k3s.service --no-pager -n 500
        log_error_and_exit "K3s cluster verification failed."
    fi

    # Wait for k3s HelmChart resources
    log_info "Waiting for HelmChart 'traefik' to appear..."
    if ! run_with_retry "kubectl -n kube-system get helmchart traefik >/dev/null 2>&1" "HelmChart/traefik exists" 240 5; then
        log_error_and_exit "HelmChart 'traefik' not found; Traefik installation not started."
    fi
    log_success "HelmChart/traefik detected."

    # Wait CRD job success then ensure CRDs visible at API level
    log_info "Waiting for job/helm-install-traefik-crd to succeed..."
    if ! wait_helm_job_success "kube-system" "helm-install-traefik-crd" 360; then
        log_error_and_exit "job/helm-install-traefik-crd failed."
    fi
    wait_for_traefik_crds

    # Wait Traefik install job success (controller will retry if first attempt failed)
    log_info "Waiting for job/helm-install-traefik to succeed..."
    if ! wait_helm_job_success "kube-system" "helm-install-traefik" 600; then
        log_error_and_exit "job/helm-install-traefik failed."
    fi

    # Deployment + Service port verification
    log_info "Waiting for Traefik Deployment to be created..."
    if ! run_with_retry "kubectl -n kube-system get deploy traefik >/dev/null 2>&1" "Deployment/traefik exists" 240 5; then
        log_error_and_exit "Traefik Deployment not created."
    fi
    log_info "Waiting for Traefik Deployment rollout..."
    if ! run_with_retry "kubectl -n kube-system rollout status deploy/traefik --timeout=90s" "Traefik Deployment rollout" 480 10; then
        log_error_and_exit "Traefik Deployment failed to roll out."
    fi
    log_success "Traefik Deployment is Ready."

    log_info "Checking Service/traefik exposes required ports (80, 443, 7000)..."
    local ports_cmd="kubectl -n kube-system get svc traefik -o jsonpath='{.spec.ports[*].port}' | tr ' ' '\n' | sort -n | tr '\n' ' '"
    if ! run_with_retry "${ports_cmd} | grep -Eq '\b80\b' && ${ports_cmd} | grep -Eq '\b443\b' && ${ports_cmd} | grep -Eq '\b7000\b'" "Service/traefik to expose 80,443,7000" 300 10; then
        echo "Observed ports: $(eval ${ports_cmd} 2>/dev/null || true)"
        diagnose_traefik_values_merge
        log_error_and_exit "Traefik Service does not expose required ports."
    fi
    log_success "Traefik Service exposes 80/443/7000."
}

# --- New: verify frps entryPoint & wildcard TLS readiness ---
function verify_frps_entrypoint_and_tls() {
    log_step 6 "Verify frps entryPoint listening and wildcard TLS readiness"

    # 1) Verify IngressRouteTCP exists and references entryPoint 'frps'
    if ! run_with_retry "kubectl -n frp-system get ingressroutetcp frps-tcp-ingress >/dev/null 2>&1" "IngressRouteTCP 'frps-tcp-ingress' present" 120 5; then
        log_info "Dumping IngressRouteTCP list in frp-system:"
        kubectl -n frp-system get ingressroutetcp -o yaml || true
        log_error_and_exit "IngressRouteTCP 'frps-tcp-ingress' not found."
    fi
    log_success "IngressRouteTCP 'frps-tcp-ingress' is present."

    # 2) Verify Traefik service exposes 7000 and external TCP is reachable
    #    This uses a TCP connect check against VPS_IP:7000
    local tcp_check_cmd="timeout 2 bash -lc '</dev/tcp/${VPS_IP}/7000' >/dev/null 2>&1"
    if ! run_with_retry "${tcp_check_cmd}" "External TCP connectivity to ${VPS_IP}:7000" 180 5; then
        log_info "Failed TCP connect to ${VPS_IP}:7000. Dumping diagnostics:"
        kubectl -n kube-system get svc traefik -o wide || true
        kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide || true
        kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --tail=100 || true
        log_warn "Possible external firewall or provider-level filtering on port 7000."
        log_error_and_exit "frps entryPoint is not externally reachable on ${VPS_IP}:7000."
    fi
    log_success "frps entryPoint is externally reachable on ${VPS_IP}:7000."

    # 3) Verify wildcard Certificate in frp-system namespace
    #    Name should match your manifest (e.g. wildcard-core01-prod-gglohh-top)
    local cert_name="wildcard-core01-prod-gglohh-top"
    if ! kubectl -n frp-system get certificate "${cert_name}" >/dev/null 2>&1; then
        log_warn "Certificate '${cert_name}' not found in namespace 'frp-system'. Skipping Ready wait."
        log_info "List certificates in frp-system for reference:"
        kubectl -n frp-system get certificate || true
    else
        if ! run_with_retry "kubectl -n frp-system wait --for=condition=Ready certificate/${cert_name} --timeout=100s" "Wildcard Certificate '${cert_name}' to be Ready" 320 10; then
            log_info "Certificate not Ready. Dumping certificate and cert-manager logs:"
            kubectl -n frp-system describe certificate "${cert_name}" || true
            kubectl -n cert-manager logs -l app.kubernetes.io/instance=cert-manager --all-containers --tail=100 || true
            log_error_and_exit "Wildcard certificate '${cert_name}' not Ready."
        fi
        log_success "Wildcard certificate '${cert_name}' is Ready."
    fi

    # 4) Verify TLS Secret exists for Traefik IngressRoute usage
    local tls_secret="wildcard-core01-prod-gglohh-top-tls"
    if ! run_with_retry "kubectl -n frp-system get secret ${tls_secret} >/dev/null 2>&1" "TLS Secret '${tls_secret}' present in frp-system" 120 5; then
        log_info "Dumping secrets in frp-system:"
        kubectl -n frp-system get secrets || true
        log_error_and_exit "TLS Secret '${tls_secret}' is missing in frp-system."
    fi
    log_success "TLS Secret '${tls_secret}' present in frp-system (for HTTPS on wildcard)."
}

function bootstrap_gitops() {
    log_step 4 "Bootstrap GitOps Engine (Argo CD)"

    log_info "Bootstrapping Argo CD via Helm..."
    log_info "This initial install will create CRDs and components with static credentials."

    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || helm repo update

    # --- [START OF PASSWORD FIX] ---
    # Inject the bcrypt-hashed password and the '--insecure' flag during the initial Helm install.
    # This ensures the 'argocd-secret' is created with the correct static password from the very beginning,
    # preventing the creation of the 'argocd-initial-admin-secret' with a random password.
    helm upgrade --install argocd argo/argo-cd \
        --version 8.2.7 \
        --namespace argocd --create-namespace \
        --set-string "server.extraArgs={--insecure}" \
        --set-string "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
        --set-string "configs.secret.argocdServerAdminPasswordMtime=$(date -u --iso-8601=seconds)" \
        --wait --timeout=15m
    # --- [END OF PASSWORD FIX] ---

    log_success "Argo CD components and CRDs installed via Helm with static password."

    log_info "Applying Argo CD application manifests to enable GitOps self-management..."
    kubectl apply -f kubernetes/bootstrap/argocd-app.yaml

    log_info "Waiting for Argo CD to sync its own application resource..."
    if ! run_with_retry "kubectl get application/argocd -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Argo CD to become Healthy and self-managed" 300; then
        log_info "Argo CD self-management sync failed. Dumping application status:"
        kubectl get application/argocd -n argocd -o yaml
        log_error_and_exit "Argo CD bootstrap failed at self-management step."
    fi

    log_success "Argo CD has been bootstrapped and is now self-managing via GitOps."
}

function deploy_applications() {
    log_step 5 "Deploy Core Applications via GitOps"

    # 1) 仅提交 cert-manager Application
    log_info "Applying cert-manager Application (only)..."
    kubectl apply -f kubernetes/apps/cert-manager-app.yaml

    # 2) API server 就绪门控，避免 Admission 注册过程的瞬时失败
    wait_apiserver_ready 300 5

    # 3) 等待 cert-manager 核心 Deployment 实际就绪（比直接看 Argo Application 更贴近事实）
    log_info "Waiting for cert-manager Deployments to become Available..."
    timeout 600 bash -lc 'until kubectl -n cert-manager get deploy cert-manager cert-manager-webhook >/dev/null 2>&1; do echo "    ...waiting for cert-manager deployments to appear"; sleep 5; done'
    if ! kubectl -n cert-manager rollout status deploy/cert-manager --timeout=7m; then
    kubectl -n cert-manager describe deploy cert-manager || true
    kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager --tail=200 || true
    log_error_and_exit "Deployment cert-manager failed to roll out."
    fi
    if ! kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=7m; then
    kubectl -n cert-manager describe deploy cert-manager-webhook || true
    kubectl -n cert-manager logs -l app.kubernetes.io/name=webhook --tail=200 || true
    log_error_and_exit "Deployment cert-manager-webhook failed to roll out."
    fi
    log_success "cert-manager core Deployments are Available."

    # 4) 再做一次 apiserver 就绪门控（webhook/CRD 安装后常见波动）
    wait_apiserver_ready 300 5

    # 5) 从 Argo 视角等待 cert-manager Application Healthy（延长超时以适应首次安装）
    log_info "Waiting for Cert-Manager application to become Healthy in Argo CD..."
    if ! run_with_retry "kubectl get application/cert-manager -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Cert-Manager Argo CD App to be Healthy" 100 10; then
    kubectl get application/cert-manager -n argocd -o yaml || true
    kubectl -n cert-manager get pods -o wide || true
    kubectl -n cert-manager get events --sort-by=.lastTimestamp | tail -n 50 || true
    kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 50 || true
    log_error_and_exit "Cert-Manager deployment via Argo CD failed (not Healthy within timeout)."
    fi
    log_success "Cert-Manager application is Healthy in Argo CD."

    log_info "Applying remaining Applications (excluding n8n)..."
    # frps 独立管理
    kubectl apply -f kubernetes/apps/frps-app.yaml
    # core-manifests 仅包含 cluster-issuer
    kubectl apply -f kubernetes/apps/core-manifests-app.yaml
    # 新增两个静态 ingress 应用
    kubectl apply -f kubernetes/apps/argocd-ingress-app.yaml

    # 新增：provisioner 网关 Application
    kubectl apply -f kubernetes/apps/provisioner-app.yaml

    kubectl apply -f kubernetes/apps/authentik-ingress-static-app.yaml

    # 逐个等待 Healthy（放宽超时以适应首次签发/拉起）
    log_info "Waiting for core-manifests application to become Healthy..."
    if ! run_with_retry "kubectl get application/core-manifests -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "core-manifests Argo CD App to be Healthy" 600 10; then
    kubectl get application/core-manifests -n argocd -o yaml || true
    log_error_and_exit "core-manifests not Healthy."
    fi

    log_info "Waiting for argocd-ingress application to become Healthy..."
    if ! run_with_retry "kubectl get application/argocd-ingress -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "argocd-ingress Argo CD App to be Healthy" 600 10; then
    kubectl get application/argocd-ingress -n argocd -o yaml || true
    log_error_and_exit "argocd-ingress not Healthy."
    fi

    # 等待 provisioner Healthy（证书/Ingress 创建可能略慢，放宽超时）
    log_info "Waiting for provisioner application to become Healthy..."
    if ! run_with_retry "kubectl get application/provisioner -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "provisioner Argo CD App to be Healthy" 600 10; then
    kubectl get application/provisioner -n argocd -o yaml || true
    kubectl -n provisioner get pods -o wide || true
    kubectl -n provisioner get events --sort-by=.lastTimestamp | tail -n 50 || true
    log_error_and_exit "provisioner not Healthy."
    fi
    log_success "provisioner application is Healthy."

    log_info "Waiting for authentik-ingress-static application to become Healthy..."
    if ! run_with_retry "kubectl get application/authentik-ingress-static -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "authentik-ingress-static Argo CD App to be Healthy" 600 10; then
    kubectl get application/authentik-ingress-static -n argocd -o yaml || true
    log_error_and_exit "authentik-ingress-static not Healthy."
    fi

    log_success "Remaining applications submitted and Healthy."
}

function final_verification() {
    log_step 6 "Final End-to-End Verification"
    wait_apiserver_ready 180 5

    log_info "Verifying ClusterIssuer 'cloudflare-staging' is ready..."
    if ! run_with_retry "kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m" "ClusterIssuer to be Ready" 120 10; then
        log_info "ClusterIssuer did not become ready. Dumping Cert-Manager logs:"
        kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --all-containers
        log_error_and_exit "ClusterIssuer verification failed."
    fi

    log_info "Verifying ArgoCD IngressRoute certificate has been issued..."
    if ! run_with_retry "kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=5m" "Certificate to be Ready" 300 15; then
        log_info "Certificate did not become ready. Dumping Cert-Manager logs and describing Certificate:"
        kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --all-containers
        kubectl describe certificate -n argocd argocd-server-tls-staging
        log_error_and_exit "Certificate issuance failed."
    fi

    log_info "Performing final reachability check on ArgoCD URL: https://${ARGOCD_FQDN}"
    local check_cmd="curl -k -L -s -o /dev/null -w '%{http_code}' --resolve ${ARGOCD_FQDN}:443:${VPS_IP} https://${ARGOCD_FQDN}/ | grep -q '200'"
    if ! run_with_retry "${check_cmd}" "ArgoCD UI to be reachable (HTTP 200 OK)" 120 10; then
        log_info "ArgoCD UI is not reachable or not returning HTTP 200. Dumping Traefik and Argo CD Server logs:"
        kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
        kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
        log_error_and_exit "End-to-end verification failed."
    fi

    log_info "Verifying Provisioner portal Certificate has been issued..."
    if ! run_with_retry "kubectl wait --for=condition=Ready certificate/portal-tls-staging -n provisioner --timeout=5m" "Portal Certificate to be Ready" 300 15; then
    kubectl -n provisioner describe certificate portal-tls-staging || true
    kubectl -n cert-manager logs -l app.kubernetes.io/instance=cert-manager --all-containers --tail=100 || true
    log_error_and_exit "Portal certificate issuance failed."
    fi

    # [ADD START] wait for provisioner gateway backend readiness and TLS secret presence
    log_info "Waiting for provisioner-gateway Deployment rollout..."
    if ! run_with_retry "kubectl -n provisioner rollout status deploy/provisioner-gateway --timeout=60s" "provisioner-gateway rollout to complete" 240 10; then
    kubectl -n provisioner describe deploy provisioner-gateway || true
    kubectl -n provisioner get pods -o wide || true
    log_error_and_exit "provisioner-gateway failed to roll out."
    fi

    log_info "Waiting for Service/provisioner-gateway endpoints to be populated..."
    if ! run_with_retry "kubectl -n provisioner get endpoints provisioner-gateway -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -E '.+'" "provisioner-gateway Endpoints to be Ready" 240 10; then
    kubectl -n provisioner get endpoints provisioner-gateway -o yaml || true
    log_error_and_exit "provisioner-gateway Endpoints not ready."
    fi

    log_info "Verifying TLS Secret 'portal-tls-staging' exists for Traefik..."
    if ! run_with_retry "kubectl -n provisioner get secret portal-tls-staging >/dev/null 2>&1" "Secret portal-tls-staging available" 180 10; then
    kubectl -n provisioner get secret || true
    log_error_and_exit "TLS Secret 'portal-tls-staging' is missing."
    fi

    # Give Traefik a short window to pick up the secret and router
    log_info "Allowing Traefik to resync TLS assets..."
    sleep 10
    # [ADD END]

    log_info "Performing reachability check on Portal URL: https://${PORTAL_FQDN}"
    # 以 200/3xx 为成功（echo-server 默认 200）
    if ! run_with_retry "curl -k -s -o /dev/null -w '%{http_code}' --resolve ${PORTAL_FQDN}:443:${VPS_IP} https://${PORTAL_FQDN}/ | egrep -q '^(200|30[12])$'" "Provisioner portal to be reachable (HTTP 200/30x)" 180 10; then
    kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --tail=120 || true
    kubectl -n provisioner logs deploy/provisioner-gateway --tail=200 || true
    log_error_and_exit "Portal end-to-end verification failed."
    fi
    log_success "Portal is reachable with valid TLS."

    # --- New: frps entryPoint + wildcard TLS verification ---
    verify_frps_entrypoint_and_tls
}

# --- [SECTION 4: MAIN EXECUTION] ---
main() {
    # Pre-flight checks
    if [[ $EUID -ne 0 ]]; then log_error_and_exit "This script must be run as root."; fi
    if ! command -v docker &> /dev/null || ! systemctl is-active --quiet docker; then log_error_and_exit "Docker is not installed or not running."; fi
    if ! command -v helm &> /dev/null; then log_error_and_exit "Helm is not installed. Please install Helm to proceed."; fi
    if [ ! -d "kubernetes/bootstrap" ] || [ ! -d "kubernetes/apps" ]; then log_error_and_exit "Required directories 'kubernetes/bootstrap' and 'kubernetes/apps' not found. Run from repo root."; fi
    
    touch "${LOG_FILE}" &>/dev/null || { echo "FATAL ERROR: Cannot write to log file at ${LOG_FILE}." >&2; exit 1; }
    exec &> >(tee -a "$LOG_FILE")

    log_info "Deployment Bootstrapper (v23.1) initiated. Full log: ${LOG_FILE}"

    ensure_cloudflare_wildcard_a
    perform_system_cleanup
    deploy_etcd
    install_k3s
    bootstrap_gitops
    deploy_applications
    final_verification

    # --- [START OF PASSWORD FIX] ---
    # The password is now static. The success message is updated to reflect this.
    # The 'argocd-initial-admin-secret' should no longer exist with this new method.
    log_info "Verifying 'argocd-initial-admin-secret' is not present..."
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        log_warn "The 'argocd-initial-admin-secret' still exists, which is unexpected. The password should be managed by 'argocd-secret'."
    else
        log_success "'argocd-initial-admin-secret' is not present, as expected."
    fi
    # --- [END OF PASSWORD FIX] ---

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and managed by ArgoCD."
    echo -e "\n\033[1;33mArgoCD Access Details:\033[0m"
    echo -e "  UI:      \033[1;36mhttps://${ARGOCD_FQDN}\033[0m"
    echo -e "           (NOTE: You must accept the 'staging' or 'untrusted' certificate in your browser)"
    echo -e "  User:    \033[1;36madmin\033[0m"
    echo -e "  Password:\033[1;36m ${ARGOCD_ADMIN_PASSWORD}\033[0m"

    echo -e "\nTo log in via CLI:"
    echo -e "  \033[0;35margocd login ${ARGOCD_FQDN} --username admin --password '${ARGOCD_ADMIN_PASSWORD}' --insecure\033[0m"
    echo -e "\nKubeconfig is available at: ${USER_KUBECONFIG_PATH}"
}

main "$@"


