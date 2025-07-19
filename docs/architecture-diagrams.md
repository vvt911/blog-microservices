# Blog Microservices Architecture Diagrams

## System Overview Architecture

```mermaid
graph TB
    subgraph "External Access"
        User[User Browser]
        Minikube[Minikube Cluster]
    end
    
    subgraph "Istio Service Mesh"
        subgraph "Istio Gateway"
            Gateway[blog-gateway<br/>Port: 80<br/>Host: *]
        end
        
        subgraph "blog-microservices namespace"
            subgraph "Frontend Layer"
                Frontend[Frontend<br/>Port: 3000<br/>API Proxy + Static Files]
            end
            
            subgraph "Backend Services"
                BlogService[Blog Service<br/>Port: 3001<br/>In-Memory Storage]
                BlogProxy[Envoy Sidecar]
                
                CommentService[Comment Service<br/>Port: 3002<br/>In-Memory Storage]
                CommentProxy[Envoy Sidecar]
                
                UserService[User Service<br/>Port: 3003<br/>In-Memory Storage]
                UserProxy[Envoy Sidecar]
                
                NotificationService[Notification Service<br/>Port: 3004<br/>In-Memory Storage]
                NotificationProxy[Envoy Sidecar]
            end
        end
        
        subgraph "Istio Networking"
            VS1[blog-virtualservice<br/>/ → frontend:3000]
            VS2[blog-service-vs<br/>Traffic Routing<br/>v1/v2 distribution]
            VS3[comment-service-vs<br/>comment-service → :3002]
            VS4[user-service-vs<br/>user-service → :3003]
            VS5[notification-service-vs<br/>notification-service → :3004]
            
            DR1[frontend-dr<br/>subset: v1]
            DR2[blog-service-dr<br/>subset: v1, v2]
            DR3[comment-service-dr<br/>subset: v1]
            DR4[user-service-dr<br/>subset: v1]
            DR5[notification-service-dr<br/>subset: v1]
        end
        
        subgraph "istio-system namespace"
            Prometheus[Prometheus<br/>Port: 9090<br/>Metrics Collection]
            Grafana[Grafana<br/>Port: 3000<br/>Visualization]
        end
    end
    
    %% User Flow
    User --> Minikube
    Minikube --> Gateway
    Gateway --> Frontend
    
    %% Frontend API Proxy Routes
    Frontend --> |/api/blogs| VS2
    Frontend --> |/api/comments| CommentService
    Frontend --> |/api/users| UserService
    Frontend --> |/api/notifications| NotificationService
    
    %% Service to Proxy Connections
    BlogService --> BlogProxy
    CommentService --> CommentProxy
    UserService --> UserProxy
    NotificationService --> NotificationProxy
    
    %% Inter-Service Communication via Proxies
    BlogProxy --> |POST /notify| NotificationProxy
    CommentProxy --> |GET /blogs/:id| BlogProxy
    CommentService --> |GET /blogs/:id| VS2
    CommentService --> |POST /notify| NotificationService
    UserService --> |POST /notify| NotificationService
    
    %% Istio Configuration
    Gateway -.-> VS1
    VS1 -.-> DR1
    VS2 -.-> DR2
    VS3 -.-> DR3
    VS4 -.-> DR4
    VS5 -.-> DR5
    
    %% Monitoring (Envoy Sidecar)
    BlogProxy -.-> Prometheus
    CommentProxy -.-> Prometheus
    UserProxy -.-> Prometheus
    NotificationProxy -.-> Prometheus
    
    Prometheus --> Grafana
    
    %% Styling
    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef backend fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef backendv2 fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef monitoring fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef external fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    classDef istio fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef traffic fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    
    class Frontend frontend
    class BlogService,CommentService,UserService,NotificationService backend
    class BlogProxy,CommentProxy,UserProxy,NotificationProxy istio
    class Prometheus,Grafana monitoring
    class User,Minikube,Gateway external
    class VS1,VS2,VS3,VS4,VS5,DR1,DR2,DR3,DR4,DR5 istio
    class Canary,ABTest traffic
```

## Traffic Management Architecture

```mermaid
graph TB
    subgraph "Istio Traffic Management"
        subgraph "Traffic Control"
            VS[blog-service-vs<br/>VirtualService]
            DR[blog-service-dr<br/>DestinationRule]
        end
        
        subgraph "Traffic Split"
            V1Route[V1 Route<br/>Version: v1]
            V2Route[V2 Route<br/>Version: v2]
        end
        
        subgraph "Traffic Scenarios"
            Canary[Canary Deployment<br/>70% V1, 30% V2]
            ABTest[A/B Testing<br/>50% V1, 50% V2]
            BlueGreen[Blue/Green<br/>Quick version switch]
        end
        
        subgraph "Services"
            BlogV1[Blog Service V1<br/>Stable Version]
            BlogV2[Blog Service V2<br/>New Version]
        end
        
        subgraph "Monitoring"
            Metrics[Traffic Metrics<br/>Success rate<br/>Latency<br/>Error rate]
            Monitor[Version Monitor<br/>Health checks<br/>Performance comparison]
        end
    end
    
    %% Traffic Flow
    VS --> DR
    DR --> V1Route
    DR --> V2Route
    V1Route --> BlogV1
    V2Route --> BlogV2
    
    %% Scenario Configuration
    Canary -.-> VS
    ABTest -.-> VS
    BlueGreen -.-> VS
    
    %% Monitoring
    BlogV1 --> Metrics
    BlogV2 --> Metrics
    Metrics --> Monitor
    
    %% Styling
    classDef control fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef route fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef service fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef scenario fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef monitor fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class VS,DR control
    class V1Route,V2Route route
    class BlogV1,BlogV2 service
    class Canary,ABTest,BlueGreen scenario
    class Metrics,Monitor monitor
```

## Data Flow Details

### 1. Traffic Routing Scenarios

#### Canary Deployment (70% V1, 30% V2)
```mermaid
graph TB
    subgraph "Canary Deployment"
        User[User Request]
        VS[blog-service-vs<br/>VirtualService]
        
        subgraph "Traffic Distribution"
            V1Traffic[70% Traffic<br/>Weight: 70]
            V2Traffic[30% Traffic<br/>Weight: 30]
        end
        
        BlogV1[Blog Service V1<br/>Stable Version<br/>Basic features]
        BlogV2[Blog Service V2<br/>Canary Version<br/>Enhanced features]
        
        User --> VS
        VS --> V1Traffic
        VS --> V2Traffic
        V1Traffic --> BlogV1
        V2Traffic --> BlogV2
        
        BlogV1 --> Response1[Response: Standard format]
        BlogV2 --> Response2[Response: Enhanced format<br/>+ V2 features indicator]
    end
    
    classDef v1 fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef v2 fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef traffic fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    
    class BlogV1,V1Traffic,Response1 v1
    class BlogV2,V2Traffic,Response2 v2
    class VS,User traffic
```

#### A/B Testing (50% V1, 50% V2)
```mermaid
graph TB
    subgraph "A/B Testing"
        User[User Request]
        VS[blog-service-vs<br/>VirtualService]
        
        subgraph "Equal Traffic Split"
            V1Traffic[50% Traffic<br/>Weight: 50]
            V2Traffic[50% Traffic<br/>Weight: 50]
        end
        
        BlogV1[Blog Service V1<br/>Control Group<br/>Standard UI]
        BlogV2[Blog Service V2<br/>Test Group<br/>Enhanced UI]
        
        User --> VS
        VS --> V1Traffic
        VS --> V2Traffic
        V1Traffic --> BlogV1
        V2Traffic --> BlogV2
        
        BlogV1 --> Metrics1[Metrics: Standard KPIs]
        BlogV2 --> Metrics2[Metrics: Enhanced KPIs<br/>+ Feature usage tracking]
    end
    
    classDef v1 fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef v2 fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef traffic fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    
    class BlogV1,V1Traffic,Metrics1 v1
    class BlogV2,V2Traffic,Metrics2 v2
    class VS,User traffic
```

### 2. Blog Post Creation Flow (V1 vs V2)

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant LB as Istio Load Balancer
    participant B1 as Blog Service V1
    participant B2 as Blog Service V2
    participant N as Notification Service
    
    U->>F: POST /api/blogs<br/>{title, content, author}
    F->>LB: POST /blogs<br/>{title, content, author}
    
    alt Traffic to V1 (70%)
        LB->>B1: Route to V1<br/>Standard processing
        B1->>B1: Create blog object<br/>Store in memory array
        B1->>N: POST /notify<br/>{type: "blog_created", message, blogId}
        N-->>B1: 201 Created
        B1-->>LB: 201 Created<br/>{id, title, content, author, createdAt, likes}
    else Traffic to V2 (30%)
        LB->>B2: Route to V2<br/>Enhanced processing
        B2->>B2: Create blog object<br/>Store in memory array<br/>+ Enhanced features
        B2->>N: POST /notify<br/>{type: "blog_created", message, blogId, version: "v2"}
        N-->>B2: 201 Created
        B2-->>LB: 201 Created<br/>{id, title, content, author, createdAt, likes, version: "v2", features: "V2 features"}
    end
    
    LB-->>F: Response with version info
    F-->>U: Success response
    
    Note over B1,B2: V1: Standard features<br/>V2: Enhanced features + version indicator
    Note over LB: Istio VirtualService<br/>handles traffic distribution
```

### 2. Comment Creation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant C as Comment Service
    participant B as Blog Service
    participant N as Notification Service
    
    U->>F: POST /api/comments<br/>{blogId, author, content}
    F->>C: POST /comments<br/>{blogId, author, content}
    C->>B: GET /blogs/{blogId}<br/>(validate blog exists)
    B-->>C: 200 OK<br/>{blog object}
    C->>C: Create comment object<br/>Store in memory array
    C->>N: POST /notify<br/>{type: "comment_created", message, commentId}
    N->>N: Create notification<br/>Store in memory array
    N-->>C: 201 Created
    C-->>F: 201 Created<br/>{id, blogId, author, content, createdAt}
    F-->>U: Success response
    
    Note over C,B: Validation step ensures<br/>referential integrity
```

### 3. User Registration Flow

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant US as User Service
    participant N as Notification Service
    
    U->>F: POST /api/users<br/>{name, email, role, bio}
    F->>US: POST /users<br/>{name, email, role, bio}
    US->>US: Check email uniqueness<br/>Create user object<br/>Store in memory array
    US->>N: POST /notify<br/>{type: "user_registered", message, userId}
    N->>N: Create notification<br/>Store in memory array
    N-->>US: 201 Created
    US-->>F: 201 Created<br/>{id, name, email, role, createdAt, profilePicture}
    F-->>U: Success response
    
    Note over US,N: Welcome notification<br/>with user details
```

### 4. Frontend API Proxy Flow

```mermaid
sequenceDiagram
    participant B as Browser
    participant F as Frontend
    participant S as Backend Service
    
    B->>F: GET /api/blogs
    F->>F: Check SERVICE_URL<br/>environment variable
    F->>S: GET /blogs<br/>via axios
    S-->>F: JSON response
    F-->>B: JSON response
    
    Note over F: Frontend acts as API Gateway<br/>Proxy all /api/* requests
    
    B->>F: GET /index.html
    F->>F: Serve static files<br/>from /public
    F-->>B: HTML/CSS/JS files
```

## Kubernetes Deployment Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        DevLaptop[Developer Laptop]
        LocalServices[Local Services<br/>npm start on ports 3000-3004]
    end
    
    subgraph "Minikube Production"
        subgraph "Docker Environment"
            DockerImages[Docker Images<br/>blog-frontend:latest<br/>blog-service:latest<br/>blog-service-v2:latest<br/>comment-service:latest<br/>user-service:latest<br/>notification-service:latest]
        end
        
        subgraph "Kubernetes Resources"
            subgraph "blog-microservices namespace"
                Deployments[Deployments<br/>blog-service: v1 + v2<br/>replicas: 1 each<br/>imagePullPolicy: Never]
                Services[Services<br/>ClusterIP<br/>blog-service: selector matches both versions<br/>ports: 3000-3004]
                Pods[Pods<br/>blog-service-v1-xxx<br/>blog-service-v2-xxx<br/>with Envoy sidecars]
            end
            
            subgraph "istio-system namespace"
                IstioGateway[Istio Gateway<br/>istio-ingressgateway]
                IstioControl[Istio Control Plane]
                MonitoringPods[Prometheus + Grafana<br/>from Istio addons]
            end
        end
    end
    
    DevLaptop --> LocalServices
    DevLaptop --> |docker build| DockerImages
    DockerImages --> |kubectl apply| Deployments
    Deployments --> Pods
    Pods --> Services
    Services --> IstioGateway
    
    IstioControl --> |inject sidecars| Pods
    MonitoringPods --> |scrape metrics| Pods
```

## Traffic Routing Configuration

```mermaid
graph TB
    subgraph "Istio Traffic Management"
        subgraph "VirtualService Configurations"
            DefaultVS[Default VirtualService<br/>100% → blog-service v1]
            CanaryVS[Canary VirtualService<br/>70% → v1, 30% → v2]
            ABTestVS[A/B Test VirtualService<br/>50% → v1, 50% → v2]
        end
        
        subgraph "DestinationRule"
            DR[blog-service-dr<br/>Defines subsets:<br/>- v1: version=v1<br/>- v2: version=v2]
        end
        
        subgraph "Traffic Scenarios"
            Scenario1[📁 k8s/traffic-scenarios/<br/>canary.yaml]
            Scenario2[📁 k8s/traffic-scenarios/<br/>ab-test.yaml]
        end
        
        subgraph "Blog Service Deployments"
            BlogV1Deploy[blog-service-v1<br/>labels: version=v1<br/>image: blog-service:latest]
            BlogV2Deploy[blog-service-v2<br/>labels: version=v2<br/>image: blog-service-v2:latest]
        end
        
        subgraph "Service"
            BlogSvc[blog-service<br/>selector: app=blog-service<br/>matches both v1 and v2]
        end
    end
    
    %% Configuration Flow
    Scenario1 --> CanaryVS
    Scenario2 --> ABTestVS
    
    %% Traffic Flow
    CanaryVS --> DR
    ABTestVS --> DR
    DefaultVS --> DR
    
    DR --> BlogSvc
    BlogSvc --> BlogV1Deploy
    BlogSvc --> BlogV2Deploy
    
    %% Styling
    classDef config fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef v1 fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef v2 fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef scenarios fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class DefaultVS,CanaryVS,ABTestVS,DR,BlogSvc config
    class BlogV1Deploy v1
    class BlogV2Deploy v2
    class Scenario1,Scenario2 scenarios
```

## mTLS Testing Architecture

```mermaid
graph TB
    subgraph "blog-microservices<br/>namespace"
        subgraph "Test Pods"
            PodNoSidecar["Test Pod<br/>Without Sidecar<br/>(test-mtls)<br/>sidecar.istio.io/inject: false"]
            PodWithSidecar["Test Pod<br/>With Sidecar<br/>(test-mtls-with-sidecar)"]
        end

        subgraph "Target Service"
            BlogService["Blog Service<br/>Port: 3001"]
            BlogSidecar["Istio Sidecar Proxy"]
        end

        subgraph "mTLS Modes"
            PERMISSIVE["PERMISSIVE Mode<br/>Accepts both plain & mTLS"]
            STRICT["STRICT Mode<br/>Only accepts mTLS"]
        end
    end

    %% Connections in PERMISSIVE mode
    PodNoSidecar -->|"HTTP Request<br/>✅ Success in PERMISSIVE"| BlogService
    PodWithSidecar -->|"mTLS Request<br/>✅ Success in PERMISSIVE"| BlogSidecar

    %% Connections in STRICT mode
    PodNoSidecar -.->|"HTTP Request<br/>❌ Fails in STRICT"| BlogService
    PodWithSidecar -->|"mTLS Request<br/>✅ Success in STRICT"| BlogSidecar

    %% Service connections
    BlogSidecar --> BlogService

    %% Mode switches
    PERMISSIVE -.->|"Switch Mode"| STRICT

    %% Styling
    classDef sidecar fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef service fill:#389826,stroke:#fff,stroke-width:2px,color:#fff
    classDef pod fill:#F9B13C,stroke:#fff,stroke-width:2px,color:#333
    classDef mode fill:#800080,stroke:#fff,stroke-width:2px,color:#fff
    
    class BlogSidecar sidecar
    class BlogService service
    class PodNoSidecar,PodWithSidecar pod
    class PERMISSIVE,STRICT mode
```

## Security & Configuration

```mermaid
graph TB
    subgraph "Istio Security"
        mTLS[Automatic mTLS<br/>Service-to-Service]
        Injection[Sidecar Injection<br/>istio-injection: enabled]
        AuthPolicy[Authorization Policies<br/>(Optional)]
    end
    
    subgraph "Network Configuration"
        Gateway[Gateway<br/>Port 80, Host: *]
        VirtualServices[Virtual Services<br/>Routing Rules]
        DestinationRules[Destination Rules<br/>v1 subsets]
    end
    
    subgraph "Application Security"
        CORS[CORS Enabled<br/>All services]
        Validation[Input Validation<br/>Required fields check]
        HealthChecks[Health Endpoints<br/>/health on all services]
        EnvVars[Environment Variables<br/>Service URLs]
    end
    
    subgraph "Services"
        Frontend[Frontend]
        BlogServiceV1[Blog Service V1]
        BlogServiceV2[Blog Service V2]
        CommentService[Comment Service]
        UserService[User Service]
        NotificationService[Notification Service]
    end
    
    Injection --> Frontend
    Injection --> BlogServiceV1
    Injection --> BlogServiceV2
    Injection --> CommentService
    Injection --> UserService
    Injection --> NotificationService
    
    mTLS --> BlogServiceV1
    mTLS --> BlogServiceV2
    mTLS --> CommentService
    mTLS --> UserService
    mTLS --> NotificationService
    
    Gateway --> VirtualServices
    VirtualServices --> DestinationRules
    
    CORS --> Frontend
    CORS --> BlogServiceV1
    CORS --> BlogServiceV2
    CORS --> CommentService
    CORS --> UserService
    CORS --> NotificationService
    
    EnvVars --> Frontend
    EnvVars --> BlogServiceV1
    EnvVars --> BlogServiceV2
    EnvVars --> CommentService
    EnvVars --> UserService
```

## Data Architecture

```mermaid
graph TB
    subgraph "In-Memory Data Stores"
        BlogData[Blog Data<br/>Array of blog objects<br/>- id, title, content, author<br/>- createdAt, likes]
        
        CommentData[Comment Data<br/>Array of comment objects<br/>- id, blogId, author, content<br/>- createdAt, likes]
        
        UserData[User Data<br/>Array of user objects<br/>- id, name, email, role<br/>- createdAt, profilePicture, bio]
        
        NotificationData[Notification Data<br/>Array of notification objects<br/>- id, type, message, timestamp<br/>- priority, read status]
    end
    
    subgraph "Service Interactions"
        BlogServiceV1[Blog Service V1] --> BlogData
        BlogServiceV2[Blog Service V2] --> BlogData
        CommentService[Comment Service] --> CommentData
        UserService[User Service] --> UserData
        NotificationService[Notification Service] --> NotificationData
        
        CommentService -.-> |Validate blogId| BlogServiceV1
        CommentService -.-> |Validate blogId| BlogServiceV2
        BlogServiceV1 -.-> |Fire-and-forget| NotificationService
        BlogServiceV2 -.-> |Fire-and-forget| NotificationService
        CommentService -.-> |Fire-and-forget| NotificationService
        UserService -.-> |Fire-and-forget| NotificationService
    end
    
    subgraph "Sample Data"
        InitialBlogs[3 Initial Blogs<br/>- Welcome to Microservices<br/>- Service Mesh Architecture<br/>- Kubernetes Best Practices]
        
        InitialComments[5 Initial Comments<br/>- Distributed across blogs<br/>- From different authors<br/>- With timestamps]
        
        InitialUsers[5 Initial Users<br/>- Different roles (admin, author, reader)<br/>- With profile pictures<br/>- Activity tracking]
        
        InitialNotifications[3 Initial Notifications<br/>- System initialized<br/>- User registered<br/>- Blog created]
    end
    
    BlogData --> InitialBlogs
    CommentData --> InitialComments
    UserData --> InitialUsers
    NotificationData --> InitialNotifications
```

## Service Version Comparison

```mermaid
graph TB
    subgraph "Blog Service V1"
        V1Features[Standard Features:<br/>- Basic CRUD operations<br/>- In-memory storage<br/>- Standard response format<br/>- Basic error handling]
        
        V1Response[Response Format:<br/>{<br/>  id, title, content,<br/>  author, createdAt, likes<br/>}]
        
        V1Docker[Docker Image:<br/>blog-service:latest<br/>Standard Node.js app]
    end
    
    subgraph "Blog Service V2"
        V2Features[Enhanced Features:<br/>- Advanced CRUD operations<br/>- In-memory storage<br/>- Enhanced response format<br/>- Advanced error handling<br/>- Version indicators]
        
        V2Response[Response Format:<br/>{<br/>  id, title, content,<br/>  author, createdAt, likes,<br/>  version: "v2",<br/>  features: "V2 features"<br/>}]
        
        V2Docker[Docker Image:<br/>blog-service-v2:latest<br/>Enhanced Node.js app]
    end
    
    subgraph "Traffic Distribution Strategy"
        ProductionUse[Production Use Cases:<br/>- Canary: 70% V1, 30% V2<br/>- A/B Test: 50% V1, 50% V2<br/>- Gradual rollout strategy]
        
        TestingStrategy[Testing Strategy:<br/>- Gradual rollout<br/>- Feature validation<br/>- Performance comparison<br/>- User experience testing]
    end
    
    subgraph "Monitoring & Metrics"
        V1Metrics[V1 Metrics:<br/>- Request count<br/>- Response time<br/>- Error rate<br/>- Standard KPIs]
        
        V2Metrics[V2 Metrics:<br/>- Request count<br/>- Response time<br/>- Error rate<br/>- Enhanced KPIs<br/>- Feature usage tracking]
        
        Comparison[Comparison Dashboard:<br/>- Version performance<br/>- Feature adoption<br/>- Error rates<br/>- User satisfaction]
    end
    
    V1Features --> V1Response
    V2Features --> V2Response
    V1Docker --> V1Features
    V2Docker --> V2Features
    
    V1Response --> V1Metrics
    V2Response --> V2Metrics
    V1Metrics --> Comparison
    V2Metrics --> Comparison
    
    ProductionUse --> TestingStrategy
    TestingStrategy --> Comparison
    
    classDef v1 fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef v2 fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef strategy fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef metrics fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class V1Features,V1Response,V1Docker,V1Metrics v1
    class V2Features,V2Response,V2Docker,V2Metrics v2
    class ProductionUse,TestingStrategy strategy
    class Comparison metrics
```

## Monitoring & Observability

```mermaid
graph TB
    subgraph "Istio Observability"
        EnvoySidecars[Envoy Sidecars<br/>Auto-injected to all services<br/>Including blog-service v1 & v2<br/>Collect metrics & traces]
        
        PrometheusEndpoints[Prometheus Metrics<br/>HTTP requests, latency<br/>Service mesh metrics]
        
        ServiceMesh[Service Mesh<br/>Traffic management<br/>Security policies]
    end
    
    subgraph "Monitoring Stack"
        Prometheus[Prometheus<br/>Port: 9090<br/>Metrics scraping]
        
        Grafana[Grafana<br/>Port: 3000<br/>Dashboards & visualization]
        
        IstioAddons[Istio Addons<br/>Pre-configured for service mesh]
    end
    
    subgraph "Application Monitoring"
        HealthEndpoints[Health Endpoints<br/>Service status check]
        
        ConsoleLogging[Console Logging<br/>Request/response logs]
        
        ServiceStatus[Service Status<br/>Running/healthy indicators]
    end
    
    EnvoySidecars --> PrometheusEndpoints
    PrometheusEndpoints --> Prometheus
    Prometheus --> Grafana
    
    IstioAddons --> Prometheus
    IstioAddons --> Grafana
    
    HealthEndpoints --> ServiceStatus
    ConsoleLogging --> ServiceStatus
```

---

**This updated architecture diagram accurately reflects the Blog Microservices system with blog-service-v2 implementation, including traffic routing scenarios, version comparison, and enhanced monitoring capabilities based on Kubernetes configurations, Istio setup, and source code of each service.**
