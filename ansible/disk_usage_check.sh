#file path /home/scripts/disk_usage_check.sh
DISK_USAGE_ALERT=90
EMAIL="ysfdnz.exe@gmail.com"
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt $DISK_USAGE_ALERT ]; then
    echo "Disk usage is above $DISK_USAGE_ALERT%. Sending email to $EMAIL."
    echo "Disk usage is at ${USAGE}%!" | mail -s "Disk Usage Alert" $EMAIL
else
    echo "Disk usage is at ${USAGE}%. No need to send email."
fi