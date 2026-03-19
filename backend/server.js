const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();
const nodemailer = require('nodemailer');
const { GoogleGenerativeAI } = require("@google/generative-ai");

const app = express();
app.use(express.json({ limit: '20mb' }));
app.use(cors());

const JWT_SECRET = 'supersecretkey_travelapp_123';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || 'AIzaSyDHMIWVfDN_b68ppDjNDcMwFvn0L0U6neA';
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// ---------------------------------------------------------
// DATABASE SETUP (SQLite)
// ---------------------------------------------------------
const db = new sqlite3.Database('./database.sqlite', (err) => {
    if (err) console.error('Error connecting to database', err);
    else console.log('Connected to SQLite Database');
});

db.serialize(() => {
    // Users
    db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        password TEXT,
        profilePicture TEXT,
        bio TEXT
    )`);
    db.run("ALTER TABLE users ADD COLUMN profilePicture TEXT", () => { });
    db.run("ALTER TABLE users ADD COLUMN bio TEXT", () => { });

    // Pending / OTP
    db.run(`CREATE TABLE IF NOT EXISTS pending_users (
        email TEXT PRIMARY KEY,
        fullName TEXT,
        phone TEXT,
        password TEXT,
        otpCode TEXT,
        expiresAt INTEGER
    )`);
    db.run(`CREATE TABLE IF NOT EXISTS password_resets (
        email TEXT PRIMARY KEY,
        otpCode TEXT,
        expiresAt INTEGER
    )`);

    // ---- SOCIAL FEATURES ----
    db.run(`CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        imageBase64 TEXT NOT NULL,
        caption TEXT,
        locationName TEXT,
        lat REAL,
        lng REAL,
        tags TEXT,
        createdAt INTEGER DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY(userId) REFERENCES users(id)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        UNIQUE(postId, userId),
        FOREIGN KEY(postId) REFERENCES posts(id),
        FOREIGN KEY(userId) REFERENCES users(id)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt INTEGER DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY(postId) REFERENCES posts(id),
        FOREIGN KEY(userId) REFERENCES users(id)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS follows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        followerId INTEGER NOT NULL,
        followingId INTEGER NOT NULL,
        UNIQUE(followerId, followingId),
        FOREIGN KEY(followerId) REFERENCES users(id),
        FOREIGN KEY(followingId) REFERENCES users(id)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        fromUserId INTEGER NOT NULL,
        postId INTEGER,
        type TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        createdAt INTEGER DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY(userId) REFERENCES users(id),
        FOREIGN KEY(fromUserId) REFERENCES users(id)
    )`);
});

// Helpers
const dbQuery = (query, params = []) => new Promise((resolve, reject) => {
    db.all(query, params, (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
    });
});
const dbRun = (query, params = []) => new Promise((resolve, reject) => {
    db.run(query, params, function (err) {
        if (err) reject(err);
        else resolve(this);
    });
});

// Auth middleware
const authMiddleware = (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ message: 'No token' });
    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) return res.status(401).json({ message: 'Invalid token' });
        req.user = decoded;
        next();
    });
};

// ---------------------------------------------------------
// EMAIL SETUP
// ---------------------------------------------------------
const GMAIL_USER = 'watggwp@gmail.com';
const GMAIL_APP_PASSWORD = 'apim llyh mqde bbpl';
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: GMAIL_USER, pass: GMAIL_APP_PASSWORD }
});
transporter.verify((error) => {
    if (error) console.warn('⚠️ Email config error:', error.message);
    else console.log('✅ Email server ready');
});

// ---------------------------------------------------------
// AUTH ROUTES
// ---------------------------------------------------------

// Register
app.post('/api/auth/register', async (req, res) => {
    const { fullName, email, phone, password } = req.body;
    try {
        const existingUser = await dbQuery('SELECT * FROM users WHERE email = ?', [email]);
        if (existingUser.length > 0) return res.status(400).json({ message: 'Email already exists' });

        const hashedPassword = await bcrypt.hash(password, 10);
        const otpCode = Math.floor(1000 + Math.random() * 9000).toString();
        const expiresAt = Date.now() + 60000;

        await dbRun(
            'INSERT OR REPLACE INTO pending_users (email, fullName, phone, password, otpCode, expiresAt) VALUES (?, ?, ?, ?, ?, ?)',
            [email, fullName, phone, hashedPassword, otpCode, expiresAt]
        );

        try {
            await transporter.sendMail({
                from: '"Travel App" <noreply@travelapp.com>',
                to: email,
                subject: 'Verify Your Email - Travel App',
                html: `<h2>Welcome to Travel App!</h2><p>Your OTP is: <strong>${otpCode}</strong></p><p>It will expire in 60 seconds.</p>`
            });
        } catch (err) { console.error('Email error:', err.message); }

        res.status(201).json({ message: 'Registration pending. OTP sent to email.', email });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Verify OTP
app.post('/api/auth/verify-otp', async (req, res) => {
    const { email, otp } = req.body;
    try {
        const pendingUsers = await dbQuery('SELECT * FROM pending_users WHERE email = ?', [email]);
        if (pendingUsers.length === 0) return res.status(400).json({ message: 'OTP not requested or expired' });

        const pendingUser = pendingUsers[0];
        if (Date.now() > pendingUser.expiresAt) {
            await dbRun('DELETE FROM pending_users WHERE email = ?', [email]);
            return res.status(400).json({ message: 'OTP has expired' });
        }

        if (pendingUser.otpCode === otp) {
            await dbRun(
                'INSERT INTO users (fullName, email, phone, password) VALUES (?, ?, ?, ?)',
                [pendingUser.fullName, pendingUser.email, pendingUser.phone, pendingUser.password]
            );
            await dbRun('DELETE FROM pending_users WHERE email = ?', [email]);
            res.status(200).json({ message: 'Account created successfully.' });
        } else {
            res.status(400).json({ message: 'Invalid OTP' });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Login
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const users = await dbQuery('SELECT * FROM users WHERE email = ?', [email]);
        if (users.length === 0) return res.status(404).json({ message: 'User not found' });

        const user = users[0];
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(401).json({ message: 'Invalid credentials' });

        const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
        res.status(200).json({
            message: 'Login successful', token,
            user: { id: user.id, fullName: user.fullName, email: user.email, phone: user.phone, profilePicture: user.profilePicture, bio: user.bio }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Me
app.get('/api/auth/me', (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ message: 'No token provided' });

    jwt.verify(token, JWT_SECRET, async (err, decoded) => {
        if (err) return res.status(401).json({ message: 'Invalid or expired token' });
        try {
            const users = await dbQuery('SELECT id, fullName, email, phone, profilePicture, bio FROM users WHERE id = ?', [decoded.id]);
            if (users.length === 0) return res.status(404).json({ message: 'User not found' });
            res.status(200).json({ user: users[0] });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    });
});

// Forgot Password
app.post('/api/auth/forgot-password', async (req, res) => {
    const { email } = req.body;
    try {
        const users = await dbQuery('SELECT * FROM users WHERE email = ?', [email]);
        if (users.length === 0) return res.status(404).json({ message: 'User not found' });

        const resetOtp = Math.floor(1000 + Math.random() * 9000).toString();
        const expiresAt = Date.now() + 60000;
        await dbRun(
            'INSERT OR REPLACE INTO password_resets (email, otpCode, expiresAt) VALUES (?, ?, ?)',
            [email, resetOtp, expiresAt]
        );

        try {
            await transporter.sendMail({
                from: '"Travel App" <noreply@travelapp.com>',
                to: email,
                subject: 'Reset Password - Travel App',
                html: `<h2>Password Reset Request</h2><p>Your reset OTP is: <strong>${resetOtp}</strong></p><p>It will expire in 60 seconds.</p>`
            });
        } catch (err) { console.error('Email error:', err.message); }

        res.status(200).json({ message: 'Password reset instructions sent to email.' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Verify Reset OTP
app.post('/api/auth/verify-reset-otp', async (req, res) => {
    const { email, otp } = req.body;
    try {
        const resetRecords = await dbQuery('SELECT * FROM password_resets WHERE email = ?', [email]);
        if (resetRecords.length === 0) return res.status(400).json({ message: 'OTP not requested or expired' });

        const resetRecord = resetRecords[0];
        if (Date.now() > resetRecord.expiresAt) {
            await dbRun('DELETE FROM password_resets WHERE email = ?', [email]);
            return res.status(400).json({ message: 'OTP has expired' });
        }

        if (resetRecord.otpCode === otp) {
            res.status(200).json({ message: 'OTP is valid' });
        } else {
            res.status(400).json({ message: 'Invalid OTP' });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Reset Password
app.post('/api/auth/reset-password', async (req, res) => {
    const { email, otp, newPassword } = req.body;
    try {
        const resetRecords = await dbQuery('SELECT * FROM password_resets WHERE email = ?', [email]);
        if (resetRecords.length === 0) return res.status(400).json({ message: 'OTP not requested or expired' });

        const resetRecord = resetRecords[0];
        if (Date.now() > resetRecord.expiresAt) {
            await dbRun('DELETE FROM password_resets WHERE email = ?', [email]);
            return res.status(400).json({ message: 'OTP has expired' });
        }

        if (resetRecord.otpCode === otp) {
            const hashedPassword = await bcrypt.hash(newPassword, 10);
            await dbRun('UPDATE users SET password = ? WHERE email = ?', [hashedPassword, email]);
            await dbRun('DELETE FROM password_resets WHERE email = ?', [email]);
            res.status(200).json({ message: 'Password reset successful' });
        } else {
            res.status(400).json({ message: 'Invalid OTP' });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ---------------------------------------------------------
// PROFILE ROUTES
// ---------------------------------------------------------

// Update profile
app.put('/api/user/profile', authMiddleware, async (req, res) => {
    try {
        const { fullName, phone, bio, profilePicture } = req.body;
        await dbRun(
            'UPDATE users SET fullName = ?, phone = ?, bio = ?, profilePicture = ? WHERE id = ?',
            [fullName, phone, bio, profilePicture, req.user.id]
        );
        res.status(200).json({ message: 'Profile updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get user public profile
app.get('/api/users/:userId', authMiddleware, async (req, res) => {
    try {
        const { userId } = req.params;
        const myId = req.user.id;

        const users = await dbQuery(
            'SELECT id, fullName, email, profilePicture, bio FROM users WHERE id = ?',
            [userId]
        );
        if (users.length === 0) return res.status(404).json({ message: 'User not found' });

        const user = users[0];

        const [posts, followers, following, isFollowing] = await Promise.all([
            dbQuery('SELECT id FROM posts WHERE userId = ?', [userId]),
            dbQuery('SELECT COUNT(*) as count FROM follows WHERE followingId = ?', [userId]),
            dbQuery('SELECT COUNT(*) as count FROM follows WHERE followerId = ?', [userId]),
            dbQuery('SELECT id FROM follows WHERE followerId = ? AND followingId = ?', [myId, userId]),
        ]);

        res.status(200).json({
            user: {
                ...user,
                postCount: posts.length,
                followerCount: followers[0].count,
                followingCount: following[0].count,
                isFollowing: isFollowing.length > 0,
            }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// ---------------------------------------------------------
// POSTS ROUTES
// ---------------------------------------------------------

// Create post
app.post('/api/posts', authMiddleware, async (req, res) => {
    try {
        const { imageBase64, caption, locationName, lat, lng, tags } = req.body;
        if (!imageBase64) return res.status(400).json({ message: 'Image is required' });

        const result = await dbRun(
            'INSERT INTO posts (userId, imageBase64, caption, locationName, lat, lng, tags) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [req.user.id, imageBase64, caption || '', locationName || '', lat || null, lng || null, JSON.stringify(tags || [])]
        );
        res.status(201).json({ message: 'Post created', postId: result.lastID });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get feed (all posts sorted by latest, with user info + like count + comment count)
app.get('/api/posts/feed', authMiddleware, async (req, res) => {
    try {
        const myId = req.user.id;
        const limit = parseInt(req.query.limit) || 20;
        const offset = parseInt(req.query.offset) || 0;

        const posts = await dbQuery(`
            SELECT 
                p.id, p.caption, p.locationName, p.lat, p.lng, p.tags, p.createdAt,
                p.imageBase64,
                u.id as userId, u.fullName, u.profilePicture,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id) as likeCount,
                (SELECT COUNT(*) FROM comments WHERE postId = p.id) as commentCount,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id AND userId = ?) as likedByMe
            FROM posts p
            JOIN users u ON p.userId = u.id
            ORDER BY p.createdAt DESC
            LIMIT ? OFFSET ?
        `, [myId, limit, offset]);

        res.status(200).json({ posts: posts.map(p => ({ ...p, likedByMe: p.likedByMe > 0 })) });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single post
app.get('/api/posts/:id', authMiddleware, async (req, res) => {
    try {
        const myId = req.user.id;
        const postId = parseInt(req.params.id);

        const posts = await dbQuery(`
            SELECT 
                p.id, p.caption, p.locationName, p.lat, p.lng, p.tags, p.createdAt,
                p.imageBase64,
                u.id as userId, u.fullName, u.profilePicture,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id) as likeCount,
                (SELECT COUNT(*) FROM comments WHERE postId = p.id) as commentCount,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id AND userId = ?) as likedByMe
            FROM posts p
            JOIN users u ON p.userId = u.id
            WHERE p.id = ?
        `, [myId, postId]);

        if (posts.length === 0) return res.status(404).json({ message: 'Post not found' });

        const post = { ...posts[0], likedByMe: posts[0].likedByMe > 0 };
        res.status(200).json({ post });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get posts by user
app.get('/api/users/:userId/posts', authMiddleware, async (req, res) => {
    try {
        const { userId } = req.params;
        const myId = req.user.id;

        const posts = await dbQuery(`
            SELECT 
                p.id, p.caption, p.locationName, p.lat, p.lng, p.tags, p.createdAt,
                p.imageBase64,
                u.id as userId, u.fullName, u.profilePicture,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id) as likeCount,
                (SELECT COUNT(*) FROM comments WHERE postId = p.id) as commentCount,
                (SELECT COUNT(*) FROM likes WHERE postId = p.id AND userId = ?) as likedByMe
            FROM posts p
            JOIN users u ON p.userId = u.id
            WHERE p.userId = ?
            ORDER BY p.createdAt DESC
        `, [myId, userId]);

        res.status(200).json({ posts: posts.map(p => ({ ...p, likedByMe: p.likedByMe > 0 })) });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Toggle like
app.post('/api/posts/:id/like', authMiddleware, async (req, res) => {
    try {
        const postId = req.params.id;
        const userId = req.user.id;

        const existing = await dbQuery('SELECT id FROM likes WHERE postId = ? AND userId = ?', [postId, userId]);
        if (existing.length > 0) {
            await dbRun('DELETE FROM likes WHERE postId = ? AND userId = ?', [postId, userId]);
            res.status(200).json({ liked: false });
        } else {
            await dbRun('INSERT INTO likes (postId, userId) VALUES (?, ?)', [postId, userId]);
            // Notify post owner (if not self-liking)
            const posts = await dbQuery('SELECT userId FROM posts WHERE id = ?', [postId]);
            if (posts.length > 0 && posts[0].userId !== userId) {
                await dbRun(
                    'INSERT INTO notifications (userId, fromUserId, postId, type) VALUES (?, ?, ?, ?)',
                    [posts[0].userId, userId, postId, 'like']
                );
            }
            res.status(200).json({ liked: true });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get comments
app.get('/api/posts/:id/comments', authMiddleware, async (req, res) => {
    try {
        const postId = req.params.id;
        const comments = await dbQuery(`
            SELECT c.id, c.text, c.createdAt, u.id as userId, u.fullName, u.profilePicture
            FROM comments c
            JOIN users u ON c.userId = u.id
            WHERE c.postId = ?
            ORDER BY c.createdAt ASC
        `, [postId]);
        res.status(200).json({ comments });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add comment
app.post('/api/posts/:id/comments', authMiddleware, async (req, res) => {
    try {
        const postId = req.params.id;
        const { text } = req.body;
        if (!text || !text.trim()) return res.status(400).json({ message: 'Comment text required' });

        const result = await dbRun(
            'INSERT INTO comments (postId, userId, text) VALUES (?, ?, ?)',
            [postId, req.user.id, text.trim()]
        );

        // Notify post owner (if not self-commenting)
        const posts = await dbQuery('SELECT userId FROM posts WHERE id = ?', [postId]);
        if (posts.length > 0 && posts[0].userId !== req.user.id) {
            await dbRun(
                'INSERT INTO notifications (userId, fromUserId, postId, type) VALUES (?, ?, ?, ?)',
                [posts[0].userId, req.user.id, postId, 'comment']
            );
        }

        const users = await dbQuery('SELECT fullName, profilePicture FROM users WHERE id = ?', [req.user.id]);
        res.status(201).json({
            comment: {
                id: result.lastID,
                postId,
                userId: req.user.id,
                text: text.trim(),
                createdAt: Math.floor(Date.now() / 1000),
                fullName: users[0].fullName,
                profilePicture: users[0].profilePicture,
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ---------------------------------------------------------
// NOTIFICATIONS ROUTES
// ---------------------------------------------------------

// Get notifications for current user
app.get('/api/notifications', authMiddleware, async (req, res) => {
    try {
        const notifications = await dbQuery(`
            SELECT n.id, n.type, n.isRead, n.createdAt, n.postId,
                   u.id as fromUserId, u.fullName as fromName, u.profilePicture as fromAvatar
            FROM notifications n
            JOIN users u ON n.fromUserId = u.id
            WHERE n.userId = ?
            ORDER BY n.createdAt DESC
            LIMIT 50
        `, [req.user.id]);
        res.status(200).json({ notifications });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get unread count
app.get('/api/notifications/unread-count', authMiddleware, async (req, res) => {
    try {
        const result = await dbQuery(
            'SELECT COUNT(*) as count FROM notifications WHERE userId = ? AND isRead = 0',
            [req.user.id]
        );
        res.status(200).json({ count: result[0].count });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Mark all as read
app.post('/api/notifications/read', authMiddleware, async (req, res) => {
    try {
        await dbRun('UPDATE notifications SET isRead = 1 WHERE userId = ?', [req.user.id]);
        res.status(200).json({ message: 'Marked as read' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ---------------------------------------------------------
// FOLLOWS ROUTES
// ---------------------------------------------------------

// Toggle follow/unfollow
app.post('/api/follows/:userId', authMiddleware, async (req, res) => {
    try {
        const followingId = parseInt(req.params.userId);
        const followerId = req.user.id;

        if (followerId === followingId) return res.status(400).json({ message: 'Cannot follow yourself' });

        const existing = await dbQuery(
            'SELECT id FROM follows WHERE followerId = ? AND followingId = ?',
            [followerId, followingId]
        );

        if (existing.length > 0) {
            await dbRun('DELETE FROM follows WHERE followerId = ? AND followingId = ?', [followerId, followingId]);
            res.status(200).json({ following: false });
        } else {
            await dbRun('INSERT INTO follows (followerId, followingId) VALUES (?, ?)', [followerId, followingId]);
            res.status(200).json({ following: true });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// ---------------------------------------------------------
// IMAGE PROXY
// ---------------------------------------------------------
const https = require('https');
app.get('/api/image', (req, res) => {
    const q = req.query.q;
    const url = `https://www.google.com/search?tbm=isch&q=${encodeURIComponent(q + ' Thailand')}`;

    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' } }, (response) => {
        let data = '';
        response.on('data', (chunk) => { data += chunk; });
        response.on('end', () => {
            const match = data.match(/https:\/\/encrypted-tbn0\.gstatic\.com\/images\?q=tbn:[a-zA-Z0-9_-]+/);
            if (match && match[0]) {
                res.redirect(match[0]);
            } else {
                res.redirect('https://loremflickr.com/400/300/thailand,travel');
            }
        });
    }).on('error', () => {
        res.redirect('https://loremflickr.com/400/300/thailand,travel');
    });
});

// ---------------------------------------------------------
// AI IDENTIFY
// ---------------------------------------------------------
app.post('/api/ai/identify', async (req, res) => {
    const { image, lat, lng, lang } = req.body;

    if (!GEMINI_API_KEY) {
        return res.status(200).json({
            result: `[Simulation] Based on GPS (${lat}, ${lng}), you are near a significant landmark.`
        });
    }

    try {
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });
        const imageParts = [{ inlineData: { data: image, mimeType: "image/jpeg" } }];
        const prompt = `Identify the place or landmark in this photo. These are the GPS coordinates: Latitude ${lat}, Longitude ${lng}. Give me a detailed history and interesting facts about this specific location. Provide the response in ${lang === 'th' ? 'Thai' : lang === 'ja' ? 'Japanese' : 'English'} language. Format it with clean markdown.`;

        const result = await model.generateContent([prompt, ...imageParts]);
        const response = await result.response;
        res.status(200).json({ result: response.text() });
    } catch (error) {
        console.error('AI error:', error);
        res.status(500).json({ message: 'AI processing failed' });
    }
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Backend server running on http://localhost:${PORT}`);
});
