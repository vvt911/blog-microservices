const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Service URLs
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';

// In-memory data store - V2 with enhanced features
let blogs = [
    {
        id: 1,
        title: "⭐ [V2] Welcome to Microservices with Istio V2",
        content: "🎯 This is our enhanced blog post with V2 features! We now support tags, categories, and better search capabilities with our new service mesh architecture. ⭐ V2 Enhanced Features Available!",
        author: "John Doe ⭐",
        createdAt: new Date().toISOString(),
        likes: 25,
        tags: ["microservices", "istio", "kubernetes"],
        category: "Technology",
        featured: true
    },
    {
        id: 2,
        title: "⭐ [V2] Advanced Service Mesh Architecture",
        content: "🚀 Version 2 brings advanced traffic routing, circuit breakers, and enhanced observability. Service mesh now provides better resilience and performance monitoring. ⭐ V2 Enhanced Features Available!",
        author: "Jane Smith ⭐",
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        likes: 45,
        tags: ["service-mesh", "architecture", "observability"],
        category: "Architecture",
        featured: true
    },
    {
        id: 3,
        title: "⭐ [V2] Kubernetes Monitoring and Observability",
        content: "📊 V2 includes comprehensive monitoring with Prometheus, Grafana, and distributed tracing. Monitor your microservices like never before! ⭐ V2 Enhanced Features Available!",
        author: "Mike Johnson ⭐",
        createdAt: new Date(Date.now() - 172800000).toISOString(),
        likes: 18,
        tags: ["kubernetes", "monitoring", "prometheus"],
        category: "DevOps",
        featured: false
    }
];

let nextId = 4;

// Routes
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'blog-service-v2',
        timestamp: new Date().toISOString(),
        version: '2.0.0',
        features: ['tags', 'categories', 'featured-posts', 'enhanced-search']
    });
});

// Get all blogs with V2 features
app.get('/blogs', (req, res) => {
    console.log('📚 V2: Fetching all blogs with enhanced features...');
    
    // Add V2 headers for easy identification
    res.set('X-Service-Version', 'v2');
    res.set('X-Service-Features', 'tags,categories,featured-posts,enhanced-search');
    
    // V2 Feature: Support for filtering by category and tags
    const { category, tag, featured } = req.query;
    let filteredBlogs = blogs;
    
    if (category) {
        filteredBlogs = filteredBlogs.filter(blog => 
            blog.category && blog.category.toLowerCase() === category.toLowerCase()
        );
    }
    
    if (tag) {
        filteredBlogs = filteredBlogs.filter(blog => 
            blog.tags && blog.tags.some(t => t.toLowerCase().includes(tag.toLowerCase()))
        );
    }
    
    if (featured === 'true') {
        filteredBlogs = filteredBlogs.filter(blog => blog.featured);
    }
    
    res.json({
        version: '2.0.0',
        serviceVersion: 'V2 ⭐',
        total: filteredBlogs.length,
        message: '🎯 Enhanced V2 API with advanced features!',
        blogs: filteredBlogs
    });
});

// Get blog by ID with V2 features
app.get('/blogs/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const blog = blogs.find(b => b.id === id);
    
    if (!blog) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    console.log(`📖 V2: Fetching blog: ${blog.title}`);
    res.json({
        version: '2.0.0',
        blog: blog
    });
});

// Create new blog with V2 features
app.post('/blogs', async (req, res) => {
    const { title, content, author, tags, category, featured } = req.body;
    
    if (!title || !content || !author) {
        return res.status(400).json({ error: 'Title, content, and author are required' });
    }
    
    const newBlog = {
        id: nextId++,
        title: `🆕 ${title}`, // V2 adds emoji prefix
        content,
        author,
        createdAt: new Date().toISOString(),
        likes: 0,
        tags: tags || [],
        category: category || 'General',
        featured: featured || false
    };
    
    blogs.push(newBlog);
    console.log(`✍️ V2: New blog created: ${newBlog.title}`);
    
    // Send enhanced notification
    try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/notify`, {
            type: 'blog_created_v2',
            message: `🆕 New V2 blog post: "${title}" by ${author}`,
            blogId: newBlog.id,
            category: newBlog.category,
            tags: newBlog.tags
        });
    } catch (error) {
        console.error('Failed to send notification:', error.message);
    }
    
    res.status(201).json({
        version: '2.0.0',
        blog: newBlog
    });
});

// Update blog with V2 features
app.put('/blogs/:id', async (req, res) => {
    const id = parseInt(req.params.id);
    const blogIndex = blogs.findIndex(b => b.id === id);
    
    if (blogIndex === -1) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    const { title, content, author, tags, category, featured } = req.body;
    
    blogs[blogIndex] = {
        ...blogs[blogIndex],
        title: title || blogs[blogIndex].title,
        content: content || blogs[blogIndex].content,
        author: author || blogs[blogIndex].author,
        tags: tags || blogs[blogIndex].tags,
        category: category || blogs[blogIndex].category,
        featured: featured !== undefined ? featured : blogs[blogIndex].featured,
        updatedAt: new Date().toISOString()
    };
    
    console.log(`🔄 V2: Updated blog: ${blogs[blogIndex].title}`);
    
    // Send notification
    try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/notify`, {
            type: 'blog_updated_v2',
            message: `🔄 Blog updated: "${blogs[blogIndex].title}"`,
            blogId: id
        });
    } catch (error) {
        console.error('Failed to send notification:', error.message);
    }
    
    res.json({
        version: '2.0.0',
        blog: blogs[blogIndex]
    });
});

// Delete blog
app.delete('/blogs/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const blogIndex = blogs.findIndex(b => b.id === id);
    
    if (blogIndex === -1) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    const deletedBlog = blogs.splice(blogIndex, 1)[0];
    console.log(`🗑️ V2: Deleted blog: ${deletedBlog.title}`);
    
    res.json({
        version: '2.0.0',
        message: 'Blog deleted successfully',
        blog: deletedBlog
    });
});

// V2 New endpoint: Get featured blogs
app.get('/featured', (req, res) => {
    console.log('⭐ V2: Fetching featured blogs...');
    const featuredBlogs = blogs.filter(blog => blog.featured);
    res.json({
        version: '2.0.0',
        total: featuredBlogs.length,
        blogs: featuredBlogs
    });
});

// V2 New endpoint: Get blogs by category
app.get('/categories/:category', (req, res) => {
    const category = req.params.category;
    console.log(`📁 V2: Fetching blogs in category: ${category}`);
    
    const categoryBlogs = blogs.filter(blog => 
        blog.category && blog.category.toLowerCase() === category.toLowerCase()
    );
    
    res.json({
        version: '2.0.0',
        category: category,
        total: categoryBlogs.length,
        blogs: categoryBlogs
    });
});

// V2 New endpoint: Search blogs
app.get('/search', (req, res) => {
    const { q } = req.query;
    console.log(`🔍 V2: Searching blogs for: ${q}`);
    
    if (!q) {
        return res.status(400).json({ error: 'Query parameter q is required' });
    }
    
    const searchResults = blogs.filter(blog => 
        blog.title.toLowerCase().includes(q.toLowerCase()) ||
        blog.content.toLowerCase().includes(q.toLowerCase()) ||
        blog.author.toLowerCase().includes(q.toLowerCase()) ||
        (blog.tags && blog.tags.some(tag => tag.toLowerCase().includes(q.toLowerCase())))
    );
    
    res.json({
        version: '2.0.0',
        query: q,
        total: searchResults.length,
        blogs: searchResults
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Blog Service V2 running on port ${PORT}`);
    console.log(`📖 Version: 2.0.0`);
    console.log(`🆕 Enhanced features: tags, categories, featured posts, search`);
    console.log(`🔗 API endpoints:`);
    console.log(`   GET /health - Health check`);
    console.log(`   GET /blogs - Get all blogs (with filters)`);
    console.log(`   GET /blogs/:id - Get blog by ID`);
    console.log(`   POST /blogs - Create new blog`);
    console.log(`   PUT /blogs/:id - Update blog`);
    console.log(`   DELETE /blogs/:id - Delete blog`);
    console.log(`   GET /featured - Get featured blogs`);
    console.log(`   GET /categories/:category - Get blogs by category`);
    console.log(`   GET /search?q=term - Search blogs`);
});
