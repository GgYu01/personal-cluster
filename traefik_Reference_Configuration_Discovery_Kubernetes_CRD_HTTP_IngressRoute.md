IngressRoute
IngressRoute is the CRD implementation of a Traefik HTTP router.

Before creating IngressRoute objects, you need to apply the Traefik Kubernetes CRDs to your Kubernetes cluster.

This registers the IngressRoute kind and other Traefik-specific resources.

Configuration Example
You can declare an IngressRoute as detailed below:


IngressRoute

apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: test-name
  namespace: apps

spec:
  entryPoints:
    - web
  routes:
  - kind: Rule
    # Rule on the Host
    match: Host(`test.example.com`)
    # Attach a middleware
    middlewares:
    - name: middleware1
      namespace: apps
    # Enable Router observability
    observability:
      accessLogs: true
      metrics: true
      tracing: true
    # Set a pirority
    priority: 10
    services:
    # Target a Kubernetes Support
    - kind: Service
      name: foo
      namespace: apps
      # Customize the connection between Traefik and the backend
      passHostHeader: true
      port: 80
      responseForwarding:
        flushInterval: 1ms
      scheme: https
      sticky:
        cookie:
          httpOnly: true
          name: cookie
          secure: true
      strategy: RoundRobin
      weight: 10
  tls:
    # Generate a TLS certificate using a certificate resolver
    certResolver: foo
    domains:
    - main: example.net
      sans:
      - a.example.net
      - b.example.net
    # Customize the TLS options
    options:
      name: opt
      namespace: apps
    # Add a TLS certificate from a Kubernetes Secret
    secretName: supersecret
Configuration Options
Field	Description	Default	Required
entryPoints	List of entry points names.
If not specified, HTTP routers will accept requests from all EntryPoints in the list of default EntryPoints.		No
routes	List of routes.		Yes
routes[n].kind	Kind of router matching, only Rule is allowed yet.	"Rule"	No
routes[n].match	Defines the rule corresponding to an underlying router.		Yes
routes[n].priority	Defines the priority to disambiguate rules of the same length, for route matching.
If not set, the priority is directly equal to the length of the rule, and so the longest length has the highest priority.
A value of 0 for the priority is ignored, the default rules length sorting is used.	0	No
routes[n].middlewares	List of middlewares to attach to the IngressRoute.
More information here.	""	No
routes[n].
middlewares[m].
name	Middleware name.
The character @ is not authorized.
More information here.		Yes
routes[n].
middlewares[m].
namespace	Middleware namespace.
Can be empty if the middleware belongs to the same namespace as the IngressRoute.
More information here.		No
routes[n].
observability.
accesslogs	Defines whether the route will produce access-logs. See here for more information.	false	No
routes[n].
observability.
metrics	Defines whether the route will produce metrics. See here for more information.	false	No
routes[n].
observability.
tracing	Defines whether the route will produce traces. See here for more information.	false	No
routes[n].
services	List of any combination of TraefikService and Kubernetes service.
More information here.		No
routes[n].
services[m].
kind	Kind of the service targeted.
Two values allowed:
- Service: Kubernetes Service
TraefikService: Traefik Service.
More information here.	"Service"	No
routes[n].
services[m].
name	Service name.
The character @ is not authorized.
More information here.		Yes
routes[n].
services[m].
namespace	Service namespace.
Can be empty if the service belongs to the same namespace as the IngressRoute.
More information here.		No
routes[n].
services[m].
port	Service port (number or port name).
Evaluated only if the kind is Service.		No
routes[n].
services[m].
responseForwarding.
flushInterval	Interval, in milliseconds, in between flushes to the client while copying the response body.
A negative value means to flush immediately after each write to the client.
This configuration is ignored when a response is a streaming response; for such responses, writes are flushed to the client immediately.
Evaluated only if the kind is Service.	100ms	No
routes[n].
services[m].
scheme	Scheme to use for the request to the upstream Kubernetes Service.
Evaluated only if the kind is Service.	"http"
"https" if port is 443 or contains the string https.	No
routes[n].
services[m].
serversTransport	Name of ServersTransport resource to use to configure the transport between Traefik and your servers.
Evaluated only if the kind is Service.	""	No
routes[n].
services[m].
passHostHeader	Forward client Host header to server.
Evaluated only if the kind is Service.	true	No
routes[n].
services[m].
healthCheck.scheme	Server URL scheme for the health check endpoint.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	""	No
routes[n].
services[m].
healthCheck.mode	Health check mode.
If defined to grpc, will use the gRPC health check protocol to probe the server.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	"http"	No
routes[n].
services[m].
healthCheck.path	Server URL path for the health check endpoint.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	""	No
routes[n].
services[m].
healthCheck.interval	Frequency of the health check calls for healthy targets.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	"100ms"	No
routes[n].
services[m].
healthCheck.unhealthyInterval	Frequency of the health check calls for unhealthy targets.
When not defined, it defaults to the interval value.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	"100ms"	No
routes[n].
services[m].
healthCheck.method	HTTP method for the health check endpoint.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	"GET"	No
routes[n].
services[m].
healthCheck.status	Expected HTTP status code of the response to the health check request.
Only for Kubernetes service of type ExternalName.
If not set, expect a status between 200 and 399.
Evaluated only if the kind is Service.		No
routes[n].
services[m].
healthCheck.port	URL port for the health check endpoint.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.		No
routes[n].
services[m].
healthCheck.timeout	Maximum duration to wait before considering the server unhealthy.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	"5s"	No
routes[n].
services[m].
healthCheck.hostname	Value in the Host header of the health check request.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	""	No
routes[n].
services[m].
healthCheck.
followRedirect	Follow the redirections during the healtchcheck.
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName.	true	No
routes[n].
services[m].
healthCheck.headers	Map of header to send to the health check endpoint
Evaluated only if the kind is Service.
Only for Kubernetes service of type ExternalName).		No
routes[n].
services[m].
sticky.
cookie.name	Name of the cookie used for the stickiness.
When sticky sessions are enabled, a Set-Cookie header is set on the initial response to let the client know which server handles the first response.
On subsequent requests, to keep the session alive with the same server, the client should send the cookie with the value set.
If the server pecified in the cookie becomes unhealthy, the request will be forwarded to a new server (and the cookie will keep track of the new server).
Evaluated only if the kind is Service.	""	No
routes[n].
services[m].
sticky.
cookie.httpOnly	Allow the cookie can be accessed by client-side APIs, such as JavaScript.
Evaluated only if the kind is Service.	false	No
routes[n].
services[m].
sticky.
cookie.secure	Allow the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).
Evaluated only if the kind is Service.	false	No
routes[n].
services[m].
sticky.
cookie.sameSite	SameSite policy
Allowed values:
-none
-lax
strict
Evaluated only if the kind is Service.	""	No
routes[n].
services[m].
sticky.
cookie.maxAge	Number of seconds until the cookie expires.
Negative number, the cookie expires immediately.
0, the cookie never expires.
Evaluated only if the kind is Service.	0	No
routes[n].
services[m].
strategy	Load balancing strategy between the servers.
RoundRobin is the only supported value yet.
Evaluated only if the kind is Service.	"RoundRobin"	No
routes[n].
services[m].
weight	Service weight.
To use only to refer to WRR TraefikService	""	No
routes[n].
services[m].
nativeLB	Allow using the Kubernetes Service load balancing between the pods instead of the one provided by Traefik.
Evaluated only if the kind is Service.	false	No
routes[n].
services[m].
nodePortLB	Use the nodePort IP address when the service type is NodePort.
It allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.
Evaluated only if the kind is Service.	false	No
tls	TLS configuration.
Can be an empty value({}):
A self signed is generated in such a case
(or the default certificate is used if it is defined.)		No
tls.secretName	Secret name used to store the certificate (in the same namesapce as the IngressRoute)	""	No
tls.
options.name	Name of the TLSOption to use.
More information here.	""	No
tls.
options.namespace	Namespace of the TLSOption to use.	""	No
tls.certResolver	Name of the Certificate Resolver to use to generate automatic TLS certificates.	""	No
tls.domains	List of domains to serve using the certificates generates (one tls.domain= one certificate).
More information in the dedicated section.		No
tls.
domains[n].main	Main domain name	""	Yes
tls.
domains[n].sans	List of alternative domains (SANs)		No
ExternalName Service
Traefik backends creation needs a port to be set, however Kubernetes ExternalName Service could be defined without any port. Accordingly, Traefik supports defining a port in two ways:

only on IngressRoute service
on both sides, you'll be warned if the ports don't match, and the IngressRoute service port is used
Thus, in case of two sides port definition, Traefik expects a match between ports.


Ports defined on Resource

IngressRoute

apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: test.route
  namespace: apps

spec:
  entryPoints:
    - foo
  routes:
  - match: Host(`example.net`)
    kind: Rule
    services:
    - name: external-svc
      port: 80

Service ExternalName

Port defined on the Service

Port defined on both sides
Middleware
You can attach a list of middlewares to each HTTP router.
The middlewares will take effect only if the rule matches, and before forwarding the request to the service.
Middlewares are applied in the same order as their declaration in router.
In Kubernetes, the option middleware allow you to attach a middleware using its name and namespace (the namespace can be omitted when the Middleware is in the same namespace as the IngressRoute)
IngressRoute attached to a few middlewares
routes.services.kind
Port Definition
Traefik backends creation needs a port to be set, however Kubernetes ExternalName Service could be defined without any port. Accordingly, Traefik supports defining a port in two ways:

only on IngressRoute service
on both sides, you'll be warned if the ports don't match, and the IngressRoute service port is used
Thus, in case of two sides port definition, Traefik expects a match between ports.

Example
TLS Options
The options field enables fine-grained control of the TLS parameters. It refers to a TLSOption and will be applied only if a Host rule is defined.

Server Name Association
A TLS options reference is always mapped to the host name found in the Host part of the rule, but neither to a router nor a router rule. There could also be several Host parts in a rule. In such a case the TLS options reference would be mapped to as many host names.

A TLS option is picked from the mapping mentioned above and based on the server name provided during the TLS handshake, and it all happens before routing actually occurs.

In the case of domain fronting, if the TLS options associated with the Host Header and the SNI are different then Traefik will respond with a status code 421.

Conflicting TLS Options
Since a TLS options reference is mapped to a host name, if a configuration introduces a situation where the same host name (from a Host rule) gets matched with two TLS options references, a conflict occurs, such as in the example below.

Example
If that happens, both mappings are discarded, and the host name (example.net in the example) for these routers gets associated with the default TLS options instead.

Load Balancing
You can declare and use Kubernetes Service load balancing as detailed below:


IngressRoute

apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroutebar
  namespace: default

spec:
  entryPoints:
    - web
  routes:
  - match: Host(`example.com`) && PathPrefix(`/foo`)
    kind: Rule
    services:
    - name: svc1
      namespace: default
    - name: svc2
      namespace: default

K8s Service
Kubernetes Service Native Load-Balancing

To avoid creating the server load-balancer with the pod IPs and use Kubernetes Service clusterIP directly, one should set the service NativeLB option to true. Please note that, by default, Traefik reuses the established connections to the backends for performance purposes. This can prevent the requests load balancing between the replicas from behaving as one would expect when the option is set. By default, NativeLB is false.

Example
Configuring Backend Protocol
There are 3 ways to configure the backend protocol for communication between Traefik and your pods:

Setting the scheme explicitly (http/https/h2c)
Configuring the name of the kubernetes service port to start with https (https)
Setting the kubernetes service port to use port 443 (https)
If you do not configure the above, Traefik will assume an http connection.