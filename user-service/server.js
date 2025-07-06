const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3003;

// Middleware
app.use(cors());
app.use(express.json());

// Service URLs
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';

// In-memory data store
let users = [
    {
        id: 1,
        name: "John Doe",
        email: "john.doe@example.com",
        role: "admin",
        createdAt: new Date(Date.now() - 2592000000).toISOString(), // 30 days ago
        lastActive: new Date().toISOString(),
        profilePicture: "https://api.dicebear.com/7.x/avataaars/svg?seed=John",
        bio: "Full-stack developer passionate about microservices and cloud architecture."
    },
    {
        id: 2,
        name: "Jane Smith",
        email: "jane.smith@example.com",
        role: "author",
        createdAt: new Date(Date.now() - 1728000000).toISOString(), // 20 days ago
        lastActive: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
        profilePicture: "https://api.dicebear.com/7.x/avataaars/svg?seed=Jane",
        bio: "DevOps engineer and technical writer specializing in Kubernetes and service mesh."
    },
    {
        id: 3,
        name: "Mike Johnson",
        email: "mike.johnson@example.com",
        role: "author",
        createdAt: new Date(Date.now() - 864000000).toISOString(), // 10 days ago
        lastActive: new Date(Date.now() - 7200000).toISOString(), // 2 hours ago
        profilePicture: "https://api.dicebear.com/7.x/avataaars/svg?seed=Mike",
        bio: "Cloud architect with expertise in container orchestration and microservices design."
    },
    {
        id: 4,
        name: "Alice Brown",
        email: "alice.brown@example.com",
        role: "reader",
        createdAt: new Date(Date.now() - 432000000).toISOString(), // 5 days ago
        lastActive: new Date(Date.now() - 1800000).toISOString(), // 30 minutes ago
        profilePicture: "https://api.dicebear.com/7.x/avataaars/svg?seed=Alice",
        bio: "Software engineer learning about modern cloud-native technologies."
    },
    {
        id: 5,
        name: "Bob Wilson",
        email: "bob.wilson@example.com",
        role: "reader",
        createdAt: new Date(Date.now() - 172800000).toISOString(), // 2 days ago
        lastActive: new Date(Date.now() - 900000).toISOString(), // 15 minutes ago
        profilePicture: "https://api.dicebear.com/7.x/avataaars/svg?seed=Bob",
        bio: "Backend developer interested in scalable system design and best practices."
    }
];

let nextId = 6;

// Routes
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'user-service',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Get all users
app.get('/users', (req, res) => {
    const { role, active } = req.query;
    let filteredUsers = [...users];
    
    if (role) {
        filteredUsers = filteredUsers.filter(u => u.role === role);
    }
    
    if (active === 'true') {
        const oneHourAgo = new Date(Date.now() - 3600000);
        filteredUsers = filteredUsers.filter(u => new Date(u.lastActive) > oneHourAgo);
    }
    
    console.log(`👥 Fetching ${filteredUsers.length} users (total: ${users.length})`);
    res.json(filteredUsers);
});

// Get user by ID
app.get('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const user = users.find(u => u.id === id);
    
    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    console.log(`👤 Fetching user: ${user.name}`);
    res.json(user);
});

// Create new user
app.post('/users', async (req, res) => {
    const { name, email, role = 'reader', bio } = req.body;
    
    if (!name || !email) {
        return res.status(400).json({ error: 'Name and email are required' });
    }
    
    // Check if email already exists
    if (users.find(u => u.email === email)) {
        return res.status(409).json({ error: 'Email already exists' });
    }
    
    const newUser = {
        id: nextId++,
        name,
        email,
        role,
        bio: bio || `${role.charAt(0).toUpperCase() + role.slice(1)} at Blog Microservices`,
        createdAt: new Date().toISOString(),
        lastActive: new Date().toISOString(),
        profilePicture: `https://api.dicebear.com/7.x/avataaars/svg?seed=${name.replace(' ', '')}`
    };
    
    users.push(newUser);
    console.log(`👤 New user created: ${newUser.name} (${newUser.email})`);
    
    // Send notification (fire and forget)
    try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/notify`, {
            type: 'user_registered',
            message: `New user registered: ${name} (${email})`,
            userId: newUser.id
        });
    } catch (error) {
        console.error('Failed to send notification:', error.message);
    }
    
    res.status(201).json(newUser);
});

// Update user
app.put('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const userIndex = users.findIndex(u => u.id === id);
    
    if (userIndex === -1) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    const { name, email, role, bio } = req.body;
    
    // Check if new email already exists (if changing email)
    if (email && email !== users[userIndex].email) {
        if (users.find(u => u.email === email)) {
            return res.status(409).json({ error: 'Email already exists' });
        }
        users[userIndex].email = email;
    }
    
    if (name) users[userIndex].name = name;
    if (role) users[userIndex].role = role;
    if (bio) users[userIndex].bio = bio;
    
    users[userIndex].updatedAt = new Date().toISOString();
    
    console.log(`📝 User updated: ${users[userIndex].name}`);
    res.json(users[userIndex]);
});

// Update user activity
app.post('/users/:id/activity', (req, res) => {
    const id = parseInt(req.params.id);
    const user = users.find(u => u.id === id);
    
    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    user.lastActive = new Date().toISOString();
    console.log(`⏰ User activity updated: ${user.name}`);
    res.json({ lastActive: user.lastActive });
});

// Delete user
app.delete('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const userIndex = users.findIndex(u => u.id === id);
    
    if (userIndex === -1) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    const deletedUser = users.splice(userIndex, 1)[0];
    console.log(`🗑️ User deleted: ${deletedUser.name}`);
    res.json({ message: 'User deleted successfully' });
});

// Get user statistics
app.get('/stats', (req, res) => {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 3600000);
    const oneDayAgo = new Date(now.getTime() - 86400000);
    const oneWeekAgo = new Date(now.getTime() - 604800000);
    
    const stats = {
        totalUsers: users.length,
        activeUsersLastHour: users.filter(u => new Date(u.lastActive) > oneHourAgo).length,
        activeUsersLastDay: users.filter(u => new Date(u.lastActive) > oneDayAgo).length,
        activeUsersLastWeek: users.filter(u => new Date(u.lastActive) > oneWeekAgo).length,
        usersByRole: users.reduce((acc, user) => {
            acc[user.role] = (acc[user.role] || 0) + 1;
            return acc;
        }, {}),
        recentRegistrations: users.filter(u => new Date(u.createdAt) > oneWeekAgo).length
    };
    
    console.log('📊 User statistics requested');
    res.json(stats);
});

// Get users by role
app.get('/users/role/:role', (req, res) => {
    const role = req.params.role;
    const roleUsers = users.filter(u => u.role === role);
    
    console.log(`👥 Fetching ${roleUsers.length} users with role: ${role}`);
    res.json(roleUsers);
});

app.listen(PORT, () => {
    console.log(`🚀 User Service running on port ${PORT}`);
    console.log(`👥 Loaded ${users.length} sample users`);
});
