import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
if (!url || !key) console.warn('Supabase-Umgebungsvariablen fehlen. Bitte .env.local anlegen.');
export const supabase = createClient(url ?? 'https://placeholder.invalid', key ?? 'placeholder');
