#!/usr/bin/env python3

import os

from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('./'))
template = env.get_template(name='.gitlab-ci.yml.in')

configs = {
        'keystone': [
            'arm-unknown-linux-gnueabi',
            'aarch64-unknown-linux-gnu',
            'mips-unknown-elf',
            'powerpc64-unknown-linux-gnu',
            'powerpc-unknown-linux-gnu'],
        'world': [],
        'canadian': [],
    }

for root, _, files in os.walk('samples'):
    if 'crosstool.config' in files:
        config = os.path.basename(root)
        if config in configs['keystone']:
            continue

        key = 'canadian' if ',' in config else 'world'
        configs[key].append(config)

print('# Generated file DO NOT EDIT\n')
print(template.render(configs=configs))
