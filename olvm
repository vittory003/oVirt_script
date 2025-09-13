#!/usr/bin/python3
import ovirtsdk4 as sdk
import ovirtsdk4.types as types

# Connessione a OLVM
connection = sdk.Connection(
    url='https://example.fqdn.ovlm/ovirt-engine/api',
    username='admin@internal',
    password='YOURPASSWORD',
    ca_file='/path/ca.pem'
)

system_service = connection.system_service()
vms_service = system_service.vms_service()

# Input interattivi
vm_name = input("👉 Nome VM: ")
cluster_name = input("👉 Cluster (default=Default): ") or "Default"
cpu_sockets = int(input("👉 Numero socket CPU: "))
cpu_cores = int(input("👉 Numero core per socket: "))
ram_gb = int(input("👉 RAM in GB: "))
disk_id = input("👉 ID del disco RAW: ")
nic_profile = input("👉 Nome VLAN (vNIC Profile): ")
fw_choice = input("👉 Tipo firmware [bios/uefi]: ").lower()

#set firmware
if fw_choice == "uefi":
    bios_type = types.BiosType.Q35_OVMF
else:
    bios_type = types.BiosType.Q35_SEA_BIOS

# Recupero ID profilo rete
profiles_service = system_service.vnic_profiles_service()
profile_id = None
for profile in profiles_service.list():
    if profile.name == nic_profile:
        profile_id = profile.id
        print(f"✅ Profilo trovato: {profile.name} (rete: {profile.network.name}) -> {profile.id}")
        break

if not profile_id:
    print("Profilo rete non trovato!")
    print("Profili disponibili:")
    for p in profiles_service.list():
        print(f"   - {p.name} (rete: {p.network.name})")
    connection.close()
    exit(1)

# Creazione VM
print(f"📦 Creazione VM '{vm_name}'...")
vm = vms_service.add(
    types.Vm(
        name=vm_name,
        cluster=types.Cluster(name=cluster_name),
        template=types.Template(name="Blank"),
        memory=ram_gb * 1024 * 1024 * 1024,
        memory_policy=types.MemoryPolicy(
            guaranteed=1 * 1024 * 1024  # garantita = 1 MB
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

# Attacco disco
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

# Creazione NIC (nic1 fissa)
nics_service = vm_service.nics_service()
nics_service.add(
    types.Nic(
        name="nic1",
        vnic_profile=types.VnicProfile(id=profile_id),
        interface=types.NicInterface.VIRTIO
    )
)

print("VM creata...")
connection.close()
