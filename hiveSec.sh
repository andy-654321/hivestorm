#!/bin/bash

#######################################################
# Attempt to secure a hivestorm machine
#######################################################

##functions

#delete file passed as parameter if it exists
delfile () {
	[[ -f "$1" ]] && rm "$1"
}

#systemctl stop and disable a service
ctlStop () {
	if (systemctl status $1 >/dev/null); then
		systemctl stop "$1"
		systemctl disable "$1"
	fi
}

########Enumerate and verify users##############
#get users in /etc/passwd
users=$(awk '{FS=":"; if( $3 > 1000 && $3 < 2000) print $1}' /etc/passwd)
echo $users

#build list of authorized users
while read -r line
do
	authorizedUsers+=("$line")
done < users.txt
echo -e "Users: ${authorizedUsers[@]}\n"

#build list of athorized admins
while read -r line
do
	authorizedAdmins+=($(echo $line | cut -d"," -f1))
done < admins.txt
echo -e "Admins: ${authorizedAdmins[@]}\n"

#check to see if all the users are allowed
for user in $users; do
   echo $user
   if !(echo "${authorizedUsers[@]} ${authorizedAdmins[@]}" | grep -q "$user"); then
     echo "$user not found in authorized users"
     [[ $(read -p "Enter y to delete him") -eq "y" ]] && deluser "$user" || echo "Didn't delete $user"
   fi
done

#set user's passwords
for user in ${authorizedUsers[@]}; do
	echo "Setting password for user $user"
	passwd -q $user > /dev/null << EOF
P@ssw0rd
P@ssw0rd
EOF
done

#set admin passwords
for user in ${authorizedAdmins[@]}; do
	password=$(grep $user admins.txt | cut -d"," -f2)
	echo "Setting password for user $user to $password"
	passwd -q $user > /dev/null << EOF
$password
$password
EOF
done

#remove unauthorized users from sudo group
for user in $(grep adm /etc/group | cut -d":" -f4 | sed 's/,/ /g'); do
	grep -q $user admins.txt || gpasswd -d $user sudo
done
	
##apply firewall rules
iptables-restore rules.txt

##edit sshd configuration
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config


##remove suspicious crons
delfile "/etc/cron.d/john"
delfile "/etc/cron.daily/cracklib-runtime"


##remove suspicious applications
delfile "/usr/sbin/update-cracklib"
delfile "/bin/netcat"
delfile "/usr/sbin/john"
delfile "/bin/nc"

##services
ctlStop "smbd"

#set firefox to default browser
for home in /home/*; do sudo cp ~/.config/mimeapps.list $home/.config/mimeapps.list; done
