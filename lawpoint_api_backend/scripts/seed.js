const bcrypt = require('bcryptjs');
const { v4: uuid } = require('uuid');
const { run, get } = require('../src/db');
const { encryptText, lookupHash } = require('../src/utils/crypto');
const { nowIso } = require('../src/utils/time');

async function createUser({ role, email, phone, password, status = 'active', otpVerified = true }) {
  const emailHash = email ? lookupHash(email) : null;
  const phoneHash = phone ? lookupHash(phone) : null;

  let existing = null;

  if (emailHash) {
    existing = await get('SELECT * FROM users WHERE email_hash = ?', [emailHash]);
  }

  if (!existing && phoneHash) {
    existing = await get('SELECT * FROM users WHERE phone_hash = ?', [phoneHash]);
  }

  if (existing) return existing.id;

  const id = uuid();
  const ts = nowIso();

  await run(
    `INSERT INTO users (
      id,
      role,
      email_hash,
      email_enc,
      phone_hash,
      phone_enc,
      password_hash,
      status,
      otp_verified,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      role,
      emailHash,
      email ? encryptText(email) : null,
      phoneHash,
      phone ? encryptText(phone) : null,
      await bcrypt.hash(password, 10),
      status,
      otpVerified,
      ts,
      ts
    ]
  );

  return id;
}

async function ensureKnowledgeArticle({ topic, language, title, content, publishedAt }) {
  const existing = await get('SELECT * FROM knowledge_articles WHERE title = ?', [title]);
  if (existing) return existing.id;

  const id = uuid();

  await run(
    'INSERT INTO knowledge_articles (id, topic, language, title, content, published_at) VALUES (?, ?, ?, ?, ?, ?)',
    [id, topic, language, title, content, publishedAt]
  );

  return id;
}

(async () => {
  try {
    const ts = nowIso();

    const adminUserId = await createUser({
      role: 'admin',
      email: 'admin@lawpoint.test',
      phone: '0700000000',
      password: 'Password123!'
    });

    const clientUserId = await createUser({
      role: 'client',
      email: 'client@lawpoint.test',
      phone: '0711111111',
      password: 'Password123!'
    });

    const lawyerUserId = await createUser({
      role: 'lawyer',
      email: 'lawyer@lawpoint.test',
      phone: '0722222222',
      password: 'Password123!'
    });

    const existingClient = await get('SELECT * FROM client_profiles WHERE user_id = ?', [clientUserId]);
    const clientId = existingClient ? existingClient.id : uuid();

    if (!existingClient) {
      await run(
        `INSERT INTO client_profiles (
          id,
          user_id,
          full_name,
          district,
          preferred_language,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [clientId, clientUserId, 'Test Client', 'Colombo', 'English', ts, ts]
      );
    }

    const existingLawyer = await get('SELECT * FROM lawyer_profiles WHERE user_id = ?', [lawyerUserId]);
    const lawyerId = existingLawyer ? existingLawyer.id : uuid();

    if (!existingLawyer) {
      await run(
        `INSERT INTO lawyer_profiles (
          id,
          user_id,
          full_name,
          bio,
          district,
          languages,
          specializations,
          fees_lkr,
          verified_status,
          enrolment_no_enc,
          basl_id_enc,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          lawyerId,
          lawyerUserId,
          'Adv. Nadeesha Perera',
          'Family law and property dispute specialist.',
          'Colombo',
          JSON.stringify(['English', 'Sinhala']),
          JSON.stringify(['Family Law', 'Property']),
          7500,
          'approved',
          encryptText('SC12345'),
          encryptText('BASL9988'),
          ts,
          ts
        ]
      );
    }

    const existingVerification = await get('SELECT * FROM verification_requests WHERE lawyer_id = ?', [lawyerId]);
    if (!existingVerification) {
      await run(
        `INSERT INTO verification_requests (
          id,
          lawyer_id,
          status,
          submitted_at,
          decided_at,
          decided_by
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [uuid(), lawyerId, 'approved', ts, ts, adminUserId]
      );
    }

    await run('DELETE FROM availability_slots WHERE lawyer_id = ?', [lawyerId]);

    for (const slot of [
      { day: 1, start: '09:00', end: '12:00' },
      { day: 3, start: '14:00', end: '17:00' },
      { day: 5, start: '10:00', end: '13:00' }
    ]) {
      await run(
        `INSERT INTO availability_slots (
          id,
          lawyer_id,
          day_of_week,
          start_time,
          end_time,
          is_active
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [uuid(), lawyerId, slot.day, slot.start, slot.end, true]
      );
    }

    const existingCase = await get('SELECT * FROM cases WHERE client_id = ? AND lawyer_id = ?', [clientId, lawyerId]);
    const caseId = existingCase ? existingCase.id : uuid();

    if (!existingCase) {
      const caseTs = nowIso();

      await run(
        `INSERT INTO cases (
          id,
          client_id,
          lawyer_id,
          title,
          description,
          status,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [caseId, clientId, lawyerId, 'Property boundary dispute', null, 'active', caseTs, caseTs]
      );

      await run(
        `INSERT INTO case_updates (
          id,
          case_id,
          posted_by_lawyer_id,
          update_text,
          hearing_date,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [uuid(), caseId, lawyerId, 'Initial consultation completed. Awaiting land deed copy.', null, ts]
      );
    }

    await ensureKnowledgeArticle({
      topic: 'Criminal Procedure',
      language: 'English',
      title: 'Understanding bail in Sri Lanka',
      content: 'A starter article explaining the basic stages of bail and common terminology.',
      publishedAt: ts
    });

    await ensureKnowledgeArticle({
      topic: 'Family Law',
      language: 'English',
      title: 'How to prepare for a divorce consultation',
      content: 'Bring marriage documents, key dates, and any urgent child or property concerns for your first meeting.',
      publishedAt: ts
    });

    await ensureKnowledgeArticle({
      topic: 'Family Law',
      language: 'Sinhala',
      title: 'දික්කසාද උපදේශනයකට සූදානම් වන්නේ කෙසේද?',
      content: 'විවාහයට අදාල ලේඛන, වැදගත් දිනයන් සහ වහාම සැලකිල්ලට ගත යුතු කරුණු සූදානම් කරගෙන යන්න.',
      publishedAt: ts
    });

    await ensureKnowledgeArticle({
      topic: 'Property',
      language: 'Tamil',
      title: 'சொத்து ஆவணங்களை பாதுகாப்பாக வைத்திருப்பது எப்படி?',
      content: 'சொத்து ஆவணங்களை ஸ்கேன் செய்து பாதுகாப்பான காப்பகத்தில் சேமிக்கவும் மற்றும் பகிர்வதை கட்டுப்படுத்தவும்.',
      publishedAt: ts
    });

    const existingConversation = await get('SELECT * FROM conversations WHERE client_id = ? AND lawyer_id = ?', [clientId, lawyerId]);
    const conversationId = existingConversation ? existingConversation.id : uuid();

    if (!existingConversation) {
      await run(
        'INSERT INTO conversations (id, client_id, lawyer_id, created_at) VALUES (?, ?, ?, ?)',
        [conversationId, clientId, lawyerId, ts]
      );
    }

    const existingMessage = await get('SELECT * FROM messages WHERE conversation_id = ?', [conversationId]);
    if (!existingMessage) {
      await run(
        `INSERT INTO messages (
          id,
          conversation_id,
          sender_user_id,
          ciphertext,
          nonce,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [
          uuid(),
          conversationId,
          lawyerUserId,
          encryptText('Hello, I reviewed your case notes. Please upload the deed copy.'),
          uuid(),
          ts
        ]
      );
    }

    const existingAppointment = await get('SELECT * FROM appointments WHERE notes = ?', ['Starter video consultation']);
    if (!existingAppointment) {
      const start = new Date(Date.now() - 5 * 60 * 1000).toISOString();
      const end = new Date(Date.now() + 25 * 60 * 1000).toISOString();
      const appointmentId = uuid();

      await run(
        `INSERT INTO appointments (
          id,
          client_id,
          lawyer_id,
          start_at,
          end_at,
          status,
          notes,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [appointmentId, clientId, lawyerId, start, end, 'booked', 'Starter video consultation', ts, ts]
      );
    }

    console.log('Seed complete.');
    console.log('Admin: admin@lawpoint.test / Password123!');
    console.log('Client: client@lawpoint.test / Password123!');
    console.log('Lawyer: lawyer@lawpoint.test / Password123!');
  } catch (error) {
    console.error('Seed failed:', error);
    process.exit(1);
  }
})();