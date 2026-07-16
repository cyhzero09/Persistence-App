@echo off
REM Run this file AS ADMINISTRATOR to allow phone access
REM Find your Windows IP with: ipconfig
REM Then on phone browser open: http://YOUR_WINDOWS_IP:8080

netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=172.25.155.120
netsh advfirewall firewall add rule name="Flutter Dev" dir=in action=allow protocol=TCP localport=8080
echo Done! You can now access from your phone at http://<Windows IP>:8080
pause
