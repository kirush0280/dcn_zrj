#!/bin/bash

# Загрузка конфигурации
CONFIG_FILE="./config.ini"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Ошибка: Файл конфигурации $CONFIG_FILE не найден"
    exit 1
fi
source "$CONFIG_FILE"

# Конфигурационные параметры для разных моделей
declare -A FIRMWARE_PATHS
declare -A CONFIG_PATHS
declare -A SERIAL_SETTINGS

# Массив возможных приветствий (общий для всех моделей)
SWITCH_PROMPTS=("S42-8G2S#" "S4600#")

# DCN S4600-10P-SI
FIRMWARE_PATHS["DCN_S4600_10P_SI"]="/4600/S4600-XXP(-P)-SI-10.9.11-vendor_V702R101C005B012_nos.img"
CONFIG_PATHS["DCN_S4600_10P_SI"]="/dcn4600-10.cfg"
SERIAL_SETTINGS["DCN_S4600_10P_SI"]="9600,cs8,-parenb,-cstopb,-hupcl"

# ZRJ S42-8G2S
FIRMWARE_PATHS["ZRJ_S42_8G2S"]="/ZRJ/S46-S42/ZRJ-S46-S42-IS42-10.30.137-vendor_V702R101C009B004_nos.img"
CONFIG_PATHS["ZRJ_S42_8G2S"]="/4600-10.cfg"
SERIAL_SETTINGS["ZRJ_S42_8G2S"]="9600,cs8,-parenb,-cstopb,-hupcl"

# Общие параметры
TFTP_SERVER="192.168.1.111"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Функция выбора производителя и модели
select_switch_model() {
    echo -e "${GREEN}=== Инструмент настройки коммутаторов DCN/ZRJ ===${NC}"
    echo -e "${YELLOW}Выберите производителя:${NC}"
    select vendor in "DCN" "ZRJ" "Выход"; do
        case $vendor in
            "DCN")
                echo -e "${YELLOW}Выберите модель DCN:${NC}"
                select model in "S4600-10P-SI" "Назад"; do
                    case $model in
                        "S4600-10P-SI")
                            echo "Выбран коммутатор DCN S4600-10P-SI"
                            CURRENT_MODEL="DCN_S4600_10P_SI"
                            return 0
                            ;;
                        "Назад")
                            select_switch_model
                            return $?
                            ;;
                    esac
                done
                ;;
            "ZRJ")
                echo -e "${YELLOW}Выберите модель ZRJ:${NC}"
                select model in "S42-8G2S" "Назад"; do
                    case $model in
                        "S42-8G2S")
                            echo "Выбран коммутатор ZRJ S42-8G2S"
                            CURRENT_MODEL="ZRJ_S42_8G2S"
                            return 0
                            ;;
                        "Назад")
                            select_switch_model
                            return $?
                            ;;
                    esac
                done
                ;;
            "Выход")
                return 1
                ;;
        esac
    done
}

# Запускаем выбор модели
select_switch_model
if [ $? -eq 1 ]; then
    echo -e "${YELLOW}Выход из программы${NC}"
    exit 0
fi

echo -e "${GREEN}Поиск доступных USB-портов...${NC}"

# Поиск доступных USB-портов
usb_ports=($(ls /dev/ttyUSB* 2>/dev/null))

if [ ${#usb_ports[@]} -eq 0 ]; then
    echo -e "${RED}USB-порты не найдены. Проверьте подключение консольного кабеля.${NC}"
    exit 1
fi

echo -e "${GREEN}Найдены следующие USB-порты:${NC}"

# Вывод списка портов с номерами
for i in "${!usb_ports[@]}"; do
    echo -e "  ${YELLOW}[$i]${NC} ${usb_ports[$i]}"
done

# Запрос выбора порта
echo -e "${YELLOW}Выберите номер порта для подключения:${NC}"
read -p "> " port_index

# Проверка корректности ввода
if ! [[ "$port_index" =~ ^[0-9]+$ ]] || [ "$port_index" -ge ${#usb_ports[@]} ]; then
    echo -e "${RED}Некорректный выбор. Пожалуйста, выберите номер из списка.${NC}"
    exit 1
fi

selected_port=${usb_ports[$port_index]}
echo -e "${GREEN}Выбран порт: ${selected_port}${NC}"
echo -e "${YELLOW}Подключение к коммутатору и настройка...${NC}"

# Создаем expect скрипт для автоматизации
cat << EOF > /tmp/dcn_setup.exp
#!/usr/bin/expect -f

# Установка таймаута
set timeout 300

# Получение параметров
set port [lindex \$argv 0]
set firmware_url "tftp://${TFTP_SERVER}${FIRMWARE_PATHS[$CURRENT_MODEL]}"
set config_url "tftp://${TFTP_SERVER}${CONFIG_PATHS[$CURRENT_MODEL]}"

# Подключение через cu
log_user 1
spawn cu -l \$port -s 9600

# Проверка успешности подключения
expect {
    "timeout" {
        puts "CONNECT_ERROR: Не удалось подключиться к порту"
        exit 1
    }
    eof {
        puts "CONNECT_ERROR: Соединение прервано"
        exit 1
    }
    "Connected" {
        sleep 2
        send "\r"
    }
}

# Проверяем что появилось первым: Password или Username
expect {
    "Password:" {
        send "\r"
        expect "Username:"
    }
    "Username:" { }
}

# Ввод учетных данных
send "admin\r"
expect "Password:"
send "admin\r"

# Создаем строку для expect с альтернативными вариантами приветствия
set prompt_pattern "$(printf '%s|' "${SWITCH_PROMPTS[@]}")"
set prompt_pattern [string range \$prompt_pattern 0 end-1]

# Ожидание приглашения командной строки (любого из списка)
expect -re "\$prompt_pattern"

# Настройка IP-адреса
send "conf\r"
expect "(config)#"
send "interface vlan 1\r"
expect "(config-if-vlan1)#"
send "ip address 192.168.1.20 255.255.255.0\r"
expect "(config-if-vlan1)#"
send "exit\r"
expect "(config)#"
send "exit\r"
expect -re "\$prompt_pattern"

# Загрузка и установка прошивки
send "copy \$firmware_url nos.img\r"
expect "\[Y/N\]"
sleep 1
send "Y\r"
expect -re "\$prompt_pattern"

# Сохранение базовой конфигурации
send "write\r"
expect "\[Y/N\]"
send "Y\r"
expect -re "\$prompt_pattern"

# Загрузка предварительно настроенного конфига
send "copy \$config_url startup.cfg\r"
expect "\[Y/N\]"
send "Y\r"
expect -re "\$prompt_pattern"
send "exit\r"
expect -re "\$prompt_pattern"

# Выход из cu (используем специальную последовательность ~.)
send "~."
expect eof
EOF

# Делаем expect скрипт исполняемым
chmod +x /tmp/dcn_setup.exp

# Запускаем expect скрипт и проверяем результат
echo -e "${YELLOW}Запуск автоматической настройки и обновления прошивки...${NC}"
expect /tmp/dcn_setup.exp $selected_port | tee /tmp/dcn_setup.log
if grep -q "CONNECT_ERROR:" /tmp/dcn_setup.log; then
    error_msg=$(grep "CONNECT_ERROR:" /tmp/dcn_setup.log | cut -d: -f2-)
    echo -e "${RED}Ошибка подключения:${error_msg}${NC}"
    echo -e "${YELLOW}Хотите выбрать другой порт? (y/n)${NC}"
    read -p "> " retry
    if [[ $retry =~ ^[Yy]$ ]]; then
        # Очистка временных файлов
        rm -f /tmp/dcn_setup.exp /tmp/dcn_setup.log
        # Перезапуск скрипта с того же места
        exec $0
    fi
    # Очистка временных файлов
    rm -f /tmp/dcn_setup.exp /tmp/dcn_setup.log
    exit 1
fi

# Очистка лога
rm -f /tmp/dcn_setup.log

# Функция очистки всех процессов и временных файлов
cleanup_all() {
    echo -e "\n${YELLOW}Завершение работы скрипта...${NC}"
    
    # Поиск и завершение процессов cu
    cu_processes=$(ps aux | grep "cu.*ttyUSB" | grep -v grep | awk '{print $2}')
    if [ ! -z "$cu_processes" ]; then
        echo -e "${YELLOW}Завершение процессов cu...${NC}"
        for pid in $cu_processes; do
            kill $pid 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Процесс cu (PID: $pid) завершен${NC}"
            fi
        done
    fi

    # Поиск и завершение процессов expect
    expect_processes=$(ps aux | grep "expect.*dcn_setup.exp" | grep -v grep | awk '{print $2}')
    if [ ! -z "$expect_processes" ]; then
        echo -e "${YELLOW}Завершение процессов expect...${NC}"
        for pid in $expect_processes; do
            kill $pid 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Процесс expect (PID: $pid) завершен${NC}"
            fi
        done
    fi

    # Поиск и завершение процессов tee
    tee_processes=$(ps aux | grep "tee.*dcn_setup.log" | grep -v grep | awk '{print $2}')
    if [ ! -z "$tee_processes" ]; then
        echo -e "${YELLOW}Завершение процессов tee...${NC}"
        for pid in $tee_processes; do
            kill $pid 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Процесс tee (PID: $pid) завершен${NC}"
            fi
        done
    fi

    # Удаление временных файлов
    rm -f /tmp/dcn_setup.exp /tmp/dcn_setup.log

    echo -e "${GREEN}Очистка завершена${NC}"
    
    # Завершаем текущий процесс
    kill -9 $$ 2>/dev/null
}

# Добавляем обработчики сигналов
trap cleanup_all EXIT
trap cleanup_all SIGINT
trap cleanup_all SIGTERM

echo -e "${GREEN}Настройка коммутатора успешно завершена!${NC}"
echo -e "${GREEN}Коммутатор готов к работе.${NC}"
exit 0
