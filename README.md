# D. Tracking lab

Tutti i tuoi pacchi in un posto, **gratis** e senza account. Un'app Dom Studio.

## Cosa fa (v0.1)
- **Stato dentro l'app**: l'app apre da sola, in un browser invisibile, la pagina
  ufficiale del corriere, la legge e ti mostra stato, passaggi e data prevista.
  Nessun abbonamento, nessuna chiave.
- **Corriere riconosciuto dal numero**: Poste Italiane, BRT, GLS, SDA, DHL, UPS,
  InPost, DPD, FedEx/TNT, Amazon Logistics, posta internazionale.
- **Negozio riconosciuto**: dall'app da cui condividi (Amazon, Zalando, Shein,
  Temu, AliExpress, eBay, Vinted…) o dall'email di conferma.
- **Scorciatoie dalle altre app**: tieni premuto sul numero → "Aggiungi a
  D. Tracking lab"; oppure Condividi → D. Tracking lab; oppure copialo e apri l'app.
- Scansione del codice a barre, sezioni "Da tenere d'occhio / In viaggio /
  Consegnati", archivio, tema chiaro e scuro.
- Facoltativo: chiave 17TRACK per una precisione extra (200 spedizioni gratis).

## Limiti noti
- La lettura delle pagine è un'interpretazione automatica del testo: se un
  corriere cambia il suo sito, quel corriere può smettere di leggersi bene
  finché l'app non viene aggiornata.
- Gli aggiornamenti avvengono quando apri l'app o tiri giù la lista
  (notifiche in background: in arrivo con la v0.2).
- I numeri solo numerici possono appartenere a più corrieri: l'app propone il
  più probabile, ma puoi cambiarlo.

## Sviluppo
Le cartelle `android/` e `ios/` non sono salvate: le genera
`tool/setup_platforms.sh`. L'APK viene compilato da GitHub Actions a ogni push
su `main` e pubblicato nelle Releases.
