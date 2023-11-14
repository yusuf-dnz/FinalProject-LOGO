# Kubernetes
Kubernetes, container’ların kullanılabilirliğini ve verimli bir şekilde devreye alınmasını sağlamak için ekosistemi yönetir.
### React App Deploy To Kubernetes
Kubernetes pods lar içerisinde izole edilmiş konteynerler çalıştırır ve bu konteynerlerin yönetimini kolaylaştırır.

Örnek olarak oluşturduğumuz react-app imajı için deployment yazalım.
```deployment_react_app.yaml```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: react-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: react-app
  template:
    metadata:
      labels:
        app: react-app
    spec:
      containers:
        - name: react-app
          imagePullPolicy: IfNotPresent
          image: ysfdnz/logo-project:latest

          ports:
            - containerPort: 80
```
Bu yapılandrıma ile 2 replica ayağa kaldırılacak ve hizmet verecektir.
Komut ile deploy edilir.
```
kubectl apply -f deployment_react_app.yaml
```
![kubernetes1](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/0f916dc9-f48b-4355-b791-071edc99b682)

### Load Balancer Kubernetes
Pod'lar arasında kullanıcı veya sistem isteklerini eşit olarak tüm replica'lara dağıtmak için LoadBalancer servisleri kullanılır bu konteynerların güvenliği ve performansı açısından önemlidir.
```loadbalancer-react-app.yaml```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: load-balancer-service
spec:
  selector:
    app: react-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```
```localhost:80``` portunu public olarak yerel sunucumda açıyorum böylece uygulamam erişilebilir oluyor.
```
kubectl apply -f deployment_react_app.yaml
```
![kubernetes2](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/c0dce0da-b478-4995-9052-ca6daff91b83)

### App Scale (Uygulama Ölçekleme)
Kubernetes'de app scale için iki yöntem vardır, Horizontal(Yatay) ölçekleme ve Vertical(Dikey) ölçekleme bu yöntemler arasında temelde farklar vardır.
- HPA: Uygulamaları yatay ölçekler, istek ve erişim talebine göre Pod sayısını artırmayı veya azaltmayı sağlar.
- VPA: Uygulamaları dikey ölçekler, istek ve erişim talebine göre Pod lara ait donanımsal ve kaynak gereksinimleri açısından pod'u besleyerek ölçekleme sağlar.

HPA örneği yapalım;

#### Manuel Scale
Manuel ölçeklemede bir komut kullanarak replica(pod) sayımızı artırıp veya azaltıp uygulamamızı ölçekleyebiliriz.
```shell
kubectl scale deployment react-app --replicas=5
````
#### Auto Scale
Otomatik ölçeklemede herhangi bir koşul belirtilir ve bu koşul sağlandığı süreçte bu servis kendi aksiyonlarını alır ve pod sayısını günceller.
Aşşağıdaki örnekte CPU yükünün %50'yi geçmesi ile yukarı yönlü altında kalması ile aşşağı yönlü ölçekleme yapan bir servis oluşturuldu.
```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-react-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: react-app
  minReplicas: 1
  maxReplicas: 6
  targetCPUUtilizationPercentage: 50
```
Komut ile bu servis eklenir ve uygulamamız CPU yüküne göre 1-6 arası pod ile hizmet vermeye devam eder.
```shell
kubectl apply -f hpa-react-app.yaml
````
Auto Scale servisinin testi için çeşitli benchmark araçları kullanılabiliyor.
