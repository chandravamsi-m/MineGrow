const { createClient } = require('@supabase/supabase-js');
const url = 'https://lrixucumgltudgzmgskj.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyaXh1Y3VtZ2x0dWRnem1nc2tqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTA4ODA1MCwiZXhwIjoyMDk0NjY0MDUwfQ.31nCIyozo0vl2UeOyVgRysRtix0lAjDbWofaODYr4z8';

const supabase = createClient(url, key);

async function test() {
  const { data, error } = await supabase
    .from('investment_plan')
    .select('*')
    .limit(10);
  if (error) {
    console.error('Error fetching plans:', error);
  } else {
    console.log('Investment plan record columns:', data && data.length > 0 ? Object.keys(data[0]) : 'No records');
    console.log('All Record details:', data);
  }
}
test();
