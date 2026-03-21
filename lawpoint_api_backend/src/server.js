const fs = require('fs');
const http = require('http');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');


const env = require('./config/env');
const pool = require('./postgres');
const { errorHandler } = require('./middleware/error');
const { securityHeaders } = require('./middleware/securityHeaders');
const {
  sensitiveLimiter,
  paymentNotifyLimiter,
} = require('./middleware/rateLimiters');

const notificationRoutes = require('./routes/notificationRoutes');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const lawyerRoutes = require('./routes/lawyerRoutes');
const appointmentRoutes = require('./routes/appointmentRoutes');
const conversationRoutes = require('./routes/conversationRoutes');
const documentRoutes = require('./routes/documentRoutes');
const caseRoutes = require('./routes/caseRoutes');
const knowledgeRoutes = require('./routes/knowledgeRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const adminRoutes = require('./routes/adminRoutes');
const videoRoutes = require('./routes/videoRoutes');
const path = require('path');

fs.mkdirSync(env.storageDir, { recursive: true });

const app = express();
const server = http.createServer(app);

app.disable('x-powered-by');
app.use(securityHeaders());
app.use(helmet());
app.use(
  cors({
    origin: env.allowedOrigins === '*' ? true : env.allowedOrigins.split(','),
    credentials: true,
  })
);
app.use('/admin', express.static(path.join(__dirname, 'admin')));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    name: 'lawpoint-api-backend',
    time: new Date().toISOString(),
  });
});

app.get('/health/db', async (req, res) => {
  const timer = setTimeout(() => {
    if (!res.headersSent) {
      res.status(504).json({ ok: false, error: 'Database health check timed out.' });
    }
  }, 6000);

  try {
    const result = await pool.query('SELECT NOW() AS now');
    clearTimeout(timer);

    if (!res.headersSent) {
      res.json({ ok: true, time: result.rows[0].now });
    }
  } catch (error) {
    clearTimeout(timer);
    console.error('DB health error:', error);

    if (!res.headersSent) {
      res.status(500).json({ ok: false, error: error.message });
    }
  }
});

app.get('/api/v1/test-users-route', (req, res) => {
  res.json({ ok: true });
});

app.get('/payhere/return', (req, res) => {
  res.send(`
    <html>
      <body style="font-family:sans-serif;padding:24px">
        <h2>Payment submitted</h2>
        <p>You can return to the app now.</p>
      </body>
    </html>
  `);
});

app.get('/payhere/cancel', (req, res) => {
  res.send(`
    <html>
      <body style="font-family:sans-serif;padding:24px">
        <h2>Payment cancelled</h2>
        <p>You can return to the app now.</p>
      </body>
    </html>
  `);
});

// Apply sensitive limiters BEFORE mounting routes.
app.use('/api/v1/admin', sensitiveLimiter);
app.use('/api/v1/documents', sensitiveLimiter);
app.use('/api/v1/video/token', sensitiveLimiter);
app.use('/api/v1/payments/checkout-session', sensitiveLimiter);
app.use('/api/v1/payments/payhere/notify', paymentNotifyLimiter);

app.use('/api/v1/notifications', notificationRoutes);
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/lawyers', lawyerRoutes);
app.use('/api/v1/appointments', appointmentRoutes);
app.use('/api/v1/conversations', conversationRoutes);
app.use('/api/v1/documents', documentRoutes);
app.use('/api/v1/cases', caseRoutes);
app.use('/api/v1/knowledge', knowledgeRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/video', videoRoutes);

const io = new Server(server, {
  cors: {
    origin: env.allowedOrigins === '*' ? true : env.allowedOrigins.split(','),
    credentials: true,
  },
});

const videoNamespace = io.of('/ws/video');

videoNamespace.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next(new Error('Missing video token'));
    }

    const payload = jwt.verify(token, env.jwtAccessSecret);

    if (payload.scope !== 'video') {
      return next(new Error('Invalid video token'));
    }

    if (payload.allowedFrom && Date.now() < new Date(payload.allowedFrom).getTime()) {
      return next(new Error('Video session is not open yet'));
    }

    if (payload.allowedUntil && Date.now() > new Date(payload.allowedUntil).getTime()) {
      return next(new Error('Video session has expired'));
    }

    socket.data.roomName = payload.roomName;
    socket.data.userId = payload.userId;
    socket.data.role = payload.role;
    socket.data.appointmentId = payload.appointmentId;

    next();
  } catch (error) {
    next(new Error('Invalid or expired video token'));
  }
});

videoNamespace.on('connection', (socket) => {
  socket.on('join-room', () => {
    const { roomName, userId, role } = socket.data;
    if (!roomName || !userId) return;

    const room = videoNamespace.adapter.rooms.get(roomName);
    if (room && room.size >= 2) {
      socket.emit('room-full', {
        error: 'Both participants are already connected.',
      });
      return;
    }

    socket.join(roomName);
    socket.emit('room-joined', { roomName, userId, role });
    socket.to(roomName).emit('peer-joined', { userId, role });
  });

  socket.on('offer', (payload) => {
    if (!socket.data.roomName) return;
    socket.to(socket.data.roomName).emit('offer', payload);
  });

  socket.on('answer', (payload) => {
    if (!socket.data.roomName) return;
    socket.to(socket.data.roomName).emit('answer', payload);
  });

  socket.on('ice-candidate', (payload) => {
    if (!socket.data.roomName) return;
    socket.to(socket.data.roomName).emit('ice-candidate', payload);
  });

  socket.on('leave-room', () => {
    const { roomName, userId } = socket.data;
    if (roomName) {
      socket.to(roomName).emit('peer-left', { userId });
      socket.leave(roomName);
    }
  });

  socket.on('disconnect', () => {
    const { roomName, userId } = socket.data;
    if (roomName) {
      socket.to(roomName).emit('peer-left', { userId });
    }
  });
});

app.use(errorHandler);

server.listen(env.port, () => {
  console.log(`LawPoint API listening on port ${env.port}`);
});