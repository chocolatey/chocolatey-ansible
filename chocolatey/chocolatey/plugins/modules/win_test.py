#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2012, Michael DeHaan <michael.dehaan@gmail.com>, and others
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_test
short_description: A short description
description:
- Test description for module.
options:
  option:
    description:
    - A description for the option
    type: str
    required: yes
author:
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
- name: how to run module
  win_test:
    option: abc
'''

RETURN = r'''
data:
  description: sample return
  returned: always
  type: str
  sample: test
'''
