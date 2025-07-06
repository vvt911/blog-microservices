const express = require('express');
const path = require('path');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.static('public'));
app.use(express.json());

// Service URLs
const BLOG_SERVICE_URL = process.env.BLOG_SERVICE_URL || 'http://localhost:3001';
const COMMENT_SERVICE_URL = process.env.COMMENT_SERVICE_URL || 'http://localhost:3002';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:3003';
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';

// User API Routes
app.get('/api/users', async (req, res) => {
  try {
    const response = await axios.get(`${USER_SERVICE_URL}/users`);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching users:', error.message);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const response = await axios.post(`${USER_SERVICE_URL}/users`, req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error creating user:', error.message);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// Blog API Routes
app.get('/api/blogs', async (req, res) => {
  try {
    const response = await axios.get(`${BLOG_SERVICE_URL}/blogs`);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching blogs:', error.message);
    res.status(500).json({ error: 'Failed to fetch blogs' });
  }
});

app.post('/api/blogs', async (req, res) => {
  try {
    const response = await axios.post(`${BLOG_SERVICE_URL}/blogs`, req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error creating blog:', error.message);
    res.status(500).json({ error: 'Failed to create blog' });
  }
});

app.put('/api/blogs/:id', async (req, res) => {
  try {
    const response = await axios.put(`${BLOG_SERVICE_URL}/blogs/${req.params.id}`, req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error updating blog:', error.message);
    res.status(500).json({ error: 'Failed to update blog' });
  }
});

app.delete('/api/blogs/:id', async (req, res) => {
  try {
    const response = await axios.delete(`${BLOG_SERVICE_URL}/blogs/${req.params.id}`);
    res.json(response.data);
  } catch (error) {
    console.error('Error deleting blog:', error.message);
    res.status(500).json({ error: 'Failed to delete blog' });
  }
});

// Comment API Routes
app.get('/api/blogs/:id/comments', async (req, res) => {
  try {
    const response = await axios.get(`${COMMENT_SERVICE_URL}/comments/blog/${req.params.id}`);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching comments:', error.message);
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

app.post('/api/comments', async (req, res) => {
  try {
    const response = await axios.post(`${COMMENT_SERVICE_URL}/comments`, req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error creating comment:', error.message);
    res.status(500).json({ error: 'Failed to create comment' });
  }
});

// Serve main page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Frontend service running on port ${PORT}`);
});
