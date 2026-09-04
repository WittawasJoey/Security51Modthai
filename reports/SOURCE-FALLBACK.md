# รายงาน Source Language Fallback

วันที่อัปเดต: 30 สิงหาคม 2026

ฐาน I2 ของเกมมี 648 key ที่ช่องภาษาอังกฤษว่างแต่ภาษารัสเซียมีข้อความ รวมถึง Story_Dial เกือบทั้งหมวด การนับเฉพาะภาษาอังกฤษจึงทำให้ coverage สูงกว่าความจริงและทำให้ validator ตรวจ placeholder/tag ของข้อความเหล่านี้ไม่ได้

## วิธีที่ใช้

- เลือก source ตามลำดับ `English [en]` แล้ว fallback เป็น `Russian [ru]`
- ส่งออกรายการ fallback ไปที่ `translations/source_ru/strings.csv`
- validator ตรวจ placeholder, rich-text tag, control token และ line break กับ effective source
- coverage ใช้ effective source เช่นเดียวกัน
- ไม่เปลี่ยนหรือปลอมช่อง English ในไฟล์ต้นฉบับ

หลังแก้ไข จำนวน source key ที่ไม่ว่างเพิ่มจาก 3,026 เป็น 3,417 unique keys

## สถานะ Story_Dial

- แถวที่มี source รัสเซีย: 386
- แปลฉบับร่างแล้ว: 386
- ยังคงเหลือ: 0
- แถว `Story_Dial/` อีก 1 แถวไม่มี source จึงไม่นับเป็นเนื้อหาแปล
- runtime ล่าสุดรวมทุกหมวด: `3,457/3,457`
