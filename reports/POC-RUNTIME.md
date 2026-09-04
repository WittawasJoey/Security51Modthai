# รายงาน Proof of Concept ในเกม

วันที่ทดสอบ: 30 สิงหาคม 2026  
เกม: Security 51, Steam build `25104142`  
Unity: `6000.3.8f1`, IL2CPP metadata `39`  
Loader: BepInEx `6.0.0-be.785` (`6abdba47`)

## ผลที่ยืนยันแล้ว

- BepInEx สร้าง interop assemblies และโหลดปลั๊กอิน `Security 51 Thai Mod 0.1.0-poc` สำเร็จ
- ปลั๊กอินโหลดคำแปลจากตารางหลักและฉีดเข้า I2 Localization สำเร็จ รอบล่าสุดยืนยัน `3,457/3,457` รายการ
- TextMeshPro สร้าง dynamic fallback font จากไฟล์ `NotoSansThai-Variable.ttf` ที่รวมมากับม็อดสำเร็จ โดยไม่ต้องพึ่งฟอนต์ที่ติดตั้งใน Windows
- หากไฟล์ฟอนต์พกพาเสียหายหรือหายไป ปลั๊กอินยังลองใช้ฟอนต์ไทยใน Windows เป็น fallback สำรอง
- ชุดทดสอบ glyph ครอบคลุมพยัญชนะ สระ และวรรณยุกต์ไทยที่ใช้ในต้นแบบ
- runtime log รอบทดสอบล่าสุดไม่มี error จากปลั๊กอิน

## หลักฐานใน log

```text
[Info   :Security 51 Thai Mod] Security 51 Thai Mod 0.1.0-poc loaded with 3457 translations.
[Info   :Security 51 Thai Mod] Created Thai TMP fallback from bundled font 'NotoSansThai-Variable.ttf'.
[Info   :Security 51 Thai Mod] Applied 3457 Thai term values (UpdateSources).
```

ตรวจผลซ้ำแบบอัตโนมัติได้ด้วย:

```powershell
python .\tools\validate_runtime_log.py "D:\SteamLibrary\steamapps\common\Security 51\BepInEx\LogOutput.log"
```

## สิ่งที่ยังต้องตรวจด้วยภาพ

หลักฐาน runtime ยืนยันการโหลด font face และสร้าง glyph แต่ยังไม่เพียงพอสำหรับยืนยันการจัดวางบนหน้าจอ ต้องเปิดเกมแบบมองเห็นและบันทึกภาพอย่างน้อยสองบริบท เพื่อตรวจตัวสี่เหลี่ยม การซ้อนสระ/วรรณยุกต์ การตัดบรรทัด และข้อความล้นกรอบก่อนปิด Milestone M3
