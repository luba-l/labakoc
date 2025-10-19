#!/bin/bash

set -e  # прервать при ошибке

IMG="test_disk.img"
MNT="./mnt"
LOG="$MNT/log"
DISK_SIZE_MB=2048   # общий размер диска (МБ)
FILE_SIZE_MB=20    # размер каждого файла (МБ)
BACKUP_DIR="$LOG/backup"

#Подготовка окружения
echo "Подготовка окружения"
fusermount -u "$MNT" 2>/dev/null || true
rm -rf "$MNT" "$IMG"
mkdir -p "$MNT"

#Создание виртуального диска
echo "Создаём виртуальный диск ${DISK_SIZE_MB}MB"
dd if=/dev/zero of="$IMG" bs=1M count="$DISK_SIZE_MB" status=none
mkfs.ext4 -O ^has_journal "$IMG" > /dev/null

#Монтирование диска
echo "Монтируем диск через FUSE"
fuse2fs -o rw,fakeroot "$IMG" "$MNT" &
FUSE_PID=$!
sleep 1

# Проверка, что диск действительно смонтирован
if ! mountpoint -q "$MNT"; then
  echo "Ошибка: диск не смонтирован в $MNT"
  kill "$FUSE_PID" 2>/dev/null || true
  exit 1
fi

mkdir -p "$LOG"

#Функция генерации файлов
generate_files() {
  local count=$1
  echo "Создаём $count файлов по ${FILE_SIZE_MB}MB"
  for i in $(seq 1 "$count"); do
    dd if=/dev/zero of="$LOG/file_$i.log" bs=1M count=$FILE_SIZE_MB status=none
  done
  TOTAL=$(du -sm "$LOG" | awk '{print $1}')
}

#Функция запуска теста
run_test() {
  local test_name=$1
  local threshold=$2
  echo "===== Тест: $test_name ====="
  bash ./lab1.sh --path "$LOG" --threshold "$threshold" --total "$DISK_SIZE_MB" --backup "$BACKUP_DIR"
}

#Запуск тестов
echo ""
echo "Запуск 5 тестов"

# Тест 1: ниже порога
echo ""
generate_files 40
run_test "№1" 80

# Тест 2: превышение порога
echo ""
generate_files 70
run_test "№2" 50
echo ""

#Тест 3: очень маленький порог
generate_files 80
run_test "№3" 10
echo ""

# Тест 4: пустая папка
rm -rf "$LOG"/*
run_test "Пустая папка " 70

# Тест 5: ошибочные параметры (CLI)
echo ""
echo "===== Тест: Ошибочные параметры (CLI) ====="
bash ./lab1.sh --path "$LOG" --threshold 70 || echo "Ошибка CLI корректно обработана"

# Тест 6: Максимальное сжатие (LZMA)
echo ""
# Устанавливаем переменную окружения
export LAB1_MAX_COMPRESSION=1
generate_files 50
run_test "Максимальное сжатие LZMA" 20
# Сбрасываем переменную, чтобы не влияла на другие тесты
unset LAB1_MAX_COMPRESSION

fusermount -u "$MNT" 2>/dev/null || true
kill "$FUSE_PID" 2>/dev/null || true

echo ""
echo "Тестирование завершено успешно!"
