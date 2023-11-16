# vmmanager6_p2p_migration
VMmanager6 platform to platform VM migration

Миграция VM между платформами VMmanager. Заполните файл vars.sh

Затем запускайте
`sh p2p_import.sh <vm_id>`

Скрипт поддреживает:
- офлайн миграцию
- перенос из файлового хранилища в файловое
- перенос VM с несколькими дисками

VM будет выдан новый IP. Его необходимо настроить внутри перенесенной VM вручную
