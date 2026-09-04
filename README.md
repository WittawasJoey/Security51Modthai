# Security 51 Thai Mod

ม็อดภาษาไทย Security 51 เวอร์ชัน `0.1.2-beta` ปัจจุบันรองรับ Steam build `25104142` และใช้ BepInEx Unity IL2CPP x64 `6.0.0-be.785+6abdba4`

> รุ่นนี้เล่นเป็นภาษาไทยได้แล้ว มีค่า localization ภาษาไทย 3,481 รายการ ครบ 100% ของข้อความที่ต้องมีค่าใน Steam build `25104142` สถานะ beta หมายถึงยังเปิดรับการแก้คำแปลและการจัดวางตามบริบทในเกม

## สิ่งที่ต้องมี

1. Security 51 บน Steam build `25104142`
2. BepInEx Unity IL2CPP x64 `6.0.0-be.785+6abdba4` ที่เปิดเกมอย่างน้อยหนึ่งครั้งแล้ว
3. ปิดเกมก่อนติดตั้งหรือถอนการติดตั้ง

Installer จะตรวจ Steam build ID, SHA-256 ของ `Security51.exe`, BepInEx core ที่รองรับ และ checksum ของทุกไฟล์ในแพ็กเกจก่อนเขียนไฟล์ หากรายการใดไม่ตรงจะหยุดโดยไม่ติดตั้ง

## ติดตั้งแบบคลิกครั้งเดียว

1. แตกไฟล์ release ZIP ให้เรียบร้อย
2. ดับเบิลคลิก `Install-SingleClick.cmd`
3. ตัวติดตั้งจะค้นหา Security 51 ใน Steam libraries, ตรวจ build/hash, อัปเดตรุ่นเก่า และติดตั้งรุ่นใหม่อัตโนมัติ

ต้องติดตั้ง BepInEx รุ่นที่ระบุไว้ก่อน และต้องปิดเกมระหว่างติดตั้ง หากมีเกมหลายชุดหรือย้ายเกมไปตำแหน่งพิเศษ ให้ใช้วิธี PowerShell ด้านล่างเพื่อระบุ path เอง

## ติดตั้ง

แตกไฟล์ release archive แล้วเปิด PowerShell ในโฟลเดอร์ที่แตก จากนั้นใช้ path เกมของตนเอง:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-ThaiMod.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Security 51"
```

Installer สำรองเฉพาะไฟล์ปลายทางที่มีอยู่เดิมไว้ใน `%LOCALAPPDATA%\Security51ThaiMod\backups` และเขียน install record สำหรับการถอนที่ตรวจสอบย้อนกลับได้

## ถอนการติดตั้ง

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-ThaiMod.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Security 51"
```

Uninstaller ลบเฉพาะไฟล์ที่แพ็กเกจนี้ติดตั้งและคืนไฟล์เดิมจาก backup โดยไม่ลบ BepInEx หรือปลั๊กอินอื่น หากไฟล์ม็อดถูกแก้หลังติดตั้ง ระบบจะหยุดเพื่อป้องกันข้อมูลสูญหาย; `-Force` มีไว้เมื่อผู้ใช้ตั้งใจยอมให้คืน/ลบไฟล์ที่แก้แล้วเท่านั้น

## ตรวจสอบ archive

ไฟล์ `.zip.sha256` ที่มากับ release ใช้ตรวจว่า archive ไม่เสียหาย:

```powershell
Get-FileHash .\Security51ThaiMod-v0.1.1-game25104142.zip -Algorithm SHA256
```

## สร้างแพ็กเกจจาก source

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Release.ps1
```

ขั้นตอนนี้จะตรวจตารางคำแปล สร้าง JSON, compile plugin, สร้าง manifest, archive และ SHA-256 sidecar

## เมื่อเกมอัปเดต

ตรวจ build ที่ติดตั้งก่อนด้วย:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Game-Version.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Security 51"
```

อย่าฝืนติดตั้งแพ็กเกจเมื่อ build ไม่ตรง Installer จะหยุดเพื่อป้องกันความเสียหาย ขั้นตอนย้ายคำแปลและออกรุ่นสำหรับเกม build ใหม่อยู่ใน `docs/GAME_UPDATE_WORKFLOW.md` และ compatibility ที่เป็นแหล่งข้อมูลกลางอยู่ใน `version.json`

## สถานะและข้อจำกัด

- Runtime รุ่นก่อนยืนยันแล้วว่าเกมโหลดและใช้คำแปล `3,457/3,457` รายการโดยไม่มี plugin error; รุ่น `0.1.1` เพิ่มค่าเมนูภาษา/Steam Deck อีก 24 รายการ รวมเป็น 3,481 รายการและรอตรวจภาพหลังติดตั้ง
- `Story_Dial` แปลฉบับร่างครบ 386/386
- `NewsAndReports` แปลฉบับร่างครบ 133/133
- เครดิตที่มีข้อความต้นฉบับแปลฉบับร่างครบ 2/2
- `Rorschach` แปลฉบับร่างครบ 133/133
- `Abstract_Dev` ที่มีข้อความต้นฉบับแปลฉบับร่างครบ 11/11
- `Doc_Loc` แปลฉบับร่างครบ 342/342
- `CityOperations` แปลฉบับร่างครบ 287/287
- `Real_Dev` แปลฉบับร่างครบ 455/455 รายการที่มีข้อความจริง
- `DM_Ends` แปลฉบับร่างครบ 515/515 รายการที่มีข้อความจริง
- ม็อดรวม `Noto Sans Thai` แบบพกพาไว้ในแพ็กเกจ และจะใช้ฟอนต์ไทยใน Windows เป็น fallback สำรองเมื่อไฟล์ดังกล่าวโหลดไม่ได้
- `Noto Sans Thai` เผยแพร่ภายใต้ SIL Open Font License 1.1; สำเนาใบอนุญาตอยู่ที่ `BepInEx/plugins/Security51Thai/fonts/OFL.txt`
- คำแปลทั้งหมดอยู่สถานะ draft จนกว่าจะผ่าน visual/context QA
- Release archive เป็น mod-only และไม่แจก BepInEx; ผู้ใช้ต้องติดตั้ง prerequisite รุ่นที่ระบุแยกต่างหาก
