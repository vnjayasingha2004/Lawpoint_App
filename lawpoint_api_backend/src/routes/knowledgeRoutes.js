const express = require('express');

const router = express.Router();

const ITEMS = [
  {
    id: 'kh_en_001',
    topic: 'Family Law',
    language: 'english',
    title: 'Child Custody Basics in Sri Lanka',
    content:
      'A simple introduction to custody decisions, the child’s welfare, schooling, stability, and when legal advice is needed.',
    published_at: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_en_002',
    topic: 'Property',
    language: 'english',
    title: 'Land Deeds and Ownership Checks',
    content:
      'Before buying land, verify title history, survey plans, boundaries, taxes, and whether there are disputes or restrictions.',
    published_at: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_en_003',
    topic: 'Contracts',
    language: 'english',
    title: 'What to Check Before Signing a Contract',
    content:
      'Check names, payment terms, deadlines, cancellation rules, penalties, dispute clauses, and signatures before signing.',
    published_at: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000).toISOString(),
  },

  {
    id: 'kh_si_001',
    topic: 'Family Law',
    language: 'sinhala',
    title:
      '\u0daf\u0dbb\u0dd4\u0dc0\u0db1\u0dca\u0d9c\u0dda \u0db7\u0dcf\u0dbb\u0d9a\u0dcf\u0dbb\u0dad\u0dca\u0dc0\u0dba \u0d9c\u0dd0\u0db1 \u0db8\u0dd4\u0dbd\u0dd2\u0d9a \u0daf\u0dd0\u0db1\u0dd4\u0db8',
    content:
      '\u0dc1\u0dca\u200d\u0dbb\u0dd3 \u0dbd\u0d82\u0d9a\u0dcf\u0dc0\u0dda \u0daf\u0dbb\u0dd4\u0dc0\u0db1\u0dca\u0d9c\u0dda \u0db7\u0dcf\u0dbb\u0d9a\u0dcf\u0dbb\u0dad\u0dca\u0dc0\u0dba \u0dad\u0dd3\u0dbb\u0dab\u0dba \u0d9a\u0dd2\u0dbb\u0dd3\u0db8\u0dda\u0daf\u0dd3 \u0daf\u0dbb\u0dd4\u0dc0\u0dcf\u0d9c\u0dda \u0dba\u0dc4\u0db4\u0dad, \u0d86\u0dbb\u0d9a\u0dca\u0dc2\u0dcf\u0dc0 \u0dc3\u0dc4 \u0dc3\u0dca\u0dae\u0dcf\u0dc0\u0dbb \u0db4\u0dbb\u0dd2\u0dc3\u0dbb\u0dba \u0dc3\u0dbd\u0d9a\u0dcf \u0db6\u0dbd\u0dba\u0dd2.',
    published_at: new Date(Date.now() - 18 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_si_002',
    topic: 'Property',
    language: 'sinhala',
    title:
      '\u0d89\u0da9\u0db8\u0d9a\u0dca \u0db8\u0dd2\u0dbd\u0daf\u0dd3 \u0d9c\u0db1\u0dca\u0db1 \u0db4\u0dd9\u0dbb \u0db6\u0dbd\u0db1\u0dca\u0db1 \u0d95\u0db1\u0dda \u0daf\u0daa\u0dc0\u0dbd\u0dca',
    content:
      '\u0d94\u0db4\u0dca\u0db4\u0dd4 \u0d89\u0dad\u0dd2\u0dc4\u0dcf\u0dc3\u0dba, \u0dc0\u0dd2\u0d9a\u0dd4\u0dab\u0dd4\u0db8\u0dca\u0d9a\u0dbb\u0dd4\u0d9c\u0dda \u0db1\u0dd3\u0dad\u0dd2\u0db8\u0dba \u0d85\u0dba\u0dd2\u0dad\u0dd2\u0dba, \u0dc3\u0dbb\u0dca\u0dc0\u0dda \u0dc3\u0dd0\u0dbd\u0dc3\u0dd4\u0db8, \u0db8\u0dcf\u0dba\u0dd2\u0db8\u0dca \u0dc3\u0dc4 \u0db6\u0daf\u0dd4 \u0dc0\u0dcf\u0dbb\u0dca\u0dad\u0dcf \u0db4\u0dbb\u0dd3\u0d9a\u0dca\u0dc2\u0dcf \u0d9a\u0dc5 \u0dba\u0dd4\u0dad\u0dd4\u0dba.',
    published_at: new Date(Date.now() - 12 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_si_003',
    topic: 'Police Rights',
    language: 'sinhala',
    title:
      '\u0db4\u0ddc\u0dbd\u0dd2\u0dc3\u0dca \u0dc0\u0dd2\u0db8\u0dc3\u0dd3\u0db8\u0dca \u0d85\u0dad\u0dbb\u0dad\u0dd4\u0dbb \u0d94\u0db6\u0d9c\u0dda \u0d85\u0dba\u0dd2\u0dad\u0dd2\u0dc0\u0dcf\u0dc3\u0dd2\u0d9a\u0db8\u0dca',
    content:
      '\u0db4\u0ddc\u0dbd\u0dd2\u0dc3\u0dca \u0dc0\u0dd2\u0db8\u0dc3\u0dd3\u0db8\u0dca \u0d85\u0dad\u0dbb\u0dad\u0dd4\u0dbb \u0dc3\u0db1\u0dca\u0dc3\u0dd4\u0db1\u0dca\u0dc0 \u0dc3\u0dd2\u0da7\u0dd3\u0db8, \u0d9a\u0da9\u0daf\u0dcf\u0dc3\u0dd2 \u0d85\u0dad\u0dca\u0dc3\u0db1\u0dca \u0d9a\u0dd2\u0dbb\u0dd3\u0db8\u0da7 \u0db4\u0dd9\u0dbb \u0dad\u0dda\u0dbb\u0dd4\u0db8\u0dca \u0d9c\u0dd0\u0db1\u0dd3\u0db8 \u0dc3\u0dc4 \u0d85\u0dc0\u0dc1\u0dca\u200d\u0dba \u0db1\u0db8\u0dca \u0db1\u0dd3\u0dad\u0dd2 \u0d8b\u0db4\u0daf\u0dd9\u0dc3\u0dca \u0dbd\u0db6\u0dcf \u0d9c\u0dd0\u0db1\u0dd3\u0db8 \u0dc0\u0dd0\u0daf\u0d9c\u0dad\u0dca\u0dba.',
    published_at: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString(),
  },

  {
    id: 'kh_ta_001',
    topic: 'Family Law',
    language: 'tamil',
    title:
      '\u0b95\u0bc1\u0bb4\u0ba8\u0bcd\u0ba4\u0bc8 \u0baa\u0bbe\u0ba4\u0bc1\u0b95\u0bbe\u0baa\u0bcd\u0baa\u0bc1 \u0baa\u0bb1\u0bcd\u0bb1\u0bbf \u0b85\u0b9f\u0bbf\u0baa\u0bcd\u0baa\u0b9f\u0bc8 \u0ba4\u0b95\u0bb5\u0bb2\u0bcd',
    content:
      '\u0b87\u0bb2\u0b99\u0bcd\u0b95\u0bc8\u0baf\u0bbf\u0bb2\u0bcd \u0b95\u0bc1\u0bb4\u0ba8\u0bcd\u0ba4\u0bc8 \u0baa\u0bbe\u0ba4\u0bc1\u0b95\u0bbe\u0baa\u0bcd\u0baa\u0bc1 \u0ba4\u0bca\u0b9f\u0bb0\u0bcd\u0baa\u0bbe\u0ba9 \u0bae\u0bc1\u0b9f\u0bbf\u0bb5\u0bc1\u0b95\u0bb3\u0bbf\u0bb2\u0bcd \u0b95\u0bc1\u0bb4\u0ba8\u0bcd\u0ba4\u0bc8\u0baf\u0bbf\u0ba9\u0bcd \u0ba8\u0bb2\u0ba9\u0bc7 \u0bae\u0bc1\u0b95\u0bcd\u0b95\u0bbf\u0baf\u0bae\u0bcd. \u0baa\u0bbe\u0ba4\u0bc1\u0b95\u0bbe\u0baa\u0bcd\u0baa\u0bc1 \u0bae\u0bb1\u0bcd\u0bb1\u0bc1\u0bae\u0bcd \u0baa\u0bb0\u0bbe\u0bae\u0bb0\u0bbf\u0baa\u0bcd\u0baa\u0bc1 \u0ba4\u0bbf\u0bb1\u0ba9\u0bcd \u0b95\u0bb5\u0ba9\u0bbf\u0b95\u0bcd\u0b95\u0baa\u0bcd\u0baa\u0b9f\u0bc1\u0bae\u0bcd.',
    published_at: new Date(Date.now() - 16 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_ta_002',
    topic: 'Contracts',
    language: 'tamil',
    title:
      '\u0b92\u0baa\u0bcd\u0baa\u0ba8\u0bcd\u0ba4\u0ba4\u0bcd\u0ba4\u0bbf\u0bb2\u0bcd \u0b95\u0bc8\u0baf\u0bc6\u0bb4\u0bc1\u0ba4\u0bcd\u0ba4\u0bbf\u0b9f\u0bc1\u0bae\u0bcd \u0bae\u0bc1\u0ba9\u0bcd \u0baa\u0bbe\u0bb0\u0bcd\u0b95\u0bcd\u0b95 \u0bb5\u0bc7\u0ba3\u0bcd\u0b9f\u0bbf\u0baf\u0bb5\u0bc8',
    content:
      '\u0baa\u0ba3\u0bae\u0bcd, \u0b95\u0bbe\u0bb2\u0b95\u0bcd\u0b95\u0bc6\u0b9f\u0bc1, \u0bb0\u0ba4\u0bcd\u0ba4\u0bc1 \u0bb5\u0bbf\u0ba4\u0bbf\u0b95\u0bb3\u0bcd, \u0b85\u0baa\u0bb0\u0bbe\u0ba4\u0bae\u0bcd \u0bae\u0bb1\u0bcd\u0bb1\u0bc1\u0bae\u0bcd \u0ba4\u0b95\u0bb0\u0bbe\u0bb1\u0bc1 \u0ba4\u0bc0\u0bb0\u0bcd\u0bb5\u0bc1 \u0baa\u0bbf\u0bb0\u0bbf\u0bb5\u0bc8 \u0b95\u0bb5\u0ba9\u0bae\u0bbe\u0b95 \u0b9a\u0bb0\u0bbf\u0baa\u0bbe\u0bb0\u0bcd\u0b95\u0bcd\u0b95 \u0bb5\u0bc7\u0ba3\u0bcd\u0b9f\u0bc1\u0bae\u0bcd.',
    published_at: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'kh_ta_003',
    topic: 'Property',
    language: 'tamil',
    title:
      '\u0ba8\u0bbf\u0bb2\u0bae\u0bcd \u0bb5\u0bbe\u0b99\u0bcd\u0b95\u0bc1\u0bb5\u0ba4\u0bb1\u0bcd\u0b95\u0bc1 \u0bae\u0bc1\u0ba9\u0bcd \u0b89\u0bb0\u0bbf\u0bae\u0bc8\u0b9a\u0bcd \u0b9a\u0bbe\u0ba9\u0bcd\u0bb1\u0bc1\u0b95\u0bb3\u0bcd \u0b9a\u0bb0\u0bbf\u0baa\u0bbe\u0bb0\u0bcd\u0baa\u0bcd\u0baa\u0bc1',
    content:
      '\u0baa\u0ba4\u0bcd\u0ba4\u0bbf\u0bb0 \u0bb5\u0bb0\u0bb2\u0bbe\u0bb1\u0bc1, \u0b8e\u0bb2\u0bcd\u0bb2\u0bc8, survey plan, mortgage \u0b85\u0bb2\u0bcd\u0bb2\u0ba4\u0bc1 \u0bb5\u0bb4\u0b95\u0bcd\u0b95\u0bc1 \u0b89\u0bb3\u0bcd\u0bb3\u0ba4\u0bbe \u0b8e\u0ba9\u0bcd\u0baa\u0ba4\u0bc8 \u0b9a\u0bb0\u0bbf\u0baa\u0bbe\u0bb0\u0bcd\u0b95\u0bcd\u0b95 \u0bb5\u0bc7\u0ba3\u0bcd\u0b9f\u0bc1\u0bae\u0bcd.',
    published_at: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000).toISOString(),
  },
];

function normalizeLanguage(value) {
  const v = String(value || '').trim().toLowerCase();
  if (!v) return null;
  if (['en', 'eng', 'english'].includes(v)) return 'english';
  if (['si', 'sin', 'sinhala'].includes(v)) return 'sinhala';
  if (['ta', 'tam', 'tamil'].includes(v)) return 'tamil';
  return v;
}

router.get('/', async (req, res, next) => {
  try {
    const { q, language } = req.query;
    const normalizedLanguage = normalizeLanguage(language);

    const filtered = ITEMS.filter((row) => {
      const rowLanguage = normalizeLanguage(row.language);
      if (normalizedLanguage && rowLanguage !== normalizedLanguage) return false;

      if (q) {
        const text =
          `${row.topic || ''} ${row.title || ''} ${row.content || ''}`.toLowerCase();
        return text.includes(String(q).toLowerCase());
      }

      return true;
    });

    res.json({ items: filtered });
  } catch (error) {
    next(error);
  }
});

module.exports = router;