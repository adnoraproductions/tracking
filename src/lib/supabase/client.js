import { createClient } from '@supabase/supabase-js';

// These should be configured in your .env file
// VITE_SUPABASE_URL=your_project_url
// VITE_SUPABASE_ANON_KEY=your_anon_key

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'PLACEHOLDER_URL';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'PLACEHOLDER_ANON_KEY';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
