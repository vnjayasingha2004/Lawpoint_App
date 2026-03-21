const jwt = require('jsonwebtoken');
const env = require('../config/env');

function getVideoWindow(startAt, endAt) {
  const start = new Date(startAt);
  const end = new Date(endAt);

  const allowedFrom = new Date(start.getTime() - 10 * 60 * 1000);
  const allowedUntil = new Date(end.getTime() + 30 * 60 * 1000);

  const now = Date.now();

  let state = 'OPEN';
  let message = 'Session ready.';

  if (now < allowedFrom.getTime()) {
    state = 'BEFORE_WINDOW';
    message = 'Video session is not open yet.';
  } else if (now > allowedUntil.getTime()) {
    state = 'EXPIRED';
    message = 'Video session has expired.';
  }

  return {
    allowedFrom: allowedFrom.toISOString(),
    allowedUntil: allowedUntil.toISOString(),
    canJoinNow: state === 'OPEN',
    state,
    message,
  };
}

function createVideoJoinToken({
  appointmentId,
  roomName,
  userId,
  role,
  allowedFrom,
  allowedUntil,
}) {
  const expiresInSeconds = Math.max(
    60,
    Math.ceil((new Date(allowedUntil).getTime() - Date.now()) / 1000),
  );

  return jwt.sign(
    {
      scope: 'video',
      appointmentId,
      roomName,
      userId,
      role,
      allowedFrom,
      allowedUntil,
    },
    env.jwtAccessSecret,
    { expiresIn: expiresInSeconds },
  );
}

function buildVideoSession({ appointment, requester }) {
  const roomName = `appointment_${appointment.videoSessionId}`;
  const windowInfo = getVideoWindow(appointment.startTime, appointment.endTime);

  return {
    sessionId: appointment.videoSessionId,
    appointmentId: appointment.id,
    provider: 'webrtc',
    roomName,
    joinUrl: `/video/${roomName}`,
    socketPath: '/ws/video',
    socketToken: windowInfo.canJoinNow
      ? createVideoJoinToken({
          appointmentId: appointment.id,
          roomName,
          userId: requester.id,
          role: requester.role,
          allowedFrom: windowInfo.allowedFrom,
          allowedUntil: windowInfo.allowedUntil,
        })
      : null,
    allowedFrom: windowInfo.allowedFrom,
    allowedUntil: windowInfo.allowedUntil,
    canJoinNow: windowInfo.canJoinNow,
    state: windowInfo.state,
    message: windowInfo.message,
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
    ],
  };
}

module.exports = { buildVideoSession };