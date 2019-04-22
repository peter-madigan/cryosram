#!/user/bin/env python

from distutils.core import setup

setup(name='cryosram',
      version='1.0.0',
      description='A small collection for cryosram testing',
      author='Peter Madigan',
      scripts=['cryoCMOS.py','plotting.py','test_suite.py'],
      install_requires=['pyserial','bitarray','numpy','matplotlib','ipython']
)
