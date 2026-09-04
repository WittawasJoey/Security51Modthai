# รายงาน QA ระบบติดตั้งและถอนการติดตั้ง

วันที่ทดสอบล่าสุด: 3 กันยายน 2026

## รอบ versioned release `0.1.0`

- สร้างแพ็กเกจ `Security51ThaiMod-v0.1.0-game25104142.zip` จาก `version.json`
- manifest บันทึก `modVersion=0.1.0` และ Steam build `25104142`
- ติดตั้งลงสำเนาเกมเต็มที่มี path ภาษาไทยสำเร็จ จำนวน payload 4 ไฟล์
- ถอนการติดตั้งสำเร็จ install pointer ถูกลบ และไม่เหลือ payload files
- installer/uninstaller ตรวจเฉพาะโปรเซส Security51 ที่รันจาก GamePath เป้าหมาย จึงทดสอบสำเนาได้โดยไม่รบกวนเกมจากโฟลเดอร์อื่น

ผลรวม: `VERSIONED_INSTALL_UNINSTALL_OK`

## ขอบเขต

ทดสอบแพ็กเกจ `Security51ThaiMod-0.1.0-draft` ในโครงสร้าง Steam จำลอง โดยใช้สำเนา `Security51.exe` และ BepInEx core จากสภาพแวดล้อมที่ผ่าน runtime test แล้ว ไม่เขียนทับไฟล์เกมจริงระหว่างการทดสอบวงจรนี้

## ผลทดสอบ

- Build pipeline ตรวจคำแปล 3,457 รายการ: warning 0, error 0
- Plugin compile: warning 0, error 0
- สร้าง `release-manifest.json`, ZIP และ SHA-256 sidecar สำเร็จ
- Installer ตรวจ Steam build ID และ SHA-256 ของ executable สำเร็จ
- Installer ตรวจ hash ของ BepInEx prerequisite ทั้งสองไฟล์สำเร็จ
- Installer ตรวจ size/hash ของ payload ก่อนเขียนไฟล์
- สำรองไฟล์ชื่อเดียวกันที่มีอยู่เดิมและสร้าง install record สำเร็จ
- ตรวจ hash ของ payload หลังติดตั้งตรงกับ manifest
- Uninstaller ปฏิเสธการถอนเมื่อ payload ถูกแก้หลังติดตั้งตามที่ออกแบบ
- หลังคืน payload ให้ตรง install record แล้ว uninstaller คืนไฟล์เดิมได้ตรง hash
- install pointer ถูกลบหลังถอน และ BepInEx core ไม่ถูกลบ

ผลรวม: `INSTALL_UNINSTALL_CYCLE_OK`

## การทดสอบ release ล่าสุดบน build 25104142

- ตรวจพบการอัปเดต Steam จาก build `24972648` เป็น `25104142`; installer รุ่นเดิมปฏิเสธ build ใหม่ตามที่ออกแบบ
- สร้าง baseline ใหม่และยืนยันว่า `Security51.exe` ยังคง SHA-256 เดิม แต่ GameAssembly, metadata และ Unity assets หลายไฟล์เปลี่ยน
- ทดสอบแพ็กเกจที่อัปเดต compatibility แล้วใน Steam layout จำลองสะอาด
- ใช้ทั้ง game path และ state path ที่มีอักษรไทยและช่องว่าง
- installer ตรวจ build ID, executable, prerequisite และ payload hash ผ่าน
- หลังติดตั้ง payload ทุกไฟล์มี hash ตรง release manifest
- uninstaller ลบ payload และ install pointer ครบ
- BepInEx prerequisite ทั้งสองไฟล์มี hash เท่าเดิมหลังถอน

ผลรวมล่าสุด: `CLEAN_NONASCII_INSTALL_UNINSTALL_OK`

## การทดสอบสำเนาเกมเต็ม

- คัดลอกโฟลเดอร์เกมครบ 527 ไฟล์ ขนาด 2.34 GiB ไปยัง Steam layout จำลองที่มีอักษรไทย
- นำ payload ม็อดออกจากสำเนาก่อนติดตั้ง โดยคง BepInEx prerequisite ไว้
- ติดตั้ง release ล่าสุดและตรวจ payload hash ครบทุกไฟล์
- เปิด `Security51.exe` จากสำเนาโดยตรงและอ่าน `BepInEx/LogOutput.log` ภายในสำเนา
- runtime marker ผ่าน `4/4`, โหลดและฉีด `3,457/3,457`, plugin error 0
- ถอนม็อดสำเร็จ ไม่เหลือ payload หรือ install pointer
- hash ของไฟล์เกมทางการหลักทั้ง 13 ไฟล์ตรงกับ baseline หลังถอน

ผลรวมสำเนาเต็ม: `FULL_COPY_RUNTIME_INSTALL_UNINSTALL_OK`

## สิ่งที่ยังไม่ถือว่าผ่าน

- ยังไม่ได้ทดสอบ Steam library จริงบนไดรฟ์อื่นนอกเหนือจาก layout จำลอง
- ยังไม่ได้ทดสอบ archive หลังดาวน์โหลดจากช่องทางเผยแพร่จริง
- แพ็กเกจยังเป็น draft และต้องติดตั้ง BepInEx รุ่นที่กำหนดแยกต่างหาก
