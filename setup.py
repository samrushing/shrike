# -*- Mode: Python -*-

from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

# See http://wiki.cython.org/PackageHierarchy
#  for details on how to correctly mix cython & package hierarchies.

setup (
    name='shrike',
    description='shrike coroutine library',
    cmdclass={'build_ext' : build_ext},
    packages=['shrike'],
    ext_modules = [
        Extension ('shrike.coro', ['shrike/coro.pyx', 'shrike/swap.c'], include_dirs=['shrike', '.']),
        ]
    )
