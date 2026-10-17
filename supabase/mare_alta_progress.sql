-- MARÉ ALTA — save na nuvem (cross-device).
-- Progresso de jogo puro, sem PII: seguro com policy permissiva para o role anon.
--
-- COMO APLICAR (uma vez): Supabase Dashboard -> projeto -> SQL Editor ->
-- cole este arquivo inteiro e rode. A chave `anon public` usada pelo jogo
-- fica em: Settings -> Data API -> "anon" "public" key.
--
-- O jogo é OFFLINE-FIRST: sem esta tabela (ou sem a chave colada no
-- scripts/cloud_sync.gd), a nuvem fica dormente e o jogo segue 100% local.

CREATE TABLE IF NOT EXISTS public.mare_alta_progress (
    player_id text PRIMARY KEY,
    code text UNIQUE NOT NULL,
    data jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mare_alta_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mare_alta_progress_anon_all ON public.mare_alta_progress;

CREATE POLICY mare_alta_progress_anon_all
    ON public.mare_alta_progress
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.mare_alta_progress TO anon;
