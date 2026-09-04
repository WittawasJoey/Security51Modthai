# ขั้นตอนรองรับเมื่อ Security 51 อัปเดต

เลขเวอร์ชันสองส่วนต้องไม่ปะปนกัน:

- `modVersion` คือรุ่นของม็อด เช่น `0.1.0`
- `buildId` คือ Steam build ของเกม เช่น `25104142`

## 1. ตรวจว่ามีเกมอัปเดตหรือไม่

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Game-Version.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Security 51"
```

หาก build ID หรือ SHA-256 ไม่ตรง ห้ามฝืนติดตั้ง release เดิม ให้ถือว่าเป็น build ใหม่ที่ยังไม่รองรับ

## 2. เก็บ baseline ของ build ใหม่

1. สำรอง `version.json` และผล extraction ของ build ก่อนหน้าโดยต่อท้ายเลข build
2. สร้าง baseline ด้วย `tools/Get-GameBaseline.ps1`
3. บันทึก Steam build ID, hash ของ executable, Unity version และ IL2CPP metadata version
4. ห้ามแก้ไฟล์เกมต้นฉบับระหว่าง extraction

## 3. สกัดและย้ายคำแปล

1. สกัด I2 language asset จาก build ใหม่
2. ใช้ `tools/migrate_translation_source.py` ย้ายคำแปลเดิมมายัง source ใหม่
3. ตรวจรายการ key ที่เพิ่ม ลบ และเปลี่ยนข้อความอังกฤษ
4. แปลเฉพาะรายการใหม่/เปลี่ยน ห้ามนำคำแปลเก่าทับ source ที่เปลี่ยนโดยไม่ทบทวน
5. รัน `tools/validate_translation.py` จนเหลือ 0 errors

## 4. ทดสอบและออกรุ่น

1. เพิ่ม build ใหม่ใน `supportedGameBuilds` ของ `version.json`
2. เพิ่ม `translationRevision` เมื่อเปลี่ยนเฉพาะคำแปล หรือเพิ่ม `modVersion` เมื่อเปลี่ยนโค้ด/พฤติกรรม
3. build release; ชื่อไฟล์ต้องมีทั้ง mod version และ game build
4. ทดสอบ install → runtime → uninstall บนสำเนาเกมเต็ม
5. ตรวจ runtime markers, จำนวนคำแปล, plugin errors และ visual QA
6. เพิ่มรายการใน `CHANGELOG.md` โดยไม่แก้ประวัติรุ่นเก่า

## หลักการเพิ่มเวอร์ชัน

- Patch (`0.1.1`): แก้คำแปล typo, layout หรือ bug เล็ก โดยยังรองรับ build เดิม
- Minor (`0.2.0`): รองรับ game build ใหม่ เพิ่มข้อความจำนวนมาก หรือเพิ่มความสามารถที่ยังเข้ากันได้
- Major (`1.0.0` ขึ้นไป): เปลี่ยนรูปแบบแพ็กเกจ/การติดตั้งหรือมี breaking change

ทุก release ต้องรองรับเฉพาะ build ที่ผ่านการทดสอบจริง Installer จะปฏิเสธ build อื่นโดยตั้งใจเพื่อไม่ทำให้เกมเสียหาย
