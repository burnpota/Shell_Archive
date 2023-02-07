#!/bin/bash
yum clean all
yum repolist

reposync -m -n --repoid rhel-8-for-x86_64-baseos-rpms -p /GUEST/repository/repo8/BaseOS --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/BaseOS

reposync -m -n --repoid rhel-8-for-x86_64-appstream-rpms -p /GUEST/repository/repo8/AppStream --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/AppStream

reposync -m -n --repoid ansible-2.9-for-rhel-8-x86_64-rpms -p /GUEST/repository/repo8/Ansible --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/Ansible

reposync -m -n --repoid rhel-8-for-x86_64-highavailability-rpms -p /GUEST/repository/repo8/HighAvailability --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/HighAvailability

reposync -m -n --repoid openstack-16.2-for-rhel-8-x86_64-rpms -p /GUEST/repository/repo8/OSP --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/OSP

reposync -m -n --repoid rhocp-4.10-for-rhel-8-x86_64-rpms -p /GUEST/repository/repo8/OCP4.10 --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/OCP4.10

reposync -m -n --repoid rhel-8-for-x86_64-resilientstorage-rpms -p /GUEST/repository/repo8/Resilient --norepopath --download-metadata --metadata-path=/GUEST/repository/repo8/Resilient
for i in BaseOS AppStream Ansible OSP HighAvailability OCP4.10 Resilient
do
	REPODIR=$(ls -d /GUEST/repository/repo8/${i})
	cd $REPODIR
        METADIR=$(ls | grep rpms$)
        rm -rf repodata
        mv $METADIR/* .
	createrepo . -g comps.xml
        rm -rf $METADIR
	cd -
done
