import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

let clientPromise;

export async function getSupabase() {
  if (!clientPromise) {
    clientPromise = (async () => {
      const fallback = window.SBILL_CONFIG || {};
      let config = fallback;
      try {
        const response = await fetch('/api/supabase-config', { cache: 'no-store' });
        if (response.ok) config = await response.json();
      } catch (_) {}
      if (!config.supabaseUrl || !config.supabasePublishableKey) return null;
      return createClient(config.supabaseUrl, config.supabasePublishableKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
      });
    })();
  }
  return clientPromise;
}

export async function getCurrentUser() {
  const supabase = await getSupabase();
  if (!supabase) return null;
  const { data } = await supabase.auth.getUser();
  return data.user;
}

export async function getWorkspace() {
  const supabase = await getSupabase();
  if (!supabase) return null;
  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return null;
  const { data: memberships } = await supabase
    .from('business_members')
    .select('business_id,role,created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: true })
    .limit(1);
  if (!memberships?.length) return null;
  const id = memberships[0].business_id;
  const { data: business } = await supabase
    .from('businesses')
    .select('id,name,phone,email,address,gst_number,currency,invoice_prefix')
    .eq('id', id)
    .maybeSingle();
  return business || null;
}

export async function listTickets() {
  const supabase = await getSupabase();
  if (!supabase) return [];
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) return [];
  const { data, error } = await supabase
    .from('support_tickets')
    .select('*')
    .eq('user_id', userData.user.id)
    .order('updated_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function createTicket(payload) {
  const supabase = await getSupabase();
  if (!supabase) throw new Error('SBILL cloud account is not configured.');
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) throw new Error('Sign in required.');
  const allowed = {
    category: payload.category,
    subject: payload.subject,
    message: payload.message,
    priority: payload.priority || 'normal',
    business_id: payload.business_id ?? null,
  };
  const { error } = await supabase.from('support_tickets').insert({
    ...allowed,
    user_id: userData.user.id,
    status: 'open',
  });
  if (error) throw error;
}

export async function signOut() {
  const supabase = await getSupabase();
  await supabase?.auth.signOut();
}


export function friendlyError(error, fallback = 'Something went wrong. Please try again.') {
  const message = String(error?.message || error || '').toLowerCase();
  if (message.includes('invalid login credentials')) return 'Email or password is incorrect.';
  if (message.includes('email not confirmed')) return 'Please confirm your email before signing in.';
  if (message.includes('already registered') || message.includes('already been registered')) return 'An account with this email already exists. Try signing in.';
  if (message.includes('rate limit') || message.includes('too many requests')) return 'Too many attempts. Please wait a moment and try again.';
  if (message.includes('network') || message.includes('fetch')) return 'The online service is unavailable right now. Check your connection and try again.';
  if (message.includes('row-level security') || message.includes('permission')) return 'This account is not allowed to change that information.';
  return fallback;
}
