# Подготовка коммутаторов DCN/SNR/ZRJ

Этот репозиторий содержит скрипт для предварительной подготовки коммутатора:
 -  обновление прошивки
 -  загрузка конфигурационного файла.

## Требования

Для работы со скриптом установите следующее программное обеспечение:

```bash
sudo apt install cu
```

## Файл настроек:

Указываем возможные варианты промптов
```bash
SWITCH_PROMPTS=("S42-8G2S#" "S4600#")
```

Пути для прошивки, конфигов и настройка порта для подключения

bash```
FIRMWARE_PATHS["DCN_S4600_10P_SI"]="/4600/S4600-XXP(-P)-SI-10.9.11-vendor_V702R101C005B012_nos.img"
CONFIG_PATHS["DCN_S4600_10P_SI"]="/dcn4600-10.cfg"
SERIAL_SETTINGS["DCN_S4600_10P_SI"]="9600,cs8,-parenb,-cstopb,-hupcl"
```

Адрес TFTP сервера
bash```
TFTP_SERVER="192.168.1.111"
```
