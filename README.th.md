# CreateAI (micro:bit ml-trainer) — Docker แบบ offline

[English](README.md)

Image นี้ใช้งานได้โดย**ไม่ต้องต่ออินเทอร์เน็ต** ข้างในมีแอป CreateAI
([microbit-foundation/ml-trainer](https://github.com/microbit-foundation/ml-trainer))
และ **MakeCode for micro:bit** ที่ host เอง พร้อม extension machine-learning ฝังมาในตัว
ต้องใช้อินเทอร์เน็ตเฉพาะตอน build เท่านั้น

```bash
docker compose up -d --build      # build ครั้งแรกใช้เวลาประมาณ 10-15 นาที
```

เปิดที่ http://localhost:8090 (MakeCode อยู่ที่ `/makecode/`)

## ย้ายไปใช้บนเครื่องที่ไม่มีอินเทอร์เน็ต

บนเครื่องที่ build ให้ export image เป็นไฟล์:

```bash
docker save createai-microbit:offline -o createai-offline.tar
```

คัดลอกไฟล์ `createai-offline.tar` ไปที่เครื่องปลายทาง แล้วรัน:

```bash
docker load -i createai-offline.tar
```

```bash
docker run -d -p 8090:80 --restart unless-stopped createai-microbit:offline
```

## หลักการทำงาน

| Stage | หน้าที่ |
| --- | --- |
| `makecode` | สคริปต์ [makecode/build-makecode.sh](makecode/build-makecode.sh) build `pxt-microbit` ด้วยคำสั่ง `pxt staticpkg` แล้วฝัง `pxt-microbit-ml` และ `pxt-microbit-ml-runner` เป็น bundled package แทนการดึง extension จาก GitHub นอกจากนี้ยังสร้าง template `createaiprj` เพื่อให้ส่วน C++ (native image) ของโปรเจกต์ CreateAI ถูก compile ไว้ใน `hexcache/` ตั้งแต่ตอน build และปิด telemetry ของ MakeCode |
| `app` | Build ml-trainer โดยใส่ [patches/ml-trainer-self-hosted-makecode.patch](patches/ml-trainer-self-hosted-makecode.patch) ซึ่งเพิ่มค่า `VITE_MAKECODE_URL`, `VITE_MAKECODE_RENDER_BLOCKS_URL` และ `VITE_MAKECODE_ML_EXTENSION` (ไม่ตั้งค่า = ทำงานแบบเดิม) แล้วตัด script cookie/analytics ของ microbit.org ออก |
| runtime | nginx เสิร์ฟแอปที่ `/` และ MakeCode ที่ `/makecode/` ถ้าหาไฟล์ hex ไม่เจอจะตอบ 404 ตรง ๆ ไม่ส่ง index.html กลับไปแทน |

## Build args

| Arg | ค่าเริ่มต้น | ใช้ทำอะไร |
| --- | --- | --- |
| `GIT_REF` | `main` | branch/tag/commit ของ ml-trainer |
| `GIT_REPO` | repo ต้นทาง | ใช้ build จาก fork |
| `BASE_URL` | `/` | ใช้เมื่อเสิร์ฟใต้ sub-path หลัง reverse proxy เช่น `/createai/` (ต้องมี `/` ปิดท้าย) |
| `PXT_MICROBIT_REF` | `v9.0.12` | เวอร์ชัน MakeCode for micro:bit (stable) |
| `ML_EXT_REF` / `ML_RUNNER_REF` | `v1.0.16` / `v0.4.8` | ต้องตรงกับเวอร์ชัน extension ที่ ml-trainer ใช้ (ดูใน `src/makecode/utils.ts`) |

ถ้าเปลี่ยน `GIT_REF` แล้ว ml-trainer เวอร์ชันนั้นใช้ extension ML ตัวใหม่กว่า
ให้ปรับ `ML_EXT_REF` ให้ตรง และปรับ `ML_RUNNER_REF` ตามเวอร์ชันที่ระบุใน `pxt.json` ของ extension นั้น

## ข้อจำกัดเมื่อใช้งาน offline

- ลิงก์ไปเว็บ microbit.org (Project ideas, บทเรียน, คู่มือ, support) ต้องใช้อินเทอร์เน็ต
- ใน MakeCode ใช้ได้เฉพาะ extension ที่ฝังไว้ ถ้าเพิ่ม extension อื่นจาก GitHub หรือ extension ที่มี C++
  นอกเหนือจาก core/radio/microphone/machine-learning จะต้องใช้ cloud compiler
  ส่วนการแชร์โปรเจกต์และการเปิดลิงก์แชร์ก็ต้องใช้อินเทอร์เน็ตเช่นกัน
- ถ้าเลือกภาษาอื่นนอกจากอังกฤษ MakeCode อาจแสดงเป็นภาษาอังกฤษ เพราะไม่ได้ฝังไฟล์แปลภาษามาด้วย
- การเชื่อมต่อ micro:bit ผ่าน WebUSB/Web Bluetooth ต้องเปิดใน secure context คือเปิดผ่าน `localhost`
  หรือเสิร์ฟผ่าน HTTPS ถ้าใช้ใน LAN ห้องเรียน ให้วาง reverse proxy ที่มี certificate ไว้ข้างหน้า
- เป็น build แบบ open-source ที่ไม่มีแบรนด์ micro:bit เพราะ theme package ของแบรนด์เป็น package ส่วนตัว
