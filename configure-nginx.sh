#!/bin/bash

#tải xuống configure-linux.sh
echo "THÔNG TIN: Đang tải các phụ thuộc - configure-linux.sh"
curl -s -o configure-linux.sh https://www.loggly.com/install/configure-linux.sh
source configure-linux.sh "being-invoked"

##########  Khai báo biến - Bắt đầu  ##########
#tên của script hiện tại
SCRIPT_NAME=configure-nginx.sh
#phiên bản của script hiện tại
SCRIPT_VERSION=1.5

#chưa tìm thấy phiên bản nginx tại thời điểm này trong script
APP_TAG="\"nginx-version\":\"\""

#tên dịch vụ, ở đây là nginx
SERVICE="nginx"
#tên file log truy cập của nginx
NGINX_ACCESS_LOG_FILE="access.log"
#tên file log lỗi của nginx
NGINX_ERROR_LOG_FILE="error.log"
#tên và vị trí file syslog của nginx
NGINX_SYSLOG_CONFFILE=$RSYSLOG_ETCDIR_CONF/21-nginx.conf
#tên và vị trí file backup syslog của nginx
NGINX_SYSLOG_CONFFILE_BACKUP=$RSYSLOG_ETCDIR_CONF/21-nginx.conf.loggly.bk

#biến này sẽ lưu đường dẫn đến thư mục home của nginx
LOGGLY_NGINX_HOME=
#biến này sẽ lưu giá trị thư mục log của nginx
LOGGLY_NGINX_LOG_HOME=
#biến này sẽ lưu phiên bản nginx của người dùng
NGINX_VERSION=

HƯỚNG_DẪN_CẤU_HÌNH_THỦ_CÔNG="Hướng dẫn cấu hình thủ công nginx có tại https://www.loggly.com/docs/nginx-server-logs#manual. Hướng dẫn khắc phục sự cố Rsyslog tại https://www.loggly.com/docs/rsyslog-troubleshooting/."

#biến này sẽ xác định đã kiểm tra môi trường linux hay chưa
NGINX_ENV_VALIDATED="false"

#apache là tag gửi kèm log
LOGGLY_FILE_TAG="nginx"

#thêm tag vào log
TAG=

TLS_SENDING="true"

##########  Khai báo biến - Kết thúc  ##########

#kiểm tra môi trường nginx có tương thích với Loggly không
kiemTraTuongThichNginxLoggly() {
  #kiểm tra môi trường linux có tương thích với Loggly không
  checkLinuxLogglyCompatibility

  #kiểm tra nginx đã được cài đặt trên hệ thống unix chưa
  kiemTraChiTietNginx

  NGINX_ENV_VALIDATED="true"
}

# thực thi script để cài đặt và cấu hình syslog cho loggly.
caiDatCauHinhLogglyChoNginx() {
  #ghi log thông báo bắt đầu cấu hình Loggly cho Nginx
  logMsgToConfigSysLog "INFO" "THÔNG TIN: Bắt đầu cấu hình Loggly cho Nginx."

  #kiểm tra môi trường nginx có tương thích với Loggly không
  if [ "$NGINX_ENV_VALIDATED" = "false" ]; then
    kiemTraTuongThichNginxLoggly
  fi

  #cấu hình loggly cho Linux
  installLogglyConf

  #nhiều tag
  themTagVaoCauHinh

  #tạo file 21nginx.conf
  ghiFile21NginxConf

  #kiểm tra kích thước file log nginx
  kiemTraKichThuocFileLog $LOGGLY_NGINX_LOG_HOME/$NGINX_ACCESS_LOG_FILE $LOGGLY_NGINX_LOG_HOME/$NGINX_ERROR_LOG_FILE

  #kiểm tra log nginx đã gửi lên loggly chưa
  kiemTraLogNginxDaGuiLenLoggly

  #ghi log thành công
  logMsgToConfigSysLog "SUCCESS" "THÀNH CÔNG: Đã cấu hình thành công Nginx gửi log lên Loggly."
}

#thực thi script để gỡ cấu hình loggly cho Nginx
goCauHinhLogglyChoNginx() {
  logMsgToConfigSysLog "INFO" "THÔNG TIN: Bắt đầu hoàn tác."

  #kiểm tra quyền root để chạy script này
  checkIfUserHasRootPrivileges

  #kiểm tra hệ điều hành có được hỗ trợ không. Nếu không thì thoát
  checkIfSupportedOS

  #kiểm tra nginx đã được cài đặt trên hệ thống unix chưa
  kiemTraChiTietNginx

  #gỡ file 21nginx.conf
  xoaFile21NginxConf

  logMsgToConfigSysLog "INFO" "THÔNG TIN: Đã hoàn tất hoàn tác."
}

#xác định nginx đã được cài đặt và hoạt động như một dịch vụ chưa
kiemTraChiTietNginx() {
  #kiểm tra nginx được cài đặt như dịch vụ
  if [ -f /etc/init.d/$SERVICE ]; then
    logMsgToConfigSysLog "INFO" "THÔNG TIN: Nginx đã được cài đặt như một dịch vụ."
  elif [[ $(which systemctl) && $(systemctl list-unit-files $SERVICE.service | grep "$SERVICE.service") ]] &>/dev/null; then
    logMsgToConfigSysLog "INFO" "THÔNG TIN: Nginx đã được cài đặt như một dịch vụ."
  else
    logMsgToConfigSysLog "ERROR" "LỖI: Nginx chưa được cấu hình như một dịch vụ"
    exit 1
  fi

  #lấy phiên bản nginx đã cài đặt
  layPhienBanNginx

  #thiết lập các biến nginx cần thiết cho script này
  thietLapBienNginx
}

#thiết lập biến nginx dùng ở nhiều hàm khác nhau
thietLapBienNginx() {
  LOGGLY_NGINX_LOG_HOME=/var/log/$SERVICE
}

#lấy phiên bản nginx đã cài đặt trên máy unix
layPhienBanNginx() {
  NGINX_VERSION=$(nginx -v 2>&1)
  NGINX_VERSION=${NGINX_VERSION#*/}
  APP_TAG="\"nginx-version\":\"$NGINX_VERSION\""
  logMsgToConfigSysLog "INFO" "THÔNG TIN: phiên bản nginx: $NGINX_VERSION"
}

kiemTraKichThuocFileLog() {
  accessFileSize=$(wc -c "$1" | cut -f 1 -d ' ')
  errorFileSize=$(wc -c "$2" | cut -f 1 -d ' ')
  fileSize=$((accessFileSize + errorFileSize))
  if [ $fileSize -ge 102400000 ]; then
    if [ "$SUPPRESS_PROMPT" == "false" ]; then
      while true; do
        read -p "CẢNH BÁO: Hiện tại có các file log lớn có thể làm bạn vượt quá hạn mức. Vui lòng xoay vòng log trước khi tiếp tục. Bạn vẫn muốn tiếp tục chứ? (yes/no)" yn
        case $yn in
        [Yy]*)
          logMsgToConfigSysLog "INFO" "THÔNG TIN: Tổng kích thước log nginx hiện tại là $fileSize bytes. Tiếp tục cấu hình log cho nginx."
          break
          ;;
        [Nn]*)
          logMsgToConfigSysLog "INFO" "THÔNG TIN: Tổng kích thước log nginx hiện tại là $fileSize bytes. Dừng cấu hình log cho nginx."
          exit 1
          break
          ;;
        *) echo "Vui lòng trả lời yes hoặc no." ;;
        esac
      done
    else
      logMsgToConfigSysLog "WARN" "CẢNH BÁO: Hiện tại có các file log lớn có thể làm bạn vượt quá hạn mức."
      logMsgToConfigSysLog "INFO" "THÔNG TIN: Tổng kích thước log nginx hiện tại là $fileSize bytes. Tiếp tục cấu hình log cho nginx."
    fi
  elif [ $fileSize -eq 0 ]; then
    logMsgToConfigSysLog "WARN" "CẢNH BÁO: Không có log nginx gần đây nên sẽ không có log nào gửi lên Loggly. Bạn có thể tạo log bằng cách truy cập một trang trên web server."
    exit 1
  fi
}

ghiFile21NginxConf() {
  #Tạo file cấu hình syslog cho nginx nếu chưa tồn tại
  echo "THÔNG TIN: Kiểm tra file cấu hình syslog $NGINX_SYSLOG_CONFFILE."
  if [ -f "$NGINX_SYSLOG_CONFFILE" ]; then
    logMsgToConfigSysLog "WARN" "CẢNH BÁO: File syslog nginx $NGINX_SYSLOG_CONFFILE đã tồn tại."
    if [ "$SUPPRESS_PROMPT" == "false" ]; then
      while true; do
        read -p "Bạn có muốn ghi đè $NGINX_SYSLOG_CONFFILE không? (yes/no)" yn
        case $yn in
        [Yy]*)
          logMsgToConfigSysLog "INFO" "THÔNG TIN: Sẽ sao lưu file cấu hình: $NGINX_SYSLOG_CONFFILE thành $NGINX_SYSLOG_CONFFILE_BACKUP"
          sudo mv -f $NGINX_SYSLOG_CONFFILE $NGINX_SYSLOG_CONFFILE_BACKUP
          ghiNoiDungFile21Nginx
          break
          ;;
        [Nn]*) break ;;
        *) echo "Vui lòng trả lời yes hoặc no." ;;
        esac
      done
    else
      logMsgToConfigSysLog "INFO" "THÔNG TIN: Sẽ sao lưu file cấu hình: $NGINX_SYSLOG_CONFFILE thành $NGINX_SYSLOG_CONFFILE_BACKUP"
      sudo mv -f $NGINX_SYSLOG_CONFFILE $NGINX_SYSLOG_CONFFILE_BACKUP
      ghiNoiDungFile21Nginx
    fi
  else
    ghiNoiDungFile21Nginx
  fi
}

themTagVaoCauHinh() {
  #tách tag bằng dấu phẩy (,)
  IFS=, read -a array <<<"$LOGGLY_FILE_TAG"
  for i in "${array[@]}"; do
    TAG="$TAG tag=\\\"$i\\\" "
  done
}
#hàm ghi nội dung file cấu hình syslog nginx
ghiNoiDungFile21Nginx() {
  logMsgToConfigSysLog "INFO" "THÔNG TIN: Tạo file $NGINX_SYSLOG_CONFFILE"
  sudo touch $NGINX_SYSLOG_CONFFILE
  sudo chmod o+w $NGINX_SYSLOG_CONFFILE

  commonContent="
    \$ModLoad imfile
    \$InputFilePollInterval 10 
    \$WorkDirectory $RSYSLOG_DIR
    "
  if [[ "$LINUX_DIST" == *"Ubuntu"* ]]; then
    commonContent+="\$PrivDropToGroup adm		
        "
  fi

  imfileStr+=$commonContent"
    
    \$ActionSendStreamDriver gtls
    \$ActionSendStreamDriverMode 1
    \$ActionSendStreamDriverAuthMode x509/name
    \$ActionSendStreamDriverPermittedPeer *.loggly.com
    
    #RsyslogGnuTLS
    \$DefaultNetstreamDriverCAFile $CA_FILE_PATH
    
    # file access nginx:
    \$InputFileName $LOGGLY_NGINX_LOG_HOME/$NGINX_ACCESS_LOG_FILE
    \$InputFileTag nginx-access:
    \$InputFileStateFile stat-nginx-access
    \$InputFileSeverity info
    \$InputFilePersistStateInterval 20000
    \$InputRunFileMonitor

    #file lỗi nginx: 
    \$InputFileName $LOGGLY_NGINX_LOG_HOME/$NGINX_ERROR_LOG_FILE
    \$InputFileTag nginx-error:
    \$InputFileStateFile stat-nginx-error
    \$InputFileSeverity error
    \$InputFilePersistStateInterval 20000
    \$InputRunFileMonitor

    #Thêm tag cho sự kiện nginx
    \$template LogglyFormatNginx,\"<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid% [$LOGGLY_AUTH_TOKEN@41058 $TAG] %msg%\n\"

    if \$programname == 'nginx-access' then @@logs-01.loggly.com:6514;LogglyFormatNginx
    if \$programname == 'nginx-access' then ~
    if \$programname == 'nginx-error' then @@logs-01.loggly.com:6514;LogglyFormatNginx
    if \$programname == 'nginx-error' then ~
    "

  imfileStrNonTls=$commonContent"
    # file access nginx:
    \$InputFileName $LOGGLY_NGINX_LOG_HOME/$NGINX_ACCESS_LOG_FILE
    \$InputFileTag nginx-access:
    \$InputFileStateFile stat-nginx-access
    \$InputFileSeverity info
    \$InputFilePersistStateInterval 20000
    \$InputRunFileMonitor

    #file lỗi nginx: 
    \$InputFileName $LOGGLY_NGINX_LOG_HOME/$NGINX_ERROR_LOG_FILE
    \$InputFileTag nginx-error:
    \$InputFileStateFile stat-nginx-error
    \$InputFileSeverity error
    \$InputFilePersistStateInterval 20000
    \$InputRunFileMonitor

    #Thêm tag cho sự kiện nginx
    \$template LogglyFormatNginx,\"<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid% [$LOGGLY_AUTH_TOKEN@41058 $TAG] %msg%\n\"

    if \$programname == 'nginx-access' then @@logs-01.loggly.com:514;LogglyFormatNginx
    if \$programname == 'nginx-access' then ~
    if \$programname == 'nginx-error' then @@logs-01.loggly.com:514;LogglyFormatNginx
    if \$programname == 'nginx-error' then ~
    "

  if [ $TLS_SENDING == "false" ]; then
    imfileStr=$imfileStrNonTls
  fi

  #thay đổi file nginx-21 thành biến ở trên và lấy thư mục log nginx.
  sudo cat <<EOIPFW >>$NGINX_SYSLOG_CONFFILE
$imfileStr
EOIPFW

  restartRsyslog
}

#kiểm tra log nginx đã gửi lên loggly chưa
kiemTraLogNginxDaGuiLenLoggly() {
  counter=1
  maxCounter=10

  nginxInitialLogCount=0
  nginxLatestLogCount=0

  TAGS=
  IFS=, read -a array <<<"$LOGGLY_FILE_TAG"
  for i in "${array[@]}"; do
    if [ "$TAGS" == "" ]; then
      TAGS="tag%3A$i"
    else
      TAGS="$TAGS%20tag%3A$i"
    fi
  done

  queryParam="$TAGS&from=-15m&until=now&size=1"
  queryUrl="$LOGGLY_ACCOUNT_URL/apiv2/search?q=$queryParam"
  logMsgToConfigSysLog "INFO" "THÔNG TIN: URL tìm kiếm: $queryUrl"

  logMsgToConfigSysLog "INFO" "THÔNG TIN: Đang lấy số lượng log nginx ban đầu."
  #lấy số lượng log nginx 15 phút trước
  searchAndFetch nginxInitialLogCount "$queryUrl"

  logMsgToConfigSysLog "INFO" "THÔNG TIN: Đang kiểm tra log nginx đã gửi lên Loggly chưa."
  logMsgToConfigSysLog "INFO" "THÔNG TIN: Lần kiểm tra # $counter trên tổng số $maxCounter."
  #lấy số lượng log nginx 15 phút trước
  searchAndFetch nginxLatestLogCount "$queryUrl"
  let counter=$counter+1

  while [ "$nginxLatestLogCount" -le "$nginxInitialLogCount" ]; do
    echo "THÔNG TIN: Chưa tìm thấy log kiểm tra trên Loggly. Đợi 30 giây."
    sleep 30
    echo "THÔNG TIN: Đã đợi xong. Kiểm tra lại."
    logMsgToConfigSysLog "INFO" "THÔNG TIN: Lần kiểm tra # $counter trên tổng số $maxCounter."
    searchAndFetch nginxLatestLogCount "$queryUrl"
    let counter=$counter+1
    if [ "$counter" -gt "$maxCounter" ]; then
      logMsgToConfigSysLog "ERROR" "LỖI: Log nginx không gửi lên Loggly đúng hạn. Vui lòng kiểm tra kết nối mạng và firewall rồi thử lại."
      exit 1
    fi
  done

  if [ "$nginxLatestLogCount" -gt "$nginxInitialLogCount" ]; then
    logMsgToConfigSysLog "INFO" "THÔNG TIN: Đã gửi log nginx lên Loggly thành công! Bạn đã gửi log nginx lên Loggly."
    kiemTraLogDaDuocParseTrenLoggly
  fi
}

#kiểm tra log đã được parse đúng trên Loggly chưa
kiemTraLogDaDuocParseTrenLoggly() {
  nginxInitialLogCount=0
  TAG_PARSER=
  IFS=, read -a array <<<"$LOGGLY_FILE_TAG"
  for i in "${array[@]}"; do
    TAG_PARSER="$TAG_PARSER%20tag%3A$i "
  done
  queryParam="logtype%3Anginx$TAG_PARSER&from=-15m&until=now&size=1"
  queryUrl="$LOGGLY_ACCOUNT_URL/apiv2/search?q=$queryParam"
  searchAndFetch nginxInitialLogCount "$queryUrl"
  logMsgToConfigSysLog "INFO" "THÔNG TIN: Đang kiểm tra log Nginx đã được parse trên Loggly chưa."
  if [ "$nginxInitialLogCount" -gt 0 ]; then
    logMsgToConfigSysLog "INFO" "THÔNG TIN: Log Nginx đã được parse thành công trên Loggly!"
  else
    logMsgToConfigSysLog "WARN" "CẢNH BÁO: Đã nhận được log nhưng chưa ở đúng định dạng tự động parse của Loggly. Bạn vẫn có thể tìm kiếm toàn văn và đếm log trên các log này."
  fi
}

#xóa file 21nginx.conf
xoaFile21NginxConf() {
  echo "THÔNG TIN: Đang xóa file cấu hình syslog nginx của loggly."
  if [ -f "$NGINX_SYSLOG_CONFFILE" ]; then
    sudo rm -rf "$NGINX_SYSLOG_CONFFILE"
  fi
  echo "THÔNG TIN: Đã xóa tất cả file đã chỉnh sửa."
  restartRsyslog
}

#hiển thị cú pháp sử dụng
huongDanSuDung() {
  cat <<EOF
cách dùng: configure-nginx [-a tài khoản hoặc subdomain loggly] [-t token loggly (tùy chọn)] [-u tên đăng nhập] [-p mật khẩu (tùy chọn)] [-tag filetag1,filetag2 (tùy chọn)] [-s bỏ qua xác nhận {tùy chọn)] [-r hoàn tác]
cách dùng: configure-nginx [-a tài khoản hoặc subdomain loggly] [-r để hoàn tác]
cách dùng: configure-nginx [-h để xem trợ giúp]
EOF
}

##########  Lấy thông tin đầu vào từ người dùng - Bắt đầu  ##########

if [ $# -eq 0 ]; then
  huongDanSuDung
  exit
else
  while [ "$1" != "" ]; do
    case $1 in
    -t | --token)
      shift
      LOGGLY_AUTH_TOKEN=$1
      echo "AUTH TOKEN $LOGGLY_AUTH_TOKEN"
      ;;
    -a | --account)
      shift
      LOGGLY_ACCOUNT=$1
      echo "Tài khoản hoặc subdomain Loggly: $LOGGLY_ACCOUNT"
      ;;
    -u | --username)
      shift
      LOGGLY_USERNAME=$1
      echo "Đã thiết lập tên đăng nhập"
      ;;
    -p | --password)
      shift
      LOGGLY_PASSWORD=$1
      ;;
    -tag | --filetag)
      shift
      LOGGLY_FILE_TAG=$1
      echo "File tag: $LOGGLY_FILE_TAG"
      ;;
    -r | --rollback)
      LOGGLY_ROLLBACK="true"
      ;;
    -s | --suppress)
      SUPPRESS_PROMPT="true"
      ;;
    --insecure)
      LOGGLY_TLS_SENDING="false"
      TLS_SENDING="false"
      LOGGLY_SYSLOG_PORT=514
      ;;
    -h | --help)
      huongDanSuDung
      exit
      ;;
    esac
    shift
  done
fi

if [ "$LOGGLY_ACCOUNT" != "" -a "$LOGGLY_USERNAME" != "" ]; then
  if [ "$LOGGLY_PASSWORD" = "" ]; then
    getPassword
  fi
  caiDatCauHinhLogglyChoNginx
elif [ "$LOGGLY_ROLLBACK" != "" -a "$LOGGLY_ACCOUNT" != "" ]; then
  goCauHinhLogglyChoNginx
else
  huongDanSuDung
fi

##########  Lấy thông tin đầu vào từ người dùng - Kết thúc  ##########
