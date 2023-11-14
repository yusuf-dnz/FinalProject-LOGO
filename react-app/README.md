# React App & Gitlab CI/CD

- React web uygulaması oluştur.
- Dockerfile oluştur
- Uygulamayı minimum boyutlarda tutarak image oluştur
- GitLab CI/CD pipeline oluştur

### React Project.
```
npx create-react-app react-app
```
Proje üzerinde çok değişiklik yapmadan projenin dockerize yapılandırmasını ```Dockerfile``` dosyasında oluşturalım.

İstenilen dockerize işleminde docker container içerisine alınmasını istemediğimiz dosya ve klasörleri ```.dockerignore``` dosyası oluşturup burada belirtiyoruz. Bu, Docker imajının boyutunu küçültmeye, oluşturma süresini hızlandırmaya ve potansiyel olarak hassas verilerin imaja dahil edilmesini önlemeye yardımcı olur.

### Dockerfile
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

### Image Build
Dockerfile dosyası dizininde bu komut çalıştırılır.
```docker build -t ysfdnz/logo-project:latest```

![react1](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/94618832-c906-4fdb-abc7-b9e5746554a4)

Yaklaşık 20MB boyutundaki react imajımız oluşturuldu. Konteynerı kendi bilgisayarımda çalıştırıp uygulamamı ```localhost``` adresinde görebilirim.
```
docker run -p 80:80 ysfdnz/logo-project:latest
```
![react2](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/5f53a953-063c-4285-8aa2-5eba21329868)

### GitLab CI/CD Pipeline
CI/CD süreci yazılım ve sistemin güncel kalması için çok önemli bir süreçtir. Bu süreçleri otomasyona oturmak için belli araçlar vardır. Bu projemde GitLab kullanarak bir pipeline oluşturacağım. bu sayede yaptığım değişiklikleri basit bir commit işlemi ile canlı sistemime aktarabileceğim.

React uygulama dizinimde bir gitlab reposu oluşturup projemin dosyalarını gitlab da depoladım.
![react3](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/fc62d649-d6c3-4faf-a09d-de30c6f2f8ba)

Bu şekilde gerekli dizinler repoya gönderildikten sonra ```.gitlab-ci.yml``` oluşturulması isteniyor.
Pipeline için gerekli adım ve tanımlamalar bu dosyada oluşturulacak.

Runner üzerinde kullanılacak keyler güvenlik nedeniyle GitLab CI/CD variables kısmında tanımlanır.
![react4](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/f9f2cbad-fe8f-460d-bc8f-42ba3b778961)


```yml
image: docker

stages:
  - build
  - deploy

variables:
  DOCKER_IMAGE: ysfdnz/logo-project:latest
  AWS_REGION: eu-central-1
  CLUSTER_NAME: tf-logo-devops
  SERVICE_NAME: ecs-service
services:
  - docker:dind
build:
  stage: build
  script:
    - echo $DOCKER_HUB_PASS | docker login --username $DOCKER_HUB_USER --password-stdin
    - echo "Building Docker image..."
    - docker build -t $DOCKER_IMAGE .
    - echo "Pushing Docker image to your Docker registry..."
    - docker push $DOCKER_IMAGE

deploy:
  stage: deploy
  script:
    - apk add --no-cache curl python3 py3-pip
    - pip install awscli
    - echo "Deploying to AWS..."
    - aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    - aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    - aws configure set default.region $AWS_REGION
    - echo "Deploying to AWS ECS Fargate..."
    - aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment

```
GitLab üzerindeki pipeline'ım bu şekilde, GitLab'a ait runner ile bu aşamaları tek tek gerçekleştirip uygulamamın CI/CD
döngüsünü tamamladım.

Pipeline da iki stage tanımladım;
#### Build
bu aşamada projemde yaptığım değişikliklerin (örn: Yeni ana menü butonu) commit işlemi sonrası derlenerek yeni imajımın oluşturulmasını içeriyor. Öncelikle docker hub girişi yapıp ```docker build ``` komutunun çalıştırılmasını sağladım. Ardından daha sonra kullanabilmek için docker hub üzerine yeni imajımı gönderiyoruz. 
#### Deploy
Uygulamamın deploy edilmiş olduğu sunucu servisi (AWS) üzerinde yeni güncellemenin deploy edilmesi adımlarını içeriyor. Bu adımda aws komutlarını işleyebilmem için awscli paketini yüklüyorum. Key ve region konfigürasyonu sonrasında ```aws ecs update-service``` komutu ile yeni uygulama imajımı ECS servisi üzerinde yayınlıyorum. Bu aşamada varsayılan olarak "Rolling Update" işlemi başlıyor. Bu işlem eski sürüme ait çalışan task'lerin birer birer kapatılıp yerine yeni oluşturulan güncel task'lerin geçmesini sağlar. Tüm task'ler güncel haliyle değiştikten sonra işlem başarıyla tamamlanır.

![react5](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/e3764136-00d3-4aaa-9cd6-d0ee7b7777df)

Uygulamamız Rolling Update yöntemiyle yeni sürümü deploy edildi.

![react6](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/5682f9de-ffcc-42a0-a629-b5895114ffcb)
