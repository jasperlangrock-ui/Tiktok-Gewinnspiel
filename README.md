# TikTok Gewinnspiel

Produktionsfähige React/Vite/TypeScript-SPA für ein gewichtetes TikTok-Gewinnspiel mit Supabase Auth, PostgreSQL/RLS und Cloudflare Pages.

## Lokal

```bash
npm install
cp .env.example .env.local
# VITE_SUPABASE_URL und VITE_SUPABASE_ANON_KEY eintragen
npm run dev
```

## Architektur

- Öffentliche Seite `/`: nur Leserechte über RLS.
- `/login`: Supabase E-Mail/Passwort-Login.
- `/admin`: nur `profiles.role = 'admin'`.
- Teilnehmer sind pro Runde eindeutig.
- Ziehung läuft über die geschützte PostgreSQL-Funktion `draw_winner`.
- Der Service-Role-Key wird nie im Frontend verwendet.
- Keine externen kostenpflichtigen APIs.

## Datenbank

`supabase/schema.sql` vollständig im Supabase SQL Editor ausführen.

## Wichtiger Hinweis zur Ziehungsfairness

Die Datenbankfunktion wählt innerhalb der gespeicherten Losgewichte zufällig. Bei 1/3 Losen hat ein Teilnehmer mit 3 Losen genau das dreifache Gewicht eines Teilnehmers mit 1 Los. Für besonders streng auditierbare Gewinnspiele kann zusätzlich ein extern erzeugter, vorab veröffentlichter Zufalls-Seed/Commit-Reveal-Verfahren ergänzt werden.

Update for Cloudflare build
