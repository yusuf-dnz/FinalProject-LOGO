# React App & Gitlab CI/CD

- React web uygulaması oluştur.
- Dockerfile oluştur
- Uygulamayı minimum boyutlarda tutarak image oluştur
- GitLab CI/CD pipeline oluştur

React projesi oluşturmak.
```
npx create-react-app react-app
```
Proje üzerinde çok değişiklik yapmadan projenin dockerize yapılandırmasını ```Dockerfile``` dosyasında oluşturalım.

İstenilen dockerize işleminde docker container içerisine alınmasını istemediğimiz dosya ve klasörleri ```.dockerignore``` dosyası oluşturup burada belirtiyoruz. Bu, Docker imajının boyutunu küçültmeye, oluşturma süresini hızlandırmaya ve potansiyel olarak hassas verilerin imaja dahil edilmesini önlemeye yardımcı olur.

```Dockerfile
#Build aşaması
FROM node:14 AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

#Run aşaması
FROM nginx:1.19.0-alpine AS run
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80 80
CMD ["nginx", "-g", "daemon off;"]
```
Build aşaması için öncelikle ```FROM``` ile node.js image'i  seçiyoruz. çalışma dizinini ```WORKDIR``` ile belirtip, bu konuma package.json ı kopyalayıp proje bağımlılıklarını RUN npm install komutu ile yülenmesini sağladık bu şekilde projenin derlenmiş halini ```RUN npm run build``` çalıştırarak oluşturduk. Proje dizininde build klasörü oluştuktan sonra uygulamayı docker image haline getiriyoruz. Uygulamanız bir NGINX web sunucu image içerisinde çalışacak. ```COPY --from=build /app/build /usr/share/nginx/html```  komutu, önceki aşamada oluşturulan /app/build dizinindeki dosyaları Nginx’in varsayılan kök dizinine (/usr/share/nginx/html) kopyalar. ```EXPOSE 80 80```  ile containerın 80 portuna gelen istekleri içerde 80 portuna yönlendirir.
```CMD ["nginx", "-g", "daemon off;"]```  komutu Nginx'i başlatır.

Dockerfile dosyası dizininde bu komut çalıştırılır.
```docker build -t ysfdnz/logo-project:latest```

![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/27479523-472c-456c-b7f6-9ff3c56384cb)

Yaklaşık 20MB boyutundaki react imajımız oluşturuldu. Konteynerı kendi bilgisayarımda çalıştırıp uygulamamı ```localhost``` adresinde görebilirim.
```
docker run -p 80:80 ysfdnz/logo-project:latest
```
![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/abd59cb3-892c-48ad-bbc2-c033e8ba00f5)

