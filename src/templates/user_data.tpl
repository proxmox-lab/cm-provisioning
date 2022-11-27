#cloud-config
output: { all: "| tee -a /var/log/cloud-init-output.log" }
preserve_hostname: false
manage_etc_hosts: false
fqdn: ${hostname}.${domain}
packages:
  - nfs-utils
package_update: true
package_upgrade: true
package_reboot_if_required: true
write_files:
  - path: /etc/amazon/ssm/seelog.xml
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      <!--amazon-ssm-agent uses seelog logging -->
      <!--Seelog has github wiki pages, which contain detailed how-tos references: https://github.com/cihub/seelog/wiki -->
      <!--Seelog examples can be found here: https://github.com/cihub/seelog-examples -->
      <seelog type="adaptive" mininterval="2000000" maxinterval="100000000" critmsgcount="500" minlevel="info">
          <exceptions>
              <exception filepattern="test*" minlevel="error"/>
          </exceptions>
          <outputs formatid="fmtinfo">
              <console formatid="fmtinfo"/>
              <rollingfile type="size" filename="/var/log/amazon/ssm/amazon-ssm-agent.log" maxsize="30000000" maxrolls="5"/>
              <filter levels="error,critical" formatid="fmterror">
                  <rollingfile type="size" filename="/var/log/amazon/ssm/errors.log" maxsize="10000000" maxrolls="5"/>
              </filter>
          </outputs>
          <formats>
              <format id="fmterror" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
              <format id="fmtdebug" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
              <format id="fmtinfo" format="%Date %Time %LEVEL %Msg%n"/>
          </formats>
      </seelog>
  - path: /tmp/common-config.toml
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      [credentials]
        shared_credential_profile = "default"
        shared_credential_file = "/root/.aws/credentials"
  - path: /tmp/amazon-cloudwatch-agent.json
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      {
        "metrics": {
          "namespace": "MANAGED-INSTANCE-EXAMPLE",
          "metrics_collected": {
            "cpu": {
              "resources": [
                "*"
              ],
              "measurement": [
                "cpu_usage_idle",
                "cpu_usage_nice",
                "cpu_usage_guest"
              ],
              "metrics_collection_interval": 10
            },
            "netstat": {
              "measurement": [
                "tcp_established",
                "tcp_syn_sent",
                "tcp_close"
              ],
              "metrics_collection_interval": 60
            },
            "disk": {
              "measurement": [
                "used_percent"
              ],
              "resources": [
                "*"
              ]
            },
            "processes": {
              "measurement": [
                "blocked",
                "dead",
                "idle",
                "paging",
                "stopped",
                "total",
                "total_threads",
                "wait",
                "zombies",
                "running",
                "sleeping"
              ],
              "metrics_collection_interval": 10
            }
          }
        },
        "logs": {
          "logs_collected": {
            "files": {
              "collect_list": [
                {
                  "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
                  "log_group_name": "${log_group_name}",
                  "log_stream_name": "amazon-cloudwatch-agent.log"
                },
                {
                  "file_path": "/var/log/messages",
                  "log_group_name": "${log_group_name}",
                  "log_stream_name": "syslog"
                },
                {
                  "file_path": "/var/log/cron",
                  "log_group_name": "${log_group_name}",
                  "log_stream_name": "cron"
                }
              ]
            }
          },
          "force_flush_interval": 15
        }
      }
  - path: /root/.ssh/id_rsa
    encoding: text/plain
    owner: root:root
    permissions: '0600'
    content: |
      ${privkey}
  - path: /root/.ssh/id_rsa.pub
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      ${pubkey}
  - path: /tmp/master
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      fileserver_backend:
        - gitfs
      gitfs_provider: pygit2
      gitfs_remotes:
        - ${git_repository}:
          - pubkey: /root/.ssh/id_rsa.pub
          - privkey: /root/.ssh/id_rsa
          - root: salt
          - base: production
          - saltenv:
            - development:
              - ref: development
      auto_accept: True
      log_level: info
      log_level_logfile: info
      ext_pillar:
        - git:
          - production ${git_repository}:
            - env: base
            - root: pillar
            - privkey: /root/.ssh/id_rsa
            - pubkey: /root/.ssh/id_rsa.pub
          - development ${git_repository}:
            - env: development
            - root: pillar
            - privkey: /root/.ssh/id_rsa
            - pubkey: /root/.ssh/id_rsa.pub
  - path: /root/private.key
    encoding: text/plain
    owner: root:root
    permissions: '0600'
    content: |
      ${privgpgkey}
  - path: /root/public.key
    encoding: text/plain
    owner: root:root
    permissions: '0644'
    content: |
      ${pubgpgkey}
  - path: /etc/environment
    content: |
      GNUPGHOME=/etc/salt/gpgkeys
    append: true
runcmd:
  - set -euo pipefail
  - echo "*******************************************************************************"
  - echo "Configuring the AWS CLI..."
  - echo "*******************************************************************************"
  - aws configure set region ${region}
  - aws configure set aws_access_key_id ${aws_access_key_id}
  - aws configure set aws_secret_access_key ${aws_secret_access_key}
  - aws configure set aws_session_token ${aws_session_token}
  - echo "*******************************************************************************"
  - echo "Configuring the AWS SSM Agent..."
  - echo "*******************************************************************************"
  - systemctl stop amazon-ssm-agent
  - read activation_id activation_code <<<$(echo $(aws ssm create-activation --default-instance-name "${hostname}" --description "${description}" --iam-role ${role} --registration-limit 1 --region ${region} --tags ${tags} | jq -r '.ActivationId, .ActivationCode'))
  - amazon-ssm-agent -register -code $activation_code -id $activation_id -region ${region}
  - systemctl enable amazon-ssm-agent
  - systemctl start amazon-ssm-agent
  - echo "*******************************************************************************"
  - echo "Configuring the AWS CloudWatch Agent..."
  - echo "*******************************************************************************"
  - if [ ${enable_cw_logging} -eq 1 ]; then
  -   echo "*** Enabling CloudWatch Logs for this Server ***"
  -   mv /tmp/common-config.toml /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
  -   mv /tmp/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  -   systemctl enable amazon-cloudwatch-agent
  -   systemctl start amazon-cloudwatch-agent
  - else
  -   echo "*** CloudWatch Logs NOT Enabled for this Server ***"
  - fi
  - echo "*******************************************************************************"
  - echo "Installing and Configuring Saltmaster..."
  - echo "*******************************************************************************"
  - curl -o /tmp/bootstrap-salt.sh -L https://bootstrap.saltproject.io
  - chmod +x /tmp/bootstrap-salt.sh
  - /tmp/bootstrap-salt.sh -M -N -x python3 -P
  - rm /tmp/bootstrap-salt.sh
  - echo "*******************************************************************************"
  - echo "Stopping Salt Master Agent and Setting Up Git Backend Configuration..."
  - echo "*******************************************************************************"
  - systemctl stop salt-master
  - mv /tmp/master /etc/salt/master
  - echo "*******************************************************************************"
  - echo "Use Pre-Existing Salt Master Keys if Present..."
  - echo "*******************************************************************************"
  - mkdir /tmp/pki && mv /etc/salt/pki/* /tmp/pki/.
  - echo "${fs_spec}  /etc/salt/pki  nfs  nolock,hard  0  0" >> /etc/fstab
  - mount -a
  - KEY_FILES=$(find /etc/salt/pki -type f)
  - if [ -z "$KEY_FILES" ]; then
  -   echo "*** No Pre-Existing Salt Master Keys ***"
  -   mv /tmp/pki/* /etc/salt/pki;
  - else
  -   echo "*** Pre-Existing Salt Master Keys Loaded ***"
  - fi
  - rm -rf /tmp/pki
  - echo "*******************************************************************************"
  - echo "Restart Salt Master Agent..."
  - echo "*******************************************************************************"
  - systemctl start salt-master
  - echo "*******************************************************************************"
  - echo "Import GPG Keys for Encrypted Pillar Handling..."
  - echo "*******************************************************************************"
  - mkdir -p /etc/salt/gpgkeys
  - chmod 700 /etc/salt/gpgkeys
  - gpg --homedir /etc/salt/gpgkeys --import /root/private.key
  - gpg --homedir /etc/salt/gpgkeys --import /root/public.key
  - echo "*******************************************************************************"
  - echo "User Data Script Execution Complete"
  - echo "*******************************************************************************"
