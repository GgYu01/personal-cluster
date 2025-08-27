cert-manager
Provision TLS Certificate for Traefik Proxy with cert-manager on Kubernetes

Pre-requisites
To obtain certificates from cert-manager that can be used in Traefik Proxy, you will need to:

Have cert-manager properly configured
Have Traefik Proxy configured
The certificates can then be used in an Ingress / IngressRoute / HTTPRoute.

Example with ACME and HTTP challenge
ACME issuer for HTTP challenge


Issuer

apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: acme

spec:
  acme:
    # Production server is on https://acme-v02.api.letsencrypt.org/directory
    # Use staging by default.
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: acme
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik

Certificate
Let's see now how to use it with the various Kubernetes providers of Traefik Proxy. The enabled providers can be seen on the dashboard of Traefik Proxy and also in the INFO logs when Traefik Proxy starts.

With an Ingress
To use this certificate with an Ingress, the Kubernetes Ingress provider has to be enabled.

Info

This provider is enabled by default in the Traefik Helm Chart.

Route with this Certificate


Ingress

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: domain
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure

spec:
  rules:
  - host: domain.example.com
    http:
      paths:
      - path: /
        pathType: Exact
        backend:
          service:
            name:  domain-service
            port:
              number: 80
  tls:
  - secretName: domain-tls # <=== Use the name defined in Certificate resource.
With an IngressRoute
To use this certificate with an IngressRoute, the Kubernetes CRD provider has to be enabled.

Info

This provider is enabled by default in the Traefik Helm Chart.

Route with this Certificate


IngressRoute

apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: domain

spec:
  entryPoints:
    - websecure

  routes:
  - match: Host(`domain.example.com`)
    kind: Rule
    services:
    - name: domain-service
      port: 80
  tls:
    secretName: domain-tls    # <=== Use the name defined in Certificate resource.
With an HTTPRoute
To use this certificate with an HTTPRoute, the Kubernetes Gateway provider has to be enabled.

Info

This provider is disabled by default in the Traefik Helm Chart.

Route with this Certificate


HTTPRoute

---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: domain-gateway
spec:
  gatewayClassName: traefik
  listeners:
    - name: websecure
      port: 8443
      protocol: HTTPS
      hostname: domain.example.com
      tls:
        certificateRefs:
          - name: domain-tls  # <==== Use the name defined in Certificate resource.
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: domain
spec:
  parentRefs:
    - name: domain-gateway
  hostnames:
    - domain.example.com
  rules:
    - matches:
        - path:
            type: Exact
            value: /

      backendRefs:
        - name: domain-service
          port: 80
          weight: 1
Troubleshooting
There are multiple event sources available to investigate when using cert-manager:

Kubernetes events in Certificate and CertificateRequest resources
cert-manager logs
Dashboard and/or (debug) logs from Traefik Proxy
cert-manager documentation provides a detailed guide on how to troubleshoot a certificate request.

Using Traefik OSS in Production?

If you are using Traefik at work, consider adding enterprise-grade API gateway capabilities or commercial support for Traefik OSS.

Watch our API Gateway Demo Video
Request 24/7/365 OSS Support
Adding API Gateway capabilities to Traefik OSS is fast and seamless. There's no rip and replace and all configurations remain intact. See it in action via this short video.