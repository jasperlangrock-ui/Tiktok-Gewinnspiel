import { supabase } from './supabase';
import type { Draw, DrawResult, Giveaway, Participant, Profile, TicketCount } from '../types/database';

export async function getActiveGiveaway() {
  const { data, error } = await supabase
    .from('giveaways')
    .select('*')
    .eq('status', 'active')
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as Giveaway | null;
}

export async function getPublicParticipants(giveawayId: string) {
  const { data, error } = await supabase
    .from('participants')
    .select('*')
    .eq('giveaway_id', giveawayId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return (data ?? []) as Participant[];
}

export async function getDraws(giveawayId?: string) {
  let q = supabase.from('draws').select('*').order('drawn_at', { ascending: false });
  if (giveawayId) q = q.eq('giveaway_id', giveawayId);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as Draw[];
}

export async function getProfile(): Promise<Profile | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('profiles')
    .select('id,email,role')
    .eq('id', user.id)
    .maybeSingle();
  if (error) throw error;
  return data as Profile | null;
}

export async function login(email: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

export async function logout() {
  await supabase.auth.signOut();
}

export async function addParticipant(giveawayId: string, username: string, tickets: TicketCount) {
  const { data, error } = await supabase
    .from('participants')
    .insert({ giveaway_id: giveawayId, username, tickets })
    .select('*')
    .single();
  if (error) throw error;
  return data as Participant;
}

export async function updateParticipant(id: string, tickets: TicketCount) {
  const { data, error } = await supabase
    .from('participants')
    .update({ tickets })
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return data as Participant;
}

export async function deleteParticipant(id: string) {
  const { error } = await supabase.from('participants').delete().eq('id', id);
  if (error) throw error;
}

export async function createGiveaway(title: string, startDate: string, endDate: string) {
  const { data, error } = await supabase
    .from('giveaways')
    .insert({ title, start_date: startDate, end_date: endDate, status: 'active' })
    .select('*')
    .single();
  if (error) throw error;
  return data as Giveaway;
}

export async function completeGiveaway(id: string) {
  const { error } = await supabase
    .from('giveaways')
    .update({ status: 'completed' })
    .eq('id', id);
  if (error) throw error;
}

export async function drawWinner(giveawayId: string) {
  const { data, error } = await supabase.rpc('draw_winner', {
    p_giveaway_id: giveawayId
  });

  if (error) {
    console.error("DRAW ERROR:", error);   // ⭐ WICHTIG: zeigt dir den echten Fehler
    throw error;
  }

  return data as unknown as DrawResult;
}
