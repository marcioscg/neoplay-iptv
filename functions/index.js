// Pushes agendados do MIAU NET (Firebase Cloud Messaging).
//
// O app grava em push_profiles/{uid}: token FCM, "enabled", sugestões do dia
// (títulos reais do catálogo do aparelho, já sem adulto) e a última série.
// Estas funções só escolhem, deduplicam por dia e enviam.
//
// Deploy: firebase deploy --only functions   (exige plano Blaze)

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const TZ = 'America/Sao_Paulo';
const ADULT = /(\bxxx\b|\+\s*18|\b18\s*\+|\badult\b|adulto|\bporn|porno|hentai|\berot|er[oó]tic|\bsex\b|sexo|onlyfans|brazzers)/i;

// Data local (yyyy-mm-dd) no fuso do Brasil: chave de "já enviado hoje".
function today() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(new Date());
}

function isAdult(entry) {
  return !entry || entry.adult === true ||
    ADULT.test(`${entry.title || ''} ${entry.series || ''}`);
}

// Conta removida ou bloqueada não recebe push.
async function accountActive(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) return true; // master não tem doc em users
  const u = snap.data();
  if (u.deleted === true || u.status === 'blocked') return false;
  // Mesma regra do app (AdminUser.isExpired): vitalício nunca vence.
  if (u.plan !== 'vitalicio' && u.expiresAt &&
      new Date(u.expiresAt) < new Date()) return false;
  return true;
}

async function send(ref, token, notification, data) {
  try {
    await admin.messaging().send({
      token,
      notification,
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return true;
  } catch (e) {
    const code = e.errorInfo?.code || e.code || '';
    if (code.includes('registration-token-not-registered') ||
        code.includes('invalid-registration-token')) {
      await ref.update({ token: null });
    }
    logger.warn('Falha no push', { uid: ref.id, code });
    return false;
  }
}

// Percorre os perfis ativos; [pick] devolve a notificação ou null.
async function run(dayField, pick) {
  const day = today();
  const snap = await db.collection('push_profiles').where('enabled', '==', true).get();
  let sent = 0;
  for (const doc of snap.docs) {
    const p = doc.data();
    if (!p.token || p[dayField] === day) continue;
    if (!(await accountActive(doc.id))) continue;
    const msg = pick(p);
    if (!msg) continue;
    // Marca antes de enviar: no máximo um push por dia, mesmo com retry.
    await doc.ref.update({ [dayField]: day, ...(msg.extra || {}) });
    if (await send(doc.ref, p.token, msg.notification, msg.data)) sent++;
  }
  logger.info(`${dayField}: ${sent} enviados`);
}

// Tarde: sugestão de outro título do gênero do último assistido, sem repetir.
exports.dailySuggestion = onSchedule(
  { schedule: '0 15 * * *', timeZone: TZ, region: 'southamerica-east1' },
  () => run('lastSuggestDay', (p) => {
    const sentIds = Array.isArray(p.sentSuggestionIds) ? p.sentSuggestionIds : [];
    const pool = (p.suggestions || []).filter((s) => s && s.id && !isAdult(s));
    if (pool.length === 0) return null;
    const fresh = pool.filter((s) => !sentIds.includes(s.id));
    const s = (fresh.length ? fresh : pool)[0];
    return {
      notification: {
        title: s.kind === 'series' ? 'Uma série para hoje' : 'Um filme para hoje',
        body: `Que tal assistir "${s.title}"?`,
      },
      data: { type: 'suggest', mediaId: String(s.id) },
      extra: { sentSuggestionIds: [...sentIds, s.id].slice(-60) },
    };
  }),
);

// 22h: lembrete para continuar a última série assistida.
exports.seriesReminder = onSchedule(
  { schedule: '0 22 * * *', timeZone: TZ, region: 'southamerica-east1' },
  () => run('lastSeriesDay', (p) => {
    const s = p.lastSeries;
    if (!s || !s.id || isAdult(s)) return null;
    return {
      notification: {
        title: 'Que tal continuar assistindo sua série?',
        body: s.series ? `${s.series} · ${s.title}` : s.title,
      },
      data: { type: 'series', mediaId: String(s.id) },
    };
  }),
);
