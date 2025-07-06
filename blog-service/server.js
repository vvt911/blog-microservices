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

// In-memory data store
let blogs = [
    {
        id: 1,
        title: "Welcome to Microservices with Istio",
        content: "This is our first blog post demonstrating how microservices work together with Istio service mesh. Each service is independent and communicates through well-defined APIs.",
        author: "John Doe",
        createdAt: new Date().toISOString(),
        likes: 15
    },
    {
        id: 2,
        title: "Understanding Service Mesh Architecture",
        content: "Service mesh provides a dedicated infrastructure layer for handling service-to-service communication. It makes communication between service instances flexible, reliable, and fast.",
        author: "Jane Smith",
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        likes: 23
    },
    {
        id: 3,
        title: "Kubernetes and Microservices Best Practices",
        content: "Running microservices on Kubernetes requires careful planning. This post covers deployment strategies, service discovery, and configuration management.",
        author: "Mike Johnson",
        createdAt: new Date(Date.now() - 172800000).toISOString(),
        likes: 8
    }
];

let nextId = 4;

// Routes
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'blog-service',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Get all blogs
app.get('/blogs', (req, res) => {
    console.log('📚 Fetching all blogs...');
    res.json(blogs);
});

// Get blog by ID
app.get('/blogs/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const blog = blogs.find(b => b.id === id);
    
    if (!blog) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    console.log(`📖 Fetching blog: ${blog.title}`);
    res.json(blog);
});

// Create new blog
app.post('/blogs', async (req, res) => {
    const { title, content, author } = req.body;
    
    if (!title || !content || !author) {
        return res.status(400).json({ error: 'Title, content, and author are required' });
    }
    
    const newBlog = {
        id: nextId++,
        title,
        content,
        author,
        createdAt: new Date().toISOString(),
        likes: 0
    };
    
    blogs.push(newBlog);
    console.log(`✍️ New blog created: ${newBlog.title}`);
    
    // Send notification (fire and forget)
    try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/notify`, {
            type: 'blog_created',
            message: `New blog post: "${title}" by ${author}`,
            blogId: newBlog.id
        });
    } catch (error) {
        console.error('Failed to send notification:', error.message);
    }
    
    res.status(201).json(newBlog);
});

// Update blog
app.put('/blogs/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const blogIndex = blogs.findIndex(b => b.id === id);
    
    if (blogIndex === -1) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    const { title, content } = req.body;
    
    if (title) blogs[blogIndex].title = title;
    if (content) blogs[blogIndex].content = content;
    blogs[blogIndex].updatedAt = new Date().toISOString();
    
    console.log(`📝 Blog updated: ${blogs[blogIndex].title}`);
    res.json(blogs[blogIndex]);
});

// Like a blog
app.post('/blogs/:id/like', (req, res) => {
    const id = parseInt(req.params.id);
    const blog = blogs.find(b => b.id === id);
    
    if (!blog) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    blog.likes++;
    console.log(`❤️ Blog liked: ${blog.title} (${blog.likes} likes)`);
    res.json({ likes: blog.likes });
});

// Delete blog
app.delete('/blogs/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const blogIndex = blogs.findIndex(b => b.id === id);
    
    if (blogIndex === -1) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    const deletedBlog = blogs.splice(blogIndex, 1)[0];
    console.log(`🗑️ Blog deleted: ${deletedBlog.title}`);
    res.json({ message: 'Blog deleted successfully' });
});

// Get blog statistics
app.get('/stats', (req, res) => {
    const stats = {
        totalBlogs: blogs.length,
        totalLikes: blogs.reduce((sum, blog) => sum + blog.likes, 0),
        averageLikes: blogs.length > 0 ? blogs.reduce((sum, blog) => sum + blog.likes, 0) / blogs.length : 0,
        mostLikedBlog: blogs.length > 0 ? blogs.reduce((prev, current) => (prev.likes > current.likes) ? prev : current) : null
    };
    
    console.log('📊 Blog statistics requested');
    res.json(stats);
});

app.listen(PORT, () => {
    console.log(`🚀 Blog Service running on port ${PORT}`);
    console.log(`📚 Loaded ${blogs.length} sample blogs`);
});
