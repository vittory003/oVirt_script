# OLVM / oVirt - Utility Scripts

Collezione di script Bash per amministratori di sistemi che gestiscono ambienti **Oracle Linux Virtualization Manager (OLVM)** o **oVirt**.  
Gli script nascono da esigenze reali di operations quotidiane: backup, migrazioni, caricamento dischi, pulizia snapshot, ecc.

## Contenuto (ci sto lavorando :-D )

- `vmware_2_olvm.sh` → deploy VM in olvm da export OVF

## Requisiti

- Bash >= 4  
- `ovirt-engine-sdk` o CLI configurata (`ovirt-shell` / `ovirt-engine-cli`)  
- Credenziali API con permessi admin  
- Pacchetti: `curl`, `jq`, `virt-v2v`, `qemu-img`

## Setup

### Clona il repo:
git clone https://github.com/<tuo-utente>/olvm-ovirt-scripts.git
cd olvm-ovirt-scripts

### Rendi gli script eseguibili:
chmod +x *.sh


### Tutti testati in produzione su OLVM 4.5 e oVirt 4.5.

Usi a tuo rischio: verifica sempre in ambiente di test prima di metterli in produzione.

Licenza
MIT – usa, modifica, condividi liberamente.

---
