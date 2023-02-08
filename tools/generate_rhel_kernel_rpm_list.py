#!/usr/bin/env python3
# -*- coding:utf-8 -*-
#
# This script is to generate RHEL kernel RPM list
# $ python tools/generate_rhel_kernel_rpm_list.py 9 x86_64 >  KERNEL_RPM_LIST_PATH
# Then configure KERNEL_RPM_LIST as KERNEL_RPM_LIST_PATH in kdump-auto-bisect.conf

import re
import os
import sys
import urllib.request


def download(url, save_path):
    if os.path.exists(save_path):
        return
    urllib.request.urlretrieve(url, save_path)


def get_kernel_versions():
    url = f"{base_url}/"
    path = f"rhel{rhel_version}.html"
    download(url, path)
    with open(path, 'r') as f:
        # ignore 9.el8+9zz5, 80.12.1.el8_0, 434.scrmod+el8.8.0+17140+c347af46
        versions = re.findall(r'href="([0-9.]+el[0-9]+)\/"', f.read())
        return versions


if len(sys.argv) < 3:
    rhel_version = input("RHEL version 8/9?\n")
    arch = input("Architecture:?")
else:
    rhel_version = sys.argv[1]
    arch = sys.argv[2]

version_map = {"8": "4.18.0", "9": "5.14.0"}
version = version_map[rhel_version]
base_url = f"http://download.devel.redhat.com/brewroot/vol/rhel-{rhel_version}/packages/kernel/{version}"

for minor in get_kernel_versions():
    release_version = f'{version}-{minor}'
    url = f'{base_url}/{minor}/{arch}/kernel-core-{release_version}.{arch}.rpm'
    print(url)
