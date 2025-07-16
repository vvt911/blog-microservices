# 🎨 Sơ đồ Kiến trúc Hệ thống Blog Microservices

## 📊 Sơ đồ Kiến trúc Tổng quan

```mermaid
graph TB
    subgraph "🌐 External Traffic"
        User[👤 User Browser]
        LoadBalancer[⚖️ Load Balancer]
    end
    
    subgraph "🔒 Istio Service Mesh"
        Gateway[🚪 Istio Gateway<br/>Port: 80]
        
        subgraph "🏢 Blog Microservices Namespace"
            subgraph "Frontend Layer"
                Frontend[🖥️ Frontend Service<br/>Port: 3000<br/>HTML/CSS/JS]
            end
            
            subgraph "Business Logic Layer"
                BlogService[📝 Blog Service<br/>Port: 3001<br/>CRUD Blogs]
                CommentService[💬 Comment Service<br/>Port: 3002<br/>CRUD Comments]
                UserService[👥 User Service<br/>Port: 3003<br/>User Management]
                NotificationService[🔔 Notification Service<br/>Port: 3004<br/>Real-time Notifications]
            end
            
            subgraph "Data Layer"
                BlogDB[(📚 Blog Data<br/>In-Memory)]
                CommentDB[(💭 Comment Data<br/>In-Memory)]
                UserDB[(👤 User Data<br/>In-Memory)]
                NotificationDB[(🔔 Notification Data<br/>In-Memory)]
            end
        end
        
        subgraph "📈 Monitoring Stack"
            Prometheus[📊 Prometheus<br/>Port: 9090<br/>Metrics Collection]
            Grafana[📈 Grafana<br/>Port: 3000<br/>Visualization]
            Jaeger[🔍 Jaeger<br/>Port: 16686<br/>Tracing]
        end
    end
    
    subgraph "☁️ Kubernetes Infrastructure"
        K8sAPI[⚙️ Kubernetes API]
        Pods[📦 Pods]
        Services[🔗 Services]
        Ingress[🌐 Ingress]
    end
    
    %% User Flow
    User --> LoadBalancer
    LoadBalancer --> Gateway
    Gateway --> Frontend
    
    %% Frontend to Services
    Frontend --> BlogService
    Frontend --> CommentService
    Frontend --> UserService
    Frontend --> NotificationService
    
    %% Service Interactions
    BlogService --> NotificationService
    CommentService --> BlogService
    CommentService --> NotificationService
    UserService --> NotificationService
    
    %% Data Connections
    BlogService --> BlogDB
    CommentService --> CommentDB
    UserService --> UserDB
    NotificationService --> NotificationDB
    
    %% Monitoring
    BlogService -.-> Prometheus
    CommentService -.-> Prometheus
    UserService -.-> Prometheus
    NotificationService -.-> Prometheus
    Frontend -.-> Prometheus
    
    Prometheus --> Grafana
    
    %% Kubernetes
    Gateway --> K8sAPI
    Frontend --> Pods
    BlogService --> Pods
    CommentService --> Pods
    UserService --> Pods
    NotificationService --> Pods
    
    %% Styling
    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef backend fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef database fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef monitoring fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef infrastructure fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef external fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    
    class Frontend frontend
    class BlogService,CommentService,UserService,NotificationService backend
    class BlogDB,CommentDB,UserDB,NotificationDB database
    class Prometheus,Grafana,Jaeger monitoring
    class K8sAPI,Pods,Services,Ingress infrastructure
    class User,LoadBalancer,Gateway external
```

## 🔄 Luồng Dữ liệu Chi tiết

### 1. Luồng Tạo Blog Post

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant F as 🖥️ Frontend
    participant B as 📝 Blog Service
    participant N as 🔔 Notification Service
    participant DB as 📚 Blog Database
    
    U->>F: POST /create-blog
    F->>B: POST /api/blogs
    B->>DB: Store blog data
    DB-->>B: Success
    B->>N: POST /api/notifications
    N->>N: Broadcast to SSE clients
    N-->>B: Notification sent
    B-->>F: Blog created
    F-->>U: Success response
    
    Note over N: Real-time notification<br/>sent to all connected users
```

### 2. Luồng Tạo Comment

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant F as 🖥️ Frontend
    participant C as 💬 Comment Service
    participant B as 📝 Blog Service
    participant N as 🔔 Notification Service
    participant CDB as 💭 Comment DB
    
    U->>F: POST /create-comment
    F->>C: POST /api/comments
    C->>B: GET /api/blogs/:id (validate)
    B-->>C: Blog exists
    C->>CDB: Store comment
    CDB-->>C: Success
    C->>N: POST /api/notifications
    N->>N: Notify blog author
    N-->>C: Notification sent
    C-->>F: Comment created
    F-->>U: Success response
```

### 3. Luồng Real-time Notifications

```mermaid
sequenceDiagram
    participant U1 as 👤 User 1
    participant U2 as 👤 User 2
    participant F as 🖥️ Frontend
    participant N as 🔔 Notification Service
    
    U1->>F: Connect to SSE
    F->>N: GET /api/notifications/stream
    N-->>F: SSE Connection established
    
    U2->>F: Create blog post
    F->>N: POST /api/notifications
    N->>N: Process notification
    N-->>F: SSE: New blog notification
    F-->>U1: Display notification
    
    Note over N: Server-Sent Events<br/>for real-time updates
```

## 🏗️ Deployment Architecture

```mermaid
graph TB
    subgraph "🏢 Development Environment"
        DevLaptop[💻 Developer Laptop]
        LocalDocker[🐳 Local Docker]
        LocalServices[🔧 Local Services<br/>Port: 3000-3004]
    end
    
    subgraph "☁️ Production Environment"
        subgraph "Kubernetes Cluster"
            subgraph "Istio System"
                IstioGateway[🚪 Istio Gateway]
                IstioSidecar[🔀 Envoy Sidecars]
            end
            
            subgraph "blog-microservices namespace"
                K8sPods[📦 Service Pods]
                K8sServices[🔗 Kubernetes Services]
                K8sDeployments[📋 Deployments]
            end
            
            subgraph "istio-system namespace"
                IstioControl[⚙️ Istio Control Plane]
                IstioIngress[🌐 Istio Ingress Gateway]
            end
        end
        
        subgraph "External Services"
            Registry[📋 Container Registry]
            LoadBalancer[⚖️ Load Balancer]
        end
    end
    
    DevLaptop --> LocalDocker
    LocalDocker --> LocalServices
    
    DevLaptop --> Registry
    Registry --> K8sDeployments
    K8sDeployments --> K8sPods
    K8sPods --> K8sServices
    K8sServices --> IstioSidecar
    IstioSidecar --> IstioGateway
    IstioGateway --> IstioIngress
    IstioIngress --> LoadBalancer
    
    IstioControl --> IstioSidecar
    IstioControl --> IstioGateway
```

## 🔐 Security Architecture

```mermaid
graph TB
    subgraph "🔒 Security Layers"
        subgraph "Network Security"
            TLS[🔐 TLS Termination]
            NetworkPolicy[🛡️ Network Policies]
        end
        
        subgraph "Service Mesh Security"
            mTLS[🔐 Mutual TLS]
            JWT[🎫 JWT Validation]
            AuthZ[🔑 Authorization]
        end
        
        subgraph "Application Security"
            CORS[🌐 CORS Configuration]
            Validation[✅ Input Validation]
            RateLimit[⏱️ Rate Limiting]
        end
    end
    
    subgraph "🏢 Services"
        Gateway[🚪 Istio Gateway]
        Frontend[🖥️ Frontend]
        BlogService[📝 Blog Service]
        CommentService[💬 Comment Service]
        UserService[👥 User Service]
        NotificationService[🔔 Notification Service]
    end
    
    TLS --> Gateway
    JWT --> Gateway
    Gateway --> Frontend
    
    mTLS --> BlogService
    mTLS --> CommentService
    mTLS --> UserService
    mTLS --> NotificationService
    
    AuthZ --> BlogService
    AuthZ --> CommentService
    AuthZ --> UserService
    AuthZ --> NotificationService
    
    CORS --> Frontend
    Validation --> BlogService
    Validation --> CommentService
    Validation --> UserService
    Validation --> NotificationService
    
    NetworkPolicy --> BlogService
    NetworkPolicy --> CommentService
    NetworkPolicy --> UserService
    NetworkPolicy --> NotificationService
```

## 📊 Monitoring Architecture

```mermaid
graph TB
    subgraph "📈 Observability Stack"
        subgraph "Metrics"
            Prometheus[📊 Prometheus<br/>Metrics Collection]
            Grafana[📈 Grafana<br/>Visualization]
            ServiceMonitor[📋 Service Monitors]
        end
        
        subgraph "Tracing"
            Jaeger[🔍 Jaeger<br/>Distributed Tracing]
            Zipkin[📍 Zipkin<br/>Alternative Tracing]
        end
        
        subgraph "Logging"
            Fluentd[📝 Fluentd<br/>Log Collection]
            ELK[🔍 ELK Stack<br/>Log Analysis]
        end
    end
    
    subgraph "🏢 Services"
        IstioProxy[🔀 Istio Proxy]
        BlogService[📝 Blog Service]
        CommentService[💬 Comment Service]
        UserService[👥 User Service]
        NotificationService[🔔 Notification Service]
    end
    
    subgraph "📊 Dashboards"
        SystemDashboard[🖥️ System Dashboard]
        ServiceDashboard[📋 Service Dashboard]
        BusinessDashboard[📊 Business Metrics]
    end
    
    BlogService --> IstioProxy
    CommentService --> IstioProxy
    UserService --> IstioProxy
    NotificationService --> IstioProxy
    
    IstioProxy --> Prometheus
    IstioProxy --> Jaeger
    IstioProxy --> Fluentd
    
    ServiceMonitor --> Prometheus
    Prometheus --> Grafana
    
    Grafana --> SystemDashboard
    Grafana --> ServiceDashboard
    Grafana --> BusinessDashboard
    
    Jaeger --> ServiceDashboard
    ELK --> ServiceDashboard
```

## 🔄 CI/CD Pipeline

```mermaid
graph LR
    subgraph "🔨 Development"
        Code[💻 Source Code]
        LocalTest[🧪 Local Testing]
        Git[📦 Git Repository]
    end
    
    subgraph "🏗️ Build Pipeline"
        Build[🔨 Build Images]
        Test[🧪 Run Tests]
        Registry[📋 Push to Registry]
    end
    
    subgraph "🚀 Deployment Pipeline"
        Deploy[📦 Deploy to K8s]
        Configure[⚙️ Configure Istio]
        Monitor[📊 Setup Monitoring]
    end
    
    subgraph "✅ Verification"
        HealthCheck[🏥 Health Checks]
        SmokeTest[🔥 Smoke Tests]
        Production[🌐 Production Ready]
    end
    
    Code --> LocalTest
    LocalTest --> Git
    Git --> Build
    Build --> Test
    Test --> Registry
    Registry --> Deploy
    Deploy --> Configure
    Configure --> Monitor
    Monitor --> HealthCheck
    HealthCheck --> SmokeTest
    SmokeTest --> Production
```

---

**Các sơ đồ trên minh họa toàn bộ kiến trúc của hệ thống Blog Microservices từ góc độ người dùng đến infrastructure, bao gồm security, monitoring, và deployment pipeline.**
