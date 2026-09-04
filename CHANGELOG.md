# ประวัติเวอร์ชัน Security 51 Thai Mod

รูปแบบเวอร์ชันม็อดใช้ Semantic Versioning (`major.minor.patch`) และระบุ Steam build ที่รองรับแยกต่างหากเสมอ

## 0.1.2-beta — 4 กันยายน 2026

รองรับ Security 51 Steam build `25104142`

- เพิ่ม `Install-SingleClick.cmd` สำหรับติดตั้งด้วยการดับเบิลคลิก
- ค้นหา Security 51 จาก Steam registry และ `libraryfolders.vdf` อัตโนมัติ
- อัปเดตม็อดรุ่นเก่าโดยใช้ uninstaller/install record เดิมอย่างปลอดภัย
- ยังคงตรวจ Steam build, executable hash, BepInEx และ payload checksum ก่อนติดตั้ง
- รองรับ `-GamePath` เมื่อพบเกมหลายชุดหรือติดตั้งในตำแหน่งพิเศษ

## 0.1.1-beta — 4 กันยายน 2026

รองรับ Security 51 Steam build `25104142`

- ซ่อน placeholder `Button` ที่หลุดแสดงทับปุ่มเริ่มปฏิบัติการบริเวณขวาล่าง
- ตัวกรองใช้ exact match และปิดเฉพาะ text label โดยไม่ปิดตัวปุ่มหรือข้อความอื่น
- รองรับทั้ง TextMeshPro และ Unity UI Text
- เติมค่า Thai ให้รายการเลือกภาษาทุกภาษาโดยคงชื่อเจ้าของภาษา เช่น `English`, `Русский`, `简体中文` แทนการแสดง localization key ดิบ
- เติมค่า `Steam Deck` ให้ `UI/OptSD` เพื่อไม่ให้ key ดิบแสดงในหน้าตั้งค่า
- เพิ่มจำนวนค่า localization ที่ส่งเข้าเกมจาก 3,457 เป็น 3,481 รายการ; validator ผ่านด้วย 0 warnings / 0 errors

## 0.1.0-beta — 3 กันยายน 2026

รองรับ Security 51 Steam build `25104142`

- คำแปลภาษาไทย `3,457/3,457` รายการที่มีสิทธิ์แปล
- เพิ่มภาษา Thai เข้า I2 Localization ขณะเกมทำงาน
- เพิ่ม Noto Sans Thai แบบพกพาและ fallback ฟอนต์ Windows
- รักษา placeholder และ rich-text ผ่านตัวตรวจอัตโนมัติ โดยผลล่าสุดเป็น 0 warnings / 0 errors
- installer ตรวจ Steam build, executable hash, BepInEx และ checksum ของ payload
- uninstaller คืนไฟล์เดิมจาก backup และไม่ลบปลั๊กอินอื่น
- ผ่าน runtime test: markers 4/4, โหลด/ฉีด 3,457/3,457, plugin errors 0

สถานะ beta หมายถึงเล่นภาษาไทยได้แล้ว แต่ยังเปิดรับการแก้คำแปลและปัญหาการจัดวางจากภาพในเกม
