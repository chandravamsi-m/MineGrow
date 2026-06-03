const { createClient } = require('@supabase/supabase-js');
const url = 'https://lrixucumgltudgzmgskj.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyaXh1Y3VtZ2x0dWRnem1nc2tqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTA4ODA1MCwiZXhwIjoyMDk0NjY0MDUwfQ.31nCIyozo0vl2UeOyVgRysRtix0lAjDbWofaODYr4z8';

const supabase = createClient(url, key);

async function test() {
  // Let's try to querypg_catalog or pg_proc via a custom RPC call or inspect what happens
  try {
    const { data, error } = await supabase.rpc('exec_sql', { sql: 'SELECT version();' });
    console.log('exec_sql RPC check:', { data, error });
  } catch (err) {
    console.log('exec_sql RPC not found or errored:', err);
  }
}
test();
