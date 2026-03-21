const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { createWorker } = require('tesseract.js');
const { v4: uuid } = require('uuid');
const { PDFDocument } = require('pdf-lib');
const {
  createCanvas,
  DOMMatrix,
  ImageData,
  Path2D,
} = require('@napi-rs/canvas');

const env = require('../config/env');

global.DOMMatrix = global.DOMMatrix || DOMMatrix;
global.ImageData = global.ImageData || ImageData;
global.Path2D = global.Path2D || Path2D;

const OCR_LANGUAGES = process.env.OCR_LANGUAGES || 'eng+sin';
const NIC_TEMPLATE_ENABLED =
  String(process.env.NIC_TEMPLATE_ENABLED || 'true') !== 'false';
const PDF_REDACTION_ENABLED =
  String(process.env.PDF_REDACTION_ENABLED || 'true') !== 'false';
const PDF_RENDER_DPI = Number(process.env.PDF_RENDER_DPI || 144);
const PDF_MAX_SECRET_PAGES = Number(process.env.PDF_MAX_SECRET_PAGES || 10);
const NIC_AUTO_TRIM =
  String(process.env.NIC_AUTO_TRIM || 'true') !== 'false';

const NIC_SAFE_FALLBACK =
  String(process.env.NIC_SAFE_FALLBACK || 'true') !== 'false';
const NON_NIC_SAFE_FALLBACK =
  String(process.env.NON_NIC_SAFE_FALLBACK || 'false') === 'true';

const PRECISE_VALUE_MASKING =
  String(process.env.PRECISE_VALUE_MASKING || 'true') !== 'false';

const SECRET_DOCUMENT_CATEGORIES = [
  'sri_nic',
  'birth_certificate',
  'land_deed_extract',
  'other_secret',
];

const SUPPORTED_SECRET_IMAGE_MIME_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);

const SUPPORTED_SECRET_PDF_MIME_TYPES = new Set(['application/pdf']);

const COMMON_SENSITIVE_PATTERNS = [
  /\b\d{12}\b/,
  /\b\d{9}[VX]\b/i,
  /\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b/,
];

const CATEGORY_RULES = {
  sri_nic: {
    lineKeywords: [
      'DATE OF BIRTH',
      'ADDRESS',
      'PLACE OF BIRTH',
      'CARD SERIAL',
      'SERIAL NUMBER',
      'NIC NUMBER',
      'NATIONAL IDENTITY NUMBER',
      'ISSUE DATE',
      'HOLDER ADDRESS',
      'SIGNATURE',
      'BIRTH',
      'NAME',
      'IDENTITY CARD',
      'ජාතික හැඳුනුම්පත',
      'ජාතික හැඳුනුම්පත්',
      'හැඳුනුම්පත් අංකය',
      'ජාතික හැඳුනුම්පත් අංකය',
      'නම',
      'ලිපිනය',
      'උපන් දිනය',
      'උපන් ස්ථානය',
      'නිකුත් කළ දිනය',
      'අත්සන',
      'කාඩ් අංකය',
      'අනුක්‍රමික අංකය',
      'පුද්ගල අනන්‍යතාව',
    ],
    directPatterns: [...COMMON_SENSITIVE_PATTERNS],
  },

  birth_certificate: {
    lineKeywords: [
      'NAME OF CHILD',
      'CHILD',
      'FATHER',
      'MOTHER',
      'PARENTS',
      'ADDRESS',
      'DATE OF BIRTH',
      'PLACE OF BIRTH',
      'REGISTRATION',
      'ENTRY NO',
      'CERTIFICATE NO',
      'NIC',
      'NAME',
      'දරුවාගේ නම',
      'දරුවා',
      'පියාගේ නම',
      'මවගේ නම',
      'දෙමාපියන්',
      'දෙමව්පියන්',
      'ලිපිනය',
      'උපන් දිනය',
      'උපන් ස්ථානය',
      'ලියාපදිංචි අංකය',
      'සහතික අංකය',
      'හැඳුනුම්පත් අංකය',
      'නම',
    ],
    directPatterns: [...COMMON_SENSITIVE_PATTERNS],
  },

  land_deed_extract: {
    lineKeywords: [
      'OWNER',
      'PROPRIETOR',
      'ADDRESS',
      'NIC',
      'PASSPORT',
      'DRIVING LICENCE',
      'ASSESSMENT',
      'VOLUME',
      'FOLIO',
      'LOT',
      'PLAN',
      'BOUNDARY',
      'BOUNDARIES',
      'EXTENT',
      'DEED NO',
      'DEED NUMBER',
      'REGISTRATION NO',
      'REGISTRATION NUMBER',
      'PARCEL',
      'NAME',
      'LAND',
      'PROPERTY',
      'හිමිකරු',
      'හිමිකාර',
      'නම',
      'ලිපිනය',
      'හැඳුනුම්පත් අංකය',
      'ඔප්පු අංකය',
      'ලියාපදිංචි අංකය',
      'ඉඩම',
      'පිඹුරු',
      'කොටස',
      'මායිම්',
      'පර්චස්',
      'ප්‍රමාණය',
      'ඉඩමේ ප්‍රමාණය',
      'සැලැස්ම',
    ],
    directPatterns: [
      ...COMMON_SENSITIVE_PATTERNS,
      /\b[A-Z]{1,3}\d{4,12}\b/,
    ],
  },

  other_secret: {
    lineKeywords: [
      'NAME',
      'ADDRESS',
      'NIC',
      'PASSPORT',
      'DATE OF BIRTH',
      'ACCOUNT',
      'EMAIL',
      'PHONE',
      'SIGNATURE',
      'REGISTRATION',
      'CERTIFICATE',
      'නම',
      'ලිපිනය',
      'හැඳුනුම්පත්',
      'හැඳුනුම්පත් අංකය',
      'උපන් දිනය',
      'ගිණුම් අංකය',
      'දුරකථන',
      'විද්‍යුත් තැපෑල',
      'අත්සන',
      'ලියාපදිංචි අංකය',
      'සහතික අංකය',
    ],
    directPatterns: [
      ...COMMON_SENSITIVE_PATTERNS,
      /\b\d{10}\b/,
      /\b\d{3}\s?\d{3}\s?\d{4}\b/,
    ],
  },
};

let pdfJsPromise = null;

async function getPdfJs() {
  if (!pdfJsPromise) {
    pdfJsPromise = import('pdfjs-dist/legacy/build/pdf.mjs');
  }
  return pdfJsPromise;
}

function isSupportedSecretImageMime(mimeType) {
  return SUPPORTED_SECRET_IMAGE_MIME_TYPES.has(
    String(mimeType || '').toLowerCase()
  );
}

function isSupportedSecretPdfMime(mimeType) {
  return SUPPORTED_SECRET_PDF_MIME_TYPES.has(
    String(mimeType || '').toLowerCase()
  );
}

function isSupportedSecretUploadMime(mimeType, category) {
  if (isSupportedSecretImageMime(mimeType)) return true;

  if (isSupportedSecretPdfMime(mimeType)) {
    if (!PDF_REDACTION_ENABLED) return false;
    if (String(category || '').toLowerCase() === 'sri_nic') return false;
    return true;
  }

  return false;
}

function normalizeText(value) {
  return String(value || '')
    .toUpperCase()
    .replace(/[|[\]{}()_,:;'"`~]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeSinhalaText(value) {
  return String(value || '')
    .replace(/[|[\]{}()_,:;'"`~]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildNormalizedForms(value) {
  const raw = String(value || '').trim();
  return {
    raw,
    upper: normalizeText(raw),
    sinhala: normalizeSinhalaText(raw),
  };
}

function containsKeyword(forms, keyword) {
  const k = String(keyword || '').trim();
  if (!k) return false;

  const hasSinhala = /[\u0D80-\u0DFF]/.test(k);
  if (hasSinhala) {
    return forms.sinhala.includes(normalizeSinhalaText(k));
  }

  return forms.upper.includes(normalizeText(k));
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function intersectsRect(a, b) {
  return !(
    a.right < b.left ||
    a.left > b.right ||
    a.bottom < b.top ||
    a.top > b.bottom
  );
}

function clampBox(box, imageWidth, imageHeight) {
  const left = clamp(Math.round(box.left), 0, imageWidth - 1);
  const top = clamp(Math.round(box.top), 0, imageHeight - 1);
  const right = clamp(Math.round(box.right), left + 1, imageWidth);
  const bottom = clamp(Math.round(box.bottom), top + 1, imageHeight);

  return { left, top, right, bottom };
}

function boxToSizedRegion(box) {
  return {
    left: box.left,
    top: box.top,
    width: box.right - box.left,
    height: box.bottom - box.top,
  };
}

function sizedRegionToBox(region) {
  return {
    left: region.left,
    top: region.top,
    right: region.left + region.width,
    bottom: region.top + region.height,
  };
}

function toRectFromRatios(imageWidth, imageHeight, ratios) {
  return {
    left: Math.round(imageWidth * ratios.left),
    top: Math.round(imageHeight * ratios.top),
    right: Math.round(imageWidth * ratios.right),
    bottom: Math.round(imageHeight * ratios.bottom),
  };
}

function rectWithin(parent, ratios) {
  const width = parent.right - parent.left;
  const height = parent.bottom - parent.top;

  return {
    left: Math.round(parent.left + width * ratios.left),
    top: Math.round(parent.top + height * ratios.top),
    right: Math.round(parent.left + width * ratios.right),
    bottom: Math.round(parent.top + height * ratios.bottom),
  };
}

function expandBox(box, padX, padY, imageWidth, imageHeight) {
  return clampBox(
    {
      left: box.left - padX,
      top: box.top - padY,
      right: box.right + padX,
      bottom: box.bottom + padY,
    },
    imageWidth,
    imageHeight
  );
}

function groupWordsIntoLines(words, imageHeight) {
  const tolerance = Math.max(12, Math.round(imageHeight * 0.015));
  const sorted = [...words].sort((a, b) => {
    if (a.cy === b.cy) return a.left - b.left;
    return a.cy - b.cy;
  });

  const lines = [];
  for (const word of sorted) {
    const last = lines[lines.length - 1];
    if (!last || Math.abs(last.cy - word.cy) > tolerance) {
      lines.push({
        cy: word.cy,
        words: [word],
      });
    } else {
      last.words.push(word);
      last.cy = Math.round((last.cy + word.cy) / 2);
    }
  }

  for (const line of lines) {
    line.words.sort((a, b) => a.left - b.left);
    const joined = line.words.map((w) => w.text).join(' ');
    line.textRaw = joined;
    line.forms = buildNormalizedForms(joined);
  }

  return lines;
}

function rectFromWords(words, padding = 12) {
  const left = Math.min(...words.map((w) => w.left)) - padding;
  const top = Math.min(...words.map((w) => w.top)) - padding;
  const right = Math.max(...words.map((w) => w.right)) + padding;
  const bottom = Math.max(...words.map((w) => w.bottom)) + padding;

  return {
    left,
    top,
    right,
    bottom,
  };
}

function normalizeWordForCompare(value) {
  return normalizeText(String(value || '')).replace(/\s+/g, ' ').trim();
}

function findKeywordIndexInLine(words, keywords) {
  const normalizedWords = words.map((w) => normalizeWordForCompare(w.text));

  for (const keyword of keywords) {
    const normalizedKeyword = normalizeWordForCompare(keyword);
    if (!normalizedKeyword) continue;

    const keywordParts = normalizedKeyword.split(' ').filter(Boolean);
    if (!keywordParts.length) continue;

    for (let i = 0; i < normalizedWords.length; i += 1) {
      const slice = normalizedWords.slice(i, i + keywordParts.length);
      if (slice.join(' ') === keywordParts.join(' ')) {
        return i + keywordParts.length - 1;
      }
    }
  }

  return -1;
}

function buildValueRegionFromLine(lineWords, startIndex, imageWidth, imageHeight) {
  const valueWords = lineWords.slice(startIndex).filter((w) => {
    const text = String(w.text || '').trim();
    return text.length > 0;
  });

  if (!valueWords.length) return null;

  const box = clampBox(rectFromWords(valueWords, 10), imageWidth, imageHeight);
  return boxToSizedRegion(box);
}

function buildPatternWordRegions(words, patterns, imageWidth, imageHeight) {
  const out = [];

  for (const word of words) {
    const raw = String(word.text || '');
    const upper = normalizeText(raw);

    const matched = patterns.some(
      (pattern) => pattern.test(raw) || pattern.test(upper)
    );

    if (!matched) continue;

    const box = clampBox(rectFromWords([word], 10), imageWidth, imageHeight);
    out.push(boxToSizedRegion(box));
  }

  return out;
}

function buildPreciseLineRegions(lines, rules, imageWidth, imageHeight) {
  const out = [];

  for (const line of lines) {
    const keywordEndIndex = findKeywordIndexInLine(line.words, rules.lineKeywords);

    if (keywordEndIndex >= 0 && keywordEndIndex < line.words.length - 1) {
      const region = buildValueRegionFromLine(
        line.words,
        keywordEndIndex + 1,
        imageWidth,
        imageHeight
      );
      if (region) out.push(region);
      continue;
    }

    const hasPattern = rules.directPatterns.some(
      (pattern) =>
        pattern.test(String(line.textRaw || '')) ||
        pattern.test(String(line.forms?.upper || '')) ||
        pattern.test(String(line.forms?.sinhala || ''))
    );

    if (hasPattern) {
      const box = clampBox(rectFromWords(line.words, 10), imageWidth, imageHeight);
      out.push(boxToSizedRegion(box));
    }
  }

  return out;
}

function mergeRegions(regions) {
  if (!regions.length) return [];

  const sorted = [...regions].sort((a, b) => {
    if (a.top === b.top) return a.left - b.left;
    return a.top - b.top;
  });

  const out = [{ ...sorted[0] }];

  for (let i = 1; i < sorted.length; i += 1) {
    const prev = out[out.length - 1];
    const cur = sorted[i];

    const horizontalGap = Math.max(
      0,
      Math.max(cur.left - prev.right, prev.left - cur.right)
    );

    const verticalGap = Math.max(
      0,
      Math.max(cur.top - prev.bottom, prev.top - cur.bottom)
    );

    const sameBand =
      verticalGap <= 8 &&
      horizontalGap <= 16;

    const overlapping =
      cur.left <= prev.right &&
      cur.right >= prev.left &&
      cur.top <= prev.bottom &&
      cur.bottom >= prev.top;

    if (sameBand || overlapping) {
      prev.left = Math.min(prev.left, cur.left);
      prev.top = Math.min(prev.top, cur.top);
      prev.right = Math.max(prev.right, cur.right);
      prev.bottom = Math.max(prev.bottom, cur.bottom);
    } else {
      out.push({ ...cur });
    }
  }

  return out;
}

function shouldMaskLineByKeywords(forms, keywords) {
  return keywords.some((keyword) => containsKeyword(forms, keyword));
}

function shouldMaskByPattern(text, patterns) {
  return patterns.some((pattern) => pattern.test(String(text || '')));
}

function buildTextRuleRegions(words, category, imageWidth, imageHeight) {
  const rules = CATEGORY_RULES[category] || CATEGORY_RULES.other_secret;
  const lines = groupWordsIntoLines(words, imageHeight);

  if (PRECISE_VALUE_MASKING && category !== 'sri_nic') {
    const preciseRegions = [
      ...buildPreciseLineRegions(lines, rules, imageWidth, imageHeight),
      ...buildPatternWordRegions(
        words,
        rules.directPatterns,
        imageWidth,
        imageHeight
      ),
    ];

    return mergeRegions(preciseRegions.map(sizedRegionToBox))
      .map((box) => clampBox(box, imageWidth, imageHeight))
      .map(boxToSizedRegion)
      .filter((r) => r.width > 8 && r.height > 8);
  }

  const regions = [];

  for (const line of lines) {
    const shouldMaskLine =
      shouldMaskLineByKeywords(line.forms, rules.lineKeywords) ||
      shouldMaskByPattern(line.textRaw, rules.directPatterns) ||
      shouldMaskByPattern(line.forms.upper, rules.directPatterns) ||
      shouldMaskByPattern(line.forms.sinhala, rules.directPatterns);

    if (shouldMaskLine) {
      regions.push(rectFromWords(line.words, 14));
    }
  }

  for (const word of words) {
    const forms = buildNormalizedForms(word.text);
    const shouldMaskWord =
      shouldMaskByPattern(forms.raw, rules.directPatterns) ||
      shouldMaskByPattern(forms.upper, rules.directPatterns) ||
      shouldMaskLineByKeywords(forms, rules.lineKeywords);

    if (shouldMaskWord) {
      regions.push(rectFromWords([word], 10));
    }
  }

  return mergeRegions(regions)
    .map((box) => clampBox(box, imageWidth, imageHeight))
    .map(boxToSizedRegion)
    .filter((r) => r.width > 8 && r.height > 8);
}

function countCharsOnSide(words, imageWidth, side) {
  return words.reduce((sum, word) => {
    const cx = (word.left + word.right) / 2;
    const onSide =
      side === 'left' ? cx < imageWidth / 2 : cx >= imageWidth / 2;

    return onSide ? sum + String(word.text || '').length : sum;
  }, 0);
}

function detectNicTextSide(words, imageWidth) {
  const totalChars = words.reduce(
    (sum, word) => sum + String(word.text || '').length,
    0
  );

  if (totalChars < 10) {
    return 'right';
  }

  const leftChars = countCharsOnSide(words, imageWidth, 'left');
  const rightChars = countCharsOnSide(words, imageWidth, 'right');
  const maxSide = Math.max(leftChars, rightChars, 1);
  const deltaRatio = Math.abs(leftChars - rightChars) / maxSide;

  if (deltaRatio < 0.15) {
    return 'full';
  }

  return rightChars >= leftChars ? 'right' : 'left';
}

function wordsInsideRect(words, rect) {
  return words.filter((word) =>
    intersectsRect(
      {
        left: word.left,
        top: word.top,
        right: word.right,
        bottom: word.bottom,
      },
      rect
    )
  );
}

function buildSriNicTemplateRegions(words, imageWidth, imageHeight) {
  if (!NIC_TEMPLATE_ENABLED) {
    return {
      regions: [],
      mode: 'disabled',
      textArea: null,
      templateMatched: false,
    };
  }

  if (imageWidth < 420 || imageHeight < 220) {
    return {
      regions: [],
      mode: 'too_small',
      textArea: null,
      templateMatched: false,
    };
  }

  const nicAspect = 85.60 / 53.98;
  const ratio = imageWidth / imageHeight;

  if (Math.abs(ratio - nicAspect) > 0.45) {
    return {
      regions: [],
      mode: 'aspect_mismatch',
      textArea: null,
      templateMatched: false,
    };
  }

  const textSide = detectNicTextSide(words, imageWidth);

  let textArea;
  if (textSide === 'right') {
    textArea = toRectFromRatios(imageWidth, imageHeight, {
      left: 0.38,
      top: 0.06,
      right: 0.96,
      bottom: 0.95,
    });
  } else if (textSide === 'left') {
    textArea = toRectFromRatios(imageWidth, imageHeight, {
      left: 0.04,
      top: 0.06,
      right: 0.62,
      bottom: 0.95,
    });
  } else {
    textArea = toRectFromRatios(imageWidth, imageHeight, {
      left: 0.05,
      top: 0.06,
      right: 0.95,
      bottom: 0.95,
    });
  }

  const templateBands = [
    {
      name: 'identity_or_name',
      box: rectWithin(textArea, {
        left: 0.0,
        top: 0.04,
        right: 1.0,
        bottom: 0.20,
      }),
    },
    {
      name: 'dob_birth_place_number',
      box: rectWithin(textArea, {
        left: 0.0,
        top: 0.22,
        right: 1.0,
        bottom: 0.43,
      }),
    },
    {
      name: 'address_profession',
      box: rectWithin(textArea, {
        left: 0.0,
        top: 0.46,
        right: 1.0,
        bottom: 0.80,
      }),
    },
    {
      name: 'serial_footer',
      box: rectWithin(textArea, {
        left: 0.0,
        top: 0.82,
        right: 1.0,
        bottom: 0.96,
      }),
    },
  ];

  const qrCandidate =
    textSide === 'right'
      ? rectWithin(textArea, {
          left: 0.72,
          top: 0.66,
          right: 0.98,
          bottom: 0.96,
        })
      : textSide === 'left'
      ? rectWithin(textArea, {
          left: 0.02,
          top: 0.66,
          right: 0.28,
          bottom: 0.96,
        })
      : rectWithin(textArea, {
          left: 0.72,
          top: 0.66,
          right: 0.98,
          bottom: 0.96,
        });

  const boxes = [];

  for (const band of templateBands) {
    const bandWords = wordsInsideRect(words, band.box);

    if (bandWords.length >= 2) {
      boxes.push(
        clampBox(
          rectFromWords(
            bandWords,
            band.name === 'address_profession' ? 18 : 14
          ),
          imageWidth,
          imageHeight
        )
      );
    } else {
      boxes.push(expandBox(band.box, 4, 4, imageWidth, imageHeight));
    }
  }

  boxes.push(expandBox(qrCandidate, 4, 4, imageWidth, imageHeight));

  return {
    regions: mergeRegions(boxes).map(boxToSizedRegion),
    mode: `template_${textSide}`,
    textArea,
    templateMatched: true,
  };
}

function filterRegionsInsideTextArea(regions, textArea) {
  if (!textArea) return regions;

  return regions.filter((region) =>
    intersectsRect(sizedRegionToBox(region), textArea)
  );
}

function buildAllTextRegions(words, imageWidth, imageHeight) {
  if (!words.length) return [];

  const lines = groupWordsIntoLines(words, imageHeight);
  const boxes = lines.map((line) => rectFromWords(line.words, 14));

  return mergeRegions(boxes)
    .map((box) => clampBox(box, imageWidth, imageHeight))
    .map(boxToSizedRegion)
    .filter((r) => r.width > 8 && r.height > 8);
}

function buildSriNicBroadFallbackRegions(words, imageWidth, imageHeight) {
  const ratio = imageWidth / Math.max(imageHeight, 1);

  if (words.length >= 3) {
    const bbox = clampBox(rectFromWords(words, 28), imageWidth, imageHeight);
    return [boxToSizedRegion(bbox)];
  }

  let textArea;

  if (ratio >= 1.15) {
    const textSide = detectNicTextSide(words, imageWidth);

    if (textSide === 'left') {
      textArea = toRectFromRatios(imageWidth, imageHeight, {
        left: 0.03,
        top: 0.05,
        right: 0.68,
        bottom: 0.96,
      });
    } else if (textSide === 'right') {
      textArea = toRectFromRatios(imageWidth, imageHeight, {
        left: 0.32,
        top: 0.05,
        right: 0.97,
        bottom: 0.96,
      });
    } else {
      textArea = toRectFromRatios(imageWidth, imageHeight, {
        left: 0.18,
        top: 0.05,
        right: 0.97,
        bottom: 0.96,
      });
    }
  } else {
    textArea = toRectFromRatios(imageWidth, imageHeight, {
      left: 0.18,
      top: 0.15,
      right: 0.95,
      bottom: 0.95,
    });
  }

  const boxes = [
    rectWithin(textArea, { left: 0.00, top: 0.02, right: 1.00, bottom: 0.22 }),
    rectWithin(textArea, { left: 0.00, top: 0.24, right: 1.00, bottom: 0.46 }),
    rectWithin(textArea, { left: 0.00, top: 0.48, right: 1.00, bottom: 0.82 }),
    rectWithin(textArea, { left: 0.00, top: 0.84, right: 1.00, bottom: 0.98 }),
  ];

  return mergeRegions(
    boxes.map((box) => expandBox(box, 6, 6, imageWidth, imageHeight))
  )
    .map(boxToSizedRegion)
    .filter((r) => r.width > 8 && r.height > 8);
}

async function prepareSecretImageBuffer(buffer, category) {
  const oriented = await sharp(buffer).rotate().png().toBuffer();

  if (String(category || '').toLowerCase() !== 'sri_nic' || !NIC_AUTO_TRIM) {
    return oriented;
  }

  try {
    const originalMeta = await sharp(oriented).metadata();
    const trimmedResult = await sharp(oriented)
      .trim()
      .png()
      .toBuffer({ resolveWithObject: true });

    const trimmedBuffer = trimmedResult.data;
    const trimmedInfo = trimmedResult.info;

    const originalArea =
      Math.max(1, Number(originalMeta.width || 1)) *
      Math.max(1, Number(originalMeta.height || 1));

    const trimmedArea =
      Math.max(1, Number(trimmedInfo.width || 1)) *
      Math.max(1, Number(trimmedInfo.height || 1));

    const keptRatio = trimmedArea / originalArea;

    if (
      Number(trimmedInfo.width || 0) >= 250 &&
      Number(trimmedInfo.height || 0) >= 140 &&
      keptRatio >= 0.25
    ) {
      return trimmedBuffer;
    }

    return oriented;
  } catch {
    return oriented;
  }
}

function buildSensitiveRegions(words, category, imageWidth, imageHeight) {
  const ocrRegions = buildTextRuleRegions(words, category, imageWidth, imageHeight);

  if (category !== 'sri_nic') {
    if (ocrRegions.length) {
      return {
        regions: ocrRegions,
        mode: 'precise_non_nic',
      };
    }

    if (NON_NIC_SAFE_FALLBACK) {
      const allTextRegions = buildAllTextRegions(words, imageWidth, imageHeight);
      if (allTextRegions.length) {
        return {
          regions: allTextRegions,
          mode: 'non_nic_all_text_fallback',
        };
      }
    }

    return {
      regions: [],
      mode: 'manual_required_non_nic',
    };
  }

  const allTextRegions = buildAllTextRegions(words, imageWidth, imageHeight);
  const nicTemplate = buildSriNicTemplateRegions(words, imageWidth, imageHeight);

  if (nicTemplate.templateMatched) {
    const filteredOcrRegions = filterRegionsInsideTextArea(
      ocrRegions,
      nicTemplate.textArea
    );

    const filteredAllTextRegions = filterRegionsInsideTextArea(
      allTextRegions,
      nicTemplate.textArea
    );

    const merged = mergeRegions([
      ...nicTemplate.regions.map(sizedRegionToBox),
      ...filteredOcrRegions.map(sizedRegionToBox),
      ...filteredAllTextRegions.map(sizedRegionToBox),
    ])
      .map((box) => clampBox(box, imageWidth, imageHeight))
      .map(boxToSizedRegion)
      .filter((r) => r.width > 8 && r.height > 8);

    if (merged.length) {
      return {
        regions: merged,
        mode: `nic_${nicTemplate.mode}_plus_text`,
      };
    }
  }

  if (allTextRegions.length) {
    return {
      regions: allTextRegions,
      mode: 'nic_all_text_fallback',
    };
  }

  if (NIC_SAFE_FALLBACK) {
    const safeRegions = buildSriNicBroadFallbackRegions(
      words,
      imageWidth,
      imageHeight
    );

    if (safeRegions.length) {
      return {
        regions: safeRegions,
        mode: 'nic_safe_fallback',
      };
    }
  }

  return {
    regions: [],
    mode: 'manual_required_nic',
  };
}
async function blurRegions(imageBuffer, regions) {
  let current = await sharp(imageBuffer).png().toBuffer();

  for (const region of regions) {
    const patch = await sharp(current)
      .extract({
        left: region.left,
        top: region.top,
        width: region.width,
        height: region.height,
      })
      .blur(18)
      .png()
      .toBuffer();

    current = await sharp(current)
      .composite([
        {
          input: patch,
          left: region.left,
          top: region.top,
        },
      ])
      .png()
      .toBuffer();
  }

  return current;
}

async function createOcrWorker() {
  return createWorker(OCR_LANGUAGES);
}

async function recognizeWordsWithWorker(worker, imageBuffer) {
  const result = await worker.recognize(imageBuffer);
  const rawWords = result?.data?.words || [];

  return rawWords
    .map((word) => {
      const bbox = word.bbox || {};
      const left = Number(bbox.x0 || 0);
      const top = Number(bbox.y0 || 0);
      const right = Number(bbox.x1 || 0);
      const bottom = Number(bbox.y1 || 0);

      return {
        text: word.text || '',
        confidence: Number(word.confidence || 0),
        left,
        top,
        right,
        bottom,
        cy: Math.round((top + bottom) / 2),
      };
    })
    .filter((word) => word.text && word.right > word.left && word.bottom > word.top);
}

async function renderPdfPageToPng(page, dpi) {
  const scale = Math.max(1, Number(dpi || 144) / 72);
  const viewport = page.getViewport({ scale });

  const width = Math.max(1, Math.floor(viewport.width));
  const height = Math.max(1, Math.floor(viewport.height));

  const canvas = createCanvas(width, height);
  const context = canvas.getContext('2d');

  const renderTask = page.render({
    canvasContext: context,
    viewport,
  });

  await renderTask.promise;

  return canvas.toBuffer('image/png');
}

async function embedPngPage(pdfDoc, pngBuffer) {
  const image = await pdfDoc.embedPng(pngBuffer);
  const page = pdfDoc.addPage([image.width, image.height]);

  page.drawImage(image, {
    x: 0,
    y: 0,
    width: image.width,
    height: image.height,
  });
}

async function createImageRedactedDerivative({
  buffer,
  mimeType,
  originalFileName,
  category,
}) {
  if (!isSupportedSecretImageMime(mimeType)) {
    return {
      status: 'MANUAL_REQUIRED',
      storageKey: null,
      summary: {
        reason: 'unsupported_secret_image_type',
        category,
      },
    };
  }

  const prepared = await prepareSecretImageBuffer(buffer, category);
  const metadata = await sharp(prepared).metadata();

  const preprocessed = await sharp(prepared)
    .grayscale()
    .normalize()
    .sharpen()
    .png()
    .toBuffer();

  const worker = await createOcrWorker();
  try {
    const words = await recognizeWordsWithWorker(worker, preprocessed);
    const detection = buildSensitiveRegions(
      words,
      category,
      metadata.width || 1,
      metadata.height || 1
    );

    if (!detection.regions.length) {
      return {
        status: 'MANUAL_REQUIRED',
        storageKey: null,
        summary: {
          reason: 'no_sensitive_regions_detected',
          category,
          ocrWordCount: words.length,
          ocrLanguages: OCR_LANGUAGES,
          mode: detection.mode || 'unknown',
        },
      };
    }

    const redactedBuffer = await blurRegions(prepared, detection.regions);
    const storageKey = `${uuid()}_redacted_${path.parse(
      originalFileName || 'secret'
    ).name}.png`;
    const outputPath = path.join(env.storageDir, storageKey);

    fs.mkdirSync(env.storageDir, { recursive: true });
    fs.writeFileSync(outputPath, redactedBuffer);

    return {
      status: 'READY',
      storageKey,
      summary: {
        category,
        outputType: 'image/png',
        ocrLanguages: OCR_LANGUAGES,
        ocrWordCount: words.length,
        regionCount: detection.regions.length,
        mode: detection.mode || 'ocr_only',
        generatedAt: new Date().toISOString(),
      },
    };
  } finally {
    await worker.terminate();
  }
}

async function createPdfRedactedDerivative({
  buffer,
  originalFileName,
  category,
}) {
  if (!PDF_REDACTION_ENABLED) {
    return {
      status: 'MANUAL_REQUIRED',
      storageKey: null,
      summary: {
        reason: 'pdf_redaction_disabled',
        category,
      },
    };
  }

  const pdfjsLib = await getPdfJs();
  const loadingTask = pdfjsLib.getDocument({
    data: new Uint8Array(buffer),
    disableWorker: true,
    useSystemFonts: true,
    isEvalSupported: false,
    stopAtErrors: false,
    verbosity: 0,
  });

  let pdf = null;
  try {
    pdf = await loadingTask.promise;

    if (pdf.numPages > PDF_MAX_SECRET_PAGES) {
      return {
        status: 'MANUAL_REQUIRED',
        storageKey: null,
        summary: {
          reason: 'pdf_page_limit_exceeded',
          category,
          pageCount: pdf.numPages,
          maxPages: PDF_MAX_SECRET_PAGES,
        },
      };
    }

    const worker = await createOcrWorker();
    try {
      const outputPdf = await PDFDocument.create();
      let totalRegions = 0;
      let redactedPages = 0;
      const pageSummaries = [];

      for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
        const page = await pdf.getPage(pageNumber);
        const pagePng = await renderPdfPageToPng(page, PDF_RENDER_DPI);
        const meta = await sharp(pagePng).metadata();
        const preprocessed = await sharp(pagePng)
          .grayscale()
          .normalize()
          .sharpen()
          .png()
          .toBuffer();

        const words = await recognizeWordsWithWorker(worker, preprocessed);
        const detection = buildSensitiveRegions(
          words,
          category,
          meta.width || 1,
          meta.height || 1
        );

        const hasHits = detection.regions.length > 0;
        const finalPagePng = hasHits
          ? await blurRegions(pagePng, detection.regions)
          : pagePng;

        if (hasHits) {
          totalRegions += detection.regions.length;
          redactedPages += 1;
        }

        await embedPngPage(outputPdf, finalPagePng);

        pageSummaries.push({
          pageNumber,
          regionCount: detection.regions.length,
          mode: detection.mode || 'ocr_only',
          ocrWordCount: words.length,
        });

        if (typeof page.cleanup === 'function') {
          page.cleanup();
        }
      }

      if (totalRegions === 0) {
        return {
          status: 'MANUAL_REQUIRED',
          storageKey: null,
          summary: {
            reason: 'no_sensitive_regions_detected_in_pdf',
            category,
            pageCount: pdf.numPages,
            pageSummaries,
            ocrLanguages: OCR_LANGUAGES,
          },
        };
      }

      const pdfBytes = await outputPdf.save();
      const storageKey = `${uuid()}_redacted_${path.parse(
        originalFileName || 'secret'
      ).name}.pdf`;
      const outputPath = path.join(env.storageDir, storageKey);

      fs.mkdirSync(env.storageDir, { recursive: true });
      fs.writeFileSync(outputPath, Buffer.from(pdfBytes));

      return {
        status: 'READY',
        storageKey,
        summary: {
          category,
          outputType: 'application/pdf',
          mode: 'pdf_raster_ocr',
          ocrLanguages: OCR_LANGUAGES,
          pageCount: pdf.numPages,
          redactedPages,
          totalRegionCount: totalRegions,
          dpi: PDF_RENDER_DPI,
          generatedAt: new Date().toISOString(),
        },
      };
    } finally {
      await worker.terminate();
    }
  } catch (error) {
    return {
      status: 'MANUAL_REQUIRED',
      storageKey: null,
      summary: {
        reason: 'pdf_redaction_exception',
        category,
        message: error.message,
      },
    };
  } finally {
    if (pdf && typeof pdf.cleanup === 'function') {
      try {
        pdf.cleanup();
      } catch {}
    }
    if (loadingTask && typeof loadingTask.destroy === 'function') {
      try {
        await loadingTask.destroy();
      } catch {}
    }
  }
}

async function createRedactedDerivative({
  buffer,
  mimeType,
  originalFileName,
  category,
}) {
  if (isSupportedSecretImageMime(mimeType)) {
    return createImageRedactedDerivative({
      buffer,
      mimeType,
      originalFileName,
      category,
    });
  }

  if (isSupportedSecretPdfMime(mimeType)) {
    if (String(category || '').toLowerCase() === 'sri_nic') {
      return {
        status: 'MANUAL_REQUIRED',
        storageKey: null,
        summary: {
          reason: 'nic_pdf_not_supported_yet',
          category,
        },
      };
    }

    return createPdfRedactedDerivative({
      buffer,
      originalFileName,
      category,
    });
  }

  return {
    status: 'MANUAL_REQUIRED',
    storageKey: null,
    summary: {
      reason: 'unsupported_secret_file_type',
      category,
    },
  };
}

module.exports = {
  SECRET_DOCUMENT_CATEGORIES,
  isSupportedSecretImageMime,
  isSupportedSecretPdfMime,
  isSupportedSecretUploadMime,
  createRedactedDerivative,
};