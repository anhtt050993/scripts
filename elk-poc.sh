#!/bin/bash
echo "Chào mừng bạn đen với script cai dat ELK stack.
Vui long tra loi cau hoi sau de tiep tuc!"
sleep 2

read -p "Tuan Anh có đẹp trai không? (yes/no): " answer

if [ "$answer" = "no" ]; then
    echo "Ban không xung dang su dung script này"
    exit 1
elif [ "$answer" = "yes" ]; then
    echo "Ban có dôi mat that tinh tuong
          Mòi ban tiep tuc lam theo huong dan"
else echo "Câu tra? loi không hop le"
exit 1
fi
sleep 2

read -p "Nhap dia chi IP cua Sever ELK: " ip
sudo yum -y install java-openjdk-devel java-openjdk
ntpdate -u 0.centos.pool.ntp.org
cat <<EOF | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo yum -y install vim elasticsearch
sudo systemctl enable --now elasticsearch.service 
curl -X PUT "http://127.0.0.1:9200/mytest_index"
sudo yum -y install kibana
sudo systemctl enable --now kibana
sudo yum -y install logstash
sudo systemctl enable --now logstash
yum install filebeat -y
cp -vp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.ori
sed -i 's/#cluster.name/cluster.name/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#node.name/node.name/g' /etc/elasticsearch/elasticsearch.yml
sed -i "s/#network.host: 192.168.0.1/network.host: $ip/g" /etc/elasticsearch/elasticsearch.yml
sed -i 's/#http.port/http.port/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#discovery.seed_hosts/discovery.seed_hosts/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#cluster.initial_master_nodes/cluster.initial_master_nodes/g' /etc/elasticsearch/elasticsearch.yml
cp -vp /etc/kibana/kibana.yml /etc/kibana/kibana.yml.ori
sed -i "s/#server.host: \"localhost\"/server.host: \"$ip\"/g" /etc/kibana/kibana.yml
sed -i "s/localhost:9200/$ip:9200/g" /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.hosts/elasticsearch.hosts/g' /etc/kibana/kibana.yml
cp -vp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.ori
sed -i "s/#host: \"localhost:5601\"/host: \"$ip\"/g" /etc/filebeat/filebeat.yml
sed -i "s/localhost:5044/$ip:5044/g" /etc/filebeat/filebeat.yml
#sed -i 's/#username: "elastic"/username: "elastic"/g' /etc/filebeat/filebeat.yml
sed -i 's/^  hosts: \[\"localhost:9200\"\]/#  hosts: \[\"localhost:9200\"\]/g' /etc/filebeat/filebeat.yml
sed -i 's/output.elasticsearch/#output.elasticsearch/g' /etc/filebeat/filebeat.yml
sed -i 's/#output.logstash/output.logstash/g' /etc/filebeat/filebeat.yml
sed -i 's/^  enabled: false/  enabled: true/g' /etc/filebeat/filebeat.yml
sed -i 's/^  #hosts/  hosts/g' /etc/filebeat/filebeat.yml
sed -i 's/type: filestream/type: log/g' /etc/filebeat/filebeat.yml
sed -i 's/*.log/messages/g' /etc/filebeat/filebeat.yml
sed -i 's/id: my-filestream-id/#id: my-filestream-id/g' /etc/filebeat/filebeat.yml
echo "  pipeline.workers: 1" >> /etc/logstash/pipelines.yml
systemctl start filebeat
systemctl enable filebeat
systemctl restart elasticsearch
systemctl restart kibana

cat <<EOF | sudo tee /etc/logstash/conf.d/filebeat-input.conf
input {
  beats {
    port => 5044
  }
}
EOF
cat <<EOF | sudo tee /etc/logstash/conf.d/syslog-filter.conf
filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
      add_field => [ "received_at", "%{@timestamp}" ]
      add_field => [ "received_from", "%{host}" ]
    }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}
EOF
cat <<EOF | sudo tee /etc/logstash/conf.d/output-elasticsearch.conf
output {
  elasticsearch { hosts => ["$ip:9200"]
    hosts => "$ip:9200"
    manage_template => false
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
EOF

systemctl restart logstash
