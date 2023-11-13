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

![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/27479523-472c-456c-b7f6-9ff3c56384cb)

Yaklaşık 20MB boyutundaki react imajımız oluşturuldu. Konteynerı kendi bilgisayarımda çalıştırıp uygulamamı ```localhost``` adresinde görebilirim.
```
docker run -p 80:80 ysfdnz/logo-project:latest
```
![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/abd59cb3-892c-48ad-bbc2-c033e8ba00f5)

### GitLab CI/CD Pipeline
CI/CD süreci yazılım ve sistemin güncel kalması için çok önemli bir süreçtir. Bu süreçleri otomasyona oturmak için belli araçlar vardır. Bu projemde GitLab kullanarak bir pipeline oluşturacağım. bu sayede yaptığım değişiklikleri basit bir commit işlemi ile canlı sistemime aktarabileceğim.

React uygulama dizinimde bir gitlab reposu oluşturup projemin dosyalarını gitlab da depoladım.
![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/7db560cd-44b3-40c1-8551-780a5166f975)

Bu şekilde gerekli dizinler repoya gönderildikten sonra ```.gitlab-ci.yml``` oluşturulması isteniyor.
Pipeline için gerekli adım ve tanımlamalar bu dosyada oluşturulacak.

Runner üzerinde kullanılacak keyler güvenlik nedeniyle GitLab CI/CD variables kısmında tanımlanır.
![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/1c3acf4b-7d85-45b0-8c7d-21a9a20addea)


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

![Ekran görüntüsü 2023-11-14 000211](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/84adf2e0-b02d-4d37-9366-e4e91e1e1c0c)

Uygulamamız Rolling Update yöntemiyle yeni sürümü deploy edildi.

![Ekran görüntüsü 2023-11-13 235926](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/61446d26-b841-4ef7-a725-fe01a8527e40)
