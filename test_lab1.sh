#!/bin/bash

set -e  # прервать при ошибке

IMG="test_disk.img"
MNT="./mnt"
LOG="$MNT/log"
DISK_SIZE_MB=800   # общий размер диска (МБ)
FILE_SIZE_MB=10    # размер каждого файла (МБ)
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

if [ ! -d "$MNT" ]; then
  echo "Ошибка монтирования"
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

#Тест 1: 40 файлов, порог 80%
echo ""
generate_files 40
run_test "№1" 80
echo ""

#Тест 2: 60 файлов, порог 70%
echo ""
generate_files 60
run_test "№2" 70
echo ""

#Тест 3: 70 файлов, порог 60%
echo ""
generate_files 70
run_test "№3" 60
echo ""

#Тест 4: 20 файлов, порог 90%
echo ""
generate_files 20
run_test "№4" 90
echo ""

#Тест 5: 70 файлов, порог 50%
echo ""
generate_files 70
run_test "№5" 50
echo ""

fusermount -u "$MNT" 2>/dev/null || true
kill "$FUSE_PID" 2>/dev/null || true

echo ""
echo "Тестирование завершено успешно!"
