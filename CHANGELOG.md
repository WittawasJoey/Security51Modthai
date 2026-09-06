# ประวัติเวอร์ชัน Security 51 Thai Mod

รูปแบบเวอร์ชันม็อดใช้ Semantic Versioning (`major.minor.patch`) และระบุ Steam build ที่รองรับแยกต่างหากเสมอ

## 0.1.6-beta (Planned / แผนการพัฒนาถัดไป)

- ตรวจสอบและปรับปรุงความสวยงามของการตัดคำและขนาดฟอนต์ (Text Wrapping & Dynamic Auto-sizing) ในหน้าต่างเอกสารรายงานประจำวัน (Daily Isolator Report) และคำอธิบายความผิดปกติ (Anomaly Description)
- ปรับปรุงการแสดงผลของไอคอนและปุ่มกดคอนโทรลเลอร์ (Gamepad / Steam Deck Controller Prompts) ให้แสดงผลไอคอนอย่างสวยงามในทุกสเกลหน้าจอ
- ขัดเกลาและตรวจสอบบริบทคำแปลเชิงลึก (In-game Context & Lore Polish) สำหรับเนื้อเรื่องหลักและบทสนทนาทางเลือก
- อัปเดตและทดสอบความเข้ากันได้ทันทีเมื่อตัวเกม Security 51 มีการอัปเดตแพตช์ Steam Build ใหม่

## 0.1.5-beta — 6 กันยายน 2026

รองรับ Security 51 Steam build `25104142`

- **แก้ไขข้อความ "Button" สีเทาหลุดแสดงในหน้าต่างปฏิบัติการเมือง (City Operations) และขอบจอขวา:**
  - พิสูจน์สาเหตุที่แท้จริงจาก Prefab และโครงสร้าง UI: ตัวเกมเดิมใช้ `EmptyFont` (PathID: 9393 ใน `resources.assets`) ซึ่งเป็นฟอนต์เปล่าไม่มี glyph เพื่อซ่อนข้อความ placeholder `"Button"` บนปุ่มที่เป็นไอคอนกราฟิกล้วน (`ApplyButton`, `HintButton`, `BackButton`)
  - แก้ไขกลไก Font Fallback ที่ระดับ Engine TextMeshPro: ยกเลิกการใส่ฟอนต์ภาษาไทยเข้า `TMP_Settings.fallbackFontAssets` และกรองข้ามฟอนต์ตระกูล `"Empty"` เพื่อคืนพฤติกรรมดั้งเดิมของตัวเกม ป้องกันไม่ให้ TextMeshPro ดึงตัวอักษรภาษาอังกฤษจากฟอนต์ไทยมาแสดงผล
  - เสริมการป้องกันสองชั้น (Two-Layer Defense) ด้วย Harmony Postfix Patches ที่ `CityOperations.Views.CityOperationsWindowView.OnEnable` และ `SetConfirmButtonState` พร้อมตัวกรองซ่อน placeholder ที่ระบุเจาะจงปุ่มไอคอน (`GamepadInput.Icons.InputIconImage`) โดยไม่แตะต้อง component `Button`, `onClick`, `Image`, `raycastTarget` หรือข้อความที่มี Localization
- **เพิ่มตัวถอนการติดตั้งแบบคลิกเดียว (`Uninstall-SingleClick.cmd` / `Uninstall-SingleClick.ps1`):**
  - อำนวยความสะดวกให้ผู้ใช้สามารถดับเบิลคลิกเพื่อถอนการติดตั้งม็อดภาษาไทยได้ทันที
  - ระบบค้นหาตำแหน่งเกมอัตโนมัติจาก Steam Libraries, ตรวจสอบสถานะว่าเกมปิดอยู่หรือไม่, คืนค่าไฟล์เดิมจากข้อมูลสำรอง และคงไฟล์ระบบ BepInEx ไว้อย่างปลอดภัย
- **ปรับปรุงโครงสร้างโปรเจกต์:**
  - เพิ่มการอ้างอิง `Assembly-CSharp`, `OdinSerializer`, และ `GamepadInput` ในโปรเจกต์ม็อด C# ทำให้สามารถควบคุม UI lifecycle ได้อย่างปลอดภัยและมีประสิทธิภาพสูงสุด

## 0.1.4-beta — 6 กันยายน 2026

รองรับ Security 51 Steam build `25104142`

- แก้ไขปัญหาเกมแครชตอนเปิดเกม `0xc00000fd` (Stack Overflow): ถอด Hook `LocalizationManager.InitializeIfNeeded` อย่างถาวรหลังพิสูจน์ด้วย Native Disassembly ว่า `CurrentLanguage` มีการเรียก `InitializeIfNeeded` ภายใน ทำให้เกิด Recursion วนลูปไม่รู้จบ
- ตรวจสอบสถานะภาษาอย่างปลอดภัยผ่าน raw backing field `mCurrentLanguage` โดยไม่กระตุ้นการทำงานของ `InitializeIfNeeded`
- ลด Overhead และขจัด Micro-stutter: ใช้ Pointer Tracking (`_configuredSourcePointers` และ `_configuredFontPointers`) จัดการเฉพาะ Source และ Font ที่เพิ่งโหลดใหม่ โดยไม่ต้องวนซ้ำ 3,481 รายการในฉากเดิม
- Pre-cache Glyph ภาษาไทยล่วงหน้า: บันทึกอักขระภาษาไทยทั้งช่วง Unicode (U+0E01–U+0E5B) พร้อมฟีเจอร์การจัดวรรณยุกต์ OpenType (`includeFontFeatures: true`) เข้า Dynamic Atlas ตั้งแต่โหลดเสร็จ ป้องกันการกระตุกระหว่างบทสนทนา
- ตัวกรอง placeholder แบบ Surgical & Non-destructive: ซ่อนเฉพาะข้อความ "Button" ที่ซ้อนทับปุ่มซึ่งมีป้ายข้อความแปลอยู่แล้ว และจะไม่แตะต้อง component ที่มี `I2.Loc.Localize` พร้อมคืนค่าการแสดงผลทันทีหากข้อความเปลี่ยนไปจากเดิม
- ปรับปรุงความปลอดภัยตัวติดตั้ง Single-Click: ทำ Pre-flight Validation (Hash ของไฟล์เกม, Steam build ID, BepInEx core, Package payload) ให้เสร็จสิ้นก่อนเริ่มถอนหรือแก้ไขไฟล์เดิม และมีระบบตรวจจับไฟล์เสียหายเพื่อซ่อมแซม (Auto-repair) อัตโนมัติ

## 0.1.3-beta — 6 กันยายน 2026


รองรับ Security 51 Steam build `25104142`

- แก้ไขปัญหาเกมหน่วง/กระตุกรุนแรง (Micro-stutter / Frame drop) ขณะโต้ตอบกับ NPC หรือกด Shift เพื่อคุย
- ถอด Hook `LocalizationManager.InitializeIfNeeded` ซึ่งถูกเรียกซ้ำทุกครั้งที่มีการดึงข้อความแปล
- เพิ่ม Guard flag ป้องกันการฉีดคำแปลและฟอนต์ซ้ำซ้อนใน Main Thread ทำให้รันเพียง 1 ครั้งในรอบเปิดเกม
- ตรวจสอบความพร้อมของ `LanguageSourceData` ก่อนทำงาน เพื่อลดภาระการวนลูป 3,481 รายการและการสแกน GameObject ในฉาก

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
