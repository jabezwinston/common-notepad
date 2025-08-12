const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(express.static('public'));
app.use(express.json());

// Store users and document state
let users = new Map(); // CSV users
let connectedUsers = new Map(); // Currently connected users with their positions
let documentContent = ''; // The shared document content

// Load users from CSV file
function loadUsersFromCSV() {
  return new Promise((resolve, reject) => {
    const userMap = new Map();
    
    fs.createReadStream('users.csv')
      .pipe(csv())
      .on('data', (row) => {
        // Assuming CSV has columns: username, password
        const username = row.username || row.Username;
        const password = row.password || row.Password;
        if (username && password) {
          userMap.set(username, password);
        }
      })
      .on('end', () => {
        console.log(`Loaded ${userMap.size} users from CSV`);
        resolve(userMap);
      })
      .on('error', reject);
  });
}

// Initialize users on startup
loadUsersFromCSV().then(userMap => {
  users = userMap;
}).catch(err => {
  console.error('Error loading users:', err);
  console.log('Creating default users.csv file...');
  
  // Create a default CSV file if it doesn't exist
  const defaultCSV = `username,password
admin,admin123
user1,password1
user2,password2
editor,editor123`;
  
  fs.writeFileSync('users.csv', defaultCSV);
  console.log('Created default users.csv with sample users');
  
  // Load the default users
  loadUsersFromCSV().then(userMap => {
    users = userMap;
  });
});

// Authentication endpoint
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  
  if (users.has(username) && users.get(username) === password) {
    res.json({ success: true, username });
  } else {
    res.json({ success: false, message: 'Invalid credentials' });
  }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  // Handle user authentication
  socket.on('authenticate', (data) => {
    const { username } = data;
    
    // Store user info
    connectedUsers.set(socket.id, {
      username,
      cursorPosition: 0,
      selectionStart: 0,
      selectionEnd: 0
    });

    // Send current document state and connected users
    socket.emit('document-state', {
      content: documentContent,
      users: Array.from(connectedUsers.values())
    });

    // Notify all clients about new user
    socket.broadcast.emit('user-joined', {
      username,
      socketId: socket.id
    });

    console.log(`User ${username} authenticated with socket ${socket.id}`);
  });

  // Handle text changes
  socket.on('text-change', (data) => {
    const { content, cursorPosition } = data;
    const user = connectedUsers.get(socket.id);
    
    if (user) {
      // Update document content
      documentContent = content;
      
      // Update user cursor position
      user.cursorPosition = cursorPosition;
      
      // Broadcast changes to all other clients
      socket.broadcast.emit('text-change', {
        content,
        userId: socket.id,
        username: user.username,
        cursorPosition
      });
    }
  });

  // Handle cursor position updates
  socket.on('cursor-position', (data) => {
    const user = connectedUsers.get(socket.id);
    
    if (user) {
      user.cursorPosition = data.position;
      user.selectionStart = data.selectionStart || data.position;
      user.selectionEnd = data.selectionEnd || data.position;
      
      // Broadcast cursor position to all other clients
      socket.broadcast.emit('cursor-position', {
        userId: socket.id,
        username: user.username,
        position: data.position,
        selectionStart: user.selectionStart,
        selectionEnd: user.selectionEnd
      });
    }
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    const user = connectedUsers.get(socket.id);
    if (user) {
      console.log(`User ${user.username} disconnected`);
      connectedUsers.delete(socket.id);
      
      // Notify all clients about user leaving
      socket.broadcast.emit('user-left', {
        userId: socket.id,
        username: user.username
      });
    }
  });
});

// Handle base path for Apache reverse proxy
const BASE_PATH = process.env.BASE_PATH || '';

// Serve the main HTML file
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Handle subpath routing for Apache
app.get('/Common_Notepad', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
server.listen('127.0.0.1', PORT, () => {
  console.log(`Collaborative editor server running on port ${PORT}`);
  console.log(`Access via Apache: http://your-server-ip/Common_Notepad`);
  console.log(`Direct access: http://localhost:${PORT}`);
});