-- ============================================================
-- SISTEMA DE RASTREAMENTO DE INSUMOS (SRI)
-- Schema PostgreSQL / Supabase
-- Autenticação própria com tabela usuarios + pass_hash
-- (mesmo padrão do SGE)
-- ============================================================

-- ============================================================
-- USUÁRIOS (autenticação própria, sem Supabase Auth)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.usuarios (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome       TEXT NOT NULL,
  username   TEXT NOT NULL UNIQUE,
  pass_hash  TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin','viewer')),
  ativo      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FORNECEDORES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fornecedores (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_empresa TEXT NOT NULL,
  cidade       TEXT,
  estado       CHAR(2),
  telefone     TEXT,
  email        TEXT,
  contato      TEXT,
  categoria    TEXT NOT NULL CHECK (categoria IN ('tintas','pigmentos','produtos_auxiliares')),
  ativo        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by   TEXT
);

-- ============================================================
-- PRODUTOS (Tintas, Pigmentos, Auxiliares)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.produtos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  categoria       TEXT NOT NULL CHECK (categoria IN ('tinta','pigmento','produto_auxiliar')),
  descricao       TEXT NOT NULL,
  fabricante      TEXT NOT NULL,
  fornecedor_id   UUID REFERENCES public.fornecedores(id),
  quantidade      NUMERIC(12,4),
  unidade         TEXT DEFAULT 'g',
  lote            TEXT,
  data_fabricacao DATE,
  ativo           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by      TEXT
);

-- ============================================================
-- PEDIDOS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pedidos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero           TEXT NOT NULL UNIQUE,
  cliente          TEXT NOT NULL,
  artigo           TEXT,
  quantidade_total INTEGER NOT NULL DEFAULT 0,
  observacoes      TEXT,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by       TEXT
);

-- ============================================================
-- ORDENS DE PRODUÇÃO
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ordens_producao (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id    UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  numero_op    TEXT NOT NULL,
  referencia   TEXT,
  cor_tecido   TEXT,
  quantidade   INTEGER NOT NULL DEFAULT 0,
  observacoes  TEXT,
  ativo        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by   TEXT,
  UNIQUE (pedido_id, numero_op)
);

-- ============================================================
-- PANTONES (banco permanente de cores)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pantones (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo      TEXT NOT NULL UNIQUE,
  descricao   TEXT NOT NULL,
  observacoes TEXT,
  ativo       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by  TEXT
);

-- ============================================================
-- RECEITAS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.receitas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo            TEXT NOT NULL DEFAULT 'producao' CHECK (tipo IN ('amostra','producao')),
  pedido_id       UUID REFERENCES public.pedidos(id),
  op_id           UUID REFERENCES public.ordens_producao(id),
  responsavel     TEXT,
  observacoes     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by      TEXT
);

-- ============================================================
-- FORMULAÇÕES (cada Pantone dentro de uma Receita)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.formulacoes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receita_id          UUID NOT NULL REFERENCES public.receitas(id) ON DELETE CASCADE,
  pantone_id          UUID NOT NULL REFERENCES public.pantones(id),
  revisao             INTEGER NOT NULL DEFAULT 1,
  -- base da tinta
  base_fabricante     TEXT,
  base_produto_id     UUID REFERENCES public.produtos(id),
  base_produto_desc   TEXT,
  base_lote           TEXT,
  base_data_fab       DATE,
  base_quantidade     NUMERIC(12,4) DEFAULT 0,
  -- pigmentos armazenados como JSONB array
  -- [{fabricante, produto_id, produto_desc, lote, data_fab, quantidade, ordem}]
  pigmentos           JSONB NOT NULL DEFAULT '[]',
  -- controle de migração
  tem_migracao        BOOLEAN NOT NULL DEFAULT FALSE,
  bloqueador_prod_id  UUID REFERENCES public.produtos(id),
  bloqueador_prod_desc TEXT,
  bloqueador_lote     TEXT,
  bloqueador_qtd      NUMERIC(12,4),
  -- inibidor de foil
  tem_foil            BOOLEAN NOT NULL DEFAULT FALSE,
  foil_prod_id        UUID REFERENCES public.produtos(id),
  foil_prod_desc      TEXT,
  foil_lote           TEXT,
  foil_qtd            NUMERIC(12,4),
  observacoes         TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by          TEXT
);

-- ============================================================
-- AVALIAÇÕES DE QUALIDADE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.avaliacoes_qualidade (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receita_id     UUID NOT NULL REFERENCES public.receitas(id),
  formulacao_id  UUID REFERENCES public.formulacoes(id),
  responsavel    TEXT,
  status         TEXT NOT NULL DEFAULT 'aguardando'
                   CHECK (status IN ('aguardando','aprovada','aprovada_restricao','reprovada')),
  -- motivos de reprovação como JSONB array de strings
  motivos        JSONB NOT NULL DEFAULT '[]',
  restricoes     TEXT,
  observacoes    TEXT,
  data_avaliacao TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by     TEXT
);

-- ============================================================
-- ANEXOS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.anexos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receita_id    UUID REFERENCES public.receitas(id),
  formulacao_id UUID REFERENCES public.formulacoes(id),
  avaliacao_id  UUID REFERENCES public.avaliacoes_qualidade(id),
  nome_arquivo  TEXT NOT NULL,
  storage_path  TEXT NOT NULL,
  mime_type     TEXT,
  tamanho_bytes BIGINT,
  descricao     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    TEXT
);

-- ============================================================
-- AUDITORIA (log imutável)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.auditoria (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tabela      TEXT NOT NULL,
  registro_id UUID NOT NULL,
  operacao    TEXT NOT NULL,
  dados_antes JSONB,
  dados_depois JSONB,
  usuario     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_op_pedido          ON public.ordens_producao(pedido_id);
CREATE INDEX IF NOT EXISTS idx_receita_op         ON public.receitas(op_id);
CREATE INDEX IF NOT EXISTS idx_receita_pedido     ON public.receitas(pedido_id);
CREATE INDEX IF NOT EXISTS idx_formulacao_receita ON public.formulacoes(receita_id);
CREATE INDEX IF NOT EXISTS idx_formulacao_pantone ON public.formulacoes(pantone_id);
CREATE INDEX IF NOT EXISTS idx_qualidade_receita  ON public.avaliacoes_qualidade(receita_id);
CREATE INDEX IF NOT EXISTS idx_pantone_codigo     ON public.pantones(codigo);
CREATE INDEX IF NOT EXISTS idx_pedido_numero      ON public.pedidos(numero);
CREATE INDEX IF NOT EXISTS idx_produto_categoria  ON public.produtos(categoria);

-- ============================================================
-- TRIGGER: atualiza updated_at automaticamente
-- ============================================================
CREATE OR REPLACE FUNCTION fn_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['fornecedores','produtos','pedidos','ordens_producao',
    'pantones','receitas','formulacoes','avaliacoes_qualidade']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_upd ON public.%s', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_upd BEFORE UPDATE ON public.%s FOR EACH ROW EXECUTE FUNCTION fn_updated_at()', t, t);
  END LOOP;
END $$;

-- ============================================================
-- FUNÇÃO: ESCALONAMENTO AUTOMÁTICO DE RECEITA
-- Uso: SELECT * FROM escalonar_formulacao('<uuid>', 2000);
-- ============================================================
CREATE OR REPLACE FUNCTION public.escalonar_formulacao(
  p_formulacao_id UUID,
  p_novo_peso     NUMERIC
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_form          RECORD;
  v_peso_original NUMERIC := 0;
  v_fator         NUMERIC;
  v_pig_total     NUMERIC := 0;
  v_pig           JSONB;
  v_pig_item      JSONB;
  v_resultado     JSONB := '[]';
  v_pig_escalados JSONB := '[]';
BEGIN
  SELECT * INTO v_form FROM public.formulacoes WHERE id = p_formulacao_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Formulação não encontrada.'; END IF;

  -- soma base
  v_peso_original := COALESCE(v_form.base_quantidade, 0);
  -- soma pigmentos
  FOR v_pig_item IN SELECT * FROM jsonb_array_elements(v_form.pigmentos)
  LOOP
    v_pig_total := v_pig_total + COALESCE((v_pig_item->>'quantidade')::NUMERIC, 0);
  END LOOP;
  v_peso_original := v_peso_original + v_pig_total
    + COALESCE(v_form.bloqueador_qtd, 0)
    + COALESCE(v_form.foil_qtd, 0);

  IF v_peso_original = 0 THEN RAISE EXCEPTION 'Peso original é zero.'; END IF;

  v_fator := p_novo_peso / v_peso_original;

  -- base
  v_resultado := v_resultado || jsonb_build_array(jsonb_build_object(
    'tipo', 'base',
    'descricao', COALESCE(v_form.base_produto_desc, 'Base'),
    'lote', v_form.base_lote,
    'qtd_original', v_form.base_quantidade,
    'qtd_escalada', ROUND(v_form.base_quantidade * v_fator, 4),
    'fator', ROUND(v_fator, 6)
  ));

  -- pigmentos
  FOR v_pig_item IN SELECT * FROM jsonb_array_elements(v_form.pigmentos)
  LOOP
    v_resultado := v_resultado || jsonb_build_array(jsonb_build_object(
      'tipo', 'pigmento',
      'descricao', v_pig_item->>'produto_desc',
      'lote', v_pig_item->>'lote',
      'qtd_original', (v_pig_item->>'quantidade')::NUMERIC,
      'qtd_escalada', ROUND((v_pig_item->>'quantidade')::NUMERIC * v_fator, 4),
      'fator', ROUND(v_fator, 6)
    ));
  END LOOP;

  -- bloqueador
  IF v_form.tem_migracao AND v_form.bloqueador_qtd > 0 THEN
    v_resultado := v_resultado || jsonb_build_array(jsonb_build_object(
      'tipo', 'bloqueador',
      'descricao', COALESCE(v_form.bloqueador_prod_desc, 'Bloqueador'),
      'lote', v_form.bloqueador_lote,
      'qtd_original', v_form.bloqueador_qtd,
      'qtd_escalada', ROUND(v_form.bloqueador_qtd * v_fator, 4),
      'fator', ROUND(v_fator, 6)
    ));
  END IF;

  -- foil
  IF v_form.tem_foil AND v_form.foil_qtd > 0 THEN
    v_resultado := v_resultado || jsonb_build_array(jsonb_build_object(
      'tipo', 'foil',
      'descricao', COALESCE(v_form.foil_prod_desc, 'Inibidor de Foil'),
      'lote', v_form.foil_lote,
      'qtd_original', v_form.foil_qtd,
      'qtd_escalada', ROUND(v_form.foil_qtd * v_fator, 4),
      'fator', ROUND(v_fator, 6)
    ));
  END IF;

  RETURN jsonb_build_object(
    'formulacao_id', p_formulacao_id,
    'peso_original', v_peso_original,
    'peso_novo', p_novo_peso,
    'fator', ROUND(v_fator, 6),
    'ingredientes', v_resultado
  );
END; $$;

-- ============================================================
-- VIEW: Confiabilidade por Pantone
-- ============================================================
CREATE OR REPLACE VIEW public.vw_confiabilidade_pantone AS
SELECT
  p.id, p.codigo, p.descricao,
  COUNT(DISTINCT f.id)                                                        AS total_usos,
  COUNT(DISTINCT aq.id)                                                       AS total_avaliacoes,
  COUNT(DISTINCT aq.id) FILTER (WHERE aq.status = 'aprovada')                AS aprovacoes,
  COUNT(DISTINCT aq.id) FILTER (WHERE aq.status = 'aprovada_restricao')      AS restricoes,
  COUNT(DISTINCT aq.id) FILTER (WHERE aq.status = 'reprovada')               AS reprovacoes,
  CASE WHEN COUNT(DISTINCT aq.id) = 0 THEN NULL
    ELSE ROUND(
      (COUNT(DISTINCT aq.id) FILTER (WHERE aq.status IN ('aprovada','aprovada_restricao')))::NUMERIC
      / COUNT(DISTINCT aq.id) * 100, 1)
  END AS confiabilidade_pct,
  MAX(f.revisao)       AS revisao_atual,
  MAX(f.created_at)    AS ultima_utilizacao
FROM public.pantones p
LEFT JOIN public.formulacoes f           ON f.pantone_id = p.id
LEFT JOIN public.avaliacoes_qualidade aq ON aq.formulacao_id = f.id
GROUP BY p.id, p.codigo, p.descricao;

-- ============================================================
-- VIEW: Receitas do dia com status qualidade
-- ============================================================
CREATE OR REPLACE VIEW public.vw_receitas_hoje AS
SELECT
  r.id              AS receita_id,
  r.tipo,
  r.responsavel,
  r.created_at,
  ped.numero        AS pedido_numero,
  ped.cliente,
  op.numero_op,
  op.referencia,
  p.codigo          AS pantone_codigo,
  p.descricao       AS pantone_descricao,
  f.revisao,
  COALESCE(aq.status, 'aguardando') AS status_qualidade
FROM public.receitas r
LEFT JOIN public.pedidos ped             ON ped.id = r.pedido_id
LEFT JOIN public.ordens_producao op      ON op.id = r.op_id
LEFT JOIN public.formulacoes f           ON f.receita_id = r.id
LEFT JOIN public.pantones p              ON p.id = f.pantone_id
LEFT JOIN public.avaliacoes_qualidade aq ON aq.receita_id = r.id
WHERE r.created_at::DATE = CURRENT_DATE;

-- ============================================================
-- VIEW: Revisões por Pantone
-- ============================================================
CREATE OR REPLACE VIEW public.vw_revisoes_pantone AS
SELECT
  f.id, f.revisao, f.created_at, f.updated_by,
  f.base_produto_desc, f.base_quantidade, f.pigmentos,
  p.codigo AS pantone_codigo, p.descricao AS pantone_descricao,
  ped.numero AS pedido_numero, ped.cliente,
  op.numero_op, op.referencia
FROM public.formulacoes f
JOIN public.pantones p              ON p.id = f.pantone_id
JOIN public.receitas r              ON r.id = f.receita_id
LEFT JOIN public.ordens_producao op ON op.id = r.op_id
LEFT JOIN public.pedidos ped        ON ped.id = r.pedido_id;

-- ============================================================
-- RLS — Row Level Security
-- ============================================================
ALTER TABLE public.usuarios              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fornecedores          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordens_producao       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pantones              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receitas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.formulacoes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avaliacoes_qualidade  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anexos                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria             ENABLE ROW LEVEL SECURITY;

-- Acesso total via anon key (autenticação feita no app com pass_hash)
DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','fornecedores','produtos','pedidos',
    'ordens_producao','pantones','receitas','formulacoes',
    'avaliacoes_qualidade','anexos','auditoria']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS allow_all ON public.%s', t);
    EXECUTE format('CREATE POLICY allow_all ON public.%s FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)', t);
  END LOOP;
END $$;

-- ============================================================
-- SEED: Pantones iniciais
-- ============================================================
INSERT INTO public.pantones (codigo, descricao) VALUES
  ('11-0601', 'Bright White'),
  ('19-0303', 'Jet Black'),
  ('17-1622', 'Dusty Rose'),
  ('19-4150', 'Classic Blue'),
  ('15-1520', 'Peach Amber'),
  ('18-1660', 'Living Coral'),
  ('15-0343', 'Greenery'),
  ('18-3838', 'Ultra Violet'),
  ('16-1546', 'Peach Pink'),
  ('19-1664', 'Fiesta')
ON CONFLICT (codigo) DO NOTHING;

-- ============================================================
-- SEED: Usuário admin padrão
-- usuario: admin  |  senha: admin123
-- pass_hash gerado pelo mesmo algoritmo JS do SGE (djb2 → base36)
-- ============================================================
INSERT INTO public.usuarios (nome, username, pass_hash, role) VALUES
  ('Administrador', 'admin', '-g10hvh', 'admin')
ON CONFLICT (username) DO NOTHING;

