-- BINGO fractional checkout fix V4
-- Patches only real JSON quantity -> integer casts in checkout/delivery functions.
-- Does not alter table columns.

begin;

do $$
declare
  r record;
  def text;
  patched text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'place_store_order_with_delivery',
        'place_multi_store_order_with_delivery',
        'bingo_cart_delivery_quote'
      )
  loop
    def := pg_get_functiondef(r.oid);
    patched := def;

    -- (x->>'quantity')::integer
    patched := regexp_replace(
      patched,
      E'\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*->>\\s*''quantity''\\s*\\)\\s*::\\s*(integer|int4)',
      E'(\\1->>''quantity'')::numeric(18,3)',
      'gi'
    );

    -- x->>'quantity'::integer
    patched := regexp_replace(
      patched,
      E'([A-Za-z_][A-Za-z0-9_]*)\\s*->>\\s*''quantity''\\s*::\\s*(integer|int4)',
      E'\\1->>''quantity''::numeric(18,3)',
      'gi'
    );

    -- CAST((x->>'quantity') AS integer)
    patched := regexp_replace(
      patched,
      E'cast\\s*\\(\\s*\\(?\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*->>\\s*''quantity''\\s*\\)?\\s+as\\s+(integer|int4)\\s*\\)',
      E'(\\1->>''quantity'')::numeric(18,3)',
      'gi'
    );

    if patched is distinct from def then
      execute patched;
    end if;
  end loop;
end $$;

-- Exact verification only: detect actual JSON quantity casts to integer/int4.
do $$
declare
  bad text;
begin
  select string_agg(p.oid::regprocedure::text, E'\n')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in (
      'place_store_order_with_delivery',
      'place_multi_store_order_with_delivery',
      'bingo_cart_delivery_quote'
    )
    and (
      pg_get_functiondef(p.oid) ~* E'\\(\\s*[A-Za-z_][A-Za-z0-9_]*\\s*->>\\s*''quantity''\\s*\\)\\s*::\\s*(integer|int4)'
      or pg_get_functiondef(p.oid) ~* E'[A-Za-z_][A-Za-z0-9_]*\\s*->>\\s*''quantity''\\s*::\\s*(integer|int4)'
      or pg_get_functiondef(p.oid) ~* E'cast\\s*\\(\\s*\\(?\\s*[A-Za-z_][A-Za-z0-9_]*\\s*->>\\s*''quantity''\\s*\\)?\\s+as\\s+(integer|int4)\\s*\\)'
    );

  if bad is not null then
    raise exception 'Real INTEGER quantity cast still exists in:%', E'\n'||bad;
  end if;
end $$;

notify pgrst,'reload schema';
commit;
