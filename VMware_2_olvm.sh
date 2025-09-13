#!/bin/bash
#
# Script Conversione VM VMware OVF -> OLVM RAW + Creazione VM
#

if [ -z "$1" ]; then
  echo "Uso: $0 <hostname-vm> [-y]"
  exit 1
fi

HOSTNAME=$1
AUTO_YES=false

if [[ "$2" == "-y" ]]; then
  AUTO_YES=true
fi

SRC_DIR="/export-vm/$HOSTNAME"
CONVERTED_DIR="/export-vm/converted"
OVF_FILE="$SRC_DIR/$HOSTNAME.ovf"
OVA_FILE="$SRC_DIR/$HOSTNAME.ova"
RAW_FILE="$CONVERTED_DIR/$HOSTNAME-sda"
STORAGE_DOMAIN="Default"

# 1 Creazione OVA
if [ -f "$OVA_FILE" ]; then
  echo "⏭ OVA già presente, skip."
else
  echo "Creazione OVA..."
  cd "$SRC_DIR" || exit 1
  tar cvf "$OVA_FILE" "$HOSTNAME.ovf" *.vmdk *.mf 2>/dev/null
  echo "OVA creato: $OVA_FILE"
fi

# 2 Conversione RAW
if $AUTO_YES; then
  ans="y"
else
  read -p "Vuoi convertire l'OVA in RAW con virt-v2v? (y/n) " ans
fi

if [[ "$ans" == "y" ]]; then
  echo "Conversione con virt-v2v..."
  mkdir -p "$CONVERTED_DIR"
  virt-v2v \
    -i ova "$OVA_FILE" \
    -o local -os "$CONVERTED_DIR" \
    -of raw
  echo "Conversione completata: $RAW_FILE"
else
  echo "Conversione saltata."
fi

# 3 Upload su OLVM
if $AUTO_YES; then
  ans="y"
else
  read -p "Vuoi eseguire upload su OLVM? (y/n) " ans
fi

if [[ "$ans" == "y" ]]; then
  echo "Upload su OLVM..."
  python3 /usr/share/doc/python3-ovirt-engine-sdk4/examples/upload_disk.py \
    -c default \
    --sd-name $STORAGE_DOMAIN \
    --disk-format raw \
    "$RAW_FILE"
  echo "Upload completato."
else
  echo "Upload saltato."
fi

# 4 deploy VM
TMP_PY="/tmp/create_vm_$$.py"

cat > "$TMP_PY" <<'PYCODE'
import ovirtsdk4 as sdk
import ovirtsdk4.types as types

connection = sdk.Connection(
    url='https://example.olvm.local/ovirt-engine/api',
    username='admin@internal',
    password='LATUAPASSWORD',
    ca_file='/path/ca.pem'
)

system_service = connection.system_service()
vms_service = system_service.vms_service()

vm_name = input(" Nome VM: ")
cluster_name = input(" Cluster (default=ASM630S): ") or "Default"
cpu_sockets = int(input(" Numero socket CPU: "))
cpu_cores = int(input(" Numero core per socket: "))
ram_gb = int(input(" RAM in GB: "))
disk_id = input(" Inserisci ID del disco RAW caricato: ")
nic_profile = input(" Nome profilo rete (vNIC Profile): ")
fw_choice = input(" Tipo firmware [bios/uefi]: ").lower()

if fw_choice == "uefi":
    bios_type = types.BiosType.Q35_OVMF
else:
    bios_type = types.BiosType.Q35_SEA_BIOS

profiles_service = system_service.vnic_profiles_service()
profile_id = None
for profile in profiles_service.list():
    if profile.name == nic_profile:
        profile_id = profile.id
        print(f"Profilo trovato: {profile.name} (rete: {profile.network.name}) -> {profile.id}")
        break

if not profile_id:
    print("Profilo rete non trovato!")
    print("Profili disponibili:")
    for p in profiles_service.list():
        print(f"   - {p.name} (rete: {p.network.name})")
    connection.close()
    exit(1)

print(f"Creazione VM '{vm_name}'...")
vm = vms_service.add(
    types.Vm(
        name=vm_name,
        cluster=types.Cluster(name=cluster_name),
        template=types.Template(name="Blank"),
        memory=ram_gb * 1024 * 1024 * 1024,
        memory_policy=types.MemoryPolicy(
            guaranteed=1 * 1024 * 1024
        ),
        cpu=types.Cpu(
            topology=types.CpuTopology(
                sockets=cpu_sockets,
                cores=cpu_cores
            )
        ),
        bios=types.Bios(type=bios_type),
        os=types.OperatingSystem(type="other_linux")
    )
)

vm_service = vms_service.vm_service(vm.id)
attachments_service = vm_service.disk_attachments_service()
attachments_service.add(
    types.DiskAttachment(
        disk=types.Disk(id=disk_id),
        interface=types.DiskInterface.VIRTIO,
        bootable=True,
        active=True
    )
)

nics_service = vm_service.nics_service()
nics_service.add(
    types.Nic(
        name="nic1",
        vnic_profile=types.VnicProfile(id=profile_id),
        interface=types.NicInterface.VIRTIO
    )
)

print("VM deployata")
connection.close()
PYCODE

python3 "$TMP_PY"
rm -f "$TMP_PY"
