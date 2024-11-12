
# Table of Contents

1.  [RSS LXC Containers](#orgcab5220)
    1.  [TSC setup](#org9ddc69d)
        1.  [TSC LXC initial setup](#orgeb34a36)
        2.  [TSC packages installation.](#org0a8ed8d)
    2.  [TPCC setup](#org1654d34)


<a id="orgcab5220"></a>

# RSS LXC Containers

This note contains some recipes for creating and configuring LXC containers to
run:

1.  TSC.
2.  TPCC.


<a id="org9ddc69d"></a>

## TSC setup

We split the TSC set up in three stages, each one with its own ansible playbook:

1.  [TSC lxc playbook](#orgc87fb28)
2.  TODO:
3.  TODO:


<a id="orgeb34a36"></a>

### TSC LXC initial setup

Below re the tasks as well as some tips about how to provision a TSC using LXC

1.  How to create a LXC debian bookworm container in debian:

    To create an LXC Debian Bookworm container in Debian, follow these steps:
    
    1.  **Install LXC** (if not already installed):
        
            sudo apt update
            sudo apt install lxc
    
    2.  **Create a directory for your container**:
        
            sudo mkdir -p /var/lib/lxc/TSC-1
    
    3.  **Create the container**:
        
            sudo lxc-create --name TSC-1 --template download -- --dist debian --release bookworm --arch amd64
    
    4.  **Start the container**:
        
            sudo lxc-start -n TSC-1
    
    5.  **Access the container’s shell**:
        
            sudo lxc-attach -n TSC-1
    
    You now have a running Debian Bookworm container!

2.  How to delete or remove a LXC container:

    To delete or remove an LXC container, follow these steps:
    
    1.  **Stop the container** (if it is running):
        
            sudo lxc-stop -n TSC-1
    
    2.  **Delete the container**:
        
            sudo lxc-destroy -n TSC-1
    
    After these commands, the `TSC-1` LXC container will be removed from your
    system.

3.  How to make the container to get same ip address every start:

    To assign a static IP address to your LXC container, you can follow these steps:
    
    1.  Stop TSC-1 container
    2.  Uncomment the line "LXC<sub>DHCP</sub><sub>CONFILE</sub>=/etc/dnsmasq.conf"
    3.  as root in the server machine do
        
            echo "dhcp-host=mycontainer,10.0.3.10" >>/etc/lxc/dnsmasq.conf
            ln -s /etc/lxc/dnsmasq.conf /etc/dnsmasq.conf
    4.  restart lxc-net.service
        
            systemctl status lxc-net.service

4.  How to list all available containers and its status:

    To list all available LXC containers along with their status, use the following
    command:
    
        sudo lxc-ls -f
    
    This command will display a table with details about each container, including
    its name, state (running, stopped), and other relevant information like IP
    addresses.

5.  **Ansible** playbook that performs all previous task on host tsc-host-1.

    Below there is an Ansible playbook that sets up the TSC-1 container (lxc) on the
    host **tsc-host-1**, performing all the tasks you've outlined:
    
        ---
        - name: Set up LXC container for a TSC
          hosts: uberrimus # here should be tsc-host-1 instead
          become: yes
          #vars:
          #  DEST: TSC-1  # remove this line if "--extra-vars "DEST=TSC-1" is passed when calling ansible-playbook
        
          tasks:
            - name: Install LXC
              apt:
                name: lxc
                state: present
                update_cache: yes
        
            - name: Uncomment LXC_DHCP_CONFILE in dnsmasq.conf
              lineinfile:
                path: /etc/default/lxc-net
                regexp: '^#LXC_DHCP_CONFILE'
                line: 'LXC_DHCP_CONFILE=/etc/dnsmasq.conf'
        
            - name: Ensure the directory for SSH keys exists
              file:
                path: "{{ playbook_dir }}/ssh-keys/{{ DEST }}"
                state: directory
        
            - name: Check if keys exist
              shell: "find {{ playbook_dir }}/ssh-keys/{{ DEST }} -name '*key*' | wc -l"
              register: ssh_keys_exists
              changed_when: false
        
            - debug:
                msg: "Number of keys found: {{ ssh_keys_exists.stdout }}"
        
            - name: Generate SSH host keys
              command: ssh-keygen -t {{ item }} -N "" -f {{ playbook_dir }}/ssh-keys/{{ DEST }}/ssh_host_{{ item }}_key
              with_items:
                - rsa
                - ecdsa
                - ed25519
              when: ssh_keys_exists.stdout | trim | int != 6
        
            - name: Change keys permissions before copy
              shell: "chmod 644 {{ playbook_dir }}/ssh-keys/{{ DEST }}/*"
              register: ssh_key_files
        
            - name: Ensure the directory for SSH shared keys exists
              file:
                path: "{{ playbook_dir }}/ssh-keys/shared"
                state: directory
        
            - name: Check if shared keys exist
              shell: "find {{ playbook_dir }}/ssh-keys/shared/ -name 'id_rsa_lxc*' | wc -l"
              register: ssh_shared_keys_exists
              changed_when: false
        
            - debug:
                msg: "Number of shared keys found: {{ ssh_shared_keys_exists.stdout }}"
        
            - name: Generate SSH shared keys
              command: ssh-keygen -t rsa -N "" -f {{ playbook_dir }}/ssh-keys/shared/id_rsa_lxc
              when: ssh_shared_keys_exists.stdout | trim | int != 2
        
            - name: Change keys permissions before copy
              shell: "chmod 644 {{ playbook_dir }}/ssh-keys/shared/*"
              register: ssh_key_files
        
        
            - name: Check if {{ DEST }} container exists
              command: lxc-ls | grep {{ DEST }}
              register: tsc_exists
              ignore_errors: yes
        
            # - name: Output inventory sources
            #   debug:
            #     var: hostvars[inventory_hostname]['ansible_inventory_sources']
        
            # - name: Output tsc_exists
            #   debug:
            #     var: tsc_exists
        
            - name: Check if {{ DEST }} container exists
              command: lxc-ls --fancy
              register: lxc_list
        
            - name: Check if {{ DEST }} container is running
              command: lxc-ls --running | grep {{ DEST }}
              register: container_status
              ignore_errors: yes
              when: tsc_exists.rc == 0
        
            # - name: Output value of container_status
            #   debug:
            #     var: container_status
        
            - name: Stop {{ DEST }} container if it is running
              command: lxc-stop -n {{ DEST }}
              ignore_errors: yes
              when: container_status.stdout != "" and  DEST in container_status.stdout_lines
        
            - name: Destroy {{ DEST }} container if it exists
              command: lxc-destroy -n {{ DEST }}
              when: DEST in tsc_exists.stdout
        
            - name: Create directory for {{ DEST }} container
              file:
                path: /var/lib/lxc/{{ DEST }}
                state: directory
        
            - name: Check if {{ DEST }} container exists
              command: lxc-ls --fancy
              register: lxc_list
        
            - name: Create LXC container {{ DEST }} if it does not exist
              command: lxc-create --name {{ DEST }} --template download -- --dist debian --release bookworm --arch amd64
              when: "DEST not in lxc_list.stdout"
        
            - name: Get IP for {{ DEST }} from inventory
              shell: "grep {{ DEST }}.*ansible_hosts {{ hostvars[inventory_hostname]['ansible_inventory_sources'][0] }} | awk -F'=' '{print $2}'"
              register: tsc_ip_output
        
            - name: Print the IP of {{ DEST }}
              debug:
                msg: "IP of {{ DEST }}: {{ tsc_ip_output.stdout }}"
        
            - name: Remove static DHCP entries for {{ tsc_ip_output.stdout }} in dnsmasq.conf
              lineinfile:
                path: /etc/lxc/dnsmasq.conf
                state: absent
                regexp: '^dhcp-host=.*{{ tsc_ip_output.stdout }}.*'
        
            - name: Set static DHCP for {{ DEST }} in dnsmasq.conf
              lineinfile:
                path: /etc/lxc/dnsmasq.conf
                line: "dhcp-host={{ DEST }},{{ tsc_ip_output.stdout }}"
        
            - name: Create symlink for dnsmasq.conf
              file:
                src: /etc/lxc/dnsmasq.conf
                dest: /etc/dnsmasq.conf
                state: link
        
            - name: Remove lines containing {{ DEST }} from dnsmasq leases file
              command: sed -i '/{{ DEST }}/d' /var/lib/misc/dnsmasq.lxcbr0.leases
        
            - name: Restart lxc-net service
              systemd:
                name: lxc-net
                state: restarted
        
            - name: Start LXC container {{ DEST }}
              command: lxc-start -n {{ DEST }}
              when: "DEST not in lxc_list.stdout"
        
            - name: Check if {{ DEST }} container is running
              command: lxc-info -n {{ DEST }} -s
              register: container_status
              ignore_errors: true
        
            - name: Install OpenSSH server in {{ DEST }}
              command: lxc-attach -n {{ DEST }} -- apt-get install -y openssh-server
              when: container_status.rc == 0
        
            - name: Install Python3 in {{ DEST }}
              command: lxc-attach -n {{ DEST }} -- apt-get install -y python3 python-apt-common
              when: container_status.rc == 0
        
            # - name: Copy SSH host keys to {{ DEST }}
            #   command: lxc-file push {{ playbook_dir }}/ssh-keys/{{ DEST }}/* {{ DEST }}/etc/ssh/
            #   when: container_status.rc == 0
        
            - name: Get list of SSH host keys
              shell: "find {{ playbook_dir }}/ssh-keys/{{ DEST }} -name '*key*'"
              register: ssh_key_files
        
            - name: Copy SSH host keys to /var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/
              copy:
                src: "{{ item }}"
                dest: "/var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/"
                owner: root
                group: root
                mode: '0600'
              with_items: "{{ ssh_key_files.stdout_lines }}"
        
            - name: Change public keys permissions after copy
              shell: "chmod 644 /var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/*pub"
        
            - name: Restart SSH service in {{ DEST }}
              command: lxc-attach -n {{ DEST }} -- /etc/init.d/ssh restart
        
            - name: Set root password for {{ DEST }}
              command: lxc-attach -n {{ DEST }} -- bash -c "echo 'root:finiquito' | chpasswd"
        
            - name: Create user "concesion"
              command: lxc-attach -n {{ DEST }} -- adduser --disabled-password --gecos "" --uid 1001 concesion
        
            - name: Create user "concesion" with password
              command: lxc-attach -n {{ DEST }} -- bash -c "echo 'concesion:concesion' | chpasswd"
        
            - name: Add user "concesion" to the sudo group
              command: lxc-attach -n {{ DEST }} -- usermod -aG sudo concesion
        
            - name: Allow members of the sudo group to run sudo without a password
              become: yes
              become_method: sudo
              lineinfile:
                path:  "/var/lib/lxc/{{ DEST }}/rootfs/etc/sudoers"
                regexp: '^%sudo'
                line: '%sudo ALL=(ALL:ALL) NOPASSWD: ALL'
        
            - name: Restart sudo
              command: lxc-attach -n {{ DEST }} -- /etc/init.d/sudo restart
        
            - name: Create dir /home/concesion/.ssh
              command: lxc-attach -n {{ DEST }} -- bash -c "mkdir -p /home/concesion/.ssh; chown -R concesion:concesion /home/concesion/.ssh"
        
        
            - name: Get list of SSH shared keys
              shell: "find {{ playbook_dir }}/ssh-keys/shared -name 'id_rsa_lxc*'"
              register: ssh_shared_keys_files
        
            - name: Copy SSH shared keys to /var/lib/lxc/{{ DEST }}/rootfs/home/concesion/.ssh/
              copy:
                src: "{{ item }}"
                dest: "/var/lib/lxc/{{ DEST }}/rootfs/home/concesion/.ssh/"
                owner: root
                group: root
                mode: '0600'
              with_items: "{{ ssh_shared_keys_files.stdout_lines }}"
        
            - name: Change public keys permissions after copy
              shell: "chmod 644 /var/lib/lxc/{{ DEST }}/rootfs/home/concesion/.ssh/*pub"
        
            - name: Generate authorized_keys
              command: lxc-attach -n {{ DEST }} -- bash -c "cat /home/concesion/.ssh/id_rsa_lxc.pub > /home/concesion/.ssh/authorized_keys; chmod 600  /home/concesion/.ssh/authorized_keys"
        
            - name: Create dir /home/concesion/.ssh
              command: lxc-attach -n {{ DEST }} -- bash -c "chown -R concesion:concesion /home/concesion/.ssh"
        
            - name: Install packages (batch 1)
              command: lxc-attach -n {{ DEST }} -- bash -c "apt-get install -y {{ item }}"
              loop:
                - wget
                - curl
        
            - name: Remove sources.list file from {{ DEST }}
              command: lxc-attach -n {{ DEST }} -- rm -f /etc/apt/sources.list
        
            - name: Set sources lists
              command: lxc-attach -n {{ DEST }} -- bash -c "echo {{ item }} >> /etc/apt/sources.list"
              loop:
                - "# generated by ansible"
                - "deb http://deb.debian.org/debian/ bookworm main contrib non-free-firmware"
                - "deb-src http://deb.debian.org/debian/ bookworm main contrib non-free-firmware"
                - "deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware"
                - "deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware"
                - "deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free-firmware"
                - "deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free-firmware"
                - "deb [arch=amd64,i386] http://www.deb-multimedia.org bookworm main non-free"
        
            - name: Get keys for web.deb-multimedia.org
              command: lxc-attach -n {{ DEST }} -- bash -c "wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb; dpkg -i deb-multimedia-keyring_2016.8.1_all.deb"
        
            - name: Update sources
              command: lxc-attach -n {{ DEST }} -- bash -c "apt-get update"
        
            - name: List all LXC containers
              command: lxc-ls -f
              register: lxc_list_final
        
            - name: Display all LXC containers
              debug:
                var: lxc_list_final.stdout_lines
    
    1.  Notes:
    
        1.  `Ensure you have =ansible` installed and configured on your control
            machine. It's recommended to have ssh keys to access the hosts and guests.
            
                # this file is ansible.cfg in the root of the project
                [defaults]
                inventory = hosts
                private_key_file = ~/.ssh/id_rsa_lxc # create thix key for the project
                remote_user = concesion
        
        2.  `Adjust your inventory file to include tsc-host-1.`
            
                # this file is inventory.ini in the root of the project
                [lxc_hosts]
                uberrimus ansible_host=127.0.0.1
                tpcc-host-1 ansible_host=172.30.2.1
                tsc-host-1 ansible_host=172.30.2.10
                [lxc_guests]
                TSC-1 ansible_hosts=10.0.3.10
                TSC-2 ansible_hosts=10.0.3.11
        
        3.  Run the playbook with:
            
                cd ansible
                ansible-playbook -i inventory.ini tasks/create-lxc-TSC.yml --extra-vars "DEST=TSC-1"


<a id="org0a8ed8d"></a>

### TSC packages installation.

Instalation of Package requirements

    ---
    - name: Set up TSC packages
      hosts: all # here should be tsc-host-1 instead
      become_method: sudo
      #vars_prompt:
        #- name: "ansible_become_pass"
          #prompt: "Enter your sudo password in remote server"
          #private: yes
    
    
      tasks:
        - name: apt update
          become: yes
          command: apt update
    
        - name: avoid tshark config to block installation #esto es para que no pregunte lo del setuid y se bloquee
          become: yes
          shell: echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
    
        - name: Install packages (batch 2)
          become: yes
          become_method: sudo
          command: apt-get install -y {{ item }}
          loop:
            - vim
            - munin
            - munin-node
            - psmisc
            - daemon
            - acl
            - rsyslog-relp
            - apache2
            - php
            - php-gd
            - php-pgsql
            - php-redis
            - ntp
            - gdb
            - net-tools
            - htop
            - iotop
            - ifenslave
            - dcfldd
            - socat
            - apt-offline
            - tshark
            - nvme-cli
            - snmp
            - snmpd
            - libsnmp-dev
    
        - name: Install packages (batch 3)
          become: yes
          become_method: sudo
          command: apt-get install -y {{ item }}
          loop:
            - python3-pip
            - python3-psycopg2
            - python3-pyinotify
            - python3-pil
            - python3-redis
            - python3-joblib
            - python3-pycryptodome
            - python3-scipy
            - python3-networkx
    
        - name: Install packages (batch 3)
          become: yes
          become_method: sudo
          command: apt-get install -y {{ item }}
          loop:
            - postgresql

1.  Notes:

    1.  Run the playbook with:
        
            cd ansible 
            ansible-playbook -i inventory.ini tasks/install-packages-TSC.yml -l TSC-1


<a id="org1654d34"></a>

## TPCC setup

lo vamos gestionando

