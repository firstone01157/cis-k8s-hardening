# ใช้ Base Image เป็น Python แบบ Slim (เล็กและปลอดภัย)
FROM python:3.11-slim

# 1. ลงโปรแกรมพื้นฐานที่ Script Bash ของเราต้องใช้
# - procps: สำหรับคำสั่ง 'ps' (เช็ค Process)
# - jq: สำหรับ parse json (เผื่อใช้)
# - grep, sed, gawk: สำหรับ text processing
RUN apt-get update && apt-get install -y \
    procps \
    jq \
    curl \
    grep \
    sed \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# 2. กำหนด Working Directory
WORKDIR /app

# 3. Copy ไฟล์ทั้งหมดเข้า Container
# (รวมถึง generate_cis_scripts.py, CSV, และโฟลเดอร์ script ที่ gen แล้วถ้ามี)
COPY . /app

# 4. (Optional) รัน Script Gen เผื่อในกรณีที่เราอยากให้ Gen ใหม่สดๆ ตอน Build
# ตรวจสอบชื่อไฟล์ CSV ใน generate_cis_scripts.py ให้ตรงกับไฟล์จริงก่อนบรรทัดนี้
# RUN python3 generate_cis_scripts.py

# 5. ให้สิทธิ์ Execute กับไฟล์ .sh ทั้งหมด
RUN chmod +x /app/*.sh /app/*/*.sh

# 6. กำหนดคำสั่งเริ่มต้น (เมื่อ Container รัน จะให้ทำอะไร)
# เช่น ให้รัน Audit ทันที
CMD ["./master_audit_only.sh"]