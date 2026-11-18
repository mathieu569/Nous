// Edge Function "notify-status" : prévient l'autre quand ton état change.
// À coller dans Supabase > Edge Functions > Deploy a new function > Via Editor.
// Secret requis : FIREBASE_SERVICE_ACCOUNT (le contenu du fichier JSON du compte de service Firebase).
import { createClient } from 'npm:@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@5.2.0';

const APP_URL = 'https://mathieu569.github.io/Nous/';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

async function googleAccessToken(
  sa: { client_email: string; private_key: string },
): Promise<string> {
  const key = await importPKCS8(sa.private_key, 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) {
    throw new Error('Jeton Google refusé : ' + JSON.stringify(data));
  }
  return data.access_token;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '');

    // 1. Qui appelle ? (on vérifie le jeton de connexion)
    const asUser = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await asUser.auth.getUser(jwt);
    const user = userData?.user;
    if (!user) return reply({ error: 'Non connecté' }, 401);

    // 2. Son état actuel et son/sa partenaire (les règles RLS limitent à son couple)
    const { data: profiles, error: pErr } = await asUser
      .from('profiles')
      .select('user_id, name, status');
    if (pErr) return reply({ error: pErr.message }, 500);
    const me = profiles?.find((p) => p.user_id === user.id);
    const partner = profiles?.find((p) => p.user_id !== user.id);
    if (!me || !partner || !me.status) return reply({ sent: 0 });

    // 3. Les appareils du/de la partenaire
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: tokens } = await admin
      .from('push_tokens')
      .select('token')
      .eq('user_id', partner.user_id);
    if (!tokens || tokens.length === 0) {
      return reply({ sent: 0, note: 'aucun appareil enregistré' });
    }

    // 4. Envoi via Firebase
    const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!raw) return reply({ error: 'Secret FIREBASE_SERVICE_ACCOUNT manquant' }, 500);
    const sa = JSON.parse(raw);
    const accessToken = await googleAccessToken(sa);

    let sent = 0;
    const errors: string[] = [];
    for (const t of tokens) {
      const r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: { title: me.name, body: me.status },
              webpush: { fcm_options: { link: APP_URL } },
              android: { priority: 'HIGH' },
            },
          }),
        },
      );
      if (r.ok) {
        sent++;
      } else {
        const txt = await r.text();
        errors.push(txt.slice(0, 200));
        // jeton périmé : on le retire
        if (txt.includes('UNREGISTERED') || txt.includes('NOT_FOUND')) {
          await admin.from('push_tokens').delete().eq('token', t.token);
        }
      }
    }
    return reply({ sent, errors });
  } catch (e) {
    return reply({ error: String(e) }, 500);
  }
});
