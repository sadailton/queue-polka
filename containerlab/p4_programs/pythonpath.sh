#!/bin/env bash

ARCH="tofino2"

PYTHON_LIB_DIR=$(python3 -c "from distutils import sysconfig; print(sysconfig.get_python_lib(prefix='', standard_lib=True, plat_specific=True))")

export PYTHONPATH=$SDE_INSTALL/$PYTHON_LIB_DIR/site-packages/tofino/bfrt_grpc:$PYTHONPATH
export PYTHONPATH=$SDE_INSTALL/$PYTHON_LIB_DIR/site-packages:$PYTHONPATH
export PYTHONPATH=$SDE_INSTALL/$PYTHON_LIB_DIR/site-packages/tofino:$PYTHONPATH
export PYTHONPATH=$SDE_INSTALL/$PYTHON_LIB_DIR/site-packages/${ARCH}pd:$PYTHONPATH
export PYTHONPATH=$SDE_INSTALL/$PYTHON_LIB_DIR/site-packages/p4testutils:$PYTHONPATH
PYTHONPATH=$($SDE_INSTALL/bin/sdepythonpath.py):$PYTHONPATH