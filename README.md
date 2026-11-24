# D. Tracking lab

Tutti i tuoi pacchi in un posto, **gratis** e senza account. Un'app Dom Studio.

## Cosa fa (v0.3)
- **Stato dentro l'app, gratis e senza account**: per **BRT, DPD (consegnato in Italia da
  BRT), InPost, Poste Italiane e Amazon Logistics** l'app chiede lo stato direttamente ai servizi
  pubblici del corriere e mostra stato, passaggi, data prevista e (InPost) il
  locker di ritiro.
- DHL, UPS e GLS vietano o bloccano la lettura automatica dei loro siti:
  per loro c'è la pagina del corriere aperta dentro l'app, oppure la chiave
  facoltativa 17TRACK.
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
- I servizi dei corrieri non sono API ufficiali documentate: se un corriere
  li cambia, quel corriere può smettere di aggiornarsi finché l'app non viene
  aggiornata. BRT e Poste sono stati verificati solo con numeri inesistenti.
- Gli aggiornamenti avvengono quando apri l'app o tiri giù la lista
  (notifiche in background: in arrivo con la v0.2).
- I numeri solo numerici possono appartenere a più corrieri: l'app propone il
  più probabile, ma puoi cambiarlo.

## Sviluppo
Le cartelle `android/` e `ios/` non sono salvate: le genera
`tool/setup_platforms.sh`. L'APK viene compilato da GitHub Actions a ogni push
su `main` e pubblicato nelle Releases.
