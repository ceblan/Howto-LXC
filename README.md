
# Table of Contents

1.  [RSS LXC Containers](#org2300123)
    1.  [MATRIX setup](#org2b1927e)
        1.  [MATRIX LXC initial setup](#orgfa4b99a)
        2.  [MATRIX packages installation.](#org6405d6a)


<a id="org2300123"></a>

# RSS LXC Containers

This note contains some recipes for creating and configuring LXC containers to
run:

1.  MATRIX.


<a id="org2b1927e"></a>

## MATRIX setup

We split the MATRIX set up in three stages, each one with its own ansible
playbook:

1.  [MATRIX lxc playbook](#org87d115d)
2.  [MATRIX packages installation](#org0b6dd31)


<a id="orgfa4b99a"></a>

### MATRIX LXC initial setup

Below re the tasks as well as some tips about how to provision a MATRIX using
LXC

1.  How to create a LXC debian bookworm container in debian:

    To create an LXC Debian Bookworm container in Debian, follow these steps:
    
    1.  **Install LXC** (if not already installed):
        
            sudo apt update
            sudo apt install lxc
    
    2.  **Create a directory for your container**:
        
            sudo mkdir -p /var/lib/lxc/MATRIX
    
    3.  **Create the container**:
        
            sudo lxc-create --name MATRIX --template download -- --dist debian --release bookworm --arch amd64
    
    4.  **Start the container**:
        
            sudo lxc-start -n MATRIX
    
    5.  **Access the container’s shell**:
        
            sudo lxc-attach -n MATRIX
    
    You now have a running Debian Bookworm container!

2.  How to delete or remove a LXC container:

    To delete or remove an LXC container, follow these steps:
    
    1.  **Stop the container** (if it is running):
        
            sudo lxc-stop -n MATRIX
    
    2.  **Delete the container**:
        
            sudo lxc-destroy -n MATRIX
    
    After these commands, the `MATRIX` LXC container will be removed from your
    system.

3.  How to make the container to get same ip address every start:

    To assign a static IP address to your LXC container, you can follow these steps:
    
    1.  Stop MATRIX container
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

5.  How to tar a container to share it to other machine

    Below there is an Ansible playbook that sets up the MATRIX container (lxc) on the
    host **tsc-host-1**, performing all the tasks you've outlined:
    
        
        ---
            - name: Set up LXC container for a MATRIX
              hosts: pindaro # here should be tsc-host-1 instead
              become: yes
              vars_files:
                - vars.yml
              #vars:
              #  DEST: MATRIX  # remove this line if "--extra-vars "DEST=MATRIX" is passed when calling ansible-playbook
        
              tasks:
                - name: Install LXC
                  dnf:
                    name: lxc
                    state: present
                    update_cache: yes
        
                # - name: Uncomment LXC_DHCP_CONFILE in dnsmasq.conf
                #   lineinfile:
                #     path: /etc/default/lxc-net
                #     regexp: '^#LXC_DHCP_CONFILE'
                #     line: 'LXC_DHCP_CONFILE=/etc/dnsmasq.conf'
        
                - name: Ensure the directory for SSH keys exists
                  file:
                    path: "{{ playbook_dir }}/files/ssh-keys/{{ DEST }}"
                    state: directory
        
                - name: Check if keys exist
                  shell: "find {{ playbook_dir }}/files/ssh-keys/{{ DEST }} -name '*key*' | wc -l"
                  register: ssh_keys_exists
                  changed_when: false
        
                - debug:
                    msg: "Number of keys found: {{ ssh_keys_exists.stdout }}"
        
                - name: Generate SSH host keys
                  command: ssh-keygen -t {{ item }} -N "" -f {{ playbook_dir }}/files/ssh-keys/{{ DEST }}/ssh_host_{{ item }}_key
                  with_items:
                    - rsa
                    - ecdsa
                    - ed25519
                  when: ssh_keys_exists.stdout | trim | int != 6
        
                - name: Change {{ playbook_dir }}/files/ssh-keys/{{ DEST }} owner to {{ ansible_env.USER }}
                  shell: "chown {{ ansible_env.USER }}:{{ ansible_env.USER }} {{ playbook_dir }}/files/ssh-keys/{{ DEST }}/*"
                  register: ssh_key_files
        
        
                - name: Change keys permissions before copy
                  shell: "chmod 644 {{ playbook_dir }}/files/ssh-keys/{{ DEST }}/*"
                  register: ssh_key_files
        
                - name: Ensure the directory for SSH shared keys exists
                  file:
                    path: "{{ playbook_dir }}/files/ssh-keys/shared"
                    state: directory
        
                - name: Check if shared keys exist
                  shell: "find {{ playbook_dir }}/files/ssh-keys/shared/ -name 'id_rsa_lxc*' | wc -l"
                  register: ssh_shared_keys_exists
                  changed_when: false
        
                - debug:
                    msg: "Number of shared keys found: {{ ssh_shared_keys_exists.stdout }}"
        
                - name: Generate SSH shared keys
                  command: ssh-keygen -t rsa -N "" -f {{ playbook_dir }}/files/ssh-keys/shared/id_rsa_lxc
                  when: ssh_shared_keys_exists.stdout | trim | int != 2
        
                - name: Change keys permissions before copy
                  shell: "chmod 644 {{ playbook_dir }}/files/ssh-keys/shared/*"
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
                    dest: /etc/dnsmasq.d/lxc.conf
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
                #   command: lxc-file push {{ playbook_dir }}/files/ssh-keys/{{ DEST }}/* {{ DEST }}/etc/ssh/
                #   when: container_status.rc == 0
        
                - name: Get list of SSH host keys
                  shell: "find {{ playbook_dir }}/files/ssh-keys/{{ DEST }} -name '*key*'"
                  register: ssh_key_files
        
                - name: Copy SSH host keys to /var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/
                  copy:
                    src: "{{ item }}"
                    dest: "/var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/"
                    owner: root
                    group: root
                    mode: '0600'
                  with_items: "{{ ssh_key_files.stdout_lines }}"
        
                - name: Change keys permissions after copy
                  shell: "chmod 600 {{ playbook_dir }}/files/ssh-keys/shared/*"
                  register: ssh_key_files
        
                - name: Change keys permissions after copy
                  shell: "chmod 644 {{ playbook_dir }}/files/ssh-keys/shared/*pub"
                  register: ssh_key_files
        
                - name: Change public keys permissions after copy
                  shell: "chmod 644 /var/lib/lxc/{{ DEST }}/rootfs/etc/ssh/*pub"
        
                - name: Restart SSH service in {{ DEST }}
                  command: lxc-attach -n {{ DEST }} -- /etc/init.d/ssh restart
        
                - name: Set root password for {{ DEST }}
                  command: lxc-attach -n {{ DEST }} -- sh -c "echo 'root:finiquito' | chpasswd"
        
                - name: Create user {{ lxc_username }}
                  command: lxc-attach -n {{ DEST }} -- adduser --disabled-password --gecos "" --uid 1001 {{ lxc_username }}
        
                - name: Create group inside container (GID 300)
                  command: lxc-attach -n {{ DEST }} -- bash -c "groupadd -g 300 devpl"
        
                - name: Create user {{ lxc_username }} with password
                  command: lxc-attach -n {{ DEST }} -- sh -c "echo '{{ lxc_username }}:{{ lxc_username }}' | chpasswd"
        
                - name: Add user {{ lxc_username }} to the devpl group
                  command: lxc-attach -n {{ DEST }} -- usermod -aG devpl {{ lxc_username }}
        
                - name: create git-carlos
                  command: lxc-attach -n {{ DEST }} -- mkdir -p /home/{{ lxc_username }}/git-carlos/git-hub
        
                - name: chown git-carlos
                  command: lxc-attach -n {{ DEST }} -- chown -R {{ lxc_username }}:{{ lxc_username }} /home/{{ lxc_username }}/git-carlos
        
                - name: Add user {{ lxc_username }} to the sudo group
                  command: lxc-attach -n {{ DEST }} -- usermod -aG sudo {{ lxc_username }}
        
                - name: Allow members of the sudo group to run sudo without a password
                  become: yes
                  become_method: sudo
                  lineinfile:
                    path:  "/var/lib/lxc/{{ DEST }}/rootfs/etc/sudoers"
                    regexp: '^%sudo'
                    line: '%sudo ALL=(ALL:ALL) NOPASSWD: ALL'
        
                - name: Restart sudo
                  command: lxc-attach -n {{ DEST }} -- /etc/init.d/sudo restart
        
                - name: Create dir /home/{{ lxc_username }}/.ssh
                  command: lxc-attach -n {{ DEST }} -- sh -c "mkdir -p /home/{{ lxc_username }}/.ssh; chown -R {{ lxc_username }}:{{ lxc_username }} /home/{{ lxc_username }}/.ssh"
        
                - name: Get list of SSH shared keys
                  shell: "find {{ playbook_dir }}/files/ssh-keys/shared -name 'id_rsa_lxc*'"
                  register: ssh_shared_keys_files
        
                - name: Copy SSH shared keys to /var/lib/lxc/{{ DEST }}/rootfs/home/{{ lxc_username }}/.ssh/
                  copy:
                    src: "{{ item }}"
                    dest: "/var/lib/lxc/{{ DEST }}/rootfs/home/{{ lxc_username }}/.ssh/"
                    owner: root
                    group: root
                    mode: '0600'
                  with_items: "{{ ssh_shared_keys_files.stdout_lines }}"
        
                - name: Change public keys permissions after copy
                  shell: "chmod 644 /var/lib/lxc/{{ DEST }}/rootfs/home/{{ lxc_username }}/.ssh/*pub"
        
                - name: Generate authorized_keys
                  command: lxc-attach -n {{ DEST }} -- sh -c "cat /home/{{ lxc_username }}/.ssh/id_rsa_lxc.pub > /home/{{ lxc_username }}/.ssh/authorized_keys; chmod 600  /home/{{ lxc_username }}/.ssh/authorized_keys"
        
                - name: Create dir /home/concesion/.ssh
                  command: lxc-attach -n {{ DEST }} -- sh -c "chown -R {{ lxc_username }}:{{ lxc_username }} /home/{{ lxc_username }}/.ssh"
        
                - name: Install packages (batch 1)
                  command: lxc-attach -n {{ DEST }} -- sh -c "apt-get install -y {{ item }}"
                  loop:
                    - wget
                    - curl
        
                - name: Remove sources.list file from {{ DEST }}
                  command: lxc-attach -n {{ DEST }} -- rm -f /etc/apt/sources.list
        
                - name: Set sources lists
                  command: lxc-attach -n {{ DEST }} -- sh -c "echo {{ item }} >> /etc/apt/sources.list"
                  loop:
                    - "# generated by ansible"
                    - "deb http://deb.debian.org/debian/ bookworm main contrib non-free-firmware"
                    - "deb-src http://deb.debian.org/debian/ bookworm main contrib non-free-firmware"
                    - "deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware"
                    - "deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware"
                    - "deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free-firmware"
                    - "deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free-firmware"
        
                # - name: Get keys for web.deb-multimedia.org
                #   command: lxc-attach -n {{ DEST }} -- sh -c "wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb; dpkg -i deb-multimedia-keyring_2016.8.1_all.deb"
        
                - name: Update sources
                  command: lxc-attach -n {{ DEST }} -- sh -c "apt-get update"
        
                # - name: Add mount entry to git-carlos
                #   lineinfile:
                #     path: /var/lib/lxc/{{ DEST }}/config
                #     line: "lxc.mount.entry = /home/sice/git-sice home/{{ lxc_username }}/git-carlos none bind 0 0"
                #     create: yes # Create the file if it doesn't exist
                #     state: present # Ensure the line is present
        
                - name: Add mount entry to git-hub
                  lineinfile:
                    path: /var/lib/lxc/{{ DEST }}/config
                    line: "lxc.mount.entry = /home/carlos/git-carlos/git-hub home/{{ lxc_username }}/git-carlos/git-hub none bind 0 0"
                    create: yes # Create the file if it doesn't exist
                    state: present # Ensure the line is present
        
                - name: Stop {{ DEST }} container if it is running
                  command: lxc-stop -n {{ DEST }}
                  ignore_errors: yes
        
                - name: Pause for 5 seconds
                  wait_for:
                    delay: 1
                    timeout: 5
        
                - name: Remove lines containing {{ DEST }} from dnsmasq leases file
                  command: sed -i '/{{ DEST }}/d' /var/lib/misc/dnsmasq.lxcbr0.leases
        
                - name: Restart lxc-net service
                  systemd:
                    name: lxc-net
                    state: restarted
        
                - name: Pause for 10 seconds
                  wait_for:
                    delay: 1
                    timeout: 3
        
                - name: Start LXC container {{ DEST }}
                  command: lxc-start {{ DEST }}
        
                - name: Pause for 5 seconds
                  wait_for:
                    delay: 1
                    timeout: 5
        
        
                - name: List all LXC containers
                  command: lxc-ls -f
                  register: lxc_list_final
        
                - name: Display all LXC containers
                  debug:
                    var: lxc_list_final.stdout_lines
    
    1.  Notes:
    
        1.  Clonar el repositorio con la configuración de ansible
            
                # this file is ansible.cfg in the root of the project
                git clone https://github.com/ceblan/Howto-LXC.git
                cd Howto-LXC
        
        2.  `Ensure you have =ansible` installed and configured on your control
            machine. It's recommended to have ssh keys to access the hosts and guests.
            
                # this file is ansible.cfg in the root of the project
                [defaults]
                inventory = hosts
                private_key_file = ~/.ssh/id_rsa_lxc # create thix key for the project
                remote_user = concesion
        
        3.  Ensure you create a directory *ssh-keys* with with the host-keys and the
            shared-keys to avoid ssh problems when container is regenerated
            
                # this file is ansible.cfg in the root of the project
                sudo mkdir -p ssh-keys/MATRIX
                sudo cp /etc/ssh/ssh_host* ssh-keys/MATRIX
                sudo mkdir -p ssh-keys/shared
                ssh-keygen -t rsa -b 2048 -f ./ssh-keys/shared/id_rsa_lxc
            
                # this file is inventory.ini in the root of the project
                [lxc_hosts]
                uberrimus ansible_host=127.0.0.1
                tpcc-host-1 ansible_host=172.30.2.3
                [lxc_guests]
                MATRIX ansible_hosts=10.0.3.40
                MATRIX ansible_user=concesion
                MATRIX ansible_hosts=10.0.3.11
                MATRIX ansible_user=concesion
                MATRIX-2 ansible_hosts=10.0.3.12
                MATRIX-2 ansible_user=concesion
        
        4.  Run the playbook with:
            
                cd ansible
                ansible-playbook -i inventory.ini tasks/create-lxc-MATRIX.yml --extra-vars "DEST=MATRIX"


<a id="org6405d6a"></a>

### MATRIX packages installation.

1.  Various packages

    Instalation of Package requirements
    
        ---
        - name: Set up MATRIX packages
          hosts: all # here should be tsc-host-1 instead
          become_method: sudo
          become: true
          #vars_prompt:
            #- name: "ansible_become_pass"
              #prompt: "Enter your sudo password in remote server"
              #private: yes
        
        
          tasks:
            # - name: apt update
            #   become: yes
            #   command: apt update
        
            - name: avoid tshark config to block installation #esto es para que no pregunte lo del setuid y se bloquee
              become: yes
              shell: echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
        
            - name: Set APT to not install recommended packages
              copy:
                dest: /etc/apt/apt.conf.d/01norecommend
                content: |
                  APT::Install-Recommends "0";
                  APT::Install-Suggests "0";
        
            - name: Update APT package index
              apt:
                update_cache: yes
        
            - name: Install required packages
              become: yes
              become_method: sudo
              apt:
                name:
                  - vim
                  - munin
                  - munin-node
                  - psmisc
                  - daemon
                  - acl
                  - rsyslog-relp
                  - net-tools
                  - htop
                  - socat
                  - python3-pip
                  - make
                  - gcc
                  - libglib2.0-dev
                  - bash-completion
                  - libssl-dev
                  - libpq-dev
                  - libsqlite3-dev
                  - libjpeg-dev
                  - libpng-dev
                  - libcurl4-openssl-dev
                  - liblivemedia-dev
                  - libavcodec-dev
                  - libavformat-dev
                  - libswscale-dev
                  - g++
                  - libmodbus-dev
                  - libgtop2-dev
                  - libgtk-3-dev
                  - libhiredis-dev
                  - libjansson-dev
                  - libjson-glib-dev
                  - json-glib-tools
                  - gawk
                state: present
                install_recommends: no
    
    1.  Notes:
    
        1.  Run the playbook with:
            
                cd ansible 
                ansible-playbook -i inventory.ini tasks/install-packages-MATRIX.yml -l MATRIX

