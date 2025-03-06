Предварительная подготовка коммутатора:
1) Обновление прошивки коммутатора
2) Загрузка заранее подготовленого конфига

**Requirements:**
apt install cu

**Usage:**
SWITCH_PROMPTS=("S42-8G2S#" "S4600#")
указываем возможные варианты строки приветствия

[code]
FIRMWARE_PATHS["DCN_S4600_10P_SI"]="/4600/S4600-XXP(-P)-SI-10.9.11-vendor_V702R101C005B012_nos.img"
CONFIG_PATHS["DCN_S4600_10P_SI"]="/dcn4600-10.cfg"
SERIAL_SETTINGS["DCN_S4600_10P_SI"]="9600,cs8,-parenb,-cstopb,-hupcl"
[/code]
Указываем путь до прошивки, конфига и настройки для подключения
