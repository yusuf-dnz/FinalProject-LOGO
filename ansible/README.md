# Ansible & Shell script
linux dağıtımı olan bir sistemde periyodik olarak çalışan uyarı script'i oluşturmamız istendi.
- Script belirli aralıklarla disk kullanımını kontrol edecek.
- Disk kullanımının %90'ı aşması durumunda hedef email adresine bir uyarı maili gönderecek.

#### Gerekli paketler
 Ansible-Playbook:  Tekrarlanabilir, yeniden kullanılabilir, basit bir yapılandırma yönetimi ve karmaşık uygulamaları ortamlara dağıtmak için yazılan talimat listesidir.
```Shell
apt-get install ansible-core
```
 SSMTP, SMTP protokolünü kullanarak e-posta iletimi sağlayan basit bir posta aktarıcı programıdır. 
```Shell
apt-get install ssmtp
```
```Shell
apt-get install mailutils
```
Disk kullanımı kontrol etmesi için ```disk_usage_check.sh``` adında bir shell dosyası oluşturalım.

```Shell
DISK_USAGE_ALERT=90
EMAIL="ysfdnz.exe@gmail.com"
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt $DISK_USAGE_ALERT ]; then
    echo "Disk usage is above $DISK_USAGE_ALERT%. Sending email to $EMAIL."
    echo "Disk usage is at ${USAGE}%!" | mail -s "Disk Usage Alert" $EMAIL
else
    echo "Disk usage is at ${USAGE}%. No need to send email."
fi
```
Shell scriptde üç değişken oluşturup if bloğu içerisinde kontrol sağlayıp buna göre aksiyon alınmasını sağladı.
DISK_USAGE_ALERT: Uyarı vermesi gereken disk doluluk oranı.
EMAIL: Hedef mail adresimiz.
USAGE: Diskin çalışma zamanındaki doluluk oranı.

USAGE içerisine bu şekilde bir değer atılıyor.

![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/8294b634-2c5f-44c1-a9be-8fbe807b0193)

Bu script'in periyodik olarak çalışması gerekiyor, ansible-playbook  kullanarak cron ile bir görev atayacağız ve bu script disk belirli aralıklarla çalışacak.
```disk usage_playbook.yml``` dosyasını yapılandırmak.
```
- hosts: all
  gather_facts: no
  tasks:
    - name: Run disk usage script every 2 hours
      cron:
        name: Check disk usage
        hour: "*/2"
        job: "/home/scripts/disk_usage_check.sh"
```
Bu yapılandırma dosyasında tasks kısmında görev tanımlıyoruz. Name e görev açıklamasını yazıp, cron ile görev adını periyodunu ve görevi yapan shell komutunun dosya yolunu belirtiyoruz. Görev in eklenmesi için 
```
ansible-playbook disk_usage_playbook.yml
```
![image](https://github.com/yusuf-dnz/FinalProject-LOGO/assets/101550162/6fc8853e-936c-4129-a2be-97e549007f7b)
Kendi makinemdeki linux dağıtımına bu görevi ekledim, çıktısı yukarıdaki şekilde.

Mail gönderimi için ```/etc/ssmtp/ssmtp.conf``` dosyası içerisine smtp de kullanılacak mail adresi mail sunucusu user ve password bilgilerinin tanımlanması gerekiyor.
```
root=*****
mailhub=*****
hostname=*****
AuthUser=*****
AuthPass=*****
FromLineOverride=*****
UseSTARTTLS=*****
```
Bu .conf dosyası bu şekilde düzenlenmesi gerekir.

Projemdeki kullanım için dosyalara göz atabilirsiniz.
