#!/bin/bash

#Чтение параметров
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --path) LOG_PATH="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --total) TOTAL_MB="$2"; shift 2 ;;
    --backup) BACKUP_DIR="$2"; shift 2 ;;
    *) echo "Неизвестный параметр: $1"; exit 1 ;;
  esac
done

#Проверки на наличие параметров
if [[ -z "$LOG_PATH" || -z "$THRESHOLD" || -z "$TOTAL_MB" ]]; then
  echo "Недостаточно аргументов"
  exit 1
fi

#Если не указана папка для бэкапов, создаём самостоятельно
if [[ -z "$BACKUP_DIR" ]]; then
  BACKUP_DIR="$LOG_PATH/backup"
fi
mkdir -p "$BACKUP_DIR"

#Проверка существования каталога логов
if [ ! -d "$LOG_PATH" ]; then
  echo "Это не директория"
  exit 1
fi

#Расчёт заполненности
USED_MB=$(du -sm "$LOG_PATH" | awk '{print $1}')
USAGE=$((100 * USED_MB / TOTAL_MB))

echo "Текущая заполненность: $USAGE% (${USED_MB}MB из ${TOTAL_MB}MB)"
echo "Порог: ${THRESHOLD}%"

#Проверка превышения порога
if (( USAGE < THRESHOLD )); then
  echo "Заполненность меньше порога. Архивация не требуется"
  exit 0
fi

#Вычисление необходимого освобождения
TARGET_MB=$(( TOTAL_MB * THRESHOLD / 100 ))
NEED_FREE=$(( USED_MB - TARGET_MB ))

echo "Нужно освободить ${NEED_FREE}MB"

#Поиск и сортировка файлов по дате
FILES=$(find "$LOG_PATH" -type f ! -path "$BACKUP_DIR/*" -printf "%T@ %p\n" | sort -n | awk '{print $2}')

SUM=0
TO_ARCHIVE=()

for f in $FILES; do
  SIZE=$(du -sm "$f" | awk '{print $1}')
  TO_ARCHIVE+=("$f")
  SUM=$((SUM + SIZE))
  if (( SUM >= NEED_FREE )); then
    break
  fi
done

if (( SUM == 0 )); then
  echo "Нет файлов для архивации"
  exit 0
fi

#Архивация и удаление
ARCHIVE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
echo "Архивируем ${#TO_ARCHIVE[@]} файлов в $ARCHIVE ..."
tar -czf "$ARCHIVE" "${TO_ARCHIVE[@]}" && rm -f "${TO_ARCHIVE[@]}"
