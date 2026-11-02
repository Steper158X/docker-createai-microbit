# CreateAI (micro:bit ml-trainer) — Docker แบบ offline

[English](README.md)

Image นี้ใช้งานได้โดย**ไม่ต้องต่ออินเทอร์เน็ต** ข้างในมีแอป CreateAI
([microbit-foundation/ml-trainer](https://github.com/microbit-foundation/ml-trainer))
และ **MakeCode for micro:bit** ที่ host เอง พร้อม extension machine-learning ฝังมาในตัว
ต้องใช้อินเทอร์เน็ตเฉพาะตอน build เท่านั้น

```bash
docker compose up -d --build      # build ครั้งแรกใช้เวลาประมาณ 10-15 นาที
```

เปิด http://localhost:8090 บนเครื่องนี้ (MakeCode อยู่ที่ `/makecode/`) ส่วนเครื่องอื่นในวงแลนต้องเปิดผ่าน
ที่อยู่ HTTPS จึงจะใช้ WebUSB / Web Bluetooth ได้ ดูหัวข้อ [WebUSB (HTTPS)](#webusb-https)

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
docker run -d -p 8090:80 -p 8443:443 -e CREATEAI_TLS_HOSTS=192.168.1.10 \
  -v createai-tls:/tls --restart unless-stopped createai-microbit:offline
```

## หลักการทำงาน

| Stage | หน้าที่ |
| --- | --- |
| `makecode` | สคริปต์ [makecode/build-makecode.sh](makecode/build-makecode.sh) build `pxt-microbit` ด้วยคำสั่ง `pxt staticpkg` แล้วฝัง `pxt-microbit-ml` และ `pxt-microbit-ml-runner` เป็น bundled package แทนการดึง extension จาก GitHub นอกจากนี้ยังสร้าง template `createaiprj` เพื่อให้ส่วน C++ (native image) ของโปรเจกต์ CreateAI ถูก compile ไว้ใน `hexcache/` ตั้งแต่ตอน build และปิด telemetry ของ MakeCode |
| `app` | Build ml-trainer โดยใส่ [patches/ml-trainer-self-hosted-makecode.patch](patches/ml-trainer-self-hosted-makecode.patch) ซึ่งเพิ่มค่า `VITE_MAKECODE_URL`, `VITE_MAKECODE_RENDER_BLOCKS_URL` และ `VITE_MAKECODE_ML_EXTENSION` (ไม่ตั้งค่า = ทำงานแบบเดิม) แล้วตัด script cookie/analytics ของ microbit.org ออก |
| runtime | nginx เสิร์ฟแอปที่ `/` และ MakeCode ที่ `/makecode/` ทั้ง HTTP (80) และ HTTPS (443) โดยสคริปต์ [docker/40-createai-tls.sh](docker/40-createai-tls.sh) เตรียม cert ให้ตอน container เริ่ม ถ้าหาไฟล์ hex ไม่เจอจะตอบ 404 ตรง ๆ ไม่ส่ง index.html กลับไปแทน |

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

## WebUSB (HTTPS)

เบราว์เซอร์อนุญาต WebUSB และ Web Bluetooth เฉพาะ `https://` หรือ `localhost` เพื่อให้เครื่องอื่น
เชื่อมต่อและ flash micro:bit จากเบราว์เซอร์ได้โดยตรง container จะเสิร์ฟ HTTPS เพิ่มที่พอร์ต 8443 ด้วย cert ที่สร้างขึ้นเอง

1. ใส่ IP ของเครื่อง host ใน `docker-compose.yml` (ใส่ชื่อเครื่องเพิ่มได้ คั่นด้วยจุลภาค) แล้วเปิด container

   ```yaml
   environment:
     CREATEAI_TLS_HOSTS: "192.168.1.10"
   ```

   ```bash
   docker compose up -d
   ```

2. บนเครื่องลูกข่ายแต่ละเครื่อง ติดตั้ง CA ครั้งเดียว: เปิด **http://&lt;IP เครื่อง host&gt;:8090/rootCA.crt**
   เปิดไฟล์ที่ดาวน์โหลดมา กด **Install Certificate** แล้วเลือกเก็บใน "Trusted Root Certification Authorities"
   หรือใช้คำสั่ง (ไม่ต้องเป็น admin)

   ```bash
   certutil -user -addstore Root rootCA.crt
   ```

3. เปิด **https://&lt;IP เครื่อง host&gt;:8443** ใน Chrome หรือ Edge แล้วเชื่อมต่อ micro:bit

การทำงาน
- ตอนเริ่มครั้งแรก container จะสร้าง CA ของตัวเองเก็บไว้ใน volume `createai-tls` แล้วออก cert ของ server ให้
  `localhost` และ host ใน `CREATEAI_TLS_HOSTS` และจะออกใบใหม่เองเมื่อ host เปลี่ยนหรือใกล้หมดอายุ
- CA นี้ออก cert ได้เฉพาะ IP ภายใน (`10.x`, `172.16-31.x`, `192.168.x`, `127.x`) และชื่อที่ลงท้ายด้วย
  `.local`, `.lan`, `.home.arpa` หรือ `.internal` ต่อให้ key หลุดก็ปลอมเป็นเว็บไซต์สาธารณะไม่ได้
  host อื่นใน `CREATEAI_TLS_HOSTS` จะถูกข้ามพร้อมคำเตือน
- เสิร์ฟเฉพาะ cert สาธารณะของ CA ค่า fingerprint SHA-256 แสดงใน `docker compose logs` ใช้เทียบกับตอนติดตั้งได้
- เปลี่ยน IP ใน `CREATEAI_TLS_HOSTS` ไม่ต้องติดตั้ง CA ใหม่ แต่ถ้าลบ volume (`docker compose down -v`)
  จะได้ CA ใหม่ และทุกเครื่องต้องติดตั้งใหม่
- ควรจอง IP ของเครื่อง host ไว้ที่ router (DHCP reservation) เพื่อไม่ให้ IP เปลี่ยน
- เปิดพอร์ต 8090 และ 8443 ใน firewall ของเครื่อง host ด้วย
- ถ้าต้องการใช้ cert ของตัวเอง (เช่นจาก mkcert) ให้ mount โฟลเดอร์ที่มี `cert.pem` และ `key.pem` ไปที่ `/certs`
  เช่นเอาคอมเมนต์หน้า `- ./certs:/certs:ro` ใน `volumes` ออก
- ไม่มีระบบยืนยันตัวตน ให้ใช้เฉพาะในวงแลน ห้ามเปิดพอร์ตเหล่านี้สู่อินเทอร์เน็ต

## ข้อจำกัดเมื่อใช้งาน offline

- ลิงก์ไปเว็บ microbit.org (Project ideas, บทเรียน, คู่มือ, support) ต้องใช้อินเทอร์เน็ต
- ใน MakeCode ใช้ได้เฉพาะ extension ที่ฝังไว้ ถ้าเพิ่ม extension อื่นจาก GitHub หรือ extension ที่มี C++
  นอกเหนือจาก core/radio/microphone/machine-learning จะต้องใช้ cloud compiler
  ส่วนการแชร์โปรเจกต์และการเปิดลิงก์แชร์ก็ต้องใช้อินเทอร์เน็ตเช่นกัน
- ถ้าเลือกภาษาอื่นนอกจากอังกฤษ MakeCode อาจแสดงเป็นภาษาอังกฤษ เพราะไม่ได้ฝังไฟล์แปลภาษามาด้วย
- เป็น build แบบ open-source ที่ไม่มีแบรนด์ micro:bit เพราะ theme package ของแบรนด์เป็น package ส่วนตัว
