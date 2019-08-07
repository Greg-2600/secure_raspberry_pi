#!/bin/bash

start_service() {
# given service name as argument, start the service

	service=$1
	sudo service restart $service
}


install_service() {
# given service name as argument, install the service

	service=$1
	sudo apt install -y $service
}


create_secret() {
# get a string of "random" 32 characters

	head -300 /dev/urandom| # get the first 300 characters off the sudo random stack
	sha256sum| 		# hash it to get [a-z0-9] only
	base64| 		# change to base 64
	head -c 32 		# grab the first 32 characters
}


create_new_user() {
# function to accept argument from user and create a new account of that name
# and add associated filesystem and secret dependencies

	new_user_home="/home/$new_user/" # home directory of new user
	secret=$(create_secret)	# password for new user, generated from create_secret function

	sudo adduser $new_user  # tell the OS to add the new user account

	# make the new_user home directory writeable only by them
	sudo chmod 700 $new_user_home 

	# set new_user home directory to the new_user account
	sudo chown $new_user $new_user_home 

	# set the password for the new user
	echo -e $secret $secret|sudo passwd $user_user 

	# add new_user to the sudoers file
	sudo usermod -aG $new_user 

	# tell the user some information about what happened
	echo "Please change the password for $new_user !" 	# secure by defailt
	echo "The temporary password for $new_user is: $secret" # tell the user the secret
	secret='' # intentionaly clear the value for key secret before leaving scope
}


create_updates() {
# function to perform a system upgrade

	sudo apt update 	 # update the apt cache with current versions of packages
	sudo apt dist-upgrade -y # perform a full system update
}


update_upgrades() {
# have linux update system packages at 0606 local each day	

	cron_apt='0 6 * * 6 apt update && apt upgrade -y' # string to load into cron
	tmp_file=$(mktemp) 	     # make a temp file as cron requires flat file
	echo $cron_apt > ${tmp_file} # write the cront string into temp file
	sudo crontab $tmp_file       # run crontab and point it to load temp file
	rm ${tmp_file}               # clean up temp file
}


create_fail2ban() {
# install fail2ban to slow down door bangers

	install_service fail2ban # tell apt to kindly do the needful
	start_service fail2ban
}


update_default_user() {
# lock the default user

	default_user='pi' 		 # set default user for rPI
	secret=$(create_secret) 	 # get a secret string

	# change the password for the default_user
	echo -e $secret $secret|sudo passwd $default_user

	# intentionaly clear the value for key secret before leaving scope
	secret='' 

	sudo passwd --lock $default_user # lock the default user
}


create_ssh_server() {
# install open ssh and try to lock it down

	install_service openssh-server # install sshd
	start_service ssh
}


update_ssh_permissions() {
# allow for key based authetnication 

	mkdir ~/.ssh      		  # make a hidden dir for ssh files
	chmod 0700 ~/.ssh 		  # make writable only by new_user
	touch ~/.ssh/authorized_keys      # instantiate file to contain keys
	chmod 0600 ~/.ssh/authorized_keys # restrict key file readable only by new_user
	start_service ssh
}


update_ssh_server_key() {
# have sshd generate a new key now that additional entropy is available

	rm -v /etc/ssh/ssh_host_*            # remove initially generated ssh keys
	sudo dpkg-reconfigure openssh-server # generate them again
	start_service ssh
}


upate_ssh_config() {
# funtion to control user_name access to sshd

	# user accounts to allow to ssh 
	ssh_allow_users="$new_user" # allow the new_user to ssh to this host
	ssh_allow_str="AllowUsers $ssh_allow_users" # allow string to put in file

	# user accounts that cannot access ssh
	ssh_deny_users="root pi"  		 # list of users to implictly deny
	ssh_deny_str="DenyUsers $ssh_deny_users" # deny string to put in file

	tmp_file=$(mktemp) 		         # temp file to render new config

	cat sshd_config > ${tmp_file} 	         # existing config template
	echo $ssh_allow_str >> ${tmp_file}       # add allow string
	echo $ssh_deny_str >> ${tmp_file}        # add deny string

	# backup existing configuration file
	cp /etc/ssh/sshd_config \ 
		/etc/ssh/sshd_config/$(date+%f)

	mv ${tmp_file} /etc/ssh/sshd_config      # move new rendered config

	start_service ssh
}


create_ntp() {
# accurate clock

	install service ntp       # accurate time! 
	start_service ntp
}


create_logwatch() {
# root user receives daily email of log activity

	install_service logwatch  # log activity reporting daemon
	start_service logwatch
}


create_haveged() {
# install software RNG
# in virtualized and solid state environments, with very little 
# access to arbitrary entropy such as spinning disks, spinning fans, etc
# this software package leverages a software only approach to populating
# the entropy pool.  This is important to use as we want to (re)generate 
# cryptographic certificates.

	install_service haveged  # entropy daemon

	start_service haveged
}


#test() {
	#echo "user name entered is $new_user"
	#echo "choice entered is $choice"
#}

main() {
	create_updates
	create_haveged
	create_ntp
	create_new_user
	create_logwatch
	create_ssh_server
	upate_ssh_config
	update_ssh_permissions
	update_ssh_server_key
	update_upgrades
	update_default_user
}

# become uid0
#sudo true

read -p "Enter new user name:" new_user
read -p "you entered: $new_user is this correct (y/n)?" choice
case "$choice" in
  y|Y ) echo "yes";;
  n|N ) echo "no";;
  * ) echo "invalid";;
esac


main
