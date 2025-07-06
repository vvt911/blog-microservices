const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3004;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory data store
let notifications = [
    {
        id: 1,
        type: 'system',
        message: 'Blog Microservices system initialized successfully',
        timestamp: new Date(Date.now() - 3600000).toISOString(),
        read: true,
        priority: 'low'
    },
    {
        id: 2,
        type: 'user_registered',
        message: 'New user registered: Alice Brown (alice.brown@example.com)',
        timestamp: new Date(Date.now() - 1800000).toISOString(),
        read: false,
        priority: 'medium',
        userId: 4
    },
    {
        id: 3,
        type: 'blog_created',
        message: 'New blog post: "Understanding Service Mesh Architecture" by Jane Smith',
        timestamp: new Date(Date.now() - 900000).toISOString(),
        read: false,
        priority: 'high',
        blogId: 2
    }
];

let nextId = 4;

// Routes
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'notification-service',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Get all notifications
app.get('/notifications', (req, res) => {
    const { type, read, priority, limit = 50 } = req.query;
    let filteredNotifications = [...notifications];
    
    if (type) {
        filteredNotifications = filteredNotifications.filter(n => n.type === type);
    }
    
    if (read !== undefined) {
        filteredNotifications = filteredNotifications.filter(n => n.read === (read === 'true'));
    }
    
    if (priority) {
        filteredNotifications = filteredNotifications.filter(n => n.priority === priority);
    }
    
    // Sort by timestamp (newest first) and limit results
    filteredNotifications.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    filteredNotifications = filteredNotifications.slice(0, parseInt(limit));
    
    console.log(`🔔 Fetching ${filteredNotifications.length} notifications`);
    res.json(filteredNotifications);
});

// Get notification by ID
app.get('/notifications/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const notification = notifications.find(n => n.id === id);
    
    if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
    }
    
    console.log(`🔔 Fetching notification: ${notification.message.substring(0, 50)}...`);
    res.json(notification);
});

// Create new notification
app.post('/notify', (req, res) => {
    const { type, message, priority = 'medium', userId, blogId, commentId } = req.body;
    
    if (!type || !message) {
        return res.status(400).json({ error: 'Type and message are required' });
    }
    
    const newNotification = {
        id: nextId++,
        type,
        message,
        timestamp: new Date().toISOString(),
        read: false,
        priority,
        ...(userId && { userId }),
        ...(blogId && { blogId }),
        ...(commentId && { commentId })
    };
    
    notifications.push(newNotification);
    console.log(`🔔 New notification created: ${type} - ${message.substring(0, 50)}...`);
    
    // Simulate sending notification (email, push, etc.)
    setTimeout(() => {
        console.log(`📤 Notification sent: ${newNotification.id}`);
    }, 100);
    
    res.status(201).json(newNotification);
});

// Mark notification as read
app.patch('/notifications/:id/read', (req, res) => {
    const id = parseInt(req.params.id);
    const notification = notifications.find(n => n.id === id);
    
    if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
    }
    
    notification.read = true;
    notification.readAt = new Date().toISOString();
    
    console.log(`✅ Notification marked as read: ${notification.id}`);
    res.json(notification);
});

// Mark all notifications as read
app.patch('/notifications/read-all', (req, res) => {
    const { type, userId } = req.body;
    let updatedCount = 0;
    
    notifications.forEach(notification => {
        if (!notification.read) {
            if ((!type || notification.type === type) && 
                (!userId || notification.userId === userId)) {
                notification.read = true;
                notification.readAt = new Date().toISOString();
                updatedCount++;
            }
        }
    });
    
    console.log(`✅ Marked ${updatedCount} notifications as read`);
    res.json({ message: `${updatedCount} notifications marked as read` });
});

// Delete notification
app.delete('/notifications/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const notificationIndex = notifications.findIndex(n => n.id === id);
    
    if (notificationIndex === -1) {
        return res.status(404).json({ error: 'Notification not found' });
    }
    
    const deletedNotification = notifications.splice(notificationIndex, 1)[0];
    console.log(`🗑️ Notification deleted: ${deletedNotification.id}`);
    res.json({ message: 'Notification deleted successfully' });
});

// Delete old notifications
app.delete('/notifications/cleanup', (req, res) => {
    const { olderThanDays = 30 } = req.query;
    const cutoffDate = new Date(Date.now() - (parseInt(olderThanDays) * 24 * 60 * 60 * 1000));
    
    const initialCount = notifications.length;
    notifications = notifications.filter(n => new Date(n.timestamp) > cutoffDate);
    const deletedCount = initialCount - notifications.length;
    
    console.log(`🧹 Cleaned up ${deletedCount} old notifications (older than ${olderThanDays} days)`);
    res.json({ message: `${deletedCount} old notifications deleted` });
});

// Get notification statistics
app.get('/stats', (req, res) => {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 3600000);
    const oneDayAgo = new Date(now.getTime() - 86400000);
    const oneWeekAgo = new Date(now.getTime() - 604800000);
    
    const stats = {
        totalNotifications: notifications.length,
        unreadNotifications: notifications.filter(n => !n.read).length,
        notificationsLastHour: notifications.filter(n => new Date(n.timestamp) > oneHourAgo).length,
        notificationsLastDay: notifications.filter(n => new Date(n.timestamp) > oneDayAgo).length,
        notificationsLastWeek: notifications.filter(n => new Date(n.timestamp) > oneWeekAgo).length,
        notificationsByType: notifications.reduce((acc, notification) => {
            acc[notification.type] = (acc[notification.type] || 0) + 1;
            return acc;
        }, {}),
        notificationsByPriority: notifications.reduce((acc, notification) => {
            acc[notification.priority] = (acc[notification.priority] || 0) + 1;
            return acc;
        }, {})
    };
    
    console.log('📊 Notification statistics requested');
    res.json(stats);
});

// Get unread notification count
app.get('/unread-count', (req, res) => {
    const { userId, type } = req.query;
    let unreadNotifications = notifications.filter(n => !n.read);
    
    if (userId) {
        unreadNotifications = unreadNotifications.filter(n => n.userId === parseInt(userId));
    }
    
    if (type) {
        unreadNotifications = unreadNotifications.filter(n => n.type === type);
    }
    
    const count = unreadNotifications.length;
    console.log(`🔔 Unread notification count: ${count}`);
    res.json({ count });
});

// Broadcast notification to all users
app.post('/broadcast', (req, res) => {
    const { message, type = 'broadcast', priority = 'medium' } = req.body;
    
    if (!message) {
        return res.status(400).json({ error: 'Message is required' });
    }
    
    const broadcastNotification = {
        id: nextId++,
        type,
        message,
        timestamp: new Date().toISOString(),
        read: false,
        priority,
        broadcast: true
    };
    
    notifications.push(broadcastNotification);
    console.log(`📢 Broadcast notification created: ${message.substring(0, 50)}...`);
    
    res.status(201).json(broadcastNotification);
});

app.listen(PORT, () => {
    console.log(`🚀 Notification Service running on port ${PORT}`);
    console.log(`🔔 Loaded ${notifications.length} sample notifications`);
});
