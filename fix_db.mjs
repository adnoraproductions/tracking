import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const envFile = fs.readFileSync('.env', 'utf-8');
const env = {};
envFile.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/);
  if (match) env[match[1]] = match[2];
});

const supabase = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY);

async function fix() {
  console.log('Fetching attendance days...');
  const { data: days, error } = await supabase.from('attendance_days').select('id');
  
  if (error) {
    console.error('Error fetching days:', error);
    return;
  }

  if (days) {
    for (const day of days) {
      console.log('Fixing day:', day.id);
      const { error: rpcErr } = await supabase.rpc('rpc_update_day_totals', { p_attendance_day_id: day.id });
      if (rpcErr) console.error('Error on day', day.id, rpcErr);
    }
    console.log(`Successfully fixed ${days.length} days!`);
  }
}

fix();
