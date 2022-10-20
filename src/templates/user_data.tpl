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
runcmd:
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
  - systemctl start amazon-ssm-agent
  - echo "*******************************************************************************"
  - echo "Configuring the AWS CloudWatch Agent..."
  - echo "*******************************************************************************"
  - mv /tmp/common-config.toml /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
  - mv /tmp/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  - systemctl start amazon-cloudwatch-agent
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
  - if [ -z "$KEY_FILES" ]; then mv /tmp/pki/* /etc/salt/pki; fi
  - rm -rf /tmp/pki
  - echo "*******************************************************************************"
  - echo "Restart Salt Master Agent..."
  - echo "*******************************************************************************"
  - systemctl start salt-master
  - echo "*******************************************************************************"
  - echo "User Data Script Execution Complete"
  - echo "*******************************************************************************"
