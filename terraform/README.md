# Terraform - AWS

Terraform, açık kaynak kodlu bir araçtır ve altyapıyı kod olarak tanımlamanızı sağlar. Terraform ile, bulut sağlayıcıları (örneğin, Amazon Web Services, Microsoft Azure, Google Cloud Platform, DigitalOcean) ve özel sanallaştırma platformları (örneğin, OpenStack, VMWare) gibi birçok farklı altyapıyı yönetebilirsiniz

Bu projede, AWS altyapısını kod tanımlamalarla oluşturuyoruz. Terrrafrom tanımlamalar yapıldıktan sonra geliştiriciler için çok hızlı aksiyon almayı sağlayan bir araç, AWS konsolu üzerinden yapacağım bir çok işlemi kod tabanında belirtip sonrasında bir kaç satırlık kod ile tüm altyapıyı yönetebileceğiniz bir sistem.

Proje isterlerine göre AWS üzerinde kullanacağımız tüm servisleri sıralayalım.
- VPC
- ECS Fargate
- Security Group
- Load Balancer
- CloudWatch
- Auto Scaling Service

Tüm bu servis ve hizmetleri terraform dokümanı ve diğer web kaynaklarından araştırarak ekleyebiliyoruz.

Bizden öncelikle AWS Cloud üzerinde bir alt yapı oluşturmamız isteniyor.
### AWS
AWS için gerekli sağlayıcıları ```provider.tf``` dosyamda belirtiyorum.
```tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.24.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
```
### VPC
Ardından AWS cloud üzerinde bir VPC(Virtual Private Cloud) oluşturmamız gerekiyor.
VPC, bulut kaynaklarınızın birbirleriyle, internetle ve şirket içi ağlarla güvenli bir şekilde iletişim kurmasını sağlayan hizmet.
Projemde kullanacağım VPC ağını uygulama sunucusu, public ve private subnetlerimi belirtiyorum bu subnetler daha sonrasında yayına alacağım react uygulamasını erişmi için alt yapıyı sağlayacak.
```tf
  name = "my-vpc-devops"
  cidr = "10.1.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

```
Avaibility Zones ```azs``` kısmında  her Availability Zone, birbirinden bağımsız bir veri merkezinde bulunur. Bu, bir Availability Zone’un etkilenmesi durumunda diğer Availability Zone’ların hizmet vermeye devam edebileceği anlamına gelir.  
Her Zone için public ve private altağları oluşturuyoruz ECS hizmeti bu ağlar üzerinde çalışacak.

### ECS Fargate
AWS Fargate, Amazon Web Services (AWS) tarafından sunulan bir konteyner çalıştırma hizmetidir. Fargate, kullanıcıların konteynerlerini yönetmek için bir sunucu havuzu oluşturmasına gerek kalmadan, konteynerleri doğrudan AWS üzerinde çalıştırmasına olanak tanır. Bu yaklaşım sunucusuz(serverless) olarak adlandırıyor. Projemizde bu şekilde deploy edebileceğimiz bir docker container'ı var bunu ECS Fargate üzerinde deploy edelim.

Bu Aşamada ```ecs.tf``` dosyasında bir ```aws_ecs_cluster``` oluşturuyoruz, Cluster ECS hizmetimizin çalışacağı bir küme oluşturacak.
Ardından ECS servisimizi tanımlıyoruz.
```tf
resource "aws_ecs_service" "ecs_service" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.logo_ecs_cluster.id
  task_definition = aws_ecs_task_definition.web_page_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [module.vpc.public_subnets[0], module.vpc.public_subnets[1], module.vpc.public_subnets[2]]
    security_groups  = [aws_security_group.default_sg.id]
    assign_public_ip = true
  }
```
Burada çalışacağı cluster'ın adını, başlangıçta çalışacak task sayısını, hizmet türünü ve bu servisin hangi ağ üzerinde dağıtılacağını seçiyoruz. Public subneti seçip fargate hizmetini internetten erişilebilir seçiyoruz.
Bu sayede uygulamamız erişilebilir olacak.
### Load Balancer
ECS servisi üzerinde bir çok task çalıştıracağımız için, kullanıcılardan gelen http sorgularını dinleyip gelen tüm yükü ağ üzerinde eşit dağıtılmasını amaçlayan Load Balancer(Yük Dengeleyici) hizmeti oluşturuyoruz.
Bu daha kararlı bir sunucu performansı sağlar.
```tf
resource "aws_lb_listener" "lb_http_listener" {
  load_balancer_arn = aws_lb.react_app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.load_balancer_tg.arn
  }
}
```
### Tasks
Load Balancer dan yönlendirilen isteklere karşılık verecek Task hizmetlerin tanımlamasını yapalım.
```tf
resource "aws_ecs_task_definition" "web_page_task" {
  family                   = "web-page-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "react-app-container",
    "image": "ysfdnz/logo-project:latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings" : [
        {
          "containerPort" : 80,
          "hostPort"      : 80,
          "protocol"      :"tcp"
        }
      ]
  }
]
TASK_DEFINITION

}
```
Burada oluşturulacak her bir task için gerekli donanım kaynağı, Container imajı, çalışacağı servis türü, belirtilir.
### CloudWatch
Bizden bu task görevleri takip etmemiz için aws üzerinde bir dashboard oluşturmamız istendi, bunuda terraform ```aws_cloudwatch_dashboard``` modülü kullanarak ```cw.tf``` dosyasında oluşturdum.

### Security Group
Bu aşamada bazı security group ayarları yapmamız gerekiyor, Son kullanıcıların public subnet üzerindeki task'lere ulaşması (siber güvenlik ve performans açısından) tehditdir . Örneğin tek bir task üzerine yük bindirilip uygulamanın istenmeyen hatalar vermesine sebep olunabilir. Bu yüzden çalışan task'lerin sadece load balancer'a hizmet vermesi ve load balancer'ın da tüm son kullanıcılara hizmet vermesi güvenli bir ağ hizmeti oluşturur. Bu bağlamda göstereceğim şekilde bir yapılandırma ile sunucu ve uygulama güvenliği artacaktır.

#### User --> Load Balancer --> Tasks  
şeklinde bir yapılandırma sağlar.
```tf
resource "aws_security_group" "default_sg" {
  name        = "default-sg"
  description = "All rules"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "port 80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["10.1.0.0/16"]
    security_groups = [aws_security_group.app_security.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "default-sg"
  }
}

resource "aws_security_group" "app_security" {
  name        = "app_security"
  description = "All rules"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app_security"
  }
}
```
### Auto Scale Policys
Uygulamamızın yoğun istekler sonucunda hizmetten düşmemesi önemli bir gereksinim, bunu ölçeklenebilir uygulamalar mantığıyla çalıştırmak için çeşitli modüller geliştiriliyor. Bu modeüllerden biriside ```aws_appautoscaling_policy``` hizmetidir.
AWS bunun için iki yöntem sunuyor;
Target Tracking Scaling Policies: Bu politika türü, belirli bir hedef metrik değerine göre ölçeklendirme yapar. Örneğin, CPU kullanımı veya ağ trafiği gibi bir metrik değerine göre ölçeklendirme yapabilirsiniz.

Step Scaling Policies: Bu politika türü, belirli bir CloudWatch alarmına yanıt olarak ölçeklendirme yapar. Örneğin, bir alarm tetiklendiğinde, ölçeklendirme işlemi belirli bir adımda gerçekleşir.

Projede bizden istenen scale yönteminde;
- Task lerin ortalama CPU kullanımı %50'yi aşarsa yukarı ölçekleme yapıp yeni taskler eklenip bu yoğunluğu azaltmak.
- Ortalama CPU kullanımı %20'nin altına düşerse bu durumda aşşağı yönlü ölçekleme yaparak belirli taskleri sonlandırıp sunucu maliyetini azaltmak.
Bu iki amaç doğrultusunda kompleks bir auto scaling işlemi istendiği için  AWS'nin Step Scale Policy yöntemini kullanmamız gerekir.

Öncelikle aws auto scale yapılandırmasını yapalım, min ve max capacity çalışacak task sayısının üst ve alt sınırlarını belirtir.
```tf
resource "aws_appautoscaling_target" "target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.logo_ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```
Step Scale Policy, belirttiğim üzere cloudwatch alarm'lar ile tetiklenen action'lar içeriyor. Örnek olarak alarm yapılandırmalarından birini aşşağıda belirtiyorum, tüm yapılandırmayı ```acss.tf``` içerisinde görebilirsiniz.
```tf
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = "20"
  alarm_description   = "Low cpu utilization alarm"
  alarm_actions       = [aws_appautoscaling_policy.scale_down.arn]

  metric_query {
    id          = "e1"
    expression  = "SELECT AVG(CPUUtilization)FROM SCHEMA(\"AWS/ECS\", ClusterName,ServiceName)"
    label       = "CPUUtilization (Expected)"
    return_data = "true"
    period      = "60"

  }

}
```
Bu yapılandırmada alt limit belirttim, eğer Tasklerin ortalama CPU kullanımı %20 nin altında kalırsa bir alarm oluşturacak, ardından alarm_actions kısmında tanımlı ```scale_down``` görevini gerçekleştirecek.
Bu alarm dakikada bir ölçüm yapıyor, bu hassasiyet istenilen ölçüde değiştirilebilir. Ben sonuçları hızlı görmek adına 1 dakikalık periyot tanımladım.

Alarmın tetiklemesi için ```scale_down``` action tanımlamıştık bununda yapılandırmasını açıklayalım.
```tf
resource "aws_appautoscaling_policy" "scale_down" {
  name               = "scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.target.resource_id
  scalable_dimension = aws_appautoscaling_target.target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}
```
Tanımlamadaki ```scaling_adjustment  = -1``` önemli bir detay, bu değerin negatif olması aşşağı yönlü ölçekleme yapılacağını yani belli sayıda task'in kapatılacağını belirtir. Tabiki ```scale_up``` için bu değer ```scaling_adjustment  = 1``` şeklinde pozitif olmalı.

### Terraform Commands
Proje isterlerine yönelik hizmet ve modüller ayarlandıktan sonra geriye kalan bunu uygulamaya almaktır. Öncelikle terraform dizininde bir initialize işlemi yapılmalı.
```
terraform init
```
Bu terraform kaynağını proje yoluna dahil eder.

```
terraform plan
```
Bu aşamada ```variable.tf``` belirtmediğim için benden aws hesabımın public ve private key'lerini istiyor.

![terra1](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/5a4eda5a-6160-4d4d-9221-127b7cb7c15e)

![terra2](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/cd7e31c1-6952-45e4-b652-d72bd77d37e2)

Bu komut ile tüm eklenecek hizmetler gözden geçirilir bu aşamada herhangi bir hata varsa düzeltilmeli.


Hata yoksa altyapıyı uygulamak için aşşağıdaki komut çalıştırılır ve tek bir komutla bir kaç dakika üzerinde tüm ağınız oluşturulur ve hizmete geçer. Terraform'un avantajı budur.
```
terraform apply
```
![terra3](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/70038f9f-5c7d-41d3-a89f-c64316102e31)

Komut sonrasında herhangi bir hata verilmediyse altyapımız hazır demektir.

VPC subnetin durumu bu şekilde. Her Availiblity Zone için public ve private alt ağlar oluşturuldu.
![terra4](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/53b8fc63-9aa4-4c08-b461-4014f5da7101)

Cluster ve Task başarıyla eklendiğini AWS Console üzerinden görebiliriz.
![terra5](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/ccc6e418-f5a9-462c-a90d-cc74d850b16a)

Sunucu metriklerini izleyebileceğimiz dashboard ekranı.
![terra6](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/c5efc191-6d7b-45c7-8cc4-5aa7146a32fa)

Task'lerin ip adresini güvenlik amacıyla dışardan erişime kapatmıştık. Bu şekilde ip adresine istek attığınızda erişim alamadığımızı teyit edebiliriz.
![terra7](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/260286ee-7e19-47c2-bc9d-f7e1a7d0c6d7)

Load Balancer public olarak erişilebilir durumda ve bu istediğimiz durum.
![terra8](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/5d6a5a49-2742-470a-9656-0a32f235c076)

Auto Scale için oluşturduğumuz CloudWatch alarmları bu şekilde. İki task ile başlayan sistemimiz düşük cpu load durumundan dolayı küçülmeye gitmiş ve sadece bir adet task çalışır tutuyor.

![terra9](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/771cb487-65a1-4a21-9188-c68e84f3e1c3)

Sunucuyu başlatmak kadar yok etmekte basit bir işlem. Aşşağıdaki komutla tüm sunucu ve hizmetler silinir.
```
terraform destroy
```
