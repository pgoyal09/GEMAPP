-- QDI Gemstone ERP v2 — Supabase Schema
-- Run this in the SQL Editor at https://supabase.com/dashboard

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Customers
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL DEFAULT '',
  last_name TEXT NOT NULL DEFAULT '',
  company TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  country TEXT NOT NULL DEFAULT '',
  zip TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Gemstones (diamonds + colored stones + lots)
CREATE TABLE IF NOT EXISTS gemstones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku TEXT NOT NULL UNIQUE,
  stone_type TEXT NOT NULL DEFAULT 'diamond',
  carat_weight DOUBLE PRECISION NOT NULL DEFAULT 0,
  shape TEXT NOT NULL DEFAULT '',
  grouping TEXT NOT NULL DEFAULT 'single',
  origin TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'available',
  color TEXT NOT NULL DEFAULT '',
  clarity TEXT NOT NULL DEFAULT '',
  cut TEXT NOT NULL DEFAULT '',
  treatment TEXT NOT NULL DEFAULT '',
  polish TEXT NOT NULL DEFAULT '',
  symmetry TEXT NOT NULL DEFAULT '',
  fluorescence TEXT NOT NULL DEFAULT '',
  size TEXT,
  quality TEXT,
  has_cert BOOLEAN NOT NULL DEFAULT false,
  cert_lab TEXT NOT NULL DEFAULT '',
  cert_no TEXT NOT NULL DEFAULT '',
  length DOUBLE PRECISION,
  width DOUBLE PRECISION,
  height DOUBLE PRECISION,
  length2 DOUBLE PRECISION,
  width2 DOUBLE PRECISION,
  height2 DOUBLE PRECISION,
  cost_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  sell_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  currency_type TEXT NOT NULL DEFAULT 'USD',
  exchange_rate DECIMAL(12,4) NOT NULL DEFAULT 1.0,
  remaining_carats DOUBLE PRECISION,
  average_cost_per_carat DECIMAL(12,2),
  rfid_epc TEXT,
  rfid_tid TEXT,
  rfid_assigned_at TIMESTAMPTZ,
  rfid_last_seen_at TIMESTAMPTZ,
  rapnet_sync_status TEXT NOT NULL DEFAULT 'notSynced',
  rapnet_last_synced TIMESTAMPTZ,
  number_of_stones INTEGER,
  gem_variety TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  vendor TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Memos
CREATE TABLE IF NOT EXISTS memos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reference_number TEXT NOT NULL,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  date_assigned TIMESTAMPTZ,
  salesperson TEXT,
  status TEXT NOT NULL DEFAULT 'onMemo',
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Invoices
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reference_number TEXT NOT NULL,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  date_issued TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft',
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Line Items (shared for memos and invoices)
CREATE TABLE IF NOT EXISTS line_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku TEXT NOT NULL DEFAULT '',
  item_description TEXT NOT NULL DEFAULT '',
  carats DOUBLE PRECISION NOT NULL DEFAULT 0,
  rate DECIMAL(12,2) NOT NULL DEFAULT 0,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  kind TEXT NOT NULL DEFAULT 'inventory',
  status TEXT NOT NULL DEFAULT 'onMemo',
  is_lot_line_item BOOLEAN NOT NULL DEFAULT false,
  locked_cost_per_carat DECIMAL(12,2),
  memo_id UUID REFERENCES memos(id) ON DELETE CASCADE,
  invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
  gemstone_id UUID REFERENCES gemstones(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Lot Transactions
CREATE TABLE IF NOT EXISTS lot_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL,
  carats DOUBLE PRECISION NOT NULL DEFAULT 0,
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  price_per_carat DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  locked_cost_per_carat DECIMAL(12,2),
  notes TEXT NOT NULL DEFAULT '',
  gemstone_id UUID REFERENCES gemstones(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  method TEXT NOT NULL DEFAULT 'cash',
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  reference_number TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- History Events (audit trail)
CREATE TABLE IF NOT EXISTS history_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_type TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT '',
  gemstone_id UUID REFERENCES gemstones(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- RFID Tags
CREATE TABLE IF NOT EXISTS rfid_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  epc TEXT NOT NULL,
  tid TEXT,
  gemstone_id UUID REFERENCES gemstones(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'unassigned',
  assigned_at TIMESTAMPTZ,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_gemstones_sku ON gemstones(sku);
CREATE INDEX IF NOT EXISTS idx_gemstones_status ON gemstones(status);
CREATE INDEX IF NOT EXISTS idx_gemstones_rfid_epc ON gemstones(rfid_epc);
CREATE INDEX IF NOT EXISTS idx_memos_status ON memos(status);
CREATE INDEX IF NOT EXISTS idx_memos_customer ON memos(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_line_items_memo ON line_items(memo_id);
CREATE INDEX IF NOT EXISTS idx_line_items_invoice ON line_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_lot_transactions_gemstone ON lot_transactions(gemstone_id);
CREATE INDEX IF NOT EXISTS idx_rfid_tags_epc ON rfid_tags(epc);

-- Enable RLS on all tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE gemstones ENABLE ROW LEVEL SECURITY;
ALTER TABLE memos ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE lot_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE history_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfid_tags ENABLE ROW LEVEL SECURITY;

-- RLS Policies (user can only access own data)
CREATE POLICY "Users manage own customers" ON customers FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own gemstones" ON gemstones FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own memos" ON memos FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own invoices" ON invoices FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own line_items" ON line_items FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own lot_transactions" ON lot_transactions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own payments" ON payments FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own history_events" ON history_events FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own rfid_tags" ON rfid_tags FOR ALL USING (auth.uid() = user_id);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_gemstones_updated_at BEFORE UPDATE ON gemstones FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_memos_updated_at BEFORE UPDATE ON memos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_line_items_updated_at BEFORE UPDATE ON line_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
