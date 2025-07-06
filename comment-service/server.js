const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3002;

// Middleware
app.use(cors());
app.use(express.json());

// Service URLs
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';
const BLOG_SERVICE_URL = process.env.BLOG_SERVICE_URL || 'http://localhost:3001';

// In-memory data store
let comments = [
    {
        id: 1,
        blogId: 1,
        author: "Alice Brown",
        content: "Great introduction to microservices! Very helpful for beginners.",
        createdAt: new Date(Date.now() - 3600000).toISOString(),
        likes: 5
    },
    {
        id: 2,
        blogId: 1,
        author: "Bob Wilson",
        content: "Looking forward to more posts about Istio configuration.",
        createdAt: new Date(Date.now() - 1800000).toISOString(),
        likes: 2
    },
    {
        id: 3,
        blogId: 2,
        author: "Carol Davis",
        content: "Service mesh is indeed a game-changer for microservices architecture.",
        createdAt: new Date(Date.now() - 7200000).toISOString(),
        likes: 8
    },
    {
        id: 4,
        blogId: 2,
        author: "David Miller",
        content: "Can you write more about traffic management in Istio?",
        createdAt: new Date(Date.now() - 3600000).toISOString(),
        likes: 3
    },
    {
        id: 5,
        blogId: 3,
        author: "Eva Garcia",
        content: "Kubernetes best practices are always evolving. Thanks for sharing!",
        createdAt: new Date(Date.now() - 5400000).toISOString(),
        likes: 4
    }
];

let nextId = 6;

// Routes
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'comment-service',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Get all comments
app.get('/comments', (req, res) => {
    console.log('💬 Fetching all comments...');
    res.json(comments);
});

// Get comments by blog ID
app.get('/comments/blog/:blogId', (req, res) => {
    const blogId = parseInt(req.params.blogId);
    const blogComments = comments.filter(c => c.blogId === blogId);
    
    console.log(`💬 Fetching ${blogComments.length} comments for blog ${blogId}`);
    res.json(blogComments);
});

// Get comment by ID
app.get('/comments/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const comment = comments.find(c => c.id === id);
    
    if (!comment) {
        return res.status(404).json({ error: 'Comment not found' });
    }
    
    console.log(`💬 Fetching comment: ${comment.content.substring(0, 30)}...`);
    res.json(comment);
});

// Create new comment
app.post('/comments', async (req, res) => {
    const { blogId, author, content } = req.body;
    
    if (!blogId || !author || !content) {
        return res.status(400).json({ error: 'Blog ID, author, and content are required' });
    }
    
    // Verify blog exists
    try {
        await axios.get(`${BLOG_SERVICE_URL}/blogs/${blogId}`);
    } catch (error) {
        return res.status(404).json({ error: 'Blog not found' });
    }
    
    const newComment = {
        id: nextId++,
        blogId: parseInt(blogId),
        author,
        content,
        createdAt: new Date().toISOString(),
        likes: 0
    };
    
    comments.push(newComment);
    console.log(`💬 New comment added by ${author} on blog ${blogId}`);
    
    // Send notification (fire and forget)
    try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/notify`, {
            type: 'comment_created',
            message: `New comment by ${author} on blog ${blogId}`,
            commentId: newComment.id,
            blogId: blogId
        });
    } catch (error) {
        console.error('Failed to send notification:', error.message);
    }
    
    res.status(201).json(newComment);
});

// Update comment
app.put('/comments/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const commentIndex = comments.findIndex(c => c.id === id);
    
    if (commentIndex === -1) {
        return res.status(404).json({ error: 'Comment not found' });
    }
    
    const { content } = req.body;
    
    if (content) {
        comments[commentIndex].content = content;
        comments[commentIndex].updatedAt = new Date().toISOString();
    }
    
    console.log(`📝 Comment updated: ${comments[commentIndex].content.substring(0, 30)}...`);
    res.json(comments[commentIndex]);
});

// Like a comment
app.post('/comments/:id/like', (req, res) => {
    const id = parseInt(req.params.id);
    const comment = comments.find(c => c.id === id);
    
    if (!comment) {
        return res.status(404).json({ error: 'Comment not found' });
    }
    
    comment.likes++;
    console.log(`❤️ Comment liked: ${comment.content.substring(0, 30)}... (${comment.likes} likes)`);
    res.json({ likes: comment.likes });
});

// Delete comment
app.delete('/comments/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const commentIndex = comments.findIndex(c => c.id === id);
    
    if (commentIndex === -1) {
        return res.status(404).json({ error: 'Comment not found' });
    }
    
    const deletedComment = comments.splice(commentIndex, 1)[0];
    console.log(`🗑️ Comment deleted: ${deletedComment.content.substring(0, 30)}...`);
    res.json({ message: 'Comment deleted successfully' });
});

// Get comment statistics
app.get('/stats', (req, res) => {
    const stats = {
        totalComments: comments.length,
        totalLikes: comments.reduce((sum, comment) => sum + comment.likes, 0),
        averageLikes: comments.length > 0 ? comments.reduce((sum, comment) => sum + comment.likes, 0) / comments.length : 0,
        commentsByBlog: comments.reduce((acc, comment) => {
            acc[comment.blogId] = (acc[comment.blogId] || 0) + 1;
            return acc;
        }, {})
    };
    
    console.log('📊 Comment statistics requested');
    res.json(stats);
});

app.listen(PORT, () => {
    console.log(`🚀 Comment Service running on port ${PORT}`);
    console.log(`💬 Loaded ${comments.length} sample comments`);
});
