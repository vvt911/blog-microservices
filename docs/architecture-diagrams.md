# 🎨 Sơ đồ Kiến trúc Hệ thống Blog Microservices

## 📊 Sơ đồ Kiến trúc Tổng quan

```mermaid
graph TB
    subgraph "🌐 External Access"
        User[👤 User Browser]
        Minikube[🔧 Minikube Cluster]
    end
    
    subgraph "🔒 Istio Service Mesh"
        subgraph "🌍 Istio Gateway"
            Gateway[🚪 blog-gateway<br/>Port: 80<br/>Host: *]
        end
        
        subgraph "🏢 blog-microservices namespace"
            subgraph "Frontend Layer"
                Frontend[🖥️ Frontend<br/>Port: 3000<br/>API Proxy + Static Files]
            end
            
            subgraph "Backend Services"
                BlogService[📝 Blog Service<br/>Port: 3001<br/>In-Memory Storage]
                CommentService[💬 Comment Service<br/>Port: 3002<br/>In-Memory Storage]
                UserService[👥 User Service<br/>Port: 3003<br/>In-Memory Storage]
                NotificationService[🔔 Notification Service<br/>Port: 3004<br/>In-Memory Storage]
            end
        end
        
        subgraph "🛡️ Istio Networking"
            VS1[📋 blog-virtualservice<br/>/ → frontend:3000]
            VS2[📋 blog-service-vs<br/>blog-service → :3001]
            VS3[📋 comment-service-vs<br/>comment-service → :3002]
            VS4[📋 user-service-vs<br/>user-service → :3003]
            VS5[📋 notification-service-vs<br/>notification-service → :3004]
            
            DR1[🎯 frontend-dr<br/>subset: v1]
            DR2[🎯 blog-service-dr<br/>subset: v1]
            DR3[🎯 comment-service-dr<br/>subset: v1]
            DR4[🎯 user-service-dr<br/>subset: v1]
            DR5[🎯 notification-service-dr<br/>subset: v1]
        end
        
        subgraph "📊 istio-system namespace"
            Prometheus[📊 Prometheus<br/>Port: 9090<br/>Metrics Collection]
            Grafana[📈 Grafana<br/>Port: 3000<br/>Visualization]
        end
    end
    
    %% User Flow
    User --> Minikube
    Minikube --> Gateway
    Gateway --> Frontend
    
    %% Frontend API Proxy Routes
    Frontend --> |/api/blogs| BlogService
    Frontend --> |/api/comments| CommentService
    Frontend --> |/api/users| UserService
    Frontend --> |/api/notifications| NotificationService
    
    %% Inter-Service Communication
    BlogService --> |POST /notify| NotificationService
    CommentService --> |GET /blogs/:id| BlogService
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
    Frontend -.-> Prometheus
    BlogService -.-> Prometheus
    CommentService -.-> Prometheus
    UserService -.-> Prometheus
    NotificationService -.-> Prometheus
    
    Prometheus --> Grafana
    
    %% Styling
    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef backend fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef monitoring fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef external fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    classDef istio fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class Frontend frontend
    class BlogService,CommentService,UserService,NotificationService backend
    class Prometheus,Grafana monitoring
    class User,Minikube,Gateway external
    class VS1,VS2,VS3,VS4,VS5,DR1,DR2,DR3,DR4,DR5 istio
```

## 🔄 Luồng Dữ liệu Chi tiết

### 1. Luồng Tạo Blog Post

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant F as 🖥️ Frontend
    participant B as 📝 Blog Service
    participant N as 🔔 Notification Service
    
    U->>F: POST /api/blogs<br/>{title, content, author}
    F->>B: POST /blogs<br/>{title, content, author}
    B->>B: Create blog object<br/>Store in memory array
    B->>N: POST /notify<br/>{type: "blog_created", message, blogId}
    N->>N: Create notification<br/>Store in memory array
    N-->>B: 201 Created
    B-->>F: 201 Created<br/>{id, title, content, author, createdAt, likes}
    F-->>U: Success response
    
    Note over B,N: Fire-and-forget notification<br/>Error handling with try-catch
```

### 2. Luồng Tạo Comment

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant F as 🖥️ Frontend
    participant C as 💬 Comment Service
    participant B as 📝 Blog Service
    participant N as 🔔 Notification Service
    
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

### 3. Luồng User Registration

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant F as 🖥️ Frontend
    participant US as 👥 User Service
    participant N as 🔔 Notification Service
    
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

### 4. Luồng Frontend API Proxy

```mermaid
sequenceDiagram
    participant B as 🌐 Browser
    participant F as 🖥️ Frontend
    participant S as 📦 Backend Service
    
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

## 🏗️ Kubernetes Deployment Architecture

```mermaid
graph TB
    subgraph "🏢 Development Environment"
        DevLaptop[💻 Developer Laptop]
        LocalServices[🔧 Local Services<br/>npm start on ports 3000-3004]
    end
    
    subgraph "☁️ Minikube Production"
        subgraph "Docker Environment"
            DockerImages[🐳 Docker Images<br/>blog-frontend:latest<br/>blog-service:latest<br/>comment-service:latest<br/>user-service:latest<br/>notification-service:latest]
        end
        
        subgraph "Kubernetes Resources"
            subgraph "blog-microservices namespace"
                Deployments[📋 Deployments<br/>replicas: 1<br/>imagePullPolicy: Never]
                Services[🔗 Services<br/>ClusterIP<br/>ports: 3000-3004]
                Pods[📦 Pods<br/>with Envoy sidecars]
            end
            
            subgraph "istio-system namespace"
                IstioGateway[🚪 Istio Gateway<br/>istio-ingressgateway]
                IstioControl[⚙️ Istio Control Plane]
                MonitoringPods[📊 Prometheus + Grafana<br/>from Istio addons]
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

## 🔐 Security & Configuration

```mermaid
graph TB
    subgraph "🔒 Istio Security"
        mTLS[🔐 Automatic mTLS<br/>Service-to-Service]
        Injection[💉 Sidecar Injection<br/>istio-injection: enabled]
        AuthPolicy[🛡️ Authorization Policies<br/>(Optional)]
    end
    
    subgraph "🌐 Network Configuration"
        Gateway[🚪 Gateway<br/>Port 80, Host: *]
        VirtualServices[📋 Virtual Services<br/>Routing Rules]
        DestinationRules[🎯 Destination Rules<br/>v1 subsets]
    end
    
    subgraph "🏢 Application Security"
        CORS[🌐 CORS Enabled<br/>All services]
        Validation[✅ Input Validation<br/>Required fields check]
        HealthChecks[🏥 Health Endpoints<br/>/health on all services]
        EnvVars[⚙️ Environment Variables<br/>Service URLs]
    end
    
    subgraph "📦 Services"
        Frontend[🖥️ Frontend]
        BlogService[📝 Blog Service]
        CommentService[💬 Comment Service]
        UserService[👥 User Service]
        NotificationService[🔔 Notification Service]
    end
    
    Injection --> Frontend
    Injection --> BlogService
    Injection --> CommentService
    Injection --> UserService
    Injection --> NotificationService
    
    mTLS --> BlogService
    mTLS --> CommentService
    mTLS --> UserService
    mTLS --> NotificationService
    
    Gateway --> VirtualServices
    VirtualServices --> DestinationRules
    
    CORS --> Frontend
    CORS --> BlogService
    CORS --> CommentService
    CORS --> UserService
    CORS --> NotificationService
    
    EnvVars --> Frontend
    EnvVars --> BlogService
    EnvVars --> CommentService
    EnvVars --> UserService
```

## 🗃️ Data Architecture

```mermaid
graph TB
    subgraph "💾 In-Memory Data Stores"
        BlogData[📝 Blog Data<br/>Array of blog objects<br/>- id, title, content, author<br/>- createdAt, likes]
        
        CommentData[💬 Comment Data<br/>Array of comment objects<br/>- id, blogId, author, content<br/>- createdAt, likes]
        
        UserData[👥 User Data<br/>Array of user objects<br/>- id, name, email, role<br/>- createdAt, profilePicture, bio]
        
        NotificationData[🔔 Notification Data<br/>Array of notification objects<br/>- id, type, message, timestamp<br/>- priority, read status]
    end
    
    subgraph "🔗 Service Interactions"
        BlogService[📝 Blog Service] --> BlogData
        CommentService[💬 Comment Service] --> CommentData
        UserService[👥 User Service] --> UserData
        NotificationService[🔔 Notification Service] --> NotificationData
        
        CommentService -.-> |Validate blogId| BlogService
        BlogService -.-> |Fire-and-forget| NotificationService
        CommentService -.-> |Fire-and-forget| NotificationService
        UserService -.-> |Fire-and-forget| NotificationService
    end
    
    subgraph "🎯 Sample Data"
        InitialBlogs[📚 3 Initial Blogs<br/>- Welcome to Microservices<br/>- Service Mesh Architecture<br/>- Kubernetes Best Practices]
        
        InitialComments[💭 5 Initial Comments<br/>- Distributed across blogs<br/>- From different authors<br/>- With timestamps]
        
        InitialUsers[👤 5 Initial Users<br/>- Different roles (admin, author, reader)<br/>- With profile pictures<br/>- Activity tracking]
        
        InitialNotifications[🔔 3 Initial Notifications<br/>- System initialized<br/>- User registered<br/>- Blog created]
    end
    
    BlogData --> InitialBlogs
    CommentData --> InitialComments
    UserData --> InitialUsers
    NotificationData --> InitialNotifications
```

## 📊 Monitoring & Observability

```mermaid
graph TB
    subgraph "📈 Istio Observability"
        EnvoySidecars[🔀 Envoy Sidecars<br/>Auto-injected<br/>Collect metrics]
        
        PrometheusEndpoints[📊 Prometheus Metrics<br/>HTTP requests, latency<br/>Service mesh metrics]
        
        ServiceMesh[🕸️ Service Mesh<br/>Traffic management<br/>Security policies]
    end
    
    subgraph "🎯 Monitoring Stack"
        Prometheus[📊 Prometheus<br/>Port: 9090<br/>Metrics scraping]
        
        Grafana[📈 Grafana<br/>Port: 3000<br/>Dashboards & visualization]
        
        IstioAddons[🔧 Istio Addons<br/>Pre-configured for service mesh]
    end
    
    subgraph "📱 Application Monitoring"
        HealthEndpoints[🏥 Health Endpoints<br/>Service status check]
        
        ConsoleLogging[📝 Console Logging<br/>Request/response logs]
        
        ServiceStatus[⚡ Service Status<br/>Running/healthy indicators]
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

**Sơ đồ kiến trúc trên phản ánh chính xác hệ thống Blog Microservices thực tế dựa trên các file cấu hình Kubernetes, Istio, và source code của từng service.**
