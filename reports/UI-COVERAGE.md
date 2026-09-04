# สถานะการแปลหมวด UI

วันที่อัปเดต: 30 สิงหาคม 2026

## ผลรวม

- แถวในหมวด UI: 234
- แปลฉบับร่างแล้ว: 204
- ยกเว้นโดยตั้งใจ: 28
- ต้นฉบับว่าง: 2 (`UI/TimeOutTransport`, `UI/HelpBranches`)
- ข้อความต้นฉบับที่ไม่ว่างและยังเป็น `untranslated`: 0

ข้อยกเว้นทั้งหมดเก็บใน `translations/th/exclusions.json` พร้อมเหตุผล ได้แก่ชื่อภาษาที่ควรแสดงในภาษาของผู้ใช้ URL ชื่อผลิตภัณฑ์ ค่า `#N/A` และ fragment ที่ไม่ใช่ข้อความภาษา

## การตรวจสอบ

- canonical validator: ผ่าน ไม่มี warning/error
- placeholder, rich-text tag และ line break: ผ่าน
- build: ผ่าน ไม่มี warning/error
- runtime บน Steam build `24972648`: โหลดและฉีด `204/204`
- plugin error ใน log: 0

## สถานะคุณภาพ

คำแปลทั้ง 204 รายการยังอยู่ในสถานะ `draft` จนกว่าจะผ่านการทบทวนภาษาและตรวจหน้าจอจริง การที่หมวด UI ไม่มีรายการ untranslated ไม่ได้หมายความว่า visual QA เสร็จแล้ว
